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
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

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
    
    // Listen for connectivity changes to update next MR number
    _connectivity.isOnline.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    fetchNextMR();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivity.isOnline.removeListener(_onConnectivityChanged);
    super.dispose();
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
      final localNext = await _syncService.peekNextMrNumberLocal();
      _nextMrNumber = localNext ?? 'PENDING';
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
      final localNext = await _syncService.peekNextMrNumberLocal();
      _nextMrNumber = localNext ?? 'PENDING';
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
    PatientModel? localMatch;

    // 1. Always check Local first (helps with unsynced patients)
    try {
      final localRows = await _db.queryAll('patients_local');
      final match = localRows.firstWhere(
        (p) {
          final mr = p['mr_number']?.toString() ?? '';
          // Exact match (padded or prefixed)
          if (mr == searchInput) return true;
          if (mr == trimmed) return true;
          
          // Match numeric part (e.g. input "1" matches "CAMP-1" or "00001")
          final numericInput = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericInput.isNotEmpty) {
            final dbNumeric = mr.replaceAll(RegExp(r'[^0-9]'), '');
            if (dbNumeric.isNotEmpty && (dbNumeric == numericInput || int.tryParse(dbNumeric) == int.tryParse(numericInput))) {
              return true;
            }
          }
          return false;
        },
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        localMatch = PatientModel.fromLocalMap(match);
      }
    } catch (e) {
      debugPrint('⚠️ Local lookup error: $e');
    }

    // 2. If Offline, return local match immediately
    if (!_connectivity.isOnline.value) {
      return localMatch;
    }

    // 3. If Online, try to fetch from API for latest data/history
    try {
      final result = await _apiService.fetchPatientByMR(searchInput).timeout(const Duration(seconds: 10));
      if (result.success && result.patient != null) {
        final apiPatient = result.patient!.toPatientModel();
        
        // Update local cache for UI lists
        final index = _patients.indexWhere((p) => p.mrNumber == apiPatient.mrNumber);
        if (index != -1) {
          _patients[index] = apiPatient;
        } else {
          _patients.insert(0, apiPatient);
        }
        notifyListeners();
        return apiPatient;
      }
    } catch (e) {
      debugPrint('⚠️ API lookup failed: $e');
    }

    // 4. Final fallback: return local match if API failed or didn't find it
    return localMatch;
  }

  String _normalizeMrNumber(String input) {
    String trimmed = input.trim();
    if (trimmed.isEmpty) return "";
    
    // If it's a numeric string, pad it to 5 digits (hospital standard)
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed.padLeft(5, '0');
    }
    return trimmed;
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
        final result = await _syncService.savePatientLocal({
          'mr_number': patient.mrNumber,
          'first_name': patient.firstName,
          'last_name': patient.lastName,
          'guardian_name': patient.guardianName,
          'relation': patient.relation,
          'gender': patient.gender,
          'dob': patient.dateOfBirth,
          'age': patient.age,
          'blood_group': patient.bloodGroup,
          'profession': patient.profession,
          'education': patient.education,
          'phone': patient.phoneNumber,
          'whatsapp': patient.whatsappNo,
          'email': patient.email,
          'cnic': patient.cnic,
          'address': patient.address,
          'city': patient.city,
        });
        
        final String uuid = result['uuid']!;
        final String assignedMr = result['mr_number']!;
        
        createdPatient = PatientModel(
          mrNumber: assignedMr,
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
          deviceUuid: uuid,
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
    if (createdPatient != null) {
       await fetchNextMR();
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