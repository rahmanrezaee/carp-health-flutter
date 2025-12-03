import HealthKit

/// Constants and mappings for HealthKit Clinical Records and FHIR resources
@available(iOS 12.0, *)
enum HealthKitClinicalTypes {
    
    // MARK: - Clinical Record Type Identifiers (matching Dart enum)
    
    /// String constants for clinical record types used in Flutter communication
    enum ClinicalTypeKeys {
        static let allergyIntolerance = "CLINICAL_ALLERGY_INTOLERANCE"
        static let condition = "CLINICAL_CONDITION"
        static let coverage = "CLINICAL_COVERAGE"
        static let immunization = "CLINICAL_IMMUNIZATION"
        static let labResult = "CLINICAL_LAB_RESULT"
        static let medication = "CLINICAL_MEDICATION"
        static let procedure = "CLINICAL_PROCEDURE"
        static let vitalSign = "CLINICAL_VITAL_SIGN"
    }
    
    // MARK: - FHIR Resource Type Keys
    
    /// String constants for FHIR resource types
    enum FHIRResourceKeys {
        static let allergyIntolerance = "AllergyIntolerance"
        static let condition = "Condition"
        static let coverage = "Coverage"
        static let diagnosticReport = "DiagnosticReport"
        static let documentReference = "DocumentReference"
        static let immunization = "Immunization"
        static let medication = "Medication"
        static let medicationDispense = "MedicationDispense"
        static let medicationOrder = "MedicationOrder"
        static let medicationRequest = "MedicationRequest"
        static let medicationStatement = "MedicationStatement"
        static let observation = "Observation"
        static let procedure = "Procedure"
    }
    
    // MARK: - HKClinicalTypeIdentifier Mapping
    
    /// Maps Flutter clinical type keys to HKClinicalTypeIdentifier
    static func clinicalTypeIdentifier(for key: String) -> HKClinicalTypeIdentifier? {
        switch key {
        case ClinicalTypeKeys.allergyIntolerance:
            return .allergyRecord
        case ClinicalTypeKeys.condition:
            return .conditionRecord
        case ClinicalTypeKeys.coverage:
            return .coverageRecord
        case ClinicalTypeKeys.immunization:
            return .immunizationRecord
        case ClinicalTypeKeys.labResult:
            return .labResultRecord
        case ClinicalTypeKeys.medication:
            return .medicationRecord
        case ClinicalTypeKeys.procedure:
            return .procedureRecord
        case ClinicalTypeKeys.vitalSign:
            return .vitalSignRecord
        default:
            return nil
        }
    }
    
    /// Maps HKClinicalTypeIdentifier to Flutter clinical type key
    static func clinicalTypeKey(for identifier: HKClinicalTypeIdentifier) -> String? {
        switch identifier {
        case .allergyRecord:
            return ClinicalTypeKeys.allergyIntolerance
        case .conditionRecord:
            return ClinicalTypeKeys.condition
        case .coverageRecord:
            return ClinicalTypeKeys.coverage
        case .immunizationRecord:
            return ClinicalTypeKeys.immunization
        case .labResultRecord:
            return ClinicalTypeKeys.labResult
        case .medicationRecord:
            return ClinicalTypeKeys.medication
        case .procedureRecord:
            return ClinicalTypeKeys.procedure
        case .vitalSignRecord:
            return ClinicalTypeKeys.vitalSign
        default:
            return nil
        }
    }
    
    // MARK: - HKFHIRResourceType Mapping

    /// Maps FHIR resource type string to HKFHIRResourceType
    @available(iOS 14.0, *)
    static func fhirResourceType(for key: String) -> HKFHIRResourceType? {
        switch key {
        case FHIRResourceKeys.allergyIntolerance:
            return .allergyIntolerance
        case FHIRResourceKeys.condition:
            return .condition
        case FHIRResourceKeys.coverage:
            return .coverage
        case FHIRResourceKeys.immunization:
            return .immunization
        case FHIRResourceKeys.medicationDispense:
            return .medicationDispense
        case FHIRResourceKeys.medicationOrder:
            return .medicationOrder
        case FHIRResourceKeys.medicationRequest:
            return .medicationRequest
        case FHIRResourceKeys.medicationStatement:
            return .medicationStatement
        case FHIRResourceKeys.observation:
            return .observation
        case FHIRResourceKeys.procedure:
            return .procedure

        // MARK: iOS 16.0+ Types
        case FHIRResourceKeys.medication:
            // Use rawValue to avoid "has no member" error if SDK is older
            if #available(iOS 16.0, *) {
                return HKFHIRResourceType(rawValue: "Medication")
            }
            return nil

        // MARK: iOS 16.4+ Types
        case FHIRResourceKeys.diagnosticReport:
            if #available(iOS 16.4, *) {
                return HKFHIRResourceType(rawValue: "DiagnosticReport")
            }
            return nil
        case FHIRResourceKeys.documentReference:
            if #available(iOS 16.4, *) {
                return HKFHIRResourceType(rawValue: "DocumentReference")
            }
            return nil

        default:
            return nil
        }
    }

    /// Maps HKFHIRResourceType to FHIR resource type string
    @available(iOS 14.0, *)
    static func fhirResourceKey(for resourceType: HKFHIRResourceType) -> String? {
        switch resourceType {
        case .allergyIntolerance:
            return FHIRResourceKeys.allergyIntolerance
        case .condition:
            return FHIRResourceKeys.condition
        case .coverage:
            return FHIRResourceKeys.coverage
        case .immunization:
            return FHIRResourceKeys.immunization
        case .medicationDispense:
            return FHIRResourceKeys.medicationDispense
        case .medicationOrder:
            return FHIRResourceKeys.medicationOrder
        case .medicationRequest:
            return FHIRResourceKeys.medicationRequest
        case .medicationStatement:
            return FHIRResourceKeys.medicationStatement
        case .observation:
            return FHIRResourceKeys.observation
        case .procedure:
            return FHIRResourceKeys.procedure

        default:
            // Handle newer iOS versions dynamically using raw values
            // This prevents compiler errors when checking for members like .medication

            // Medication (iOS 16.0+)
            if #available(iOS 16.0, *) {
                if resourceType.rawValue == "Medication" {
                    return FHIRResourceKeys.medication
                }
            }

            // DiagnosticReport & DocumentReference (iOS 16.4+)
            if #available(iOS 16.4, *) {
                if resourceType.rawValue == "DiagnosticReport" {
                    return FHIRResourceKeys.diagnosticReport
                }
                if resourceType.rawValue == "DocumentReference" {
                    return FHIRResourceKeys.documentReference
                }
            }

            return nil
        }
    }

    // MARK: - Helper Methods

    /// Get HKClinicalType for a given Flutter clinical type key
    static func clinicalType(for key: String) -> HKClinicalType? {
        guard let identifier = clinicalTypeIdentifier(for: key) else {
            return nil
        }
        return HKObjectType.clinicalType(forIdentifier: identifier)
    }

    /// Get all supported clinical type identifiers
    static func allClinicalTypeIdentifiers() -> [HKClinicalTypeIdentifier] {
        return [
            .allergyRecord,
            .conditionRecord,
            .coverageRecord,
            .immunizationRecord,
            .labResultRecord,
            .medicationRecord,
            .procedureRecord,
            .vitalSignRecord
        ]
    }

    /// Get all supported clinical types
    static func allClinicalTypes() -> Set<HKClinicalType> {
        return Set(allClinicalTypeIdentifiers().compactMap { identifier in
            HKObjectType.clinicalType(forIdentifier: identifier)
        })
    }
}