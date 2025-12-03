import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health/health.dart';

// Global Health instance
final health = Health();

void main() => runApp(const ClinicalHealthApp());

class ClinicalHealthApp extends StatefulWidget {
  const ClinicalHealthApp({super.key});

  @override
  ClinicalHealthAppState createState() => ClinicalHealthAppState();
}

enum AppState {
  INITIAL,
  AUTHORIZED,
  FETCHING_DATA,
  DATA_READY,
  NO_DATA,
  ERROR,
}

class ClinicalHealthAppState extends State<ClinicalHealthApp> {
  List<ClinicalRecord> _clinicalDataList = [];
  AppState _state = AppState.INITIAL;
  String _statusMessage = "Press 'Authorize' to start.";

  @override
  void initState() {
    super.initState();
    // Configure the health plugin
    health.configure();
  }

  /// 1. Authorize: Request access to Clinical Records
  Future<void> authorize() async {
    if (!Platform.isIOS) {
      setState(() {
        _statusMessage = "Clinical Records are only available on iOS.";
        _state = AppState.ERROR;
      });
      return;
    }

    setState(() => _statusMessage = "Requesting Authorization...");

    try {
      // Check if we already have permission (optional logic)
      bool hasPermissions = await health.hasClinicalPermissions(
        ClinicalRecordType.values,
      );

      bool authorized = false;

      // If not, request it
      if (!hasPermissions) {
        authorized = await health.requestClinicalAuthorization(
          ClinicalRecordType.values,
        );
      } else {
        authorized = true;
      }

      setState(() {
        _state = authorized ? AppState.AUTHORIZED : AppState.ERROR;
        _statusMessage = authorized
            ? "Authorization Granted!"
            : "Authorization Denied or Cancelled.";
      });
    } catch (error) {
      log("Exception in authorize: $error");
      setState(() {
        _state = AppState.ERROR;
        _statusMessage = "Error during auth: $error";
      });
    }
  }

  /// 2. Fetch Data: Read Clinical Records
  Future<void> fetchClinicalData() async {

    log('fetchClinicalData records.');
    setState(() {
      _state = AppState.FETCHING_DATA;
      _statusMessage = "Fetching Clinical Records...";
    });

    final now = DateTime.now();
    // Clinical records are often old (e.g., vaccines from years ago),
    // so we look back a significant amount of time.
    final past = now.subtract(const Duration(days: 365 * 5)); // 5 years back

    try {
      List<ClinicalRecord> data = await health.getClinicalRecords(
        types: ClinicalRecordType.values,
        startDate: past,
        endDate: now,
      );
      log('Fetched ${data.length} records.');
      // Remove duplicates if necessary (HealthKit sometimes returns duplicates)
      final uniqueData =
      data.fold<Map<String, ClinicalRecord>>({}, (map, record) {
        map[record.uuid] = record;
        return map;
      }).values.toList();

      log('Fetched ${uniqueData.length} records.');

      setState(() {
        _clinicalDataList = uniqueData;
        _state = uniqueData.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
        _statusMessage =
        uniqueData.isEmpty
            ? "No clinical records found in HealthKit."
            : "Found ${uniqueData.length} records.";
      });
    } catch (error) {
      log("Exception in fetchClinicalData: $error");
      setState(() {
        _state = AppState.ERROR;
        _statusMessage = "Error fetching data: $error";
      });
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Clinical Records Example 2')),
        body: Column(
          children: [
            // Control Panel
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: authorize,
                        child: const Text("1. Authorize"),
                      ),
                      ElevatedButton(
                        onPressed:
                        (_state == AppState.AUTHORIZED ||
                            _state == AppState.DATA_READY ||
                            _state == AppState.NO_DATA)
                            ? fetchClinicalData
                            : null,
                        child: const Text("2. Fetch Data 2"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Data Display
            Expanded(child: _content),
          ],
        ),
      ),
    );
  }

  Widget get _content {
    if (_state == AppState.FETCHING_DATA) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_state == AppState.DATA_READY) {
      return ListView.builder(
        itemCount: _clinicalDataList.length,
        itemBuilder: (context, index) {
          final record = _clinicalDataList[index];
          return _buildRecordTile(record);
        },
      );
    }

    return Center(
      child: Text(
        _state == AppState.NO_DATA
            ? "No records found.\n(Check Health App > Browse > Health Records)"
            : "Waiting for action...",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildRecordTile(ClinicalRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text(
          record.displayName ?? "Unknown Record",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${record.clinicalType.key}\nDate: ${record.startDate.toString().split(' ')[0]}",
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow("Source", record.sourceName ?? "N/A"),
                _infoRow(
                  "FHIR Resource",
                  record.fhirResource?.resourceType?.name ?? "N/A",
                ),
                if (record.fhirResource?.json != null) ...[
                  const SizedBox(height: 8),
                  const Text("Raw Data:", style: TextStyle(color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[100],
                    width: double.infinity,
                    child: Text(
                      record.fhirResource!.json.toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Extension to safely access the JSON map from your FHIRResource class
extension FHIRResourceExt on FHIRResource {
  Map<String, dynamic>? get json => data;
}