part of '../health.dart';

/// Clinical record types available from Apple Health
enum ClinicalRecordType {
  /// Allergies and intolerances to substances
  allergyIntolerance,

  /// Conditions, problems, or diagnoses
  condition,

  /// Insurance coverage information
  coverage,

  /// Immunizations and vaccinations
  immunization,

  /// Laboratory results
  labResult,

  /// Medications
  medication,

  /// Medical procedures
  procedure,

  /// Vital signs observations
  vitalSign,
}

/// FHIR resource types
/// These represent the specific type of FHIR resource contained in a clinical record
enum FHIRResourceType {
  /// AllergyIntolerance resource
  allergyIntolerance,

  /// Condition resource (diagnosis, problem)
  condition,

  /// Coverage resource (insurance)
  coverage,

  /// DiagnosticReport resource
  diagnosticReport,

  /// DocumentReference resource
  documentReference,

  /// Immunization resource
  immunization,

  /// Medication resource
  medication,

  /// MedicationDispense resource
  medicationDispense,

  /// MedicationOrder resource (DSTU2)
  medicationOrder,

  /// MedicationRequest resource (R4)
  medicationRequest,

  /// MedicationStatement resource
  medicationStatement,

  /// Observation resource (lab results, vitals)
  observation,

  /// Procedure resource
  procedure,

  /// Unknown or unsupported resource type
  unknown,
}

/// FHIR version
enum FHIRVersion {
  /// FHIR DSTU2
  dstu2,

  /// FHIR R4
  r4,

  /// Unknown version
  unknown,
}

/// Extension methods for ClinicalRecordType
extension ClinicalRecordTypeExtension on ClinicalRecordType {
  /// Convert to string key used in native code
  String get key {
    switch (this) {
      case ClinicalRecordType.allergyIntolerance:
        return 'CLINICAL_ALLERGY_INTOLERANCE';
      case ClinicalRecordType.condition:
        return 'CLINICAL_CONDITION';
      case ClinicalRecordType.coverage:
        return 'CLINICAL_COVERAGE';
      case ClinicalRecordType.immunization:
        return 'CLINICAL_IMMUNIZATION';
      case ClinicalRecordType.labResult:
        return 'CLINICAL_LAB_RESULT';
      case ClinicalRecordType.medication:
        return 'CLINICAL_MEDICATION';
      case ClinicalRecordType.procedure:
        return 'CLINICAL_PROCEDURE';
      case ClinicalRecordType.vitalSign:
        return 'CLINICAL_VITAL_SIGN';
    }
  }

  /// Create from string key
  static ClinicalRecordType? fromKey(String key) {
    switch (key) {
      case 'CLINICAL_ALLERGY_INTOLERANCE':
        return ClinicalRecordType.allergyIntolerance;
      case 'CLINICAL_CONDITION':
        return ClinicalRecordType.condition;
      case 'CLINICAL_COVERAGE':
        return ClinicalRecordType.coverage;
      case 'CLINICAL_IMMUNIZATION':
        return ClinicalRecordType.immunization;
      case 'CLINICAL_LAB_RESULT':
        return ClinicalRecordType.labResult;
      case 'CLINICAL_MEDICATION':
        return ClinicalRecordType.medication;
      case 'CLINICAL_PROCEDURE':
        return ClinicalRecordType.procedure;
      case 'CLINICAL_VITAL_SIGN':
        return ClinicalRecordType.vitalSign;
      default:
        return null;
    }
  }
}

/// Extension methods for FHIRResourceType
extension FHIRResourceTypeExtension on FHIRResourceType {
  /// Create from string key
  static FHIRResourceType fromKey(String? key) {
    if (key == null) return FHIRResourceType.unknown;

    switch (key) {
      case 'AllergyIntolerance':
        return FHIRResourceType.allergyIntolerance;
      case 'Condition':
        return FHIRResourceType.condition;
      case 'Coverage':
        return FHIRResourceType.coverage;
      case 'DiagnosticReport':
        return FHIRResourceType.diagnosticReport;
      case 'DocumentReference':
        return FHIRResourceType.documentReference;
      case 'Immunization':
        return FHIRResourceType.immunization;
      case 'Medication':
        return FHIRResourceType.medication;
      case 'MedicationDispense':
        return FHIRResourceType.medicationDispense;
      case 'MedicationOrder':
        return FHIRResourceType.medicationOrder;
      case 'MedicationRequest':
        return FHIRResourceType.medicationRequest;
      case 'MedicationStatement':
        return FHIRResourceType.medicationStatement;
      case 'Observation':
        return FHIRResourceType.observation;
      case 'Procedure':
        return FHIRResourceType.procedure;
      default:
        return FHIRResourceType.unknown;
    }
  }
}

/// Extension methods for FHIRVersion
extension FHIRVersionExtension on FHIRVersion {
  /// Create from string key
  static FHIRVersion fromKey(String? key) {
    if (key == null) return FHIRVersion.unknown;

    switch (key.toUpperCase()) {
      case 'DSTU2':
        return FHIRVersion.dstu2;
      case 'R4':
        return FHIRVersion.r4;
      default:
        return FHIRVersion.unknown;
    }
  }
}
