part of '../health.dart';

/// A clinical record from Apple Health containing FHIR data
///
/// Clinical records are read-only and contain health information from
/// healthcare providers in FHIR (Fast Healthcare Interoperability Resources) format.
///
/// **iOS Only**: Clinical records are only available on iOS 12+
/// and require explicit user authorization.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class ClinicalRecord {
  /// Unique identifier for this clinical record
  final String uuid;

  /// The type of clinical record
  final ClinicalRecordType clinicalType;

  /// Start date of the clinical record
  final DateTime startDate;

  /// End date of the clinical record
  final DateTime endDate;

  /// Display name for the clinical record (e.g., "Peanut allergy")
  final String? displayName;

  /// Name of the source (healthcare provider)
  final String? sourceName;

  /// Bundle identifier of the source app
  final String? sourceBundleIdentifier;

  /// FHIR resource data
  final FHIRResource? fhirResource;

  ClinicalRecord({
    required this.uuid,
    required this.clinicalType,
    required this.startDate,
    required this.endDate,
    this.displayName,
    this.sourceName,
    this.sourceBundleIdentifier,
    this.fhirResource,
  });

  /// Create a ClinicalRecord from JSON
  factory ClinicalRecord.fromJson(Map<String, dynamic> json) {
    return ClinicalRecord(
      uuid: json['uuid'] as String,
      clinicalType:
          ClinicalRecordTypeExtension.fromKey(json['clinicalType'] as String) ??
          ClinicalRecordType.condition,
      startDate: DateTime.fromMillisecondsSinceEpoch(json['startDate'] as int),
      endDate: DateTime.fromMillisecondsSinceEpoch(json['endDate'] as int),
      displayName: json['displayName'] as String?,
      sourceName: json['sourceName'] as String?,
      sourceBundleIdentifier: json['sourceBundleIdentifier'] as String?,
      fhirResource: json['fhirResource'] != null
          ? FHIRResource.fromJson(json['fhirResource'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'clinicalType': clinicalType.key,
    'startDate': startDate.millisecondsSinceEpoch,
    'endDate': endDate.millisecondsSinceEpoch,
    if (displayName != null) 'displayName': displayName,
    if (sourceName != null) 'sourceName': sourceName,
    if (sourceBundleIdentifier != null)
      'sourceBundleIdentifier': sourceBundleIdentifier,
    if (fhirResource != null) 'fhirResource': fhirResource!.toJson(),
  };

  @override
  String toString() =>
      '''ClinicalRecord(
    uuid: $uuid,
    type: $clinicalType,
    displayName: ${displayName ?? 'N/A'},
    source: ${sourceName ?? 'Unknown'},
    fhirResourceType: ${fhirResource?.resourceType ?? 'N/A'}
  )''';
}

/// FHIR resource data extracted from a clinical record
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class FHIRResource {
  /// FHIR resource identifier (unique ID from the healthcare system)
  final String identifier;

  /// FHIR version (DSTU2, R4, etc.)
  final FHIRVersion? fhirVersion;

  /// FHIR resource type
  final FHIRResourceType? resourceType;

  /// Source URL from the healthcare provider
  final String? sourceURL;

  /// Raw FHIR JSON data
  ///
  /// This is the complete FHIR resource as a Map.
  /// You can parse this according to the FHIR specification
  /// or use a FHIR parsing library.
  final Map<String, dynamic>? data;

  /// Raw FHIR data as a string (fallback if JSON parsing fails)
  final String? rawData;

  FHIRResource({
    required this.identifier,
    this.fhirVersion,
    this.resourceType,
    this.sourceURL,
    this.data,
    this.rawData,
  });

  /// Create a FHIRResource from JSON
  factory FHIRResource.fromJson(Map<String, dynamic> json) {
    return FHIRResource(
      identifier: json['identifier'] as String,
      fhirVersion: FHIRVersionExtension.fromKey(json['fhirVersion'] as String?),
      resourceType: FHIRResourceTypeExtension.fromKey(
        json['resourceType'] as String?,
      ),
      sourceURL: json['sourceURL'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      rawData: json['rawData'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    if (fhirVersion != null) 'fhirVersion': fhirVersion.toString(),
    if (resourceType != null) 'resourceType': resourceType.toString(),
    if (sourceURL != null) 'sourceURL': sourceURL,
    if (data != null) 'data': data,
    if (rawData != null) 'rawData': rawData,
  };

  /// Get a specific field from the FHIR data
  ///
  /// Example:
  /// ```dart
  /// // Get the patient reference
  /// String? patientRef = fhirResource.getField('subject.reference');
  ///
  /// // Get status
  /// String? status = fhirResource.getField('status');
  /// ```
  dynamic getField(String path) {
    if (data == null) return null;

    final parts = path.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  /// Extract codes from FHIR CodeableConcept
  ///
  /// Many FHIR resources use CodeableConcept for coded values.
  /// This helper extracts all codes from a CodeableConcept field.
  ///
  /// Example:
  /// ```dart
  /// // Get allergy codes
  /// List<Map<String, dynamic>> codes = fhirResource.getCodes('code');
  /// for (var code in codes) {
  ///   print('System: ${code['system']}, Code: ${code['code']}');
  /// }
  /// ```
  List<Map<String, dynamic>> getCodes(String fieldPath) {
    final codes = <Map<String, dynamic>>[];
    final codeableConcept = getField(fieldPath);

    if (codeableConcept is Map<String, dynamic>) {
      final coding = codeableConcept['coding'];
      if (coding is List) {
        for (final code in coding) {
          if (code is Map<String, dynamic>) {
            codes.add({
              'system': code['system'] as String?,
              'code': code['code'] as String?,
              'display': code['display'] as String?,
            });
          }
        }
      }
    }

    return codes;
  }

  /// Get text summary from FHIR CodeableConcept
  ///
  /// Example:
  /// ```dart
  /// String? allergyName = fhirResource.getCodeText('code');
  /// ```
  String? getCodeText(String fieldPath) {
    final codeableConcept = getField(fieldPath);
    if (codeableConcept is Map<String, dynamic>) {
      return codeableConcept['text'] as String?;
    }
    return null;
  }

  @override
  String toString() =>
      '''FHIRResource(
    identifier: $identifier,
    version: ${fhirVersion ?? 'Unknown'},
    type: ${resourceType ?? 'Unknown'},
    hasData: ${data != null}
  )''';
}
