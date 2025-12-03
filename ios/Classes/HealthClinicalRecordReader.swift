import HealthKit
import Foundation

@available(iOS 12.0, *)
class HealthClinicalRecordReader {

    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Flutter Entry

    func getClinicalRecords(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let typeKeys = arguments["types"] as? [String],
              let startTimestamp = arguments["startTime"] as? Double,
              let endTimestamp = arguments["endTime"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments", details: nil))
            return
        }

        let startDate = Date(timeIntervalSince1970: startTimestamp / 1000)
        let endDate = Date(timeIntervalSince1970: endTimestamp / 1000)

        let clinicalTypes = typeKeys.compactMap { HealthKitClinicalTypes.clinicalType(for: $0) }

        if clinicalTypes.isEmpty {
            result(FlutterError(code: "NO_VALID_TYPES", message: "No valid types provided", details: nil))
            return
        }

        // DEBUG
        for type in clinicalTypes {
            let status = healthStore.authorizationStatus(for: type)
            NSLog("HealthClinicalRecordReader: Status \(type.identifier) = \(status.rawValue)")
            if status == .notDetermined {
                result(FlutterError(code: "AUTH_NOT_DETERMINED",
                                    message: "Call requestClinicalAuthorization() first",
                                    details: nil))
                return
            }
        }

        queryClinicalRecords(types: clinicalTypes, startDate: startDate, endDate: endDate) { records, error in
            if let error = error {
                result(FlutterError(code: "QUERY_ERROR", message: "Query failed: \(error.localizedDescription)", details: nil))
                return
            }
            result(records ?? [])
        }
    }

    // MARK: - Permissions

    func requestClinicalAuthorization(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let typeKeys = arguments["types"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing types", details: nil))
            return
        }

        let clinicalTypes = Set(typeKeys.compactMap { HealthKitClinicalTypes.clinicalType(for: $0) })

        if clinicalTypes.isEmpty {
            result(false)
            return
        }

        healthStore.requestAuthorization(toShare: nil, read: clinicalTypes) { success, error in
            if let error = error {
                NSLog("HealthClinicalRecordReader ERROR: \(error)")
                result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            result(success)
        }
    }

    func hasClinicalPermissions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let typeKeys = arguments["types"] as? [String] else {
            result(false)
            return
        }

        for key in typeKeys {
            guard let type = HealthKitClinicalTypes.clinicalType(for: key) else { continue }
            if healthStore.authorizationStatus(for: type) != .sharingAuthorized {
                result(false)
                return
            }
        }
        result(true)
    }

    // MARK: - Query

    private func queryClinicalRecords(types: [HKClinicalType], startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]?, Error?) -> Void) {

        let group = DispatchGroup()
        let lock = NSLock()

        var allRecords: [[String: Any]] = []
        var queryError: Error?

        for type in types {
            group.enter()

            // 1. Create a predicate for the date range
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

            // 2. Pass the predicate to the query
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in

                lock.lock()
                defer { lock.unlock() }

                if let error = error {
                    queryError = error
                } else if let results = samples as? [HKClinicalRecord] {
                    let formatted = results.compactMap { self.formatClinicalRecord($0) }
                    allRecords.append(contentsOf: formatted)
                }
                group.leave()
            }

            healthStore.execute(query)
        }

        group.notify(queue: .main) {
            if let error = queryError {
                completion(nil, error)
            } else {
                completion(allRecords, nil)
            }
        }
    }

    // MARK: - Format Output

    private func formatClinicalRecord(_ record: HKClinicalRecord) -> [String: Any]? {
        var dict: [String: Any] = [:]

        dict["uuid"] = record.uuid.uuidString
        dict["displayName"] = record.displayName

        dict["startDate"] = Int64(record.startDate.timeIntervalSince1970 * 1000)
        dict["endDate"] = Int64(record.endDate.timeIntervalSince1970 * 1000)

        dict["sourceName"] = record.sourceRevision.source.name
        dict["sourceBundleIdentifier"] = record.sourceRevision.source.bundleIdentifier

        let typeID = HKClinicalTypeIdentifier(rawValue: record.clinicalType.identifier)
        if let typeKey = HealthKitClinicalTypes.clinicalTypeKey(for: typeID) {
            dict["clinicalType"] = typeKey
        }

        // 🚨 REAL FIX: include FHIR JSON
        if let fhir = record.fhirResource {
            dict["fhir"] = extractFHIRData(from: fhir)
        } else {
            dict["fhir"] = nil
        }

        return dict
    }

    // MARK: - FHIR JSON Extract

    private func extractFHIRData(from fhir: HKFHIRResource) -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["identifier"] = fhir.identifier
        dict["sourceURL"] = fhir.sourceURL?.absoluteString

        if #available(iOS 14.0, *) {
            dict["resourceType"] = HealthKitClinicalTypes.fhirResourceKey(for: fhir.resourceType)

            if fhir.fhirVersion == .primaryDSTU2() {
                dict["fhirVersion"] = "DSTU2"
            } else if fhir.fhirVersion == .primaryR4() {
                dict["fhirVersion"] = "R4"
            } else {
                dict["fhirVersion"] = "Unknown"
            }
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: fhir.data, options: []) as? [String: Any] {
                dict["data"] = json        /// ← Full FHIR JSON object
            }
        } catch {
            dict["rawData"] = String(data: fhir.data, encoding: .utf8)
        }

        return dict
    }
}
