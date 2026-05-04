import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/auth_storage_service.dart';
import '../../global/global_api.dart';
import '../../models/appointment_model/appointments_model.dart';
import '../../core/utils/database_helper.dart';

class AppointmentsProvider extends ChangeNotifier {
  static const String _baseUrl = '${GlobalApi.baseUrl}/appointments';

  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Raw data ───────────────────────────────────────────────────────────────
  List<AppointmentModel> _all = [];

  // ── Filter state ───────────────────────────────────────────────────────────
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  TimeOfDay? _timeFrom;
  TimeOfDay? _timeTo;
  String _selectedConsultant = 'All';
  String _selectedStatus = 'All Status';
  String _searchQuery = '';
  String _quickFilter = 'Today'; // 'Today' | 'This Week' | 'Date Range'

  // ── Loading ────────────────────────────────────────────────────────────────
  bool isLoading = false;
  String? errorMessage;

  // ── Getters ────────────────────────────────────────────────────────────────
  DateTime get dateFrom => _dateFrom;
  DateTime get dateTo => _dateTo;
  TimeOfDay? get timeFrom => _timeFrom;
  TimeOfDay? get timeTo => _timeTo;
  String get selectedConsultant => _selectedConsultant;
  String get selectedStatus => _selectedStatus;
  String get searchQuery => _searchQuery;
  String get quickFilter => _quickFilter;

  List<AppointmentModel> get filtered {
    List<AppointmentModel> list = List.from(_all);

    // Date filter
    list = list.where((a) {
      try {
        final d = DateTime.parse(a.appointmentDate);
        final from = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
        final to = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59);
        return !d.isBefore(from) && !d.isAfter(to);
      } catch (_) {
        return true;
      }
    }).toList();

    // Time filter
    if (_timeFrom != null) {
      list = list.where((a) {
        try {
          final parts = a.slotTime.split(':');
          final slotMinutes =
              int.parse(parts[0]) * 60 + int.parse(parts[1]);
          final fromMinutes = _timeFrom!.hour * 60 + _timeFrom!.minute;
          return slotMinutes >= fromMinutes;
        } catch (_) {
          return true;
        }
      }).toList();
    }
    if (_timeTo != null) {
      list = list.where((a) {
        try {
          final parts = a.slotTime.split(':');
          final slotMinutes =
              int.parse(parts[0]) * 60 + int.parse(parts[1]);
          final toMinutes = _timeTo!.hour * 60 + _timeTo!.minute;
          return slotMinutes <= toMinutes;
        } catch (_) {
          return true;
        }
      }).toList();
    }

    // Consultant filter
    if (_selectedConsultant != 'All') {
      list = list
          .where((a) =>
      a.doctorName.toLowerCase() ==
          _selectedConsultant.toLowerCase())
          .toList();
    }

    // Status filter
    if (_selectedStatus != 'All Status') {
      list = list
          .where((a) =>
      a.status.toLowerCase() == _selectedStatus.toLowerCase())
          .toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) {
        return a.mrNumber.toLowerCase().contains(q) ||
            a.patientName.toLowerCase().contains(q) ||
            a.doctorName.toLowerCase().contains(q) ||
            a.patientContact.contains(q) ||
            a.appointmentId.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  // ── Stats from filtered list ───────────────────────────────────────────────
  int get total => filtered.length;
  int get booked =>
      filtered.where((a) => a.status == 'booked').length;
  int get completed =>
      filtered.where((a) => a.status == 'completed').length;
  int get cancelled =>
      filtered.where((a) => a.status == 'cancelled').length;
  int get firstVisits => filtered.where((a) => a.isFirstVisit).length;
  int get followUps => filtered.where((a) => !a.isFirstVisit).length;
  double get revenue =>
      filtered.fold(0, (sum, a) => sum + a.effectiveFee);

  String get formattedRevenue {
    final formatted = revenue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
    return 'PKR $formatted';
  }

  /// Unique consultant names from all appointments
  List<String> get consultantNames {
    final names = _all.map((a) => a.doctorName).toSet().toList()..sort();
    return ['All', ...names];
  }

  static const List<String> statusOptions = [
    'All Status',
    'booked',
    'completed',
    'cancelled',
  ];

  AppointmentsProvider() {
    fetchAppointments();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> fetchAppointments() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final headers = await _authHeaders();
      developer.log('📡 GET $_baseUrl', name: 'AppointmentsProvider');

      final response =
      await http.get(Uri.parse(_baseUrl), headers: headers);

      developer.log('📥 Status: ${response.statusCode}',
          name: 'AppointmentsProvider');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _all = (json['data'] as List)
              .map((e) => AppointmentModel.fromJson(e))
              .toList();
          developer.log('✅ Loaded ${_all.length} appointments',
              name: 'AppointmentsProvider');
        } else {
          errorMessage = 'Failed to load appointments.';
        }
      } else if (response.statusCode == 401) {
        errorMessage = 'Session expired. Please log in again.';
      } else {
        errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e, stack) {
      errorMessage = 'Network error. Check your connection.';
      developer.log('💥 $e',
          name: 'AppointmentsProvider', error: e, stackTrace: stack);
    }

