import 'package:flutter/material.dart';

import '../../../core/services/opd_receipt_api_service.dart';
import '../../../core/services/consultation_api_service.dart';
import '../../../core/services/consultant_payments_api_service.dart';
import '../../shift_management/shift_management.dart';
import '../../../models/consultation_model/doctor_model.dart';
import '../../../models/consultation_model/appointment_model.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/camp_sync_service.dart';
import '../../../core/utils/database_helper.dart';


class OpdPatient {
  final String mrNo;
  final String fullName;
  final String phone;
  final String age;
  final String gender;
  final String address;
  final String city;
  final String panel;
  final String reference;
  final String? deviceUuid;

  const OpdPatient({
    required this.mrNo,
    required this.fullName,
    required this.phone,
    required this.age,
    required this.gender,
    required this.address,
    required this.city,
    required this.panel,
    required this.reference,
    this.deviceUuid,
  });
}

class OpdService {
  final String id;
  final String name;
  final String category;
  final double price;
  final double? followUpPrice;
  final IconData icon;
  final Color color;
  final String? imageUrl;

  const OpdService({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.followUpPrice,
    required this.icon,
    required this.color,
    this.imageUrl,
  });
}

class OpdSelectedService {
  final OpdService service;
  final int quantity;
  String? doctorName;
  String? doctorSpecialty;
  String? doctorAvatar;
  String? doctorDepartment;
  String? doctorSrlNo;

  OpdSelectedService({
    required this.service,
    this.quantity = 1,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorAvatar,
    this.doctorDepartment,
    this.doctorSrlNo,
  });
}

class OpdProvider extends ChangeNotifier {
  final OpdReceiptApiService _apiService = OpdReceiptApiService();
  final ConsultantPaymentsApiService _paymentApiService = ConsultantPaymentsApiService();
  final ConsultationApiService _consultationApi = ConsultationApiService();
  final ConnectivityService _connectivity = ConnectivityService();
  final CampSyncService _syncService = CampSyncService();
  final DatabaseHelper _db = DatabaseHelper();

  List<DoctorModel> _availableDoctorModels = [];
  List<AppointmentModel> _upcomingAppointments = [];
  List<AppointmentModel> get upcomingAppointments => _upcomingAppointments;
  bool _isLoadingAppointments = false;
  bool get isLoadingAppointments => _isLoadingAppointments;

  Map<String, dynamic>? _lastSavedReceiptTokens;
  Map<String, dynamic>? get lastSavedReceiptTokens => _lastSavedReceiptTokens;


  // ── Pagination State ──
  static const int _pageSize = 50;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _isFetchingMore = false;

  // ── Loading / error state ──
  bool _loadingServices = false;
  bool _loadingReceipts = false;
  bool _isDisposed = false; // ← CRASH FIX: track disposal
  String? _errorMessage;
  String? _lastSavedReceiptId;
  List<Map<String, dynamic>>? _lastSavedReceiptServices;
  double? _lastSavedReceiptTotal;
  double? _lastSavedReceiptDiscount;

  bool get isLoadingServices => _loadingServices;
  bool get isLoadingReceipts => _loadingReceipts;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMorePages => _currentPage <= _totalPages;
  int get totalReceiptsCount => _totalCount;
  String? get errorMessage => _errorMessage;
  String? get lastSavedReceiptId => _lastSavedReceiptId;
  List<Map<String, dynamic>>? get lastSavedReceiptServices => _lastSavedReceiptServices;
  double? get lastSavedReceiptTotal => _lastSavedReceiptTotal;
  double? get lastSavedReceiptDiscount => _lastSavedReceiptDiscount;
  bool _isLoading = false;
  bool _isSaving = false;

  // Add getters
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  // Add setters if needed (or use directly)
  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  set isSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  // ── Service Doctor Mappings ──
  Map<String, dynamic> _serviceDocs = {};
  Map<String, dynamic> get serviceDocs => _serviceDocs;
  String? _consultationSrlNo;

  Future<void> fetchServiceMappings() async {
    try {
      final res = await _consultationApi.fetchServiceDoctorMappings();
      if (res.success && res.data != null) {
        _serviceDocs = res.data!;
        _safeNotify();
      }
    } catch (e) {
      debugPrint('Error fetching service mappings: $e');
    }
  }

