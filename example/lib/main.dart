import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health/health.dart';

// Global Health instance
final health = Health();

void main() => runApp(const ClinicalHealthApp());

// 1. THE ROOT WIDGET (Holds MaterialApp)
class ClinicalHealthApp extends StatelessWidget {
  const ClinicalHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clinical Health Example',
      // The context inside Home will now be UNDER MaterialApp
      home: const ClinicalRecordsScreen(),
    );
  }
}

// 2. THE SCREEN WIDGET (Holds State & Logic)
class ClinicalRecordsScreen extends StatefulWidget {
  const ClinicalRecordsScreen({super.key});

  @override
  ClinicalRecordsScreenState createState() => ClinicalRecordsScreenState();
}

enum AppState {
  INITIAL,
  AUTHORIZED,
  FETCHING_DATA,
  DATA_READY,
  NO_DATA,
  ERROR,
}

class ClinicalRecordsScreenState extends State<ClinicalRecordsScreen> {
  List<ClinicalRecord> _clinicalDataList = [];
  AppState _state = AppState.INITIAL;
  String _statusMessage = "Press 'Authorize' to start.";

  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    health.configure();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 365));
  }

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
      bool hasPermissions = await health.hasClinicalPermissions(
        ClinicalRecordType.values,
      );

      bool authorized = false;

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

  Future<void> _selectDateRange() async {
    // THIS CONTEXT now works because it is inside MaterialApp
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        if (_state == AppState.DATA_READY || _state == AppState.NO_DATA) {
          _statusMessage = "Date range updated. Press 'Fetch Data'.";
        }
      });
    }
  }

  Future<void> fetchClinicalData() async {
    log('fetchClinicalData records.');
    setState(() {
      _state = AppState.FETCHING_DATA;
      _statusMessage = "Fetching Clinical Records...";
    });

    try {
      List<ClinicalRecord> data = await health.getClinicalRecords(
        types: ClinicalRecordType.values,
        startDate: _startDate,
        endDate: _endDate,
      );

      final uniqueData =
      data.fold<Map<String, ClinicalRecord>>({}, (map, record) {
        map[record.uuid] = record;
        return map;
      }).values.toList();

      setState(() {
        _clinicalDataList = uniqueData;
        _state = uniqueData.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
        _statusMessage = uniqueData.isEmpty
            ? "No records found between ${_formatDate(_startDate)} and ${_formatDate(_endDate)}."
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

  String _formatDate(DateTime date) {
    return date.toString().split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {
    // Note: MaterialApp is removed from here and moved up to ClinicalHealthApp
    return Scaffold(
      appBar: AppBar(title: const Text('Clinical Records Example 2')),
      body: Column(
        children: [
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
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400)),
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range,
                                size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Filter Time Range",
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                Text(
                                  "${_formatDate(_startDate)}  ➔  ${_formatDate(_endDate)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: authorize,
                      child: const Text("1. Authorize"),
                    ),
                    ElevatedButton(
                      onPressed: (_state == AppState.AUTHORIZED ||
                          _state == AppState.DATA_READY ||
                          _state == AppState.NO_DATA)
                          ? fetchClinicalData
                          : null,
                      child: const Text("2. Fetch Data"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _content),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          _state == AppState.NO_DATA
              ? "No records found in this date range.\nTry expanding the date filter."
              : "Waiting for action...",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
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
                  const Text("Raw Data:",
                      style: TextStyle(color: Colors.grey)),
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

extension FHIRResourceExt on FHIRResource {
  Map<String, dynamic>? get json => data;
}