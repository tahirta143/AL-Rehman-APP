import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/services/auth_storage_service.dart';
import '../../global/global_api.dart';
import '../../models/dashboard_model.dart';
import '../../core/utils/database_helper.dart';

class DashboardProvider extends ChangeNotifier {
  final AuthStorageService _storage = AuthStorageService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCalendarLoading = false;
  bool get isCalendarLoading => _isCalendarLoading;

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  String _selectedShiftType = 'All';
  String get selectedShiftType => _selectedShiftType;

  List<ShiftDashboardInfo> _availableShifts = [];
  List<ShiftDashboardInfo> get availableShifts => _availableShifts;

  List<dynamic> _opdData = [];
  List<dynamic> _expenses = [];
  List<dynamic> get opdData => _opdData;
  List<dynamic> get expenses => _expenses;
  Map<String, Map<String, List<dynamic>>> _calendarData = {};

  // Getters for processed data
  double totalOpdRevenue = 0;
  double totalConsultRevenue = 0;
  int totalConsultCount = 0;
  int totalPatients = 0;
  double totalExpenses = 0;
  List<ExpenseBreakdownItem> expenseBreakdown = [];
  double avgRevenuePerPatient = 0;
  double netRevenue = 0;
  String topExpenseCategory = '—';

  // Shift-wise breakdowns for charts
  Map<String, double> shiftOpdRevenue = {'Morning': 0, 'Evening': 0, 'Night': 0};
  Map<String, double> shiftConsultRevenue = {'Morning': 0, 'Evening': 0, 'Night': 0};
  Map<String, int> shiftPatientCount = {'Morning': 0, 'Evening': 0, 'Night': 0};
  Map<String, int> shiftConsultCount = {'Morning': 0, 'Evening': 0, 'Night': 0};
  List<ChartDataPoint> trendData = [];

