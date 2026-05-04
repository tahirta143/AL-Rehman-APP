import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/pdf_eye_prescription_service.dart';
import '../../core/services/prescription_api_service.dart';
import '../../core/services/mr_api_service.dart';
import '../../core/services/vitals_api_service.dart';
import '../../models/vitals_model/vitals_model.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/camp_sync_service.dart';
import '../../core/utils/database_helper.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../models/prescription_model/prescription_model.dart';
import '../../models/vitals_model/vitals_model.dart';

class PrescriptionProvider extends ChangeNotifier {
  final PrescriptionApiService _apiService = PrescriptionApiService();
  final MrApiService _mrApiService = MrApiService();
  final VitalsApiService _vitalsApiService = VitalsApiService();
  final ConnectivityService _connectivity = ConnectivityService();
  final CampSyncService _syncService = CampSyncService();
  final DatabaseHelper _db = DatabaseHelper();

  // ─── Loading States ───────────────────────────────────────────────
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingPatients = false;
  bool _isLoadingHistory = false;
  bool _isLoadingTests = false;
  String? _errorMessage;

  // New Alignment State
  String? _receiptId;
  String? _tokenNumber;
  String? _doctorName;
  int? _doctorSrlNo;
  String _medMode = 'medicine'; // 'medicine' or 'formula'
  String _inputLang = 'en'; // 'en' or 'ur'
  List<dynamic> _medicineSearchResults = [];
  String _medSearchQuery = '';
  
  // Investigation Search
  String _labSearch = '';
  String _xraySearch = '';
  String _ultrasoundSearch = '';
  String _ctSearch = '';

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isLoadingPatients => _isLoadingPatients;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingTests => _isLoadingTests;
  String? get errorMessage => _errorMessage;

  String? get receiptId => _receiptId;
  String? get tokenNumber => _tokenNumber;
  String? get doctorName => _doctorName;
  int? get doctorSrlNo => _doctorSrlNo;
  String get medMode => _medMode;
  String get inputLang => _inputLang;
  List<dynamic> get medicineSearchResults => _medicineSearchResults;
  String get medSearchQuery => _medSearchQuery;
  String get labSearch => _labSearch;
  String get xraySearch => _xraySearch;
  String get ultrasoundSearch => _ultrasoundSearch;
  String get ctSearch => _ctSearch;

  bool get isAdmissionReferral => noteControllers['referTo']!.text.trim().toLowerCase().contains('admission');

  // ─── Patient State ────────────────────────────────────────────────
  PatientModel? _currentPatient;
  PatientModel? get currentPatient => _currentPatient;

  VitalsModel? _currentVitals;
  VitalsModel? get currentVitals => _currentVitals;

  List<dynamic> _consultationPatients = [];
  List<dynamic> get consultationPatients => _consultationPatients;

  List<PrescriptionModel> _prescriptionHistory = [];
  List<PrescriptionModel> get prescriptionHistory => _prescriptionHistory;

  // ─── Tests State ──────────────────────────────────────────────────
  List<dynamic> _labTests = [];
  List<dynamic> _radiologyTests = [];
  List<dynamic> get labTests => _labTests;
  List<dynamic> get radiologyTests => _radiologyTests;


  // ─── Form Data (Common) ───────────────────────────────────────────
  final Map<String, TextEditingController> vitalControllers = {
    'temp': TextEditingController(),
    'bp': TextEditingController(),
    'pulse': TextEditingController(),
    'weight': TextEditingController(),
    'height': TextEditingController(),
    'blood': TextEditingController(),
  };

  final Map<String, TextEditingController> noteControllers = {
    'history': TextEditingController(),
    'treatment': TextEditingController(),
    'notes': TextEditingController(),
    'remarks': TextEditingController(),
    'referTo': TextEditingController(),
  };

  // ─── GP Specific State ────────────────────────────────────────────
  List<PrescriptionMedicine> _prescribedMedicines = [];
  List<PrescriptionMedicine> get prescribedMedicines => _prescribedMedicines;

  List<PrescriptionInvestigation> _selectedInvestigations = [];
  List<PrescriptionInvestigation> get selectedInvestigations => _selectedInvestigations;

