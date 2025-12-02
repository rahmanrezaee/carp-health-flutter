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
    /// - Parameters:
    ///   - call: Flutter method call containing parameters
    ///   - result: Flutter result callback
    func getClinicalRecords(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let typeKeys = arguments["types"] as? [String],
              let startTimestamp = arguments["startTime"] as? Double,
              let endTimestamp = arguments["endTime"] as? Double else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing or invalid arguments for getClinicalRecords",
                details: nil
            ))
            return
        }
        
        let startDate = Date(timeIntervalSince1970: startTimestamp / 1000)
        let endDate = Date(timeIntervalSince1970: endTimestamp / 1000)
        
        // Convert type keys to HKClinicalType objects
        let clinicalTypes = typeKeys.compactMap { key -> HKClinicalType? in
            HealthKitClinicalTypes.clinicalType(for: key)
        }
        
        guard !clinicalTypes.isEmpty else {
            result(FlutterError(
                code: "NO_VALID_TYPES",
                message: "No valid clinical record types specified",
                details: nil
            ))
            return
        }
        
        // Query all requested types
        queryClinicalRecords(
            types: clinicalTypes,
            startDate: startDate,
            endDate: endDate
        ) { records, error in
            if let error = error {
                result(FlutterError(
                    code: "QUERY_ERROR",
                    message: "Failed to query clinical records: \(error.localizedDescription)",
                    details: nil
                ))
                return
            }
            
            result(records ?? [])
        }
    }
    
    // MARK: - Authorization Methods
    
    /// Request authorization for clinical records
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func requestClinicalAuthorization(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let typeKeys = arguments["types"] as? [String] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing or invalid arguments for requestClinicalAuthorization",
                details: nil
            ))
            return
        }
        
        let clinicalTypes = typeKeys.compactMap { key -> HKClinicalType? in
            HealthKitClinicalTypes.clinicalType(for: key)
        }
        
        guard !clinicalTypes.isEmpty else {
            result(FlutterError(
                code: "NO_VALID_TYPES",
                message: "No valid clinical record types specified",
                details: nil
            ))
            return
        }
        
        let typesToRead = Set(clinicalTypes)
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                result(FlutterError(
                    code: "AUTH_ERROR",
                    message: "Error requesting authorization: \(error.localizedDescription)",
                    details: nil
                ))
                return
            }
            
            result(success)
        }
    }
    
    /// Check if the app has permission for clinical records
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func hasClinicalPermissions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let typeKeys = arguments["types"] as? [String] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing or invalid arguments for hasClinicalPermissions",
                details: nil
            ))
            return
        }
        
        let clinicalTypes = typeKeys.compactMap { key -> HKClinicalType? in
            HealthKitClinicalTypes.clinicalType(for: key)
        }
        
        guard !clinicalTypes.isEmpty else {
            result(false)
            return
        }
        
        for type in clinicalTypes {
            let status = healthStore.authorizationStatus(for: type)
            if status != .sharingAuthorized {
                result(false)
                return
            }
        }
        
        result(true)
    }
    
    // MARK: - Query Helpers
    
    /// Query clinical records for multiple types
    private func queryClinicalRecords(
        types: [HKClinicalType],
        startDate: Date,
        endDate: Date,
        completion: @escaping ([[String: Any]]?, Error?) -> Void
    ) {
        let group = DispatchGroup()
        var allRecords: [[String: Any]] = []
        var queryError: Error?
        let lock = NSLock()
        
        for clinicalType in types {
            group.enter()
            
            queryClinicalRecordsByType(
                type: clinicalType,
                startDate: startDate,
                endDate: endDate
            ) { records, error in
                lock.lock()
                defer { lock.unlock() }
                
                if let error = error {
                    queryError = error
                } else if let records = records {
                    allRecords.append(contentsOf: records)
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = queryError {
                completion(nil, error)
            } else {
                completion(allRecords, nil)
            }
        }
    }
    
    /// Query clinical records for a specific type
    private func queryClinicalRecordsByType(
        type: HKClinicalType,
        startDate: Date,
        endDate: Date,
        completion: @escaping ([[String: Any]]?, Error?) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let clinicalRecords = samples as? [HKClinicalRecord] else {
                completion([], nil)
                return
            }
            
            let formattedRecords = clinicalRecords.compactMap { record in
                self.formatClinicalRecord(record)
            }
            
            completion(formattedRecords, nil)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Formatting Methods
    
    /// Format a HKClinicalRecord into a dictionary for Flutter
    private func formatClinicalRecord(_ record: HKClinicalRecord) -> [String: Any]? {
        var dict: [String: Any] = [:]
        
        // Basic record information
        dict["uuid"] = record.uuid.uuidString
        dict["startDate"] = Int64(record.startDate.timeIntervalSince1970 * 1000)
        dict["endDate"] = Int64(record.endDate.timeIntervalSince1970 * 1000)
        
        // Clinical type
        if let typeKey = HealthKitClinicalTypes.clinicalTypeKey(for: record.clinicalType.identifier) {
            dict["clinicalType"] = typeKey
        }
        
        // Display name
        dict["displayName"] = record.displayName
        
        // Source information
        dict["sourceName"] = record.sourceRevision.source.name
        dict["sourceBundleIdentifier"] = record.sourceRevision.source.bundleIdentifier
        
        // FHIR resource
        if let fhirResource = record.fhirResource {
            if let fhirData = extractFHIRData(from: fhirResource) {
                dict["fhirResource"] = fhirData
            }
        }
        
        return dict
    }
    
    /// Extract FHIR data from HKFHIRResource
    private func extractFHIRData(from fhirResource: HKFHIRResource) -> [String: Any]? {
        var fhirDict: [String: Any] = [:]
        
        // FHIR resource identifier
        fhirDict["identifier"] = fhirResource.identifier
        
        // FHIR version
        if #available(iOS 14.0, *) {
            fhirDict["fhirVersion"] = fhirVersionString(from: fhirResource.fhirVersion)
            
            // FHIR resource type
            if let resourceTypeKey = HealthKitClinicalTypes.fhirResourceKey(for: fhirResource.resourceType) {
                fhirDict["resourceType"] = resourceTypeKey
            }
        }
        
        // Source URL
        if let sourceURL = fhirResource.sourceURL {
            fhirDict["sourceURL"] = sourceURL.absoluteString
        }
        
        // Raw FHIR JSON data
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: fhirResource.data, options: []) as? [String: Any] {
                fhirDict["data"] = jsonObject
            }
        } catch {
            print("Error parsing FHIR JSON: \(error)")
            // Still try to include the raw data as a string
            if let jsonString = String(data: fhirResource.data, encoding: .utf8) {
                fhirDict["rawData"] = jsonString
            }
        }
        
        return fhirDict
    }
    
    /// Convert HKFHIRVersion to string
    @available(iOS 14.0, *)
    private func fhirVersionString(from version: HKFHIRVersion) -> String {
        switch version {
        case .primaryDSTU2:
            return "DSTU2"
        case .primaryR4:
            return "R4"
        @unknown default:
            return "Unknown"
        }
    }
}
