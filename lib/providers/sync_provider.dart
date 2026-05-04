import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/camp_sync_service.dart';
import '../../core/services/consultation_api_service.dart';
import '../../core/utils/database_helper.dart';

class SyncProvider extends ChangeNotifier {
  final ConnectivityService _connectivity = ConnectivityService();
  final CampSyncService _syncService = CampSyncService();
  final ConsultationApiService _consultationApi = ConsultationApiService();
  final DatabaseHelper _db = DatabaseHelper();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  bool _isDeviceRegistered = false;
  bool get isDeviceRegistered => _isDeviceRegistered;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  String? _campId;
  String? get campId => _campId;

  bool get isOnline => _connectivity.isOnline.value;
  bool get isOfflineForced => _connectivity.isManualOffline;

  SyncProvider() {
    _connectivity.isOnline.addListener(_onConnectivityChanged);
    _updatePendingCount();
    _checkRegistration();
  }

  Future<void> _checkRegistration() async {
    final token = await _syncService.getCampToken();
    _isDeviceRegistered = token != null;
    
    // Load last used campId
    final config = await _db.queryAll('camp_config');
    if (config.isNotEmpty) {
      _campId = config.first['camp_id']?.toString();
    }
    
    notifyListeners();
  }

  void _onConnectivityChanged() {
    notifyListeners();
    if (isOnline && _pendingCount > 0) {
      // Auto-sync when back online
      syncData();
    }
  }

  void toggleOfflineOverride() {
    _connectivity.toggleManualOffline();
    notifyListeners();
  }

  Future<void> _updatePendingCount() async {
    final patients = await _db.queryPending('patients_local');
    final visits = await _db.queryPending('visits_local');
    final vitals = await _db.queryPending('vitals_local');
    final prescriptions = await _db.queryPending('prescriptions_local');
    final appointments = await _db.queryPending('appointments_local');
    _pendingCount = patients.length + visits.length + vitals.length + prescriptions.length + appointments.length;
    notifyListeners();
  }

  Future<void> syncData() async {
    if (_isSyncing || !isOnline) return;
    
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final result = await _syncService.bulkSync();
      if (result['success'] != true) {
        _lastErrorMessage = result['message'];
      }
      debugPrint('🔄 Sync Result: ${result['message']}');
    } catch (e) {
      _lastErrorMessage = e.toString();
      debugPrint('❌ Sync Error: $e');
    } finally {
      _isSyncing = false;
      await _updatePendingCount();
    }
  }

  Future<void> bootstrap(String campId) async {
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final result = await _syncService.bootstrap(campId);
      if (result['success'] == true) {
        // --- Flutter-only Workaround: Hydrate missing fields ---
        debugPrint('💧 Hydrating doctor details from standard API...');
        try {
          final doctorsResult = await _consultationApi.fetchDoctors();
          if (doctorsResult.success && doctorsResult.doctors.isNotEmpty) {
            int count = 0;
            for (var doc in doctorsResult.doctors) {
              final updated = await _db.updateDoctorDetails(
                srlNo: doc.srlNo,
                timings: doc.consultationTimings,
                fee: doc.consultationFee,
                days: doc.availableDays,
                hospital: doc.hospitalName,
                imageUrl: doc.imageUrl ?? '',
              );
              if (updated > 0) count++;
              debugPrint('👨‍⚕️ Hydrated Dr. ${doc.doctorName}: fee=${doc.consultationFee}, timings=${doc.consultationTimings}');
            }
            debugPrint('✅ Doctors hydrated with full details: $count doctors');
          } else {
            debugPrint('⚠️ Hydration failed: ${doctorsResult.message}');
          }
        } catch (e) {
          debugPrint('❌ Hydration error: $e');
        }
        notifyListeners();
      } else {
        _lastErrorMessage = result['message'];
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> registerDevice(String campId, String deviceName) async {
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      // Use device_info_plus or a random ID
      final identifier = _syncService.generateUuid(); 
      final result = await _syncService.registerDevice(
        campId: campId,
        deviceName: deviceName,
        deviceIdentifier: identifier,
      );
      if (result['success'] == true) {
        _isDeviceRegistered = true;
      } else {
        _lastErrorMessage = result['message'];
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createSession(String name, String location) async {
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final result = await _syncService.createSession(name: name, location: location);
      if (result['success'] != true) {
        _lastErrorMessage = result['message'];
      }
      return result;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return {'success': false, 'message': e.toString()};
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivity.isOnline.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
