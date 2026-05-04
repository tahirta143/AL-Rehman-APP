import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/utils/database_helper.dart';

class OfflineDashboardProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int totalPatients = 0;
  int totalVisits = 0;
  int totalVitals = 0;
  int totalPrescriptions = 0;
  int pendingSyncCount = 0;

  final ConnectivityService _connectivity = ConnectivityService();

  OfflineDashboardProvider() {
    _connectivity.isOnline.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    fetchOfflineStats();
  }

  @override
  void dispose() {
    _connectivity.isOnline.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  Future<void> fetchOfflineStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final patients = await _db.queryAll('patients_local');
      final visits = await _db.queryAll('visits_local');
      final vitals = await _db.queryAll('vitals_local');
      final prescriptions = await _db.queryAll('prescriptions_local');

      totalPatients = patients.length;
      totalVisits = visits.length;
      totalVitals = vitals.length;
      totalPrescriptions = prescriptions.length;

      // Calculate pending syncs across all tables
      int pending = 0;
      pending += patients.where((p) => p['sync_status'] == 'pending').length;
      pending += visits.where((v) => v['sync_status'] == 'pending').length;
      pending += vitals.where((v) => v['sync_status'] == 'pending').length;
      pending += prescriptions.where((p) => p['sync_status'] == 'pending').length;
      
      pendingSyncCount = pending;
    } catch (e) {
      debugPrint('❌ Error fetching offline stats: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
