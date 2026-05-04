import 'package:flutter/material.dart';
import '../../../core/services/consultation_api_service.dart';
import '../../../core/services/opd_receipt_api_service.dart';
import '../../../models/consultation_model/doctor_model.dart';
import '../../../models/consultation_model/appointment_model.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/database_helper.dart';

// ─────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────
class ConsultationProvider extends ChangeNotifier {
  final ConsultationApiService _apiService = ConsultationApiService();
  final OpdReceiptApiService _opdApiService = OpdReceiptApiService();
  final ConnectivityService _connectivity = ConnectivityService();
  final DatabaseHelper _db = DatabaseHelper();

  // ── Service Doctor Mappings ──
  Map<String, dynamic> _serviceDocs = {};
  String? _consultationSrlNo;

  // ── State ──
  bool _isLoading = false;
  bool _isLoadingAppointments = false;
  bool _isLoadingHistory = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isLoadingAppointments => _isLoadingAppointments;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get errorMessage => _errorMessage;

  // ── Doctors ──
  List<DoctorInfo> _doctors = [];
  List<DoctorInfo> get doctors => _doctors;

  // ── Constructor: Load data on init ──
  ConsultationProvider() {
    // We no longer auto-load here to avoid unauthenticated 401 errors at startup.
    // Screens should call loadDoctors and loadAppointments explicitly in initState.
  }

