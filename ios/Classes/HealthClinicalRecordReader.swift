import HealthKit
import Foundation

/// Class responsible for reading clinical records from HealthKit
@available(iOS 12.0, *)
class HealthClinicalRecordReader {

    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Main Query Method

    /// Get clinical records from HealthKit
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

        // Convert keys to HKClinicalType
        let clinicalTypes = typeKeys.compactMap { HealthKitClinicalTypes.clinicalType(for: $0) }

        if clinicalTypes.isEmpty {
            result(FlutterError(code: "NO_VALID_TYPES", message: "No valid types provided", details: nil))
            return
        }

        // DEBUG: Check status before querying
        for type in clinicalTypes {
            let status = healthStore.authorizationStatus(for: type)
            NSLog("HealthClinicalRecordReader: Status for \(type.identifier) is \(status.rawValue) (0=notDetermined, 1=denied, 2=authorized)")

            if status == .notDetermined {
                result(FlutterError(code: "AUTH_NOT_DETERMINED", message: "Authorization not determined for \(type.identifier). Did you enable the Capability in Apple Developer Portal?", details: nil))
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

    // MARK: - Authorization Methods

    func requestClinicalAuthorization(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let typeKeys = arguments["types"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing types", details: nil))
            return
        }

        let clinicalTypes = typeKeys.compactMap { HealthKitClinicalTypes.clinicalType(for: $0) }
        let typesToRead = Set(clinicalTypes)

        if typesToRead.isEmpty {
            result(false)
            return
        }

        // Clinical records are read-only, so toShare is always nil
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                NSLog("HealthClinicalRecordReader: Auth Error: \(error.localizedDescription)")
                result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            // Success just means the prompt was presented (or suppressed), not that the user said yes.
            NSLog("HealthClinicalRecordReader: Request Auth Success: \(success)")
            result(success)
        }
    }

    func hasClinicalPermissions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let typeKeys = arguments["types"] as? [String] else {
            result(false)
            return
        }

        let clinicalTypes = typeKeys.compactMap { HealthKitClinicalTypes.clinicalType(for: $0) }

        for type in clinicalTypes {
            let status = healthStore.authorizationStatus(for: type)
            if status != .sharingAuthorized {
                // If any type is not authorized, return false
                result(false)
                return
            }
        }
        result(true)
    }

    // MARK: - Query Logic

    private func queryClinicalRecords(types: [HKClinicalType], startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        let group = DispatchGroup()
        var allRecords: [[String: Any]] = []
        var queryError: Error?
        let lock = NSLock()

        for type in types {
            group.enter()

        // FIX 1: Use 'nil' predicate to match Native behavior (Fetch ALL history)
        // Alternatively, ensure your Flutter 'startDate' is set to 50 years ago.
        let predicate: NSPredicate? = nil

            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in

                lock.lock()
                defer { lock.unlock() }

                if let error = error {
                    NSLog("Error querying \(type.identifier): \(error)")
                    queryError = error
                } else if let clinicalRecords = samples as? [HKClinicalRecord] {
                // Debug log
                NSLog("Found \(clinicalRecords.count) records for \(type.identifier)")

                    let formatted = clinicalRecords.compactMap { self.formatClinicalRecord($0) }
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

    // MARK: - Formatter

    private func formatClinicalRecord(_ record: HKClinicalRecord) -> [String: Any]? {
            var dict: [String: Any] = [:]
            dict["uuid"] = record.uuid.uuidString
            dict["startDate"] = Int64(record.startDate.timeIntervalSince1970 * 1000)
            dict["endDate"] = Int64(record.endDate.timeIntervalSince1970 * 1000)
            dict["displayName"] = record.displayName
            dict["sourceName"] = record.sourceRevision.source.name
            dict["sourceBundleIdentifier"] = record.sourceRevision.source.bundleIdentifier

            let typeID = HKClinicalTypeIdentifier(rawValue: record.clinicalType.identifier)
            if let typeKey = HealthKitClinicalTypes.clinicalTypeKey(for: typeID) {
                dict["clinicalType"] = typeKey
            }


            return dict
        }

    private func extractFHIRData(from fhir: HKFHIRResource) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["identifier"] = fhir.identifier
        dict["sourceURL"] = fhir.sourceURL?.absoluteString

        if #available(iOS 14.0, *) {
            dict["resourceType"] = HealthKitClinicalTypes.fhirResourceKey(for: fhir.resourceType)

            // Fix: Handle HKFHIRVersion struct comparison
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
                dict["data"] = json
            }
        } catch {
            dict["rawData"] = String(data: fhir.data, encoding: .utf8)
        }

        return dict
    }
}