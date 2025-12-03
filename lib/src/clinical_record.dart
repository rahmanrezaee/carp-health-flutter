part of '../health.dart';

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class ClinicalRecord {
  final String uuid;
  final ClinicalRecordType clinicalType;
  final DateTime startDate;
  final DateTime endDate;
  final String? displayName;
  final String? sourceName;
  final String? sourceBundleIdentifier;
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
      fhirResource: json['fhir'] != null
          ? FHIRResource.fromJson(
        Map<String, dynamic>.from(
          json['fhir'] as Map<dynamic, dynamic>,
        ),
      )
          : null,
    );
  }


  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'clinicalType': clinicalType.key,
    'startDate': startDate.millisecondsSinceEpoch,
    'endDate': endDate.millisecondsSinceEpoch,
    if (displayName != null) 'displayName': displayName,
    if (sourceName != null) 'sourceName': sourceName,
    if (sourceBundleIdentifier != null)
      'sourceBundleIdentifier': sourceBundleIdentifier,
    if (fhirResource != null) 'fhir': fhirResource!.toJson(),
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

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class FHIRResource {
  final String identifier;
  final FHIRVersion? fhirVersion;
  final FHIRResourceType? resourceType;
  final String? sourceURL;
  final Map<String, dynamic>? data;
  final String? rawData;

  FHIRResource({
    required this.identifier,
    this.fhirVersion,
    this.resourceType,
    this.sourceURL,
    this.data,
    this.rawData,
  });

  factory FHIRResource.fromJson(Map<String, dynamic> json) {
    return FHIRResource(
      identifier: json['identifier'] as String,
      fhirVersion: FHIRVersionExtension.fromKey(json['fhirVersion'] as String?),
      resourceType: FHIRResourceTypeExtension.fromKey(
        json['resourceType'] as String?,
      ),
      sourceURL: json['sourceURL'] as String?,
      data: json['data'] != null
          ? Map<String, dynamic>.from(
        json['data'] as Map<dynamic, dynamic>,
      )
          : null,
      rawData: json['rawData'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    if (fhirVersion != null) 'fhirVersion': fhirVersion!.toString(),
    if (resourceType != null) 'resourceType': resourceType!.toString(),
    if (sourceURL != null) 'sourceURL': sourceURL,
    if (data != null) 'data': data,
    if (rawData != null) 'rawData': rawData,
  };

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