  // ── Load Doctors from API ──
  Future<void> loadDoctors({bool isPublic = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    bool loadFromLocal = false;
    if (!_connectivity.isOnline.value) {
      loadFromLocal = true;
    }

    try {
      if (!loadFromLocal) {
        try {
          final mappingsResult = await _apiService.fetchServiceDoctorMappings().timeout(const Duration(seconds: 5));
          final opdServicesResult = await _opdApiService.fetchOpdServices().timeout(const Duration(seconds: 5));

          if (mappingsResult.success && mappingsResult.data != null) {
            _serviceDocs = mappingsResult.data!;
          }
          if (opdServicesResult.success) {
            for (var s in opdServicesResult.services) {
              if (s.serviceName.toLowerCase().contains('consultation')) {
                _consultationSrlNo = s.srlNo.toString();
                break;
              }
            }
          }

          final result = await _apiService.fetchDoctors(isPublic: isPublic).timeout(const Duration(seconds: 10));

          if (result.success && result.doctors.isNotEmpty) {
            _doctors = result.doctors.map((doctor) {
              final appointmentCount = _appointments
                  .where((a) => a.consultantName == 'Dr. ${doctor.doctorName}')
                  .length;

              double fee = double.tryParse(doctor.consultationFee) ?? 0.0;
              double followUpFee = (fee * 0.7).floorToDouble();

              final lookupKey = _consultationSrlNo ?? 'Consultation';
              if (_serviceDocs.containsKey(lookupKey)) {
                final mappings = _serviceDocs[lookupKey] as List<dynamic>;
                final match = mappings.firstWhere(
                  (m) => m['doctor_srl_no'].toString() == doctor.srlNo.toString(),
                  orElse: () => null,
                );
                if (match != null) {
                  if (match['rate'] != null) {
                    fee = double.tryParse(match['rate'].toString()) ?? fee;
                  }
                  final fUpDays = int.tryParse(match['followup_days']?.toString() ?? '0') ?? 0;
                  if (fUpDays > 0) {
                    followUpFee = 0;
                  } else {
                    followUpFee = (fee * 0.7).floorToDouble();
                  }
                }
              }

              return doctor.toDoctorInfo(
                totalAppointments: appointmentCount,
                customFee: fee.toStringAsFixed(0),
                customFollowUp: followUpFee.toStringAsFixed(0),
              );
            }).toList();
            _errorMessage = null;
            _isLoading = false;
            notifyListeners();
            return;
          } else {
            loadFromLocal = true;
          }
        } catch (e) {
          debugPrint('⚠️ Doctor API load failed: $e. Falling back to local.');
          loadFromLocal = true;
        }
      }

      if (loadFromLocal) {
        final localDocs = await _db.queryAll('master_doctors');
        if (localDocs.isNotEmpty) {
          _doctors = localDocs.map((d) {
            final fee = d['consultation_fee']?.toString() ?? '0';
            final parsedFee = double.tryParse(fee) ?? 0.0;
            final followUp = d['follow_up_fee']?.toString() ?? (parsedFee * 0.7).floor().toString();
            final srlNo = int.tryParse(d['srl_no']?.toString() ?? '0') ?? 0;
            
            // Generate avatar color dynamically based on ID
            final avatarColors = [
              const Color(0xFF00B5AD), const Color(0xFF8E24AA), const Color(0xFF1E88E5), 
              const Color(0xFFE53935), const Color(0xFF43A047), const Color(0xFFF4511E)
            ];
            final color = avatarColors[srlNo % avatarColors.length];

            final timings = d['doctor_timings']?.toString() ?? '';
            
            return DoctorInfo(
              id: srlNo.toString(),
              name: 'Dr. ${d['doctor_name']}',
              specialty: d['doctor_specialization']?.toString() ?? 'Medical Officer',
              consultationFee: (fee.isEmpty || fee == '0') ? '0' : fee,
              followUpCharges: (followUp.isEmpty || followUp == '0') ? '0' : followUp,
              availableDays: (d['available_days']?.toString() ?? 'Mon,Tue,Wed,Thu,Fri,Sat,Sun')
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
              timings: timings.isEmpty ? '09:00 AM - 05:00 PM' : timings,
              hospital: d['hospital_name']?.toString() ?? 'Hospital',
              imageAsset: d['image_url']?.toString() ?? '',
              department: d['doctor_department']?.toString() ?? '',
              avatarColor: color,
              totalAppointments: 0,
            );
          }).toList();
          _errorMessage = null;
        } else {
          _errorMessage = 'No doctors available offline. Please Bootstrap while online.';
        }
      }
    } catch (e) {
      debugPrint('Error in loadDoctors: $e');
      _errorMessage = 'Failed to load doctors: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void resetLoading() {
    _isLoading = true;
    notifyListeners();
  }

  // ── Appointments ──
  List<ConsultationAppointment> _appointments = [];

  List<ConsultationAppointment> get appointments =>
      List.unmodifiable(_appointments);

  List<Map<String, dynamic>> get appointmentsAsMaps =>
      _appointments.map((a) => a.toMap()).toList();

  // ── Load Appointments from API ──
  Future<void> loadAppointments({bool isPublic = false}) async {
    _isLoadingAppointments = true;
    notifyListeners();

    final result = await _apiService.fetchAppointments(isPublic: isPublic);

    if (result.success) {
      // Convert AppointmentModel to ConsultationAppointment
      _appointments = result.appointments.map((appointment) {
        // Find hospital name from doctor
        final doctor = _doctors.firstWhere(
              (d) => d.id == appointment.doctorSrlNo.toString(),
          orElse: () => DoctorInfo(
            id: '',
            name: '',
            specialty: '',
            consultationFee: '',
            followUpCharges: '',
            availableDays: [],
            timings: '',
            hospital: 'WMCTH',
            imageAsset: '',
            department: '',
            avatarColor: Colors.grey,
            totalAppointments: 0,
          ),
        );
        return appointment.toConsultationAppointment(doctor.hospital);
      }).toList();
    } else {
      _appointments = [];
    }

    // Load local appointments (both pending and synced)
    try {
      final db = await _db.database;
      final localRows = await db.query('appointments_local');
      
      for (var app in localRows) {
        final deviceId = app['device_uuid']?.toString() ?? '';
        
        // Prevent duplicates if already in _appointments from API
        if (_appointments.any((a) => a.id == deviceId)) continue;

        final docId = app['doctor_srl_no']?.toString() ?? '';
        final doctor = _doctors.firstWhere(
          (d) => d.id == docId,
          orElse: () => DoctorInfo(
            id: docId,
            name: 'Dr. ID: $docId',
            specialty: 'Doctor',
            consultationFee: app['fee']?.toString() ?? '0',
            followUpCharges: app['follow_up_charges']?.toString() ?? '0',
            availableDays: [],
            timings: '09:00 AM - 05:00 PM',
            hospital: 'Hospital (Offline)',
            imageAsset: '',
            department: '',
            avatarColor: Colors.grey,
            totalAppointments: 0,
          ),
        );

        final appointment = ConsultationAppointment(
          id: deviceId,
          patientName: app['patient_name']?.toString() ?? 'Local Patient',
          mrNo: app['mr_number']?.toString() ?? '',
          contactNo: app['patient_contact']?.toString() ?? '',
          address: app['patient_address']?.toString() ?? '',
          consultantName: doctor.name,
          specialty: doctor.specialty,
          consultationFee: app['fee']?.toString() ?? doctor.consultationFee,
          followUpCharges: app['follow_up_charges']?.toString() ?? doctor.followUpCharges,
          availableDays: doctor.availableDays,
          timings: doctor.timings,
          timeSlot: app['appointment_time']?.toString() ?? '',
          appointmentDate: DateTime.tryParse(app['appointment_date']?.toString() ?? '') ?? DateTime.now(),
          status: app['sync_status'] == 'pending' ? 'Pending' : 'Upcoming',
          hospital: doctor.hospital,
          type: 'OPD',
          isFirstVisit: app['is_first_visit'] == 1,
          tokenNumber: app['token_number'] as int?,
        );
        _appointments.insert(0, appointment);
      }
    } catch (e) {
      debugPrint('Error loading local appointments in consultation provider: $e');
    }

    _isLoadingAppointments = false;
    notifyListeners();
  }

  // ── Patient History ──
  List<ConsultationAppointment> _patientHistory = [];
  List<ConsultationAppointment> get patientHistory => _patientHistory;

  Future<void> fetchPatientHistory(String mrNumber) async {
    _isLoadingHistory = true;
    _patientHistory = [];
    notifyListeners();

    final result = await _apiService.fetchAppointmentsByMr(mrNumber);

    if (result.success) {
      _patientHistory = result.appointments.map((appointment) {
        final doctor = _doctors.firstWhere(
              (d) => d.id == appointment.doctorSrlNo.toString(),
          orElse: () => DoctorInfo(
            id: '',
            name: '',
            specialty: '',
            consultationFee: '',
            followUpCharges: '',
            availableDays: [],
            timings: '',
            hospital: 'WMCTH',
            imageAsset: '',
            department: '',
            avatarColor: Colors.grey,
            totalAppointments: 0,
          ),
        );
        return appointment.toConsultationAppointment(doctor.hospital);
      }).toList();
    }
    _isLoadingHistory = false;
    notifyListeners();
  }

  // ── Summary stats ──
  int get totalConsultations => _appointments.length;
  int get upcomingAppointments =>
      _appointments.where((a) => a.status == 'Upcoming').length;
  int get completedAppointments =>
      _appointments.where((a) => a.status == 'Completed').length;

  // ── Appointments for a specific doctor on a specific date ──
  List<ConsultationAppointment> appointmentsForDoctorOnDate(
      String doctorName, DateTime date) {
    return _appointments
        .where((a) =>
    a.consultantName == doctorName &&
        a.appointmentDate.year == date.year &&
        a.appointmentDate.month == date.month &&
        a.appointmentDate.day == date.day &&
        a.status != 'Cancelled')
        .toList();
  }

  // ── Available slots for doctor ──
  int availableSlotsForDoctor(String doctorName, DateTime date) {
    final doctor = doctors.firstWhere(
          (d) => d.name == doctorName,
      orElse: () => doctors.first,
    );
    final allSlots = generateTimeSlots(doctor.timings);
    final booked = bookedSlots(date, doctorName);
    return allSlots.length - booked.length;
  }

  // ── Consultants map list (for backward compat) ──
  List<Map<String, dynamic>> get consultants => doctors.map((d) => {
    'name': d.name,
    'specialty': d.specialty,
    'fee': d.consultationFee,
    'followUp': d.followUpCharges,
    'days': d.availableDays,
    'timings': d.timings,
    'hospital': d.hospital,
  }).toList();

  // ── ADD Appointment (POST to API) ──
  Future<bool> addAppointment(ConsultationAppointment appointment) async {
    // Find doctor srl_no from doctor name
    final doctorName = appointment.consultantName.replaceAll('Dr. ', '');
    final doctor = _doctors.firstWhere(
          (d) => d.name.contains(doctorName),
      orElse: () => _doctors.first,
    );

    final doctorSrlNo = int.tryParse(doctor.id) ?? 0;

    // Convert to API request format
    final requestData = appointment.toApiRequest(doctorSrlNo);

    if (!_connectivity.isOnline.value) {
      debugPrint('📴 Offline: Saving appointment locally');
      final db = await _db.database;
      final dateStr = appointment.appointmentDate.toIso8601String().substring(0, 10);
      final uuid = 'OFF-${DateTime.now().millisecondsSinceEpoch}';

      // Calculate offline token number
      final existingLocal = await db.query(
        'appointments_local',
        where: 'doctor_srl_no = ? AND appointment_date LIKE ?',
        whereArgs: [doctorSrlNo, '$dateStr%'],
      );
      final nextToken = existingLocal.length + 1;

      final appData = {
        'device_uuid': uuid,
        'mr_number': appointment.mrNo,
        'patient_name': appointment.patientName,
        'patient_contact': appointment.contactNo,
        'patient_address': appointment.address,
        'doctor_srl_no': doctorSrlNo,
        'appointment_date': appointment.appointmentDate.toIso8601String(),
        'appointment_time': appointment.timeSlot,
        'fee': appointment.consultationFee,
        'follow_up_charges': appointment.followUpCharges,
        'is_first_visit': appointment.isFirstVisit ? 1 : 0,
        'token_number': nextToken,
        'reason': 'OPD Consultation',
        'sync_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await db.insert('appointments_local', appData);
      
      // Update UI with token and doctor info
      final offlineApp = ConsultationAppointment(
        id: uuid,
        patientName: appointment.patientName,
        mrNo: appointment.mrNo,
        contactNo: appointment.contactNo,
        address: appointment.address,
        consultantName: doctor.name,
        specialty: doctor.specialty,
        consultationFee: appointment.consultationFee,
        followUpCharges: appointment.followUpCharges,
        availableDays: doctor.availableDays,
        timings: doctor.timings,
        timeSlot: appointment.timeSlot,
        appointmentDate: appointment.appointmentDate,
        status: 'Pending',
        hospital: doctor.hospital,
        type: appointment.type,
        isFirstVisit: appointment.isFirstVisit,
        tokenNumber: nextToken,
      );

      _appointments.insert(0, offlineApp);
      notifyListeners();
      return true;
    }

    // Call API
    final result = await _apiService.createAppointment(requestData);

    if (result.success) {
      // Add to local list
      _appointments.insert(0, appointment);
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  // ── DELETE / CANCEL ──
  Future<bool> cancelAppointment(String id) async {
    final appointmentId = int.tryParse(id);
    if (appointmentId == null) return false;

    final result = await _apiService.deleteAppointment(appointmentId);
    if (result.success) {
      _appointments.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  // ── UPDATE ──
  Future<bool> updateAppointment(String id, ConsultationAppointment appointment) async {
    final appointmentId = int.tryParse(id);
    if (appointmentId == null) return false;

    // Find doctor srl_no
    final doctorName = appointment.consultantName.replaceAll('Dr. ', '');
    final doctor = _doctors.firstWhere(
          (d) => d.name.contains(doctorName),
      orElse: () => _doctors.first,
    );
    final doctorSrlNo = int.tryParse(doctor.id) ?? 0;

    final requestData = appointment.toApiRequest(doctorSrlNo);
    final result = await _apiService.updateAppointment(appointmentId, requestData);

    if (result.success) {
      final index = _appointments.indexWhere((a) => a.id == id);
      if (index != -1) {
        _appointments[index] = appointment;
      }
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  void removeAppointment(String id) {
    _appointments.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // ── Time slot helpers ──
  List<String> generateTimeSlots(String timings) {
    try {
      final parts = timings.split(' - ');
      if (parts.length != 2) return [];
      final start = _parseTime(parts[0].trim());
      final end = _parseTime(parts[1].trim());
      if (start == null || end == null) return [];
      final slots = <String>[];
      var current = start;
      while (_timeToMinutes(current) < _timeToMinutes(end)) {
        slots.add(_formatTime(current));
        current = _addMinutes(current, 15);
      }
      return slots;
    } catch (_) {
      return [];
    }
  }

  List<String> bookedSlots(DateTime date, String consultantName) {
    return _appointments
        .where((a) =>
    a.consultantName == consultantName &&
        a.appointmentDate.year == date.year &&
        a.appointmentDate.month == date.month &&
        a.appointmentDate.day == date.day &&
        a.status != 'Cancelled')
        .map((a) => a.timeSlot)
        .toList();
  }

  TimeOfDay? _parseTime(String s) {
    try {
      final isPM = s.contains('PM');
      final isAM = s.contains('AM');
      final cleaned = s.replaceAll('AM', '').replaceAll('PM', '').trim();
      final p = cleaned.split(':');
      int hour = int.parse(p[0]);
      int minute = int.parse(p[1]);
      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
  TimeOfDay _addMinutes(TimeOfDay t, int m) {
    final total = _timeToMinutes(t) + m;
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  String _formatTime(TimeOfDay t) {
    int hour = t.hour % 12;
    if (hour == 0) hour = 12;

    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }
}