  PrescriptionModel? _lastSavedPrescription;
  PrescriptionModel? get lastSavedPrescription => _lastSavedPrescription;

  List<String> _instructions = [];
  List<String> get instructions => _instructions;

  List<dynamic> _diagnosisQuestions = [];
  List<dynamic> get diagnosisQuestions => _diagnosisQuestions;
  
  Map<int, dynamic> _diagnosisAnswers = {};
  Map<int, dynamic> get diagnosisAnswers => _diagnosisAnswers;

  // ─── Eye Specific State ───────────────────────────────────────────
  // History Checkboxes
  final Map<String, bool> eyeHistory = {
    'Asthma': false, 'Diabetes': false, 'HBV': false, 'HCV': false,
    'Hypertension': false, 'Ischemic Heart Disease': false, 'Pregnancy': false, 'RT Injury': false,
  };
  final TextEditingController eyeOtherHistoryCtrl = TextEditingController();

  // Refraction Matrix
  final Map<String, Map<String, TextEditingController>> refractionCtrls = {
    'right': {
      'sph': TextEditingController(), 'cyl': TextEditingController(), 
      'axis': TextEditingController(), 'va': TextEditingController(), 'addition': TextEditingController()
    },
    'left': {
      'sph': TextEditingController(), 'cyl': TextEditingController(), 
      'axis': TextEditingController(), 'va': TextEditingController(), 'addition': TextEditingController()
    },
    'add01': {
      'sph': TextEditingController(), 'cyl': TextEditingController(), 
      'axis': TextEditingController(), 'va': TextEditingController(), 'addition': TextEditingController()
    },
    'add02': {
      'sph': TextEditingController(), 'cyl': TextEditingController(), 
      'axis': TextEditingController(), 'va': TextEditingController(), 'addition': TextEditingController()
    },
  };

  // Vision Stats
  final Map<String, Map<String, TextEditingController>> visionCtrls = {
    'right': {'var': TextEditingController(), 'ph': TextEditingController(), 'ref': TextEditingController()},
    'left': {'var': TextEditingController(), 'ph': TextEditingController(), 'ref': TextEditingController()},
  };

  // Examination & Management
  final TextEditingController presentingComplaintsCtrl = TextEditingController();
  List<EyeSideItem> _eyeComplaints = [];
  List<EyeSideItem> _eyeExaminations = [];
  List<EyeSideItem> _eyeDiagnosis = [];
  List<EyeSideItem> _eyeAdvised = [];
  String _eyeTreatmentType = '';
  
  // API Setup Lists
  List<String> eyeSetupComplaints = [];
  List<String> eyeSetupExaminations = [];
  List<String> eyeSetupDiagnosis = [];
  List<String> eyeSetupAdvised = [];
  List<String> eyeSetupSurgery = [];
  final TextEditingController eyeRemarksCtrl = TextEditingController();
  final TextEditingController eyeSurgeryNameCtrl = TextEditingController();
  DateTime? _eyeOperationDate;
  List<String> _surgerySearchResults = [];
  List<String> get surgerySearchResults => _surgerySearchResults;

  List<EyeSideItem> get eyeComplaints => _eyeComplaints;
  List<EyeSideItem> get eyeExaminations => _eyeExaminations;
  List<EyeSideItem> get eyeDiagnosis => _eyeDiagnosis;
  List<EyeSideItem> get eyeAdvised => _eyeAdvised;
  String get eyeTreatmentType => _eyeTreatmentType;
  DateTime? get eyeOperationDate => _eyeOperationDate;

  // ─── Actions ─────────────────────────────────────────────────────

  Future<void> loadConsultationPatients() async {
    _isLoadingPatients = true;
    notifyListeners();
    await loadEyeSetupItems();

    try {
      // 1. Load local pending visits
      final localVisits = await _db.queryAll('visits_local');
      final List<dynamic> merged = localVisits
          .where((v) => v['sync_status'] == 'pending')
          .map((v) => {
                'patient_mr_number': v['patient_uuid'],
                'patient_name': v['patient_name'],
                'receipt_id': v['receipt_id'],
                'service_detail': v['opd_service'],
                'date': v['date'],
                'status': 'Pending Sync',
              })
          .toList();

      // 2. Load Online
      if (_connectivity.isOnline.value) {
        try {
          final res = await _apiService.fetchConsultationPatients().timeout(const Duration(seconds: 10));
          if (res['success'] == true) {
            merged.addAll(res['data'] as List? ?? []);
          }
        } catch (e) {
          debugPrint('⚠️ Online consultation patients load failed: $e');
        }
      }

      _consultationPatients = merged;
    } catch (e) {
      debugPrint('Error merging consultation patients: $e');
    }

    _isLoadingPatients = false;
    notifyListeners();
  }

