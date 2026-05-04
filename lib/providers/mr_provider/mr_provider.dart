import 'package:flutter/material.dart';
import '../../core/services/mr_api_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/camp_sync_service.dart';
import '../../core/utils/database_helper.dart';
import '../../models/mr_model/mr_patient_model.dart';

class MrProvider extends ChangeNotifier {
  final MrApiService _apiService = MrApiService();
  final ConnectivityService _connectivity = ConnectivityService();
  final CampSyncService _syncService = CampSyncService();
  final DatabaseHelper _db = DatabaseHelper();

  // ── Pagination State ──
  static const int _pageSize = 50;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  // ── Core State ──
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;
  String? _nextMrNumber;
  List<PatientModel> _patients = [];
  String _searchQuery = '';
  PatientModel? _selectedPatient;
  int _totalCount = 0;

  // ── Getters ──
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMorePages => _currentPage <= _totalPages;
  String? get errorMessage => _errorMessage;
  String? get nextMrNumber => _nextMrNumber;
  PatientModel? get selectedPatient => _selectedPatient;
  int get totalPatients => _patients.length;
  int get totalCount => _totalCount;
  String get searchQuery => _searchQuery;

  // ── Constructor ──
  MrProvider() {
    loadPatients();
    fetchNextMR();
  }

  // ── Filtered patients list (local search fallback) ──
  List<PatientModel> get patients {
    if (_searchQuery.isEmpty) return List.from(_patients);
    final q = _searchQuery.toLowerCase();
    return _patients.where((p) {
      return p.mrNumber.toLowerCase().contains(q) ||
          p.fullName.toLowerCase().contains(q) ||
          p.phoneNumber.contains(q) ||
          p.cnic.contains(q);
    }).toList();
  }

  Future<void> loadPatients() async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = 1;
    _patients = [];
    _totalCount = 0;
    notifyListeners();

