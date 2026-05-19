import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/nutrition_api_service.dart';
import '../../core/services/ai_api_service.dart';
import '../../models/nutrition_model/nutrition_prescription_model.dart';
import '../prescription_provider/prescription_provider.dart';

class NutritionProvider extends ChangeNotifier {
  final NutritionApiService _apiService = NutritionApiService();
  final AiApiService _aiApiService = AiApiService();

  // ─── Loading States ───────────────────────────────────────────────
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  bool _analyzingVisits = false;
  bool get analyzingVisits => _analyzingVisits;

  // ─── History & Analysis ──────────────────────────────────────────
  List<NutritionPrescriptionModel> _visitHistory = [];
  List<NutritionPrescriptionModel> get visitHistory => _visitHistory;

  String _visitAnalysis = '';
  String get visitAnalysis => _visitAnalysis;


  // ─── Controllers ──────────────────────────────────────────────────
  final Map<String, TextEditingController> controllers = {
    'kcal': TextEditingController(),
    'carbs': TextEditingController(),
    'proteins': TextEditingController(),
    'fats': TextEditingController(),
    'fluid': TextEditingController(),
    'dietOrder': TextEditingController(),
    'dietType': TextEditingController(),
    'dietaryRec': TextEditingController(),
    'lifestyleRec': TextEditingController(),
    'doctorName': TextEditingController(),
  };

  // ─── Diet Plans ──────────────────────────────────────────────────
  List<DietPlanItem> _dietPlans = [
    DietPlanItem(mealPart: 'Pre Breakfast'),
    DietPlanItem(mealPart: 'Breakfast'),
    DietPlanItem(mealPart: 'Snack 1'),
    DietPlanItem(mealPart: 'Lunch'),
    DietPlanItem(mealPart: 'Snack 2'),
    DietPlanItem(mealPart: 'Dinner'),
    DietPlanItem(mealPart: 'Before Bed'),
  ];
  List<DietPlanItem> get dietPlans => _dietPlans;

  // ─── Consultation Timer ────────────────────────────────────────────
  Timer? _consultationTimer;