  Future<void> loadEyeSetupItems() async {
    final res = await _apiService.fetchEyeSetupItems('');
    if (res['success'] == true) {
      final items = res['data'] as List? ?? [];
      eyeSetupComplaints.clear();
      eyeSetupExaminations.clear();
      eyeSetupDiagnosis.clear();
      eyeSetupAdvised.clear();
      eyeSetupSurgery.clear();
      for (var item in items) {
        final type = (item['item_type'] ?? '').toString().trim();
        final name = item['item_name'] ?? '';
        if (type == 'Complaint') eyeSetupComplaints.add(name);
        else if (type == 'Examination') eyeSetupExaminations.add(name);
        else if (type == 'Diagnosis') eyeSetupDiagnosis.add(name);
        else if (type == 'Advised') eyeSetupAdvised.add(name);
        else if (type == 'Surgery') eyeSetupSurgery.add(name);
      }
    }
  }

  Future<void> selectConsultationPatient(dynamic patient, {String? department}) async {
    final mr = patient['patient_mr_number']?.toString().trim() ?? '';
    _receiptId = patient['receipt_id']?.toString();
    _tokenNumber = patient['token_number']?.toString();
    _doctorSrlNo = int.tryParse(patient['doctor_srl_no']?.toString() ?? '');
    _doctorName = patient['doctor_name']?.toString();
    
    vitalControllers['receiptId']?.text = _receiptId ?? '';

    await searchPatient(mr, department: department);
  }

  void setMedMode(String mode) {
    _medMode = mode;
    _medicineSearchResults = [];
    _medSearchQuery = '';
    notifyListeners();
  }

  void setInputLang(String lang) {
    _inputLang = lang;
    notifyListeners();
  }

  void updateLabSearch(String q) { _labSearch = q; notifyListeners(); }
  void updateXraySearch(String q) { _xraySearch = q; notifyListeners(); }
  void updateUltrasoundSearch(String q) { _ultrasoundSearch = q; notifyListeners(); }
  void updateCtSearch(String q) { _ctSearch = q; notifyListeners(); }