  DashboardProvider() {
    // Initial fetch happens when screen mounts or date selected
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> setSelectedDate(DateTime date) async {
    _selectedDate = date;
    notifyListeners();
    await Future.wait([
      fetchAvailableShifts(date),
      fetchCalendarData(date),
    ]);
  }

  void setSelectedShiftType(String type) {
    _selectedShiftType = type;
    fetchData();
    notifyListeners();
  }

  void resetToToday() {
    _selectedDate = DateTime.now();
    _selectedShiftType = 'All';
    notifyListeners();
  }

  Future<void> fetchAvailableShifts(DateTime date) async {
    _isLoading = true;
    _availableShifts = [];
    notifyListeners();
    
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
     
    try {
      final headers = await _authHeaders();
      // React logic: Derive shifts from patient data to be consistent with records
      final url = '${GlobalApi.baseUrl}/opd-patient-data?shift_date=$dateStr&limit=500';
      developer.log('📡 GET $url (for shifts)', name: 'DashboardProvider');
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] is List) {
          final List<dynamic> data = json['data'];
          final Map<int, ShiftDashboardInfo> shiftsMap = {};
          
          for (var r in data) {
            final shiftId = r['shift_id'];
            if (shiftId != null && !shiftsMap.containsKey(shiftId)) {
              shiftsMap[shiftId] = ShiftDashboardInfo(
                shiftId: shiftId,
                shiftType: r['shift_type'] ?? 'Unknown',
                shiftDate: r['shift_date'] ?? dateStr,
              );
            }
          }
          
          final List<ShiftDashboardInfo> allShifts = shiftsMap.values.toList()
            ..sort((a, b) => a.shiftId.compareTo(b.shiftId));
            
          // Night shift exclusion logic from React
          final nightShifts = allShifts.where((s) => _normalizeShiftType(s.shiftType) == 'Night').toList();
          int? shiftIdToExclude;
          if (nightShifts.length > 1) {
            shiftIdToExclude = nightShifts[0].shiftId;
          }
          
          _availableShifts = allShifts.where((s) => s.shiftId != shiftIdToExclude).toList();
          
          developer.log('✅ Derived ${_availableShifts.length} shifts for $dateStr', name: 'DashboardProvider');
        }
      }
    } catch (e) {
      developer.log('Error fetching available shifts: $e', name: 'DashboardProvider');
    }
    await fetchData();
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.wait([
      fetchAvailableShifts(_selectedDate),
      fetchCalendarData(_selectedDate),
    ]);
  }

  Future<void> fetchData() async {
    _isLoading = true;
    // Clear old data immediately to avoid "same data" flash
    _opdData = [];
    _expenses = [];
    _processData(); 
    notifyListeners();

    List<int> shiftIdsToFetch = [];
    if (_selectedShiftType == 'All') {
      shiftIdsToFetch = _availableShifts.map((s) => s.shiftId).toList();
    } else {
      shiftIdsToFetch = _availableShifts
          .where((s) => _normalizeShiftType(s.shiftType) == _selectedShiftType)
          .map((s) => s.shiftId)
          .toList();
    }

    try {
      final headers = await _authHeaders();
      List<dynamic> allOpdData = [];
      List<dynamic> allExpenses = [];
      final Set<dynamic> seenRecords = {};
      final Set<dynamic> seenExpenses = {};

      if (shiftIdsToFetch.isEmpty && _selectedShiftType == 'All') {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        // Fallback: Use multiple date parameters to be robust across different API versions
        final opdUrl = '${GlobalApi.baseUrl}/opd-patient-data?shift_date=$dateStr&reg_date=$dateStr&registration_date=$dateStr&date=$dateStr&limit=500';
        final expUrl = '${GlobalApi.baseUrl}/expenses?shift_date=$dateStr&reg_date=$dateStr&date=$dateStr&limit=500';

        final responses = await Future.wait([
          http.get(Uri.parse(opdUrl), headers: headers),
          http.get(Uri.parse(expUrl), headers: headers),
        ]);

        final opdRes = responses[0];
        final expRes = responses[1];

        if (opdRes.statusCode == 200) {
          final json = jsonDecode(opdRes.body);
          if (json['success'] == true && json['data'] != null) {
            allOpdData = json['data'];
          }
        }
        if (expRes.statusCode == 200) {
          final json = jsonDecode(expRes.body);
          if (json['success'] == true && json['data'] != null) {
            allExpenses = json['data'];
          }
        }
      } else {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final futures = shiftIdsToFetch.map((shiftId) async {
          // Fetch OPD data for shift, ensuring date is also passed if shift IDs are static
          final opdUrl = '${GlobalApi.baseUrl}/opd-patient-data/shift/$shiftId?shift_date=$dateStr&reg_date=$dateStr&date=$dateStr';
          final opdRes = await http.get(Uri.parse(opdUrl), headers: headers);
          if (opdRes.statusCode == 200) {
            final json = jsonDecode(opdRes.body);
            if (json['success'] == true && json['data'] != null) {
              return {'type': 'opd', 'data': json['data']};
            }
          }
          return null;
        }).toList();

        final expFutures = shiftIdsToFetch.map((shiftId) async {
          // Fetch Expenses for shift, ensuring date is also passed
          final expUrl = '${GlobalApi.baseUrl}/expenses/shift/$shiftId?shift_date=$dateStr&date=$dateStr';
          final expRes = await http.get(Uri.parse(expUrl), headers: headers);
          if (expRes.statusCode == 200) {
            final json = jsonDecode(expRes.body);
            if (json['success'] == true && json['data'] != null) {
              return {'type': 'expense', 'data': json['data']};
            }
          }
          return null;
        }).toList();

        final results = await Future.wait([...futures, ...expFutures]);
        
        for (var result in results) {
          if (result == null) continue;
          final List<dynamic> data = result['data'];
          if (result['type'] == 'opd') {
            for (var r in data) {
              if (seenRecords.add(r['srl_no'])) {
                allOpdData.add(r);
              }
            }
          } else {
            for (var e in data) {
              final key = e['id'] ?? e['srl_no'];
              if (seenExpenses.add(key)) {
                allExpenses.add(e);
              }
            }
          }
        }
      }

      _opdData = allOpdData;
      _expenses = allExpenses;
      _processData();
      
      developer.log('📈 Processed ${_opdData.length} records and ${_expenses.length} expenses', name: 'DashboardProvider');
      developer.log('💰 Total Revenue: $totalOpdRevenue, Total Expenses: $totalExpenses', name: 'DashboardProvider');

    } catch (e) {
      developer.log('Error fetching dashboard data: $e', name: 'DashboardProvider');
    }

    _isLoading = false;
    notifyListeners();
  }

  void resetLoading() {
    _isLoading = true;
    notifyListeners();
  }

  Future<void> _processData() async {
    // Reset values
    totalOpdRevenue = 0;
    totalConsultRevenue = 0;
    totalConsultCount = 0;
    totalPatients = 0;
    totalExpenses = 0;
    shiftOpdRevenue = {'Morning': 0, 'Evening': 0, 'Night': 0};
    shiftConsultRevenue = {'Morning': 0, 'Evening': 0, 'Night': 0};
    shiftPatientCount = {'Morning': 0, 'Evening': 0, 'Night': 0};
    shiftConsultCount = {'Morning': 0, 'Evening': 0, 'Night': 0};
    Map<String, double> hourMap = {};

    // Process OPD
    for (var r in _opdData) {
      final shift = _normalizeShiftType(r['shift_type']);
      if (!shiftOpdRevenue.containsKey(shift)) continue;

      // React uses service_amount || total_amount
      final amount = _parseDouble(r['service_amount'] ?? r['total_amount']);
      
      totalOpdRevenue += amount;
      totalPatients += 1;
      
      shiftOpdRevenue[shift] = (shiftOpdRevenue[shift] ?? 0) + amount;
      shiftPatientCount[shift] = (shiftPatientCount[shift] ?? 0) + 1;

      // Identify consultation strictly like React: String(r.opd_service || "").trim() === "Consultation"
      final opdService = (r['opd_service'] ?? '').toString().trim();
      if (opdService == 'Consultation') {
        totalConsultRevenue += amount;
        totalConsultCount += 1;
        shiftConsultRevenue[shift] = (shiftConsultRevenue[shift] ?? 0) + amount;
        shiftConsultCount[shift] = (shiftConsultCount[shift] ?? 0) + 1;
      }

      // Trend data: group by hour
      try {
        final dateStr = r['created_at'] ?? r['reg_date'] ?? r['date_time'] ?? '';
        if (dateStr.isNotEmpty) {
           DateTime dt;
           if (dateStr.contains('T')) {
             dt = DateTime.parse(dateStr);
           } else {
             // Try common formats if ISO fails
             dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr);
           }
           final hourKey = DateFormat('h a').format(dt);
           hourMap[hourKey] = (hourMap[hourKey] ?? 0) + amount;
        }
      } catch (_) {}
    }

    // Process Expenses
    Map<String, double> expMap = {};
    for (var e in _expenses) {
      final amt = _parseDouble(e['expense_amount']);
      totalExpenses += amt;
      final category = (e['expense_type'] ?? e['category'] ?? e['expense_head'] ?? e['expense_name'] ?? 'Other').toString().trim();
      expMap[category] = (expMap[category] ?? 0) + amt;
    }

    final sortedExp = expMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    expenseBreakdown = sortedExp.take(8).map((entry) => ExpenseBreakdownItem(
      name: entry.key,
      value: entry.value,
      color: _getContrastColor(sortedExp.indexOf(entry)),
    )).toList();

    avgRevenuePerPatient = totalPatients > 0 ? (totalOpdRevenue / totalPatients) : 0;
    netRevenue = totalOpdRevenue - totalExpenses;
    topExpenseCategory = sortedExp.isNotEmpty ? sortedExp[0].key : '—';

    // Finalize trend data: sort chronologically if possible
    // We'll just sort by the hour for now
    final sortedHours = hourMap.entries.toList()..sort((a, b) {
       // Simple map for sorting h a format
       final order = {
         '12 AM': 0, '1 AM': 1, '2 AM': 2, '3 AM': 3, '4 AM': 4, '5 AM': 5, '6 AM': 6, '7 AM': 7, 
         '8 AM': 8, '9 AM': 9, '10 AM': 10, '11 AM': 11, '12 PM': 12, '1 PM': 13, '2 PM': 14, 
         '3 PM': 15, '4 PM': 16, '5 PM': 17, '6 PM': 18, '7 PM': 19, '8 PM': 20, '9 PM': 21, 
         '10 PM': 22, '11 PM': 23
       };
       return (order[a.key] ?? 0).compareTo(order[b.key] ?? 0);
    });
    
    trendData = sortedHours.map((e) => ChartDataPoint(e.key, e.value)).toList();
    if (trendData.isEmpty) {
       trendData = [ChartDataPoint('8 AM', 0), ChartDataPoint('12 PM', 0), ChartDataPoint('6 PM', 0)];
    }
  }

  String _normalizeShiftType(String type) {
    if (type == null) return 'Unknown';
    final t = type.toString().trim().toLowerCase();
    if (t == 'morning') return 'Morning';
    if (t == 'evening') return 'Evening';
    if (t == 'night') return 'Night';
    return 'Unknown';
  }

  Color _getContrastColor(int index) {
    final colors = [
      const Color(0xFF10B981), // emerald
      const Color(0xFF6366F1), // indigo
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEF4444), // rose
      const Color(0xFF8B5CF6), // violet
      const Color(0xFF06B6D4), // cyan
      const Color(0xFFF97316), // orange
      const Color(0xFF64748B), // slate
    ];
    return colors[index % colors.length];
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> fetchCalendarData(DateTime date) async {
    _isCalendarLoading = true;
    notifyListeners();

    try {
      final headers = await _authHeaders();
      final year = date.year;
      final month = date.month;
      final url = '${GlobalApi.baseUrl}/appointments/calendar?year=$year&month=$month';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] is List) {
          final List<dynamic> appointments = json['data'];
          Map<String, Map<String, List<dynamic>>> grouped = {};
          
          for (var apt in appointments) {
            final dateStr = DateTime.parse(apt['appointment_date']).toIso8601String().split('T')[0];
            final doctorName = apt['doctor_name'] ?? 'Unknown Doctor';
            
            grouped.putIfAbsent(dateStr, () => {});
            grouped[dateStr]!.putIfAbsent(doctorName, () => []);
            grouped[dateStr]![doctorName]!.add(apt);
          }
          _calendarData = grouped;
        }
      }
    } catch (e) {
      developer.log('Error fetching calendar data from API: $e', name: 'DashboardProvider');
    }

    // Load local appointments and merge into calendar
    try {
      final db = await DatabaseHelper().database;
      
      // Load doctors mapping for name resolution
      final doctorRows = await db.query('master_doctors');
      final doctorMap = {
        for (var d in doctorRows) 
          d['srl_no'].toString(): d['doctor_name']?.toString() ?? 'Dr. Unknown'
      };

      final localRows = await db.query('appointments_local');
      
      for (var row in localRows) {
        final dateStr = DateTime.tryParse(row['appointment_date']?.toString() ?? '')
            ?.toIso8601String().split('T')[0];
        if (dateStr == null) continue;

        final docSrlNo = row['doctor_srl_no']?.toString() ?? '';
        final doctorName = doctorMap[docSrlNo] ?? 'Dr. ID: $docSrlNo';

        _calendarData.putIfAbsent(dateStr, () => {});
        _calendarData[dateStr]!.putIfAbsent(doctorName, () => []);
        
        // Prevent duplicates if already there (unlikely for offline but safe)
        final alreadyPresent = _calendarData[dateStr]![doctorName]!
            .any((a) => a['device_uuid'] == row['device_uuid']);
            
        if (!alreadyPresent) {
          _calendarData[dateStr]![doctorName]!.add({
            'appointment_date': row['appointment_date'],
            'doctor_name': doctorName,
            'patient_name': row['patient_name'],
            'slot_time': row['appointment_time'],
            'token_number': row['token_number'],
            'sync_status': row['sync_status'],
            'device_uuid': row['device_uuid'],
          });
        }
      }
    } catch (e) {
      developer.log('Error loading local appointments for calendar: $e', name: 'DashboardProvider');
    }

    _isCalendarLoading = false;
    notifyListeners();
  }

  Map<String, Map<String, List<dynamic>>> get calendarData => _calendarData;

  // Chart data getters
  List<ChartDataPoint> get barChartData {
    // We need to group by OPD/Consultation and then by Shift
    // In React: [{ metric: "OPD", Morning: ..., Evening: ..., Night: ... }]
    // Here we'll return List<ChartDataPoint> or similar structure that Syncfusion likes
    return []; // Will handle in UI or specific getter
  }
}