  void startConsultationTimer(PrescriptionProvider prescriptionProvider) {
    _consultationTimer?.cancel();
    // Initial fetch
    prescriptionProvider.loadConsultationPatients();
    // Periodic fetch every 30 seconds
    _consultationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      prescriptionProvider.loadConsultationPatients();
    });
  }

  void stopConsultationTimer() {
    _consultationTimer?.cancel();
    _consultationTimer = null;
  }

  // ─── Actions ──────────────────────────────────────────────────────

  void updateMealTime(int index, String time) {
    _dietPlans[index].mealTime = time;
    notifyListeners();
  }

  Future<dynamic> savePrescription(PrescriptionProvider prescriptionProvider) async {
    if (prescriptionProvider.currentPatient == null) {
      return null;
    }

    _isSaving = true;
    notifyListeners();

    try {
      final patient = prescriptionProvider.currentPatient!;
      final vitals = prescriptionProvider.currentVitals;

      final payload = NutritionPrescriptionModel(
        mrNumber: patient.mrNumber,
        receiptId: prescriptionProvider.receiptId,
        doctorSrlNo: null, // As seen in React code
        doctorName: controllers['doctorName']!.text.isNotEmpty 
            ? controllers['doctorName']!.text 
            : (prescriptionProvider.doctorName ?? ''),
        
        // Vitals
        temp: vitals?.temperature?.toString(),
        bp: (vitals?.systolic != null && vitals?.diastolic != null) 
            ? '${vitals!.systolic}/${vitals!.diastolic}' 
            : null,
        pulse: vitals?.pulse?.toString(),
        weight: vitals?.weight?.toString(),
        height: vitals?.height?.toString(),
        bloodGroup: patient.bloodGroup,

        // Macros
        totalKilocalories: controllers['kcal']!.text,
        totalCarbs: controllers['carbs']!.text,
        totalProteins: controllers['proteins']!.text,
        totalFats: controllers['fats']!.text,

        // Diet Specs
        totalFluidIntake: controllers['fluid']!.text,
        dietOrder: controllers['dietOrder']!.text,
        dietType: controllers['dietType']!.text,
        dietaryRecommendations: controllers['dietaryRec']!.text,
        lifestyleRecommendations: controllers['lifestyleRec']!.text,

        // Diet Plans
        dietPlans: _dietPlans.map((item) => DietPlanModel(
          mealPart: item.mealPart,
          mealTime: item.mealTime,
          foodItems: item.foodController.text,
        )).toList(),
      );

      final res = await _apiService.saveNutritionistPrescription(payload.toJson());
      
      _isSaving = false;
      notifyListeners();
      
      if (res['success'] == true) {
        // The API usually returns the ID in res['data']['id'] or res['id']
        return res['data']?['id'] ?? res['id'];
      }
      return null;
    } catch (e) {
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  Future<NutritionPrescriptionModel?> fetchPrescriptionById(dynamic id) async {
    if (id == null) return null;
    try {
      final res = await _apiService.fetchNutritionistPrescriptionById(int.parse(id.toString()));
      if (res['success'] == true && res['data'] != null) {
        return NutritionPrescriptionModel.fromJson(res['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchHistory(String mrNumber) async {
    _isLoadingHistory = true;
    _visitHistory = [];
    _visitAnalysis = '';
    notifyListeners();

    try {
      final res = await _apiService.fetchNutritionistPrescriptionHistory(mrNumber);
      if (res['success'] == true && res['data'] != null) {
        final list = res['data'] as List? ?? [];
        _visitHistory = list.map((x) => NutritionPrescriptionModel.fromJson(x)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching nutritionist history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    _visitHistory = [];
    _visitAnalysis = '';
    _isLoadingHistory = false;
    _analyzingVisits = false;
    notifyListeners();
  }

  Future<bool> summarizeVisitsWithAI(String patientName) async {
    if (_visitHistory.isEmpty) return false;
    _analyzingVisits = true;
    notifyListeners();

    try {
      final records = _visitHistory.map((visit) => {
        'date': visit.createdAt,
        'doctor': visit.doctorName,
        'vitals': {
          'bp': visit.bp,
          'temp': visit.temp,
          'pulse': visit.pulse,
          'weight': visit.weight,
          'height': visit.height,
          'blood_group': visit.bloodGroup,
        },
        'nutrition_assessment': {
          'total_kilocalories': visit.totalKilocalories,
          'total_carbs': visit.totalCarbs,
          'total_proteins': visit.totalProteins,
          'total_fats': visit.totalFats,
          'total_fluid_intake': visit.totalFluidIntake,
          'diet_order': visit.dietOrder,
          'diet_type': visit.dietType,
          'dietary_recommendations': visit.dietaryRecommendations,
          'lifestyle_recommendations': visit.lifestyleRecommendations,
        },
        'diet_plan_schedule': visit.dietPlans.map((plan) => {
          'meal_part': plan.mealPart,
          'meal_time': plan.mealTime,
          'food_items': plan.foodItems,
        }).toList(),
      }).toList();

      final res = await _aiApiService.summarizePatientHistory(records, patientName);
      if (res['success'] == true) {
        _visitAnalysis = res['summary'] ?? '';
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error summarizing visits: $e');
      return false;
    } finally {
      _analyzingVisits = false;
      notifyListeners();
    }
  }

  void clearForm() {
    for (var controller in controllers.values) {
      controller.clear();
    }
    for (var plan in _dietPlans) {
      plan.mealTime = '--:--';
      plan.foodController.clear();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stopConsultationTimer();
    for (var controller in controllers.values) {
      controller.dispose();
    }
    for (var plan in _dietPlans) {
      plan.foodController.dispose();
    }
    super.dispose();
  }
}

class DietPlanItem {
  final String mealPart;
  String mealTime;
  final TextEditingController foodController;

  DietPlanItem({
    required this.mealPart,
    this.mealTime = '--:--',
    TextEditingController? controller,
  }) : foodController = controller ?? TextEditingController();
}