  void updateMedSearch(String query) async {
    _medSearchQuery = query;
    if (query.isEmpty) {
      _medicineSearchResults = [];
      notifyListeners();
      return;
    }
    
    if (!_connectivity.isOnline.value) {
      debugPrint('📴 App is OFFLINE. Searching medicines in local DB.');
      final localMeds = await _db.queryAll('master_medicines');
      _medicineSearchResults = localMeds.where((m) => 
        (m['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase())
      ).map((m) => {
        'id': m['id'],
        'medicine_name': m['name'],
        'formula': m['is_formula'],
      }).toList();
      notifyListeners();
      return;
    }

    final res = await _apiService.searchMedicines(query);
    if (res['success'] == true) {
      _medicineSearchResults = res['data'] ?? [];
    }
    notifyListeners();
  }

  Future<void> searchPatient(String mrNumber, {String? department}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPatient = null;
    notifyListeners();

    final mr = mrNumber.trim();
    bool foundOnline = false;

    if (_connectivity.isOnline.value) {
      final result = await _mrApiService.fetchPatientByMR(mr);
      if (result.success && result.patient != null) {
        _currentPatient = result.patient!.toPatientModel();
        foundOnline = true;
        await fetchDiagnosis(department ?? 'General'); 
        await fetchVitals(mr, receiptId: _receiptId);
        await fetchHistory(mr);
      }
    }

    if (!foundOnline) {
      // 📴 Search locally
      debugPrint('📴 Prescription search: searching local DB for $mr');
      final db = await _db.database;
      final localRows = await db.query(
        'patients_local',
        where: 'mr_number = ? OR device_uuid = ?',
        whereArgs: [mr, mr]
      );

      if (localRows.isNotEmpty) {
        _currentPatient = PatientModel.fromLocalMap(localRows.first);
        debugPrint('✅ Found patient locally: ${_currentPatient?.fullName}');
      }
    }

    if (_currentPatient == null) {
      _errorMessage = 'Patient not found locally or online';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchVitals(String mrNumber, {String? receiptId}) async {
    _currentVitals = null;
    notifyListeners();
    try {
      Map<String, dynamic> res = {'success': false};

      // 1. Try fetching by Receipt ID first if available
      if (receiptId != null && receiptId.isNotEmpty) {
        res = await _vitalsApiService.getVitalsByReceipt(receiptId);
      }

      // 2. Fallback to MR Number if Receipt fetch failed or returned no data
      if (res['success'] != true || res['data'] == null) {
        res = await _vitalsApiService.getVitalsByMR(mrNumber);
      }
      
      if (res['success'] == true && res['data'] != null) {
        _currentVitals = VitalsModel.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('Error fetching vitals: $e');
    }
    notifyListeners();
  }

  Future<void> fetchHistory(String mrNumber) async {
    _isLoadingHistory = true;
    notifyListeners();
    final res = await _apiService.fetchPrescriptionHistory(mrNumber);
    if (res['success'] == true) {
      final List raw = res['data'] ?? [];
      _prescriptionHistory = raw.map((e) => PrescriptionModel.fromJson(e)).toList();
    }
    _isLoadingHistory = false;
    notifyListeners();
  }

  Future<void> loadTests() async {
    if (_labTests.isNotEmpty && _radiologyTests.isNotEmpty) return;
    _isLoadingTests = true;
    notifyListeners();
    
    final labRes = await _apiService.fetchLabTests();
    if (labRes['success'] == true) _labTests = labRes['data'] ?? [];

    final radRes = await _apiService.fetchRadiologyTests();
    if (radRes['success'] == true) _radiologyTests = radRes['data'] ?? [];

    _isLoadingTests = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> searchMedicines(String query) async {
    return await _apiService.searchMedicines(query);
  }

  Future<void> fetchDiagnosis(String department) async {
    final res = await _apiService.fetchDiagnosisQuestions(department);
    if (res['success'] == true) {
      _diagnosisQuestions = res['data'] ?? [];
      _diagnosisAnswers = {};
    }
    notifyListeners();
  }

  // ─── GP Form Helpers ──────────────────────────────────────────────
  
  void addMedicine(PrescriptionMedicine med) {
    _prescribedMedicines.add(med);
    notifyListeners();
  }

  void removeMedicine(int index) {
    _prescribedMedicines.removeAt(index);
    notifyListeners();
  }

  void toggleInvestigation(String type, String name) {
    final exists = _selectedInvestigations.any((i) => i.investigationType == type && i.testName == name);
    if (exists) {
      _selectedInvestigations.removeWhere((i) => i.investigationType == type && i.testName == name);
    } else {
      _selectedInvestigations.add(PrescriptionInvestigation(investigationType: type, testName: name));
    }
    notifyListeners();
  }

  void addInstruction(String text) {
    if (text.trim().isNotEmpty) {
      _instructions.add(text.trim());
      notifyListeners();
    }
  }

  void removeInstruction(int index) {
    _instructions.removeAt(index);
    notifyListeners();
  }

  void setDiagnosisAnswer(int questionId, dynamic value) {
    _diagnosisAnswers[questionId] = value;
    notifyListeners();
  }

  void setAdmissionReferral(bool value) {
    final controller = noteControllers['referTo']!;
    if (value) {
      if (controller.text.trim().isEmpty || controller.text.trim().toLowerCase() != 'admission') {
        controller.text = 'Admission';
      }
    } else {
      if (controller.text.trim().toLowerCase() == 'admission') {
        controller.text = '';
      }
    }
    notifyListeners();
  }

  // ─── Eye Form Helpers ───────────────────────────────────────────

  void toggleEyeHistory(String key) {
    eyeHistory[key] = !(eyeHistory[key] ?? false);
    notifyListeners();
  }

  void addEyeItem(String listType, String name, String side) {
    final item = EyeSideItem(name: name, side: side);
    if (listType == 'complaint') _eyeComplaints.add(item);
    else if (listType == 'examination') _eyeExaminations.add(item);
    else if (listType == 'diagnosis') _eyeDiagnosis.add(item);
    else if (listType == 'advised') _eyeAdvised.add(item);
    notifyListeners();
  }

  void removeEyeItem(String listType, int index) {
    if (listType == 'complaint') _eyeComplaints.removeAt(index);
    else if (listType == 'examination') _eyeExaminations.removeAt(index);
    else if (listType == 'diagnosis') _eyeDiagnosis.removeAt(index);
    else if (listType == 'advised') _eyeAdvised.removeAt(index);
    notifyListeners();
  }

  void setEyeTreatmentType(String type) {
    _eyeTreatmentType = type;
    notifyListeners();
  }

  void setOperationDate(DateTime date) {
    _eyeOperationDate = date;
    notifyListeners();
  }

  Future<void> printOldPrescription(BuildContext context, PrescriptionModel rx) async {
    if (_currentPatient != null) {
      await PDFEyePrescriptionService.printPrescription(rx, _currentPatient!);
    }
  }

  // ─── Submission ──────────────────────────────────────────────────

  Future<bool> savePrescription({bool isEye = false, required String doctorName, int? doctorSrlNo}) async {
    if (_currentPatient == null) return false;
    
    _isSaving = true;
    notifyListeners();

    final vitals = {
      for (var entry in vitalControllers.entries) entry.key: entry.value.text
    };

    final prescription = PrescriptionModel(
      mrNumber: _currentPatient?.mrNumber ?? '',
      doctorName: doctorName,
      doctorSrlNo: doctorSrlNo,
      receiptId: _receiptId,
      vitals: vitalControllers.map((key, controller) => MapEntry(key, controller.text)),
      historyExamination: isEye ? (presentingComplaintsCtrl.text.isEmpty ? null : presentingComplaintsCtrl.text) : (noteControllers['history']?.text.isEmpty ?? true ? null : noteControllers['history']!.text),
      treatment: isEye ? (_eyeTreatmentType.isEmpty ? null : _eyeTreatmentType) : (noteControllers['treatment']?.text.isEmpty ?? true ? null : noteControllers['treatment']!.text),
      remarks: isEye ? (eyeRemarksCtrl.text.isEmpty ? null : eyeRemarksCtrl.text) : (noteControllers['remarks']?.text.isEmpty ?? true ? null : noteControllers['remarks']!.text),
      consultantNotes: noteControllers['notes']?.text.isEmpty ?? true ? null : noteControllers['notes']!.text,
      referTo: noteControllers['referTo']?.text.isEmpty ?? true ? null : noteControllers['referTo']!.text,
      medicines: _prescribedMedicines,
      investigations: _selectedInvestigations,
      instructions: _instructions,
      diagnosis: _diagnosisAnswers.entries.map((e) => PrescriptionDiagnosis(
        questionId: e.key,
        questionText: '', 
        answerText: e.value is String ? e.value : null,
        answerValue: e.value,
      )).toList(),
      eyeDetails: isEye ? _buildEyeDetails() : null,
    );

    bool isSuccess = false;
    if (_connectivity.isOnline.value) {
      final res = await _apiService.savePrescription(prescription.toJson());
      isSuccess = res['success'] == true || res['status'] == true;
    } else {
      debugPrint('📴 App is OFFLINE. Saving prescription locally.');
      
      final visitUuid = _syncService.generateUuid();
      
      // 1. Save Vitals
      await _db.insert('vitals_local', {
        'device_uuid': _syncService.generateUuid(),
        'patient_uuid': _currentPatient!.deviceUuid ?? _currentPatient!.mrNumber,
        'mr_number': _currentPatient!.mrNumber == 'PENDING' ? null : _currentPatient!.mrNumber,
        'visit_uuid': visitUuid,
        'bsr': double.tryParse(vitalControllers['blood']?.text ?? '0') ?? 0.0,
        'systolic': double.tryParse(vitalControllers['bp']?.text.split('/')[0] ?? '0') ?? 0.0,
        'diastolic': double.tryParse(vitalControllers['bp']?.text.split('/').last ?? '0') ?? 0.0,
        'pulse': double.tryParse(vitalControllers['pulse']?.text ?? '0') ?? 0.0,
        'weight': double.tryParse(vitalControllers['weight']?.text ?? '0') ?? 0.0,
        'temp': double.tryParse(vitalControllers['temp']?.text ?? '0') ?? 0.0,
        'sync_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Save Prescription
      await _db.insert('prescriptions_local', {
        'device_uuid': _syncService.generateUuid(),
        'patient_uuid': _currentPatient!.deviceUuid ?? _currentPatient!.mrNumber,
        'mr_number': _currentPatient!.mrNumber == 'PENDING' ? null : _currentPatient!.mrNumber,
        'visit_uuid': visitUuid,
        'doctor_srl_no': doctorSrlNo,
        'treatment': prescription.treatment,
        'medicines_json': jsonEncode(prescription.medicines),
        'investigations_json': jsonEncode(prescription.investigations),
        'sync_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      isSuccess = true;
    }
    
    _isSaving = false;
    
    if (isSuccess) {
      _lastSavedPrescription = prescription;
      clearForm();
    }
    
    notifyListeners();
    return isSuccess;
  }

  void updateSurgerySearch(String query) {
    if (query.isEmpty) {
      _surgerySearchResults = [];
    } else {
      _surgerySearchResults = eyeSetupSurgery
          .where((s) => s.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  EyePrescriptionDetails _buildEyeDetails() {
    return EyePrescriptionDetails(
      history: Map<String, bool>.from(eyeHistory),
      otherHistory: eyeOtherHistoryCtrl.text,
      rightRefraction: _getRefraction('right'),
      leftRefraction: _getRefraction('left'),
      add01Refraction: _getRefraction('add01'),
      add02Refraction: _getRefraction('add02'),
      rightVision: _getVision('right'),
      leftVision: _getVision('left'),
      presentingComplaints: presentingComplaintsCtrl.text,
      complaints: _eyeComplaints,
      examinations: _eyeExaminations,
      diagnosis: _eyeDiagnosis,
      advised: _eyeAdvised,
      treatmentType: _eyeTreatmentType,
      remarks: eyeRemarksCtrl.text,
      operationDate: _eyeOperationDate?.toString().split(' ')[0],
      surgeryName: eyeSurgeryNameCtrl.text.isEmpty ? null : eyeSurgeryNameCtrl.text,
    );
  }

  RefractionMatrix _getRefraction(String side) {
    final ctrls = refractionCtrls[side]!;
    return RefractionMatrix(
      sph: ctrls['sph']!.text,
      cyl: ctrls['cyl']!.text,
      axis: ctrls['axis']!.text,
      va: ctrls['va']!.text,
      addition: ctrls['addition']!.text,
    );
  }

  VisionStats _getVision(String side) {
    final ctrls = visionCtrls[side]!;
    return VisionStats(
      varValue: ctrls['var']!.text,
      ph: ctrls['ph']!.text,
      ref: ctrls['ref']!.text,
    );
  }

  void clearForm() {
    for (var c in vitalControllers.values) c.clear();
    for (var c in noteControllers.values) c.clear();
    _prescribedMedicines = [];
    _selectedInvestigations = [];
    _instructions = [];
    _diagnosisAnswers = {};
    _currentPatient = null;
    _receiptId = null;
    _tokenNumber = null;
    _doctorName = null;
    _doctorSrlNo = null;
    _medMode = 'medicine';
    _medicineSearchResults = [];
    _medSearchQuery = '';
    _eyeComplaints = [];
    _eyeExaminations = [];
    _eyeDiagnosis = [];
    _eyeAdvised = [];
    _eyeTreatmentType = '';
    _eyeOperationDate = null;
    eyeOtherHistoryCtrl.clear();
    presentingComplaintsCtrl.clear();
    eyeRemarksCtrl.clear();
    for (var side in refractionCtrls.values) {
      for (var ctrl in side.values) ctrl.clear();
    }
    for (var side in visionCtrls.values) {
      for (var ctrl in side.values) ctrl.clear();
    }
    eyeHistory.updateAll((key, value) => false);
    
    notifyListeners();
  }
}