    // Load local appointments (both pending and synced)
    try {
      final db = await DatabaseHelper().database;
      
      // Load doctors mapping for offline name resolution
      final doctorRows = await db.query('master_doctors');
      final doctorMap = {
        for (var d in doctorRows) 
          d['srl_no'].toString(): {
            'name': d['doctor_name']?.toString() ?? 'Dr. Unknown',
            'specialty': d['doctor_specialization']?.toString() ?? 'Consultant'
          }
      };

      final localRows = await db.query('appointments_local');
      
      for (var row in localRows) {
        final deviceId = row['device_uuid']?.toString() ?? '';
        // Avoid duplicates if already in _all from API
        if (_all.any((a) => a.appointmentId == deviceId)) continue;

        final docSrlNo = row['doctor_srl_no']?.toString() ?? '';
        final docInfo = doctorMap[docSrlNo] ?? {
          'name': 'Dr. ID: $docSrlNo',
          'specialty': 'Consultant'
        };

        _all.insert(0, AppointmentModel(
          id: 0, 
          appointmentId: deviceId,
          mrNumber: row['mr_number']?.toString() ?? '',
          patientName: row['patient_name']?.toString() ?? 'Local Patient',
          patientContact: row['patient_contact']?.toString() ?? '',
          doctorSrlNo: int.tryParse(docSrlNo) ?? 0,
          doctorName: docInfo['name']!,
          appointmentDate: row['appointment_date']?.toString() ?? DateTime.now().toIso8601String(),
          slotTime: row['appointment_time']?.toString() ?? '',
          status: row['sync_status'] == 'pending' ? 'pending' : 'booked',
          isFirstVisit: row['is_first_visit'] == 1,
          fee: double.tryParse(row['fee']?.toString() ?? '0') ?? 0.0,
          followUpCharges: double.tryParse(row['follow_up_charges']?.toString() ?? '0') ?? 0.0,
          createdAt: row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          doctorSpecialization: docInfo['specialty']!,
          consultationTimeFrom: '',
          consultationTimeTo: '',
          tokenNumber: row['token_number'] as int?,
        ));
      }
    } catch (e) {
      debugPrint('Error loading local appointments in provider: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Filter setters ─────────────────────────────────────────────────────────
  void setQuickFilter(String filter) {
    _quickFilter = filter;
    final now = DateTime.now();
    if (filter == 'Today') {
      _dateFrom = now;
      _dateTo = now;
    } else if (filter == 'This Week') {
      final weekday = now.weekday;
      _dateFrom = now.subtract(Duration(days: weekday - 1));
      _dateTo = _dateFrom.add(const Duration(days: 6));
    }
    notifyListeners();
  }

  void setDateFrom(DateTime d) {
    _dateFrom = d;
    _quickFilter = 'Date Range';
    notifyListeners();
  }

  void setDateTo(DateTime d) {
    _dateTo = d;
    _quickFilter = 'Date Range';
    notifyListeners();
  }

  void setTimeFrom(TimeOfDay? t) {
    _timeFrom = t;
    notifyListeners();
  }

  void setTimeTo(TimeOfDay? t) {
    _timeTo = t;
    notifyListeners();
  }

  void setConsultant(String c) {
    _selectedConsultant = c;
    notifyListeners();
  }

  void setStatus(String s) {
    _selectedStatus = s;
    notifyListeners();
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void refresh() {
    fetchAppointments();
  }

  // ── UPDATE ──
  Future<bool> updateAppointment(int id, Map<String, dynamic> data) async {
    isLoading = true;
    notifyListeners();
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/$id'),
        headers: headers,
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        if (resJson['success'] == true) {
          await fetchAppointments();
          return true;
        }
      }
      errorMessage = 'Failed to update appointment';
    } catch (e) {
      errorMessage = 'Error updating appointment: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // ── CANCEL / DELETE ──
  Future<bool> cancelAppointment(int id) async {
    isLoading = true;
    notifyListeners();
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/$id'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        if (resJson['success'] == true) {
          await fetchAppointments();
          return true;
        }
      }
      errorMessage = 'Failed to cancel appointment';
    } catch (e) {
      errorMessage = 'Error cancelling appointment: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return false;
  }
}