  // ── Refer to Discount ──
  bool _isReferredToDiscount = false;
  bool get isReferredToDiscount => _isReferredToDiscount;
  void setReferredToDiscount(bool val) {
    _isReferredToDiscount = val;
    _safeNotify();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CRASH FIX: Override dispose + safe notifyListeners
  // Root cause of crash: notifyListeners() called after widget disposed
  // while background async fetch was still running.
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  // ── Constructor ──
  OpdProvider() {
    _initStaticServices();
    // We no longer auto-load API data here to avoid unauthenticated 401 errors for patients.
    // Screens should call loadOpdServices(), loadDoctors(), and loadReceipts() explicitly.
  }

  // ── Mock Patients ──
  // final List<OpdPatient> _patients = const [
  //   OpdPatient(
  //       mrNo: '000001',
  //       fullName: 'Ahmed Hassan',
  //       phone: '0300-1234567',
  //       age: '35',
  //       gender: 'Male',
  //       address: '12-B Model Town',
  //       city: 'Lahore',
  //       panel: 'State Life',
  //       reference: 'General Physician'),
  //   OpdPatient(
  //       mrNo: '000002',
  //       fullName: 'Fatima Malik',
  //       phone: '0321-9876543',
  //       age: '28',
  //       gender: 'Female',
  //       address: 'House 5, Block C, Gulberg',
  //       city: 'Lahore',
  //       panel: 'EFU',
  //       reference: 'Specialist'),
  //   OpdPatient(
  //       mrNo: '000003',
  //       fullName: 'Muhammad Ali Khan',
  //       phone: '0333-5554444',
  //       age: '52',
  //       gender: 'Male',
  //       address: 'Sector G-10, Street 4',
  //       city: 'Islamabad',
  //       panel: 'SLIC',
  //       reference: 'General Physician'),
  //   OpdPatient(
  //       mrNo: '000004',
  //       fullName: 'Ayesha Siddiqui',
  //       phone: '0345-7778888',
  //       age: '41',
  //       gender: 'Female',
  //       address: 'Flat 3, Pearl Heights, Clifton',
  //       city: 'Karachi',
  //       panel: 'Jubilee',
  //       reference: 'Emergency'),
  //   OpdPatient(
  //       mrNo: '000005',
  //       fullName: 'Usman Tariq',
  //       phone: '0312-3334455',
  //       age: '19',
  //       gender: 'Male',
  //       address: 'Village Kot Addu',
  //       city: 'Muzaffargarh',
  //       panel: 'None',
  //       reference: 'General Physician'),
  // ];
  //
  // OpdPatient? lookupPatient(String mrNo) {
  //   try {
  //     return _patients.firstWhere((p) => p.mrNo == mrNo);
  //   } catch (_) {
  //     return null;
  //   }
  // }

  // ── Panels & References ──
  final List<String> panels = const [
    'None', 'State Life', 'EFU', 'SLIC',
    'Jubilee', 'Adamjee', 'New Hampshire', 'IGI',
  ];

  final List<String> references = const [
    'General Physician', 'Specialist', 'Emergency',
    'Self', 'Referral', 'Online',
  ];

  // ── OPD Service Categories ──
  final List<Map<String, dynamic>> serviceCategories = const [
    {'id': 'opd',          'label': 'OPD',          'icon': Icons.local_hospital_rounded,    'color': Color(0xFFE53935)},
    {'id': 'consultation', 'label': 'Consultation',  'icon': Icons.medical_information_rounded,'color': Color(0xFF00B5AD)},
    {'id': 'xray',         'label': 'X-Ray',         'icon': Icons.radio_rounded,             'color': Color(0xFF1E88E5)},
    {'id': 'ctscan',       'label': 'CT-Scan',       'icon': Icons.document_scanner_rounded,  'color': Color(0xFF8E24AA)},
    {'id': 'mri',          'label': 'MRI',           'icon': Icons.blur_circular_rounded,     'color': Color(0xFF00ACC1)},
    {'id': 'ultrasound',   'label': 'Ultrasound',    'icon': Icons.sensors_rounded,           'color': Color(0xFF43A047)},
    {'id': 'laboratory',   'label': 'Laboratory',    'icon': Icons.biotech_rounded,           'color': Color(0xFFF4511E)},
    {'id': 'emergency',    'label': 'Emergency',     'icon': Icons.emergency_rounded,         'color': Color(0xFFE53935)},
  ];

  // ── Services per Category ──
  final Map<String, List<OpdService>> services = {};

  void _initStaticServices() {
    services.clear();
    services.addAll({
      'consultation': [],
      'xray': [
        OpdService(id: 'xr1', name: 'Chest X-Ray',     category: 'xray', price: 800,  icon: Icons.radio_rounded, color: Color(0xFF1E88E5)),
        OpdService(id: 'xr2', name: 'Spine X-Ray',     category: 'xray', price: 1000, icon: Icons.radio_rounded, color: Color(0xFF1E88E5)),
        OpdService(id: 'xr3', name: 'Hand/Wrist X-Ray',category: 'xray', price: 600,  icon: Icons.radio_rounded, color: Color(0xFF1E88E5)),
      ],
      'ctscan': [
        OpdService(id: 'ct1', name: 'CT Head',    category: 'ctscan', price: 5000, icon: Icons.document_scanner_rounded, color: Color(0xFF8E24AA)),
        OpdService(id: 'ct2', name: 'CT Chest',   category: 'ctscan', price: 6000, icon: Icons.document_scanner_rounded, color: Color(0xFF8E24AA)),
        OpdService(id: 'ct3', name: 'CT Abdomen', category: 'ctscan', price: 7000, icon: Icons.document_scanner_rounded, color: Color(0xFF8E24AA)),
      ],
      'mri': [
        OpdService(id: 'mr1', name: 'MRI Brain', category: 'mri', price: 8000, icon: Icons.blur_circular_rounded, color: Color(0xFF00ACC1)),
        OpdService(id: 'mr2', name: 'MRI Spine', category: 'mri', price: 9000, icon: Icons.blur_circular_rounded, color: Color(0xFF00ACC1)),
        OpdService(id: 'mr3', name: 'MRI Knee',  category: 'mri', price: 7500, icon: Icons.blur_circular_rounded, color: Color(0xFF00ACC1)),
      ],
      'ultrasound': [
        OpdService(id: 'us1', name: 'Abdominal Ultrasound', category: 'ultrasound', price: 1500, icon: Icons.sensors_rounded, color: Color(0xFF43A047)),
        OpdService(id: 'us2', name: 'Pelvic Ultrasound',    category: 'ultrasound', price: 1500, icon: Icons.sensors_rounded, color: Color(0xFF43A047)),
        OpdService(id: 'us3', name: 'Thyroid Ultrasound',   category: 'ultrasound', price: 1200, icon: Icons.sensors_rounded, color: Color(0xFF43A047)),
      ],
      'laboratory': [
        OpdService(id: 'lb1', name: 'CBC (Complete Blood Count)', category: 'laboratory', price: 500,  icon: Icons.biotech_rounded, color: Color(0xFFF4511E)),
        OpdService(id: 'lb2', name: 'LFTs (Liver Function Test)', category: 'laboratory', price: 800,  icon: Icons.biotech_rounded, color: Color(0xFFF4511E)),
        OpdService(id: 'lb3', name: 'RFTs (Renal Function Test)', category: 'laboratory', price: 800,  icon: Icons.biotech_rounded, color: Color(0xFFF4511E)),
        OpdService(id: 'lb4', name: 'Blood Sugar (Fasting)',       category: 'laboratory', price: 200,  icon: Icons.biotech_rounded, color: Color(0xFFF4511E)),
        OpdService(id: 'lb5', name: 'HbA1c',                       category: 'laboratory', price: 1200, icon: Icons.biotech_rounded, color: Color(0xFFF4511E)),
        OpdService(id: 'lb6', name: 'Lipid Profile',               category: 'laboratory', price: 1000, icon: Icons.biotech_rounded, color: Color(0xFFF4511E)),
        OpdService(id: 'lb7', name: 'Urine Analysis',              category: 'laboratory', price: 300,  icon: Icons.biotech_rounded, color: Color(0xFFF4511E)),
      ],
      'emergency': [
        // OpdService(id: 'em1', name: 'Emergency Consultation', category: 'emergency', price: 2500, icon: Icons.emergency_rounded, color: Color(0xFFE53935)),
        // OpdService(id: 'em2', name: 'Trauma Care',            category: 'emergency', price: 5000, icon: Icons.emergency_rounded, color: Color(0xFFE53935)),
        // OpdService(id: 'em3', name: 'Resuscitation',          category: 'emergency', price: 3500, icon: Icons.emergency_rounded, color: Color(0xFFE53935)),
        // OpdService(id: 'em4', name: 'Emergency Surgery Prep', category: 'emergency', price: 4000, icon: Icons.emergency_rounded, color: Color(0xFFE53935)),
      ],
    });
  }

  // ── Load OPD Services from API ──
  Future<void> loadOpdServices() async {
    _loadingServices = true;
    _errorMessage = null;
    _safeNotify();

    bool loadFromLocal = false;
    if (!_connectivity.isOnline.value) {
      loadFromLocal = true;
    }

    try {
      if (!loadFromLocal) {
        try {
          final results = await Future.wait([
            _apiService.fetchOpdServices().timeout(const Duration(seconds: 10)),
            _apiService.fetchLabTests().timeout(const Duration(seconds: 10)),
            _apiService.fetchRadiologyTests().timeout(const Duration(seconds: 10)),
          ]);
          
          final opdResult = results[0] as OpdServicesResult;
          final labResult = results[1] as Map<String, dynamic>;
          final radResult = results[2] as Map<String, dynamic>;

          if (opdResult.success) {
            services.removeWhere((key, _) => key != 'consultation' && key != 'emergency');

            for (var s in opdResult.services) {
              if (s.isActive == 0) continue;
              
              final name = s.serviceName.toLowerCase();
              final head = s.receiptType.toLowerCase();
              double rate = double.tryParse(s.serviceRate) ?? 0.0;
              String category = 'standard';
              Color color = Colors.blueGrey;
              IconData icon = Icons.medical_services_rounded;

              if (name.contains('consultation')) {
                _consultationSrlNo = s.srlNo.toString();
              }

              if (head.contains('x-ray') || head.contains('xray') || name.contains('x-ray') || name.contains('xray')) {
                category = 'xray'; color = const Color(0xFF1E88E5); icon = Icons.radio_rounded;
              } else if (head.contains('ct scan') || head.contains('ctscan') || name.contains('ct scan') || name.contains('ctscan')) {
                category = 'ctscan'; color = const Color(0xFF8E24AA); icon = Icons.document_scanner_rounded;
              } else if (head.contains('mri') || name.contains('mri')) {
                category = 'mri'; color = const Color(0xFF00ACC1); icon = Icons.blur_circular_rounded;
              } else if (head.contains('ultrasound') || name.contains('ultrasound') || head.contains('u/s') || name.contains('u/s')) {
                category = 'ultrasound'; color = const Color(0xFF43A047); icon = Icons.sensors_rounded;
              } else if (head.contains('laboratory') || head.contains('lab') || name.contains('lab ') || name.contains(' laboratory')) {
                category = 'laboratory'; color = const Color(0xFFF4511E); icon = Icons.biotech_rounded;
              } else if (head.contains('emergency') || name.contains('emergency')) {
                category = 'emergency'; color = const Color(0xFFE53935); icon = Icons.emergency_rounded;
              }

              final service = OpdService(
                id: s.serviceId, name: s.serviceName, category: category,
                price: rate, icon: icon, color: color, imageUrl: s.imageUrl,
              );

              if (!services.containsKey(category)) services[category] = [];
              if (!services[category]!.any((e) => e.id == service.id)) {
                services[category]!.add(service);
              }
            }
          }

          if (labResult['success'] == true) {
            final list = labResult['data'] as List<dynamic>? ?? [];
            for (var t in list) {
              if (t['is_active'] == 0) continue;
              final service = OpdService(
                id: 'LB_${t['id'] ?? t['srl_no']}',
                name: t['test_name']?.toString() ?? 'Unnamed Lab Test',
                category: 'laboratory',
                price: double.tryParse(t['test_rate']?.toString() ?? '0') ?? 0.0,
                icon: Icons.biotech_rounded, color: const Color(0xFFF4511E),
                imageUrl: t['image_url']?.toString(),
              );
              if (!services.containsKey('laboratory')) services['laboratory'] = [];
              if (!services['laboratory']!.any((e) => e.id == service.id)) services['laboratory']!.add(service);
            }
          }

          if (radResult['success'] == true) {
            final list = radResult['data'] as List<dynamic>? ?? [];
            for (var t in list) {
              if (t['is_active'] == 0) continue;
              final testCatRaw = t['test_category']?.toString().toLowerCase() ?? '';
              String category = 'xray';
              Color color = const Color(0xFF1E88E5);
              IconData icon = Icons.radio_rounded;
              if (testCatRaw.contains('ct-scan') || testCatRaw.contains('ct scan')) {
                category = 'ctscan'; color = const Color(0xFF8E24AA); icon = Icons.document_scanner_rounded;
              } else if (testCatRaw.contains('mri')) {
                category = 'mri'; color = const Color(0xFF00ACC1); icon = Icons.blur_circular_rounded;
              } else if (testCatRaw.contains('ultrasound')) {
                category = 'ultrasound'; color = const Color(0xFF43A047); icon = Icons.sensors_rounded;
              }
              final service = OpdService(
                id: 'RD_${t['id'] ?? t['srl_no']}',
                name: t['test_name']?.toString() ?? 'Unnamed Rad Test',
                category: category,
                price: double.tryParse(t['test_rate']?.toString() ?? '0') ?? 0.0,
                icon: icon, color: color,
                imageUrl: t['image_url']?.toString(),
              );
              if (!services.containsKey(category)) services[category] = [];
              if (!services[category]!.any((e) => e.id == service.id)) services[category]!.add(service);
            }
          }
        } catch (e) {
          debugPrint('⚠️ OPD API Exception: $e. Falling back to local.');
          loadFromLocal = true;
        }
      }

      if (loadFromLocal) {
        debugPrint('📴 Loading OPD services from local master data.');
        final localSvcs = await _db.queryAll('master_services');
        if (localSvcs.isNotEmpty) {
          services.removeWhere((key, _) => key != 'consultation' && key != 'emergency');
          for (var s in localSvcs) {
            if (s['is_active'] == 0) continue;
            final name = s['service_name'].toString().toLowerCase();
            final head = s['receipt_type'].toString().toLowerCase();
            double rate = double.tryParse(s['service_rate'].toString()) ?? 0.0;
            String category = 'standard';
            Color color = Colors.blueGrey;
            IconData icon = Icons.medical_services_rounded;

            if (name.contains('consultation')) _consultationSrlNo = s['srl_no'].toString();

            if (head.contains('x-ray') || head.contains('xray') || name.contains('x-ray') || name.contains('xray')) {
              category = 'xray'; color = const Color(0xFF1E88E5); icon = Icons.radio_rounded;
            } else if (head.contains('ct scan') || head.contains('ctscan') || name.contains('ct scan') || name.contains('ctscan')) {
              category = 'ctscan'; color = const Color(0xFF8E24AA); icon = Icons.document_scanner_rounded;
            } else if (head.contains('laboratory') || head.contains('lab') || name.contains('lab ') || name.contains(' laboratory')) {
              category = 'laboratory'; color = const Color(0xFFF4511E); icon = Icons.biotech_rounded;
            } else if (head.contains('emergency') || name.contains('emergency')) {
              category = 'emergency'; color = const Color(0xFFE53935); icon = Icons.emergency_rounded;
            }

            final service = OpdService(
              id: s['service_id'].toString(), name: s['service_name'].toString(), category: category,
              price: rate, icon: icon, color: color,
            );
            if (!services.containsKey(category)) services[category] = [];
            if (!services[category]!.any((e) => e.id == service.id)) services[category]!.add(service);
          }
        }
      }
      _errorMessage = null;
    } catch (e) {
      if (!_isDisposed) _errorMessage = 'Failed to load services: $e';
      debugPrint('❌ Error loading OPD/Ref/Lab/Rad services: $e');
    }

    _loadingServices = false;
    _safeNotify();
  }

  // ── Load Doctors ──
  Future<void> loadDoctors() async {
    debugPrint('🔍 loadDoctors triggered. isOnline: ${_connectivity.isOnline.value}');
    bool loadFromLocal = false;
    if (!_connectivity.isOnline.value) {
      loadFromLocal = true;
    }

    try {
      if (!loadFromLocal) {
        try {
          await fetchServiceMappings().timeout(const Duration(seconds: 5));
          if (_consultationSrlNo == null) {
             await loadOpdServices().timeout(const Duration(seconds: 10));
          }
          
          final result = await _consultationApi.fetchDoctors().timeout(const Duration(seconds: 10));
          if (result.success && result.doctors.isNotEmpty) {
             final colors = [
               const Color(0xFF00B5AD), const Color(0xFF8E24AA),
               const Color(0xFF1E88E5), const Color(0xFFE53935),
               const Color(0xFF43A047), const Color(0xFFF4511E),
               const Color(0xFF00897B), const Color(0xFFD81B60),
             ];
             final doctorServices = result.doctors
                 .where((d) => d.isActive == 1)
                 .toList()
                 .asMap()
                 .entries
                 .map((entry) {
               final i = entry.key;
               final d = entry.value;
               double fee = double.tryParse(d.consultationFee) ?? 0.0;
               return OpdService(
                 id: d.doctorId,
                 name: 'Dr. ${d.doctorName}',
                 category: 'consultation',
                 price: fee,
                 icon: Icons.person_rounded,
                 color: colors[i % colors.length],
               );
             }).toList();
             services['consultation'] = doctorServices;
             _safeNotify();
             return;
          } else {
             debugPrint('⚠️ Doctor API failed: ${result.message}. Trying local.');
             loadFromLocal = true;
          }
        } catch (e) {
          debugPrint('⚠️ Doctor API Exception: $e. Trying local.');
          loadFromLocal = true;
        }
      }

      if (loadFromLocal) {
        debugPrint('📴 Loading doctors from local master data.');
        final localDocs = await _db.queryAll('master_doctors');
        if (localDocs.isNotEmpty) {
           final colors = [
             const Color(0xFF00B5AD), const Color(0xFF8E24AA),
             const Color(0xFF1E88E5), const Color(0xFFE53935),
             const Color(0xFF43A047), const Color(0xFFF4511E),
             const Color(0xFF00897B), const Color(0xFFD81B60),
           ];
           final doctorServices = localDocs.asMap().entries.map((entry) {
             final i = entry.key;
             final d = entry.value;
             final fee = double.tryParse(d['consultation_fee'] ?? '0') ?? 0.0;
             return OpdService(
               id: d['doctor_id'],
               name: 'Dr. ${d['doctor_name']}',
               category: 'consultation',
               price: fee,
               followUpPrice: (fee * 0.7).floorToDouble(),
               icon: Icons.person_rounded,
               color: colors[i % colors.length],
             );
           }).toList();
           services['consultation'] = doctorServices;
           _errorMessage = null; // Found locally
           _safeNotify();
        } else {
           debugPrint('❌ No doctors found in local master data.');
           _errorMessage = 'No doctors found. If you are at a camp, please "Bootstrap" while online.';
           _safeNotify();
        }
      }
    } catch (e) {
      debugPrint('❌ Fatal error in loadDoctors: $e');
    }
  }


  // ── Fetch Upcoming Appointments ──
  Future<void> fetchUpcomingAppointments(String mrNumber) async {
    if (mrNumber.isEmpty) {
      _upcomingAppointments = [];
      _safeNotify();
      return;
    }
    _isLoadingAppointments = true;
    _safeNotify();
    try {
      final res = await _consultationApi.fetchAppointmentsByMr(mrNumber);
      if (res.success) {
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        _upcomingAppointments = res.appointments.where((a) {
          final aDate = a.appointmentDate.split('T')[0];
          return aDate == todayStr && a.status.toLowerCase() != 'cancelled';
        }).toList();
      } else {
        _upcomingAppointments = [];
      }
    } catch (e) {
      _upcomingAppointments = [];
      debugPrint('Error fetching appointments: $e');
    } finally {
      _isLoadingAppointments = false;
      _safeNotify();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // RECEIPTS — Paginated loading
  // ─────────────────────────────────────────────────────────────────────────────

  // Internal mutable list — do NOT expose directly to UI widgets
  final List<Map<String, dynamic>> _receipts = [];

  // Read-only copy for UI — safe to iterate
  List<Map<String, dynamic>> get receipts => List.unmodifiable(_receipts);

  // ── Convert API model → local map (shared helper) ──
  Map<String, dynamic> _toReceiptMap(dynamic r) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(r.date);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return {
      'srl_no': r.srlNo,
      'receipt_id': r.receiptId,
      'receiptNo': r.receiptId,
      'mrNo': r.patientMrNumber,
      'patient_mr_number': r.patientMrNumber,
      'patient_name': r.patientName,
      'patientName': r.patientName,
      'age': r.patientAge?.toString() ?? '',
      'patient_age': r.patientAge,
      'gender': r.patientGender,
      'patient_gender': r.patientGender,
      'date': parsedDate,
      'shift_date': parsedDate,
      'services': r.serviceDetail.isNotEmpty
          ? r.serviceDetail.split(',').map((e) => e.trim()).toList()
          : (r.opdService.isNotEmpty
          ? r.opdService.split(',').map((e) => e.trim()).toList()
          : <String>[]),
      'details': r.serviceDetail,
      'service_detail': r.serviceDetail,
      'total': r.totalAmount,
      'total_amount': r.totalAmount,
      'discount': r.discount,
      'paid': r.paid,
      'payable': r.payable ?? (r.totalAmount - r.discount),
      'status': r.status,
      'opd_cancelled': r.opdCancelled ?? false,
      'paid_to_doctor': r.paidToDoctor ?? false,
      'phone_number': r.phoneNumber,
    };
  }

  // ── Load page 1 (called on init and refresh) ──
  Map<String, dynamic> _localVisitToMap(Map<String, dynamic> v) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(v['date'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return {
      'srl_no': 0,
      'receipt_id': v['receipt_id'] ?? 'LOCAL',
      'receiptNo': v['receipt_id'] ?? 'LOCAL',
      'mrNo': v['mr_number'] ?? v['patient_uuid'] ?? '',
      'patient_mr_number': v['mr_number'] ?? v['patient_uuid'] ?? '',
      'patient_name': v['patient_name'] ?? '',
      'patientName': v['patient_name'] ?? '',
      'age': '',
      'patient_age': null,
      'gender': '',
      'patient_gender': '',
      'date': parsedDate,
      'time': v['time'] ?? '',
      'opd_service': v['opd_service'] ?? '',
      'service_detail': v['opd_service'] ?? '',
      'total_amount': double.tryParse(v['total_amount']?.toString() ?? '0') ?? 0.0,
      'discount': 0.0,
      'paid': double.tryParse(v['paid']?.toString() ?? '0') ?? 0.0,
      'status': 'Pending Sync', // Special status for local data
    };
  }

  Future<void> loadReceipts() async {
    if (_isDisposed) return;

    _loadingReceipts = true;
    _errorMessage = null;
    _currentPage = 1;
    _receipts.clear();
    _totalCount = 0;
    _safeNotify();

    try {
      // 1. Load local pending visits first
      final localVisits = await _db.queryAll('visits_local');
      final List<Map<String, dynamic>> localMapped = localVisits
          .where((v) => v['sync_status'] == 'pending')
          .map((v) => _localVisitToMap(v))
          .toList();
      
      _receipts.addAll(localMapped);
      _totalCount = localMapped.length;

      // 2. Try online load
      if (_connectivity.isOnline.value) {
        try {
          final result = await _apiService.fetchOpdReceipts(page: 1, limit: _pageSize).timeout(const Duration(seconds: 10));

          if (_isDisposed) return;

          if (result.success) {
            _receipts.addAll(result.receipts.map(_toReceiptMap));
            _totalPages = result.totalPages;
            _totalCount += result.totalCount;
            _currentPage = 2;
            _errorMessage = null;
          } else {
            _errorMessage = result.message;
          }
        } catch (e) {
          debugPrint('⚠️ Online receipts load failed (ignoring since offline records shown): $e');
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = 'Failed to load receipts: $e';
        debugPrint('❌ Error loading receipts: $e');
      }
    }

    _loadingReceipts = false;
    _safeNotify();
  }

  // ── Load next page (called by scroll listener) ──
  Future<void> loadMoreReceipts() async {
    if (_isDisposed || _isFetchingMore || !hasMorePages) return;

    _isFetchingMore = true;
    _safeNotify();

    try {
      final result = await _apiService.fetchOpdReceipts(
        page: _currentPage,
        limit: _pageSize,
      );

      if (_isDisposed) return; // CRASH FIX

      if (result.success) {
        _receipts.addAll(result.receipts.map(_toReceiptMap));
        _totalPages = result.totalPages;
        _totalCount = result.totalCount;
        _currentPage++;
      } else {
        _errorMessage = result.message;
      }
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('❌ Error loading more receipts: $e');
      }
    }

    _isFetchingMore = false;
    _safeNotify();
  }

  // ── Cancel receipt ──
  Future<bool> cancelReceipt(int index, String cancelReason) async {
    if (index < 0 || index >= _receipts.length) return false;

    final receipt = _receipts[index];
    final receiptSrlNo = receipt['srl_no'];

    if (receiptSrlNo == null || receiptSrlNo == 0) {
      _errorMessage = 'Cannot cancel: Missing receipt serial number';
      _safeNotify();
      return false;
    }

    _loadingReceipts = true;
    _errorMessage = null;
    _safeNotify();

    final result = await _apiService.cancelOpdReceipt(receiptSrlNo, cancelReason);

    if (_isDisposed) return result.success; // CRASH FIX

    if (result.success) {
      _receipts[index]['status'] = 'Cancelled';
      _receipts[index]['details'] = 'CANCELLED - ${_receipts[index]['details']}';
      _errorMessage = null;
    } else {
      _errorMessage = result.message;
    }

    _loadingReceipts = false;
    _safeNotify();
    return result.success;
  }

  // ── Refund receipt ──
  Future<bool> refundReceipt(int index, double refundAmount, String refundReason) async {
    if (index < 0 || index >= _receipts.length) return false;

    final receipt = _receipts[index];
    debugPrint('💰 Attempting to refund receipt at index $index: $receipt');

    int? receiptSrlNo;
    if (receipt.containsKey('srl_no') && receipt['srl_no'] != null) {
      receiptSrlNo = receipt['srl_no'] is int
          ? receipt['srl_no'] as int
          : int.tryParse(receipt['srl_no'].toString());
    }

    if (receiptSrlNo == null || receiptSrlNo == 0) {
      _errorMessage = 'Cannot refund: Missing receipt serial number. Please refresh data.';
      debugPrint('❌ ERROR: Missing srl_no in receipt: $receipt');
      _safeNotify();
      return false;
    }

    _loadingReceipts = true;
    _errorMessage = null;
    _safeNotify();

    final result = await _apiService.refundOpdReceipt(receiptSrlNo, refundAmount, refundReason);

    if (_isDisposed) return result.success; // CRASH FIX

    if (result.success) {
      _receipts[index]['status'] = 'Refunded';
      _receipts[index]['discount'] = (receipt['discount'] as double) + refundAmount;
      _receipts[index]['paid'] = (receipt['paid'] as double) - refundAmount;

      if (result.receipt != null) {
        _receipts[index]['total_amount'] = result.receipt!.totalAmount;
        _receipts[index]['discount'] = result.receipt!.discount;
        _receipts[index]['paid'] = result.receipt!.paid;
        _receipts[index]['payable'] = result.receipt!.payable;
      }

      debugPrint('✅ Refund successful for receipt srl_no: $receiptSrlNo');
      _errorMessage = null;
    } else {
      debugPrint('❌ Refund failed: ${result.message}');
      _errorMessage = result.message;
    }

    _loadingReceipts = false;
    _safeNotify();
    return result.success;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SELECTED SERVICES
  // ─────────────────────────────────────────────────────────────────────────────

  final List<OpdSelectedService> _selectedServices = [];
  List<OpdSelectedService> get selectedServices => List.unmodifiable(_selectedServices);

  void addService(OpdService service) {
    if (!_selectedServices.any((s) => s.service.id == service.id)) {
      String? dept, srl, dName;

      if (service.category == 'consultation') {
        try {
          final doc = _availableDoctorModels.firstWhere(
                (d) => d.doctorId == service.id,
            orElse: () => _availableDoctorModels.firstWhere(
                  (d) => 'Dr. ${d.doctorName}' == service.name.split(' (')[0],
              orElse: () => _availableDoctorModels.first,
            ),
          );
          dept = doc.doctorDepartment;
          srl = doc.srlNo.toString();
          dName = doc.doctorName;
        } catch (_) {}
      }

      _selectedServices.add(OpdSelectedService(
        service: service,
        doctorName: dName,
        doctorDepartment: dept,
        doctorSrlNo: srl,
      ));
      _safeNotify();
    }
  }

  void removeService(String serviceId) {
    _selectedServices.removeWhere((s) => s.service.id == serviceId);
    _safeNotify();
  }

  bool isSelected(String serviceId) =>
      _selectedServices.any((s) => s.service.id == serviceId);

  double get servicesTotal =>
      _selectedServices.fold(0.0, (sum, s) => sum + (s.service.price * s.quantity));

  void clearServices() {
    _selectedServices.clear();
    _safeNotify();
  }

  // ── Share Calculation Logic ──
  Map<String, dynamic> calculateServiceShare(OpdSelectedService s) {
    double drShareAmount = 0;
    double drSharePercentage = 0;
    String shareType = 'percentage';
    final lineTotal = s.service.price * s.quantity;

    if (s.service.category == 'consultation') {
      // Find doctor info
      DoctorModel? doc;
      try {
        doc = _availableDoctorModels.firstWhere(
          (d) => d.srlNo.toString() == s.doctorSrlNo,
        );
      } catch (_) {
        try {
          doc = _availableDoctorModels.firstWhere((d) => d.doctorId == s.service.id);
        } catch (_) {
          if (_availableDoctorModels.isNotEmpty) doc = _availableDoctorModels.first;
        }
      }

      if (doc != null) {
        shareType = 'percentage';
        drSharePercentage = double.tryParse(doc.doctorShare) ?? 100.0;

        final lookupKey = _consultationSrlNo ?? 'Consultation';
        if (_serviceDocs.containsKey(lookupKey)) {
          final mappings = _serviceDocs[lookupKey] as List<dynamic>;
          final config = mappings.firstWhere(
            (m) => m['doctor_srl_no'].toString() == s.doctorSrlNo,
            orElse: () => null,
          );

          if (config != null) {
            shareType = config['share_type'] ?? 'percentage';
            if (shareType == 'fixed') {
              drShareAmount = (double.tryParse(config['share_value'].toString()) ?? 0.0) * s.quantity;
              drSharePercentage = 0;
            } else {
              drSharePercentage = double.tryParse(config['share_value'].toString()) ?? 0.0;
              drShareAmount = lineTotal * (drSharePercentage / 100.0);
            }
          } else {
            drShareAmount = lineTotal * (drSharePercentage / 100.0);
          }
        } else {
          drShareAmount = lineTotal * (drSharePercentage / 100.0);
        }
      }
    } else {
      // Other services (Lab, Xray etc)
      // Check if doctor is assigned and if there's a mapping
      String serviceLookupId = s.service.id;
      // Parity Fix: Strip internal prefixes for mapping lookups
      if (serviceLookupId.startsWith('LB_')) serviceLookupId = serviceLookupId.substring(3);
      if (serviceLookupId.startsWith('RD_')) serviceLookupId = serviceLookupId.substring(3);

      if (s.doctorSrlNo != null && _serviceDocs.containsKey(serviceLookupId)) {
        final mappings = _serviceDocs[serviceLookupId] as List<dynamic>;
        final config = mappings.firstWhere(
          (m) => m['doctor_srl_no'].toString() == s.doctorSrlNo,
          orElse: () => null,
        );

        if (config != null) {
          shareType = config['share_type'] ?? 'percentage';
          if (shareType == 'fixed') {
            drShareAmount = (double.tryParse(config['share_value'].toString()) ?? 0.0) * s.quantity;
            drSharePercentage = 0;
          } else {
            drSharePercentage = double.tryParse(config['share_value'].toString()) ?? 0.0;
            drShareAmount = lineTotal * (drSharePercentage / 100.0);
          }
        }
      }
    }

    return {
      'drSharePercentage': drSharePercentage,
      'drShareAmount': drShareAmount,
      'shareType': shareType,
    };
  }

  double get totalDrShareAmount {
    return _selectedServices.fold(0.0, (sum, s) {
      return sum + (calculateServiceShare(s)['drShareAmount'] as double);
    });
  }

  double get totalHospitalShareAmount {
    return servicesTotal - totalDrShareAmount;
  }

  bool get hasEmergencyService =>
      _selectedServices.any((s) => s.service.category == 'emergency');

  bool _emergencyAdmission = false;
  bool get emergencyAdmission => _emergencyAdmission;
  set emergencyAdmission(bool val) {
    _emergencyAdmission = val;
    _safeNotify();
  }

  final List<Map<String, dynamic>> _admittedEmergencyPatients = [];
  List<Map<String, dynamic>> get admittedEmergencyPatients =>
      List.unmodifiable(_admittedEmergencyPatients);

  void admitEmergencyPatient(Map<String, dynamic> patientData) {
    _admittedEmergencyPatients.add(patientData);
    _safeNotify();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SAVE RECEIPT
  // ─────────────────────────────────────────────────────────────────────────────

  int _receiptCounter = 71960;

  Future<bool> saveReceipt({
    required OpdPatient patient,
    required List<OpdSelectedService> services,
    required double discount,
    required double amountPaid,
    ShiftModel? currentShift,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final double totalAmount = services.fold(0.0, (sum, s) => sum + (s.service.price * s.quantity));
    final double payableAmount = (totalAmount - discount).clamp(0.0, double.infinity);
    final double balanceAmount = (payableAmount - amountPaid).clamp(0.0, double.infinity);

    // --- Token Flow Sync (React Parity) ---
    final Map<String, dynamic> appointmentTokens = {};
    final List<int> appointmentIds = [];

    for (var svc in services) {
      if (svc.service.category == 'consultation' &&
          svc.doctorSrlNo != null &&
          svc.doctorSrlNo!.isNotEmpty) {
        // Try to find matching appointment in today's upcoming appointments
        try {
          final matchingAppt = _upcomingAppointments.firstWhere((a) {
            final drId = a.doctorSrlNo.toString();
            final patientMr = a.mrNumber;
            // Parity Fix: Compare against doctorSrlNo, not service.id
            return drId == svc.doctorSrlNo && patientMr == patient.mrNo;
          });

          if (matchingAppt.tokenNumber != null) {
            appointmentTokens[svc.doctorSrlNo!] = matchingAppt.tokenNumber;
          }
          appointmentIds.add(matchingAppt.id);
        } catch (_) {
          // No match found in upcoming appointments
        }
      }
    }

    String categoryToLabel(String category, OpdSelectedService svc) {
      switch (category) {
        case 'consultation': return 'Consultation';
        case 'laboratory':   return 'Laboratory';
        case 'xray':         return 'X-Ray';
        case 'ctscan':       return 'CT-Scan';
        case 'mri':          return 'MRI';
        case 'ultrasound':   return 'Ultrasound';
        case 'emergency':    return 'Emergency';
        default:            return svc.service.name;
      }
    }

    final servicesHeads = services.map((s) => categoryToLabel(s.service.category, s)).toSet().toList();
    // React prefixes consultation details with "Dr. Name"
    final detailsList = services.map((s) {
      if (s.service.category == 'consultation' && s.doctorName != null && s.doctorName!.isNotEmpty) {
        return 'Dr. ${s.doctorName}';
      }
      return s.service.name;
    }).toList();

    String? firstDoctorId;
    final consSvc = services.where((s) => s.service.category == 'consultation').toList();
    if (consSvc.isNotEmpty) firstDoctorId = consSvc.first.service.id;

    double totalDrSharePercentage = 0;
    for (var s in consSvc) {
      totalDrSharePercentage += (calculateServiceShare(s)['drSharePercentage'] as num).toDouble();
    }
    double avgDrShare = consSvc.isNotEmpty ? totalDrSharePercentage / consSvc.length : 0;
    double totalDrShare = 0;

    final serviceDetails = services.map((s) {
      final shareInfo = calculateServiceShare(s);
      final drShareAmount = shareInfo['drShareAmount'] as double;
      final drSharePercentage = shareInfo['drSharePercentage'] as double;
      final shareType = shareInfo['shareType'] as String;
      final lineTotal = s.service.price * s.quantity;

      totalDrShare += drShareAmount;

      return {
        'id': s.service.id,
        'name': s.service.name,
        'rate': s.service.price,
        'quantity': s.quantity,
        'total': lineTotal,
        'type': s.service.category,
        'drShare': drSharePercentage,
        'drShareAmount': drShareAmount,
        'shareType': shareType,
        'doctorSrlNo': s.doctorSrlNo,
        'doctorName': s.doctorName,
        'department': s.doctorDepartment,
      };
    }).toList();

    totalDrShare = serviceDetails.fold(0.0, (sum, d) => sum + (d['drShareAmount'] as double));

    final payload = {
      'patient_mr_number': patient.mrNo,
      'patient_name': patient.fullName,
      'phone_number': patient.phone.isEmpty ? 'N/A' : patient.phone,
      'patient_age': patient.age,
      'patient_gender': patient.gender,
      'patient_address': patient.address.isEmpty ? 'N/A' : patient.address,
      'city': patient.city.isEmpty ? 'N/A' : patient.city,
      'panel': (patient.panel == 'None' || patient.panel.isEmpty) ? 'Private' : patient.panel,
      'reference': (patient.reference == 'None' || patient.reference.isEmpty) ? 'Self' : patient.reference,
      'doctor_id': firstDoctorId,
      'date': dateStr, 'time': timeStr,
      'opd_service': servicesHeads.join(', '),
      'service_detail': detailsList.join(', '),
      'service_details': serviceDetails,
      'total_amount': totalAmount, 'service_amount': totalAmount,
      'discount': discount, 'payable': payableAmount,
      'paid': amountPaid, 'balance': balanceAmount,
      'dr_share': avgDrShare, 'dr_share_amount': totalDrShare,
      'hospital_share': totalAmount - totalDrShare,
      'opd_discount': discount > 0, 'discount_amount': discount,
      'discount_reason': null, 'discount_id': null,
      'patient_token_appointment': appointmentIds.isNotEmpty,
      'appointment_tokens': appointmentTokens,
      'appointment_ids': appointmentIds,
      'patient_checked': false,
      'patient_requested_discount': discount > 0,
      'status': 'Active', 'payment_mode': 'Cash', 'receipt_type': 'Small',
      'shift_id': currentShift?.shiftId ?? 0,
      'shift_type': currentShift?.shiftType ?? 'N/A',
      'shift_date': currentShift?.shiftDate ?? dateStr,
      'emergency_paid': servicesHeads.any((h) => h.toLowerCase() == 'emergency'),
      'refer_to_discount': _isReferredToDiscount,
    };

    debugPrint('══ OPD RECEIPT PAYLOAD ══\n$payload');

    bool success = false;
    bool savedLocally = false;

    if (_connectivity.isOnline.value) {
      try {
        final apiResult = await _apiService.createOpdReceipt(payload).timeout(const Duration(seconds: 10));
        success = apiResult.success;
        if (success) {
          _lastSavedReceiptId = apiResult.receipt?.receiptId;
          _lastSavedReceiptTokens = apiResult.tokens ?? apiResult.receipt?.tokens;
        } else {
          _errorMessage = apiResult.message;
          debugPrint('❌ API Save Failed: ${apiResult.message}');
          // If it's a network error or server down, we can fallback
          if (apiResult.message?.toLowerCase().contains('connection') == true || 
              apiResult.message?.toLowerCase().contains('timeout') == true ||
              apiResult.message?.toLowerCase().contains('failed to connect') == true) {
            savedLocally = true;
          }
        }
      } catch (e) {
        debugPrint('⚠️ API Exception: $e. Falling back to local storage.');
        savedLocally = true;
      }
    } else {
      savedLocally = true;
    }

    if (savedLocally) {
      debugPrint('📴 Saving receipt locally (Offline/API Failure).');
      try {
        final localVisit = {
          'patient_uuid': patient.deviceUuid ?? payload['patient_mr_number'],
          'mr_number': payload['patient_mr_number'], // Store the MR (could be PENDING)
          'patient_name': payload['patient_name'],
          'receipt_id': 'LOCAL-${DateTime.now().millisecondsSinceEpoch}',
          'date': payload['date'],
          'time': payload['time'],
          'opd_service': payload['opd_service'],
          'total_amount': payload['total_amount'],
          'paid': payload['paid'],
          'sync_status': 'pending',
        };
        _lastSavedReceiptId = await _syncService.saveVisitLocal(localVisit);
        success = true;
      } catch (e) {
        debugPrint('❌ Local Save Error: $e');
        _errorMessage = 'Failed to save locally: $e';
        success = false;
      }
    }

    debugPrint('══ OPD RECEIPT RESULT ══\nsuccess: $success');

    if (_isDisposed) return success;

    if (!success) {
      _safeNotify();
      return false;
    }
    _lastSavedReceiptServices = List<Map<String, dynamic>>.from(serviceDetails);
    _lastSavedReceiptTotal = totalAmount;
    _lastSavedReceiptDiscount = discount;

    // Post-save cleanup logic removed (MR incrementing handled by MrProvider + UI)

    if (!_isReferredToDiscount && _connectivity.isOnline.value) {
      for (var i = 0; i < services.length; i++) {
        final svc = services[i];
        final detail = serviceDetails[i];
        final drShareAmount = (detail['drShareAmount'] as num?)?.toDouble() ?? 0.0;
        final drShareValue = (detail['drShare'] as num?)?.toDouble() ?? 0.0;

        if (drShareAmount > 0) {
          final dName = svc.doctorName ??
              (services.firstWhere((s) => s.doctorName != null, orElse: () => services.first).doctorName ?? 'Unknown');
          final dDept = svc.doctorDepartment ?? '';

          await _paymentApiService.createConsultantPayment({
            'payment_date': dateStr,
            'payment_time': timeStr,
            'doctor_name': dName,
            'doctor_id': detail['doctorSrlNo'] ?? firstDoctorId,
            'payment_department': dDept,
            'total': detail['total'],
            'payment_share': drShareValue,
            'payment_amount': drShareAmount,
            'share_type': detail['shareType'],
            'receipt_id': _lastSavedReceiptId,
            'patient_id': patient.mrNo,
            'patient_date': dateStr,
            'patient_service': svc.service.name,
            'patient_name': patient.fullName,
            'shift_id': currentShift?.shiftId ?? 0,
            'shift_type': currentShift?.shiftType ?? 'N/A',
            'shift_date': currentShift?.shiftDate ?? dateStr,
          });
        }
      }
    }

    if (_isDisposed) return true;

    final receiptNo = _lastSavedReceiptId ?? 'OPD$_receiptCounter';

    _receipts.insert(0, {
      'receiptNo': receiptNo,
      'mrNo': patient.mrNo, 'patientName': patient.fullName,
      'age': patient.age, 'gender': patient.gender,
      'date': DateTime.now(),
      'services': services.map((s) => s.service.name).toList(),
      'details': detailsList.join(', '),
      'total': totalAmount, 'discount': discount,
      'paid': amountPaid, 'status': 'Active',
    });
    _receiptCounter++;
    _totalCount++;

    if (_emergencyAdmission &&
        services.any((s) => s.service.category == 'emergency')) {
      _admittedEmergencyPatients.add({
        'mrNo': patient.mrNo, 'name': patient.fullName,
        'age': patient.age, 'gender': patient.gender,
        'phone': patient.phone, 'address': patient.address,
        'admittedSince': DateTime.now(), 'receiptNo': receiptNo,
        'emergencyServices': services
            .where((s) => s.service.category == 'emergency')
            .map((s) => s.service.name)
            .toList(),
      });
    }

    _emergencyAdmission = false;
    _selectedServices.clear();
    _safeNotify();
    return true;
  }
}