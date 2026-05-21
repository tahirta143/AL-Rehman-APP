import 'package:flutter/material.dart';
import '../../core/services/mr_api_service.dart';
import '../../models/mr_model/mr_patient_model.dart';

class MrProvider extends ChangeNotifier {
  final MrApiService _apiService = MrApiService();
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  static const int _pageSize = 50;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;
  String? _nextMrNumber;
  List<PatientModel> _patients = [];
  String _searchQuery = '';
  PatientModel? _selectedPatient;
  int _totalCount = 0;

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

  MrProvider() {
    loadPatients();
    fetchNextMR();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<PatientModel> get patients {
    if (_searchQuery.isEmpty) return List.from(_patients);
    final q = _searchQuery.toLowerCase();
    return _patients.where((p) =>
      p.fullName.toLowerCase().contains(q) ||
      p.phoneNumber.contains(q) ||
      p.cnic.contains(q)
    ).toList();
  }

  Future<void> loadPatients() async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = 1;
    _patients = [];
    _totalCount = 0;
    notifyListeners();

    try {
      final result = await _apiService.fetchAllPatients(page: 1, limit: _pageSize)
          .timeout(const Duration(seconds: 10));
      if (result.success) {
        _patients = result.patients.map((p) => p.toPatientModel()).toList();
        _totalPages = result.totalPages;
        _totalCount = result.count;
        _currentPage = 2;
      } else {
        _errorMessage = result.message;
      }
    } catch (e) {
      _errorMessage = 'Failed to load patients: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMorePatients() async {
    if (_isFetchingMore || !hasMorePages || _searchQuery.isNotEmpty) return;
    _isFetchingMore = true;
    notifyListeners();

    final result = await _apiService.fetchAllPatients(page: _currentPage, limit: _pageSize);
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

  Future<void> fetchNextMR() async {
    try {
      final result = await _apiService.fetchNextMRNumber().timeout(const Duration(seconds: 5));
      if (result.success && result.nextMR != null) {
        _nextMrNumber = result.nextMR;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ fetchNextMR failed: $e');
    }
  }

  Future<List<PatientModel>> searchPatients(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    try {
      final result = await _apiService.fetchAllPatients(page: 1, limit: 20, search: q)
          .timeout(const Duration(seconds: 10));
      if (result.success) {
        return result.patients.map((p) => p.toPatientModel()).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Search failed: $e');
    }
    return [];
  }

  Future<PatientModel?> findByMrNumber(String input, {bool normalize = false}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    try {
      final result = await _apiService.fetchPatientByMR(trimmed).timeout(const Duration(seconds: 10));
      if (result.success && result.patient != null) {
        final p = result.patient!.toPatientModel();
        final idx = _patients.indexWhere((x) => x.mrNumber == p.mrNumber);
        if (idx != -1) {
          _patients[idx] = p;
        } else {
          _patients.insert(0, p);
        }
        notifyListeners();
        return p;
      }
    } catch (e) {
      debugPrint('⚠️ MR lookup failed: $e');
    }
    return null;
  }

  void setSearchQuery(String query) { _searchQuery = query; notifyListeners(); }
  void clearSearch() { _searchQuery = ''; notifyListeners(); }
  void selectPatient(PatientModel? patient) { _selectedPatient = patient; notifyListeners(); }

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

    final resolvedMr = mrNumber.trim().isEmpty ? (_nextMrNumber ?? '') : mrNumber.trim();
    final patient = PatientModel(
      mrNumber: resolvedMr,
      firstName: firstName.trim().toUpperCase(),
      lastName: lastName.trim().toUpperCase(),
      guardianName: guardianName.trim(),
      relation: relation, gender: gender, dateOfBirth: dateOfBirth, age: age,
      bloodGroup: bloodGroup, profession: profession, education: education,
      whatsappNo: whatsappNo, phoneNumber: phoneNumber.trim(), email: email.trim(),
      cnic: cnic.trim(), address: address.trim(), city: city.trim(),
      registeredAt: DateTime.now(),
    );

    PatientModel? created;
    try {
      final result = await _apiService.createPatient(patient.toApiRequest())
          .timeout(const Duration(seconds: 10));
      if (result.success && result.patient != null) {
        created = result.patient!.toPatientModel();
        _patients.insert(0, created);
        _totalCount++;
        _selectedPatient = created;
        _errorMessage = null;
      } else {
        _errorMessage = result.message;
      }
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
    }

    _isCreating = false;
    notifyListeners();
    if (created != null) await fetchNextMR();
    return created;
  }

  Future<bool> updatePatient(PatientModel patient) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.updatePatient(patient.mrNumber, patient.toApiRequest());
    _isCreating = false;

    if (result.success && result.patient != null) {
      final updated = result.patient!.toPatientModel();
      final idx = _patients.indexWhere((p) => p.mrNumber == patient.mrNumber);
      if (idx != -1) _patients[idx] = updated;
      if (_selectedPatient?.mrNumber == patient.mrNumber) _selectedPatient = updated;
      _errorMessage = null;
      notifyListeners();
      return true;
    }
    _errorMessage = result.message;
    notifyListeners();
    return false;
  }

  Future<bool> deletePatient(String mrNumber) async {
    final result = await _apiService.deletePatient(mrNumber);
    if (result.success) {
      _patients.removeWhere((p) => p.mrNumber == mrNumber);
      _totalCount--;
      if (_selectedPatient?.mrNumber == mrNumber) _selectedPatient = null;
      notifyListeners();
      return true;
    }
    _errorMessage = result.message;
    notifyListeners();
    return false;
  }
}
