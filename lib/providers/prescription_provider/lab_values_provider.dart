import 'package:flutter/material.dart';
import '../../core/services/lab_values_api_service.dart';
import '../../models/prescription_model/lab_values_model.dart';

class LabValuesProvider with ChangeNotifier {
  final LabValuesApiService _apiService = LabValuesApiService();

  LabValuesSheetModel _sheet = LabValuesSheetModel();
  LabValuesSheetModel get sheet => _sheet;

  bool _isLoading = false;
  bool _isSaving = false;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── Actions ─────────────────────────────────────────────────────

  Future<void> loadLabValues({String? mrNumber, String? receiptId}) async {
    final hasMr = mrNumber != null && mrNumber.trim().isNotEmpty;
    final hasReceipt = receiptId != null && receiptId.trim().isNotEmpty;

    if (!hasMr && !hasReceipt) {
      _sheet = LabValuesSheetModel();
      _isLoading = false; // Ensure loading is false
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = receiptId != null && receiptId.isNotEmpty
          ? await _apiService.fetchLabValuesByReceipt(receiptId)
          : await _apiService.fetchLabValuesByMR(mrNumber!);

      if (res['success'] == true) {
        _sheet = LabValuesSheetModel.fromJson(res['data'] ?? {});
      } else {
        _sheet = LabValuesSheetModel();
        _errorMessage = res['message'];
      }
    } catch (e) {
      _errorMessage = e.toString();
      _sheet = LabValuesSheetModel();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveSheet(String mrNumber, {String? receiptId}) async {
    if (mrNumber.isEmpty) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'mr_number': mrNumber,
        'receipt_id': receiptId,
        'parameters': _sheet.parameters,
        'dates': _sheet.dates,
        'entries': _sheet.entries,
      };

      final res = await _apiService.saveLabValues(payload);
      if (res['success'] == true) {
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Failed to save lab values';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ─── Local State Mutators ────────────────────────────────────────

  void addParameter(String name, {required String mrNumber, String? receiptId}) {
    if (name.isEmpty || _sheet.parameters.contains(name)) return;
    
    final newParams = [..._sheet.parameters, name];
    _sheet = _sheet.copyWith(parameters: newParams);
    notifyListeners();
    saveSheet(mrNumber, receiptId: receiptId);
  }

  void removeParameter(String name, {required String mrNumber, String? receiptId}) {
    final newParams = _sheet.parameters.where((p) => p != name).toList();
    final newEntries = Map<String, Map<String, String>>.from(_sheet.entries);
    newEntries.remove(name);
    
    _sheet = _sheet.copyWith(parameters: newParams, entries: newEntries);
    notifyListeners();
    saveSheet(mrNumber, receiptId: receiptId);
  }

  void addDate(String dateStr, {required String mrNumber, String? receiptId}) {
    if (dateStr.isEmpty || _sheet.dates.contains(dateStr)) return;
    
    final newDates = [..._sheet.dates, dateStr];
    _sheet = _sheet.copyWith(dates: newDates);
    notifyListeners();
    saveSheet(mrNumber, receiptId: receiptId);
  }

  void removeDate(String dateStr, {required String mrNumber, String? receiptId}) {
    final newDates = _sheet.dates.where((d) => d != dateStr).toList();
    final newEntries = Map<String, Map<String, String>>.from(_sheet.entries);
    
    for (var param in _sheet.parameters) {
      if (newEntries.containsKey(param)) {
        final Map<String, String> datesMap = Map.from(newEntries[param]!);
        datesMap.remove(dateStr);
        newEntries[param] = datesMap;
      }
    }

    _sheet = _sheet.copyWith(dates: newDates, entries: newEntries);
    notifyListeners();
    saveSheet(mrNumber, receiptId: receiptId);
  }

  void updateCell(String parameter, String date, String value, {required String mrNumber, String? receiptId}) {
    final newEntries = Map<String, Map<String, String>>.from(_sheet.entries);
    
    if (!newEntries.containsKey(parameter)) {
      newEntries[parameter] = {};
    }
    
    final Map<String, String> datesMap = Map.from(newEntries[parameter]!);
    datesMap[date] = value;
    newEntries[parameter] = datesMap;

    _sheet = _sheet.copyWith(entries: newEntries);
    notifyListeners();
    saveSheet(mrNumber, receiptId: receiptId);
  }
}