    try {
      // 1. Load Local Pending Patients
      final localPatients = await _db.queryAll('patients_local');
      final List<PatientModel> merged = localPatients
          .where((p) => p['sync_status'] == 'pending')
          .map((p) => PatientModel.fromLocalMap(p))
          .toList();

      _totalCount = merged.length;

      // 2. Load Online Patients (if online)
      if (_connectivity.isOnline.value) {
        try {
          final result = await _apiService.fetchAllPatients(
            page: 1,
            limit: _pageSize,
          ).timeout(const Duration(seconds: 10));

          if (result.success) {
            merged.addAll(result.patients.map((p) => p.toPatientModel()).toList());
            _totalPages = result.totalPages;
            _totalCount += result.count;
            _currentPage = 2;
          } else {
            _errorMessage = result.message;
          }
        } catch (e) {
          debugPrint('⚠️ Online patients load failed (using local only): $e');
        }
      }

      _patients = merged;
    } catch (e) {
      debugPrint('Error loading patients: $e');
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Load Next Page ──
  Future<void> loadMorePatients() async {
    if (_isFetchingMore || !hasMorePages || _searchQuery.isNotEmpty) return;

    _isFetchingMore = true;
    notifyListeners();

    final result = await _apiService.fetchAllPatients(
      page: _currentPage,
      limit: _pageSize,
    );

    if (result.success) {
      _patients.addAll(result.patients.map((p) => p.toPatientModel()));
      _totalPages = result.totalPages;
      _totalCount = result.count;
      _currentPage++;
    } else {
      _errorMessage = result.message;
    }

    _isFetchingMore = false;
    notifyListeners();
  }

  // ── Fetch Next MR Number ──
  Future<void> fetchNextMR() async {
    if (!_connectivity.isOnline.value) {
      _nextMrNumber = 'OFF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      notifyListeners();
      return;
    }

    try {
      final result = await _apiService.fetchNextMRNumber().timeout(const Duration(seconds: 5));
      if (result.success && result.nextMR != null) {
        _nextMrNumber = result.nextMR;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ fetchNextMR failed: $e');
      _nextMrNumber = 'OFF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      notifyListeners();
    }
  }

  // ── Live Search patients by name or phone ──
  Future<List<PatientModel>> searchPatients(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    List<PatientModel> results = [];

    // 1. Search Local
    try {
      final local = await _db.queryAll('patients_local');
      final matches = local.where((p) {
        final name = '${p['first_name']} ${p['last_name']}'.toLowerCase();
        final mr = (p['mr_number'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? '').toString();
        return name.contains(q) || mr.contains(q) || phone.contains(q);
      }).map((p) => PatientModel.fromLocalMap(p)).toList();
      results.addAll(matches);
    } catch (e) {
      debugPrint('⚠️ Local search failed: $e');
    }

    // 2. Search API (if online)
    if (_connectivity.isOnline.value) {
      try {
        final apiResult = await _apiService.fetchAllPatients(
          page: 1,
          limit: 20,
          search: q,
        ).timeout(const Duration(seconds: 10));

        if (apiResult.success) {
          final apiPatients = apiResult.patients.map((p) => p.toPatientModel()).toList();
          // Avoid duplicates (by MR Number)
          for (var p in apiPatients) {
            if (!results.any((existing) => existing.mrNumber == p.mrNumber)) {
              results.add(p);
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ API search failed: $e');
      }
    }

    return results;
  }

  // ── MR number lookup — always hits API to get full data with history ──
  Future<PatientModel?> findByMrNumber(String input, {bool normalize = false}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final searchInput = normalize ? _normalizeMrNumber(trimmed) : trimmed;

    if (!_connectivity.isOnline.value) {
      debugPrint('📴 App is OFFLINE. Searching patient in local DB.');
      final localPatient = await _db.queryPending('patients_local');
      final match = localPatient.firstWhere(
        (p) => p['mr_number'] == searchInput,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        return PatientModel(
          mrNumber: match['mr_number'],
          firstName: match['first_name'],
          lastName: match['last_name'],
          guardianName: match['guardian_name'],
          gender: match['gender'],
          phoneNumber: match['phone'],
          address: match['address'],
          city: match['city'],
          bloodGroup: match['blood_group'],
          registeredAt: DateTime.parse(match['created_at']),
        );
      }
      return null;
    }

    // ✅ Always fetch from API so we get visit history
    final result = await _apiService.fetchPatientByMR(searchInput);

    if (result.success && result.patient != null) {
      final patient = result.patient!.toPatientModel();

      // Update local cache
      final index =
      _patients.indexWhere((p) => p.mrNumber == patient.mrNumber);
      if (index != -1) {
        _patients[index] = patient;
      } else {
        _patients.insert(0, patient);
      }
      notifyListeners();
      return patient;
    }

    return null;
  }

  String _normalizeMrNumber(String input) {
    return input.trim();
  }

  // ── State mutations ──
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void selectPatient(PatientModel? patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  // ── Register new patient via API ──
  Future<PatientModel?> registerPatient({
    String mrNumber = '',
    required String firstName,
    required String lastName,
    String guardianName = '',
    String relation = 'Parent',
    required String gender,
    String dateOfBirth = '',
    int? age,
    String bloodGroup = '',
    String profession = '',
    String education = '',
    String whatsappNo = '',
    String phoneNumber = '',
    String email = '',
    String cnic = '',
    String address = '',
    String city = '',
  }) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    final resolvedMr = mrNumber.trim().isEmpty
        ? (_nextMrNumber ?? '00001')
        : mrNumber.trim();

    final patient = PatientModel(
      mrNumber: resolvedMr,
      firstName: firstName.trim().toUpperCase(),
      lastName: lastName.trim().toUpperCase(),
      guardianName: guardianName.trim(),
      relation: relation,
      gender: gender,
      dateOfBirth: dateOfBirth,
      age: age,
      bloodGroup: bloodGroup,
      profession: profession,
      education: education,
      whatsappNo: whatsappNo,
      phoneNumber: phoneNumber.trim(),
      email: email.trim(),
      cnic: cnic.trim(),
      address: address.trim(),
      city: city.trim(),
      registeredAt: DateTime.now(),
    );

    bool savedLocally = false;
    PatientModel? createdPatient;

    if (_connectivity.isOnline.value) {
      try {
        final result = await _apiService.createPatient(patient.toApiRequest()).timeout(const Duration(seconds: 10));
        if (result.success && result.patient != null) {
          createdPatient = result.patient!.toPatientModel();
          _patients.insert(0, createdPatient);
          _totalCount++;
          _selectedPatient = createdPatient;
          _errorMessage = null;
        } else {
          _errorMessage = result.message;
          debugPrint('❌ API Registration Failed: ${result.message}');
          if (result.message?.toLowerCase().contains('connection') == true || 
              result.message?.toLowerCase().contains('timeout') == true ||
              result.message?.toLowerCase().contains('failed to connect') == true) {
            savedLocally = true;
          }
        }
      } catch (e) {
        debugPrint('⚠️ API Exception during registration: $e. Falling back to local storage.');
        savedLocally = true;
      }
    } else {
      savedLocally = true;
    }

    if (savedLocally) {
      debugPrint('📴 Saving patient locally (Offline/API Failure).');
      try {
        final uuid = await _syncService.savePatientLocal({
          'mr_number': patient.mrNumber,
          'first_name': patient.firstName,
          'last_name': patient.lastName,
          'guardian_name': patient.guardianName,
          'gender': patient.gender,
          'phone': patient.phoneNumber,
          'address': patient.address,
          'city': patient.city,
          'blood_group': patient.bloodGroup,
        });
        
        createdPatient = PatientModel(
          mrNumber: patient.mrNumber,
          firstName: patient.firstName,
          lastName: patient.lastName,
          guardianName: patient.guardianName,
          relation: patient.relation,
          gender: patient.gender,
          dateOfBirth: patient.dateOfBirth,
          age: patient.age,
          bloodGroup: patient.bloodGroup,
          profession: patient.profession,
          education: patient.education,
          whatsappNo: patient.whatsappNo,
          phoneNumber: patient.phoneNumber,
          email: patient.email,
          cnic: patient.cnic,
          address: patient.address,
          city: patient.city,
          registeredAt: patient.registeredAt,
          deviceUuid: uuid, // Capture the local device UUID
          syncStatus: 'pending',
        );
        
        _patients.insert(0, createdPatient);
        _totalCount++;
        _selectedPatient = createdPatient;
        _errorMessage = null;
      } catch (e) {
        debugPrint('❌ Local Registration Error: $e');
        _errorMessage = 'Failed to save locally: $e';
      }
    }

    _isCreating = false;
    notifyListeners();
    if (createdPatient != null && _connectivity.isOnline.value) {
       fetchNextMR();
    }
    return createdPatient;
  }

  // ── Update existing patient via API ──
  Future<bool> updatePatient(PatientModel patient) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.updatePatient(
      patient.mrNumber,
      patient.toApiRequest(),
    );
    _isCreating = false;

    if (result.success && result.patient != null) {
      final updatedPatient = result.patient!.toPatientModel();
      final index =
      _patients.indexWhere((p) => p.mrNumber == patient.mrNumber);
      if (index != -1) _patients[index] = updatedPatient;
      if (_selectedPatient?.mrNumber == patient.mrNumber) {
        _selectedPatient = updatedPatient;
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  // ── Delete patient via API ──
  Future<bool> deletePatient(String mrNumber) async {
    final result = await _apiService.deletePatient(mrNumber);
    if (result.success) {
      _patients.removeWhere((p) => p.mrNumber == mrNumber);
      _totalCount--;
      if (_selectedPatient?.mrNumber == mrNumber) _selectedPatient = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }
}