import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/auth_storage_service.dart';
import '../../global/global_api.dart';
import '../../models/add_expenses_model/add_expenses_model.dart';
// import '../../services/auth_storage_service.dart';

class ExpensesProvider extends ChangeNotifier {
  static const String _baseUrl = '${GlobalApi.baseUrl}/expenses';

  final AuthStorageService _storage = AuthStorageService();
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    developer.log('🔑 Token: $token', name: 'ExpensesProvider');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  List<String> _expenseHeads = [];
  List<String> get expenseHeads => _expenseHeads;

  static const List<String> shifts = ['Morning', 'Evening', 'Night'];

  List<ExpenseModel> _allExpenses = [];
  List<ExpenseModel> _expenses = [];
  String _searchQuery = '';
  bool isLoading = false;
  String? errorMessage;

  List<ExpenseModel> get expenses => _expenses;

  // Returns the shift_id of the most recent expense (used when adding new expense)
  int get currentShiftId =>
      _allExpenses.isNotEmpty ? _allExpenses.first.shiftId : 0;

  String get currentShiftDate =>
      _allExpenses.isNotEmpty ? _allExpenses.first.shiftDate : '';
  
  String get currentShiftType =>
      _allExpenses.isNotEmpty ? _allExpenses.first.expenseShift : 'Morning';

  String get formattedTotal {
    final total = _expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final formatted = total.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
    return 'PKR $formatted';
  }

  final int? _initialShiftId;

  ExpensesProvider({int? shiftId}) : _initialShiftId = shiftId {
    fetchExpenses(shiftId: shiftId);
    fetchExpenseHeads();
  }

  Future<void> fetchExpenseHeads() async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/expense-heads';
      developer.log('📡 GET $url', name: 'ExpensesProvider');
      
      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _expenseHeads = (json['data'] as List)
              .map((e) => e['expense_head'].toString())
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      developer.log('❌ Error fetching expense heads: $e', name: 'ExpensesProvider');
    }
  }

  Future<void> fetchExpenses({int? shiftId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final headers = await _authHeaders();
      final url = shiftId != null ? '$_baseUrl/shift/$shiftId' : _baseUrl;
      developer.log('📡 GET $url', name: 'ExpensesProvider');

      final response = await http.get(Uri.parse(url), headers: headers);

      developer.log('📥 Status: ${response.statusCode}', name: 'ExpensesProvider');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _allExpenses = (json['data'] as List)
              .map((e) => ExpenseModel.fromJson(e))
              .toList();
          _applyFilter();
        } else {
          errorMessage = 'Failed to load expenses.';
        }
      } else if (response.statusCode == 401) {
        errorMessage = 'Session expired. Please log in again.';
      } else {
        errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e, stack) {
      errorMessage = 'Network error. Check your connection.';
      developer.log('💥 $e', name: 'ExpensesProvider', error: e, stackTrace: stack);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> addExpense({
    required String category,
    required double amount,
    required String expenseBy,
    required String description,
    int? shiftId,
    String? shiftDate,
    String? expenseShift,
  }) async {
    final now = DateTime.now();
    final expenseDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final expenseTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    // Use provided shift data or fallback to guesses
    final effectiveShiftId = shiftId ?? currentShiftId;
    final effectiveShiftDate = shiftDate ?? (currentShiftDate.isNotEmpty ? currentShiftDate : expenseDate);
    final effectiveExpenseShift = expenseShift ?? currentShiftType;

    final body = jsonEncode({
      'expense_date': expenseDate,
      'expense_time': expenseTime,
      'expense_shift': effectiveExpenseShift,
      'expense_description': description,
      'expense_name': category,
      'expense_amount': amount,
      'expense_by': expenseBy,
      'shift_id': effectiveShiftId,
      'shift_date': effectiveShiftDate,
    });

    try {
      final headers = await _authHeaders();
      developer.log('📡 POST $_baseUrl', name: 'ExpensesProvider');
      developer.log('📤 Body: $body', name: 'ExpensesProvider');

      final response = await http.post(Uri.parse(_baseUrl), headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchExpenses(shiftId: effectiveShiftId);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // update expenses
  Future<bool> updateExpense({
    required int srlNo,
    required String category,
    required double amount,
    required String expenseBy,
    required String description,
    required String expenseShift, required String expenseDate, required String expenseTime,
  }) async {
    final body = jsonEncode({
      'expense_name': category,
      'expense_amount': amount,
      'expense_by': expenseBy,
      'expense_description': description,
      'expense_shift': expenseShift,
      'expense_date': expenseDate,
      'expense_time': expenseTime,
    });

    try {
      final headers = await _authHeaders();
      final url = '$_baseUrl/$srlNo';  // ← srl_no e.g. /api/expenses/4101
      developer.log('📡 PUT $url', name: 'ExpensesProvider');
      developer.log('📤 Body: $body', name: 'ExpensesProvider');

      final response = await http.put(Uri.parse(url), headers: headers, body: body);

      developer.log('📥 Status: ${response.statusCode}', name: 'ExpensesProvider');
      developer.log('📥 Body: ${response.body}', name: 'ExpensesProvider');

      if (response.statusCode == 200) {
        developer.log('✅ Updated srl_no: $srlNo', name: 'ExpensesProvider');
        await fetchExpenses();
        return true;
      }
      developer.log('❌ Update failed ${response.statusCode}: ${response.body}', name: 'ExpensesProvider');
      return false;
    } catch (e, stack) {
      developer.log('💥 $e', name: 'ExpensesProvider', error: e, stackTrace: stack);
      return false;
    }
  }


  // delete expenses
  Future<bool> deleteExpense(int srlNo) async {  // ← int, not String
    try {
      final headers = await _authHeaders();
      final url = '$_baseUrl/$srlNo';  // ← uses srlNo e.g. /api/expenses/4101
      developer.log('📡 DELETE $url', name: 'ExpensesProvider');

      final response = await http.delete(Uri.parse(url), headers: headers);

      developer.log('📥 Status: ${response.statusCode}', name: 'ExpensesProvider');
      developer.log('📥 Body: ${response.body}', name: 'ExpensesProvider');

      if (response.statusCode == 200) {
        developer.log('✅ Deleted srl_no: $srlNo', name: 'ExpensesProvider');
        _allExpenses.removeWhere((e) => e.srlNo == srlNo);  // ← match by srlNo
        _applyFilter();
        notifyListeners();
        return true;
      }
      developer.log('❌ Delete failed ${response.statusCode}: ${response.body}', name: 'ExpensesProvider');
      return false;
    } catch (e, stack) {
      developer.log('💥 $e', name: 'ExpensesProvider', error: e, stackTrace: stack);
      return false;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _applyFilter();
    fetchExpenses(shiftId: _initialShiftId);
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _expenses = List.from(_allExpenses);
    } else {
      _expenses = _allExpenses.where((e) {
        return e.category.toLowerCase().contains(_searchQuery) ||
            e.expenseBy.toLowerCase().contains(_searchQuery) ||
            e.description.toLowerCase().contains(_searchQuery) ||
            e.id.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }
}