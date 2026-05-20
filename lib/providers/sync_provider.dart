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

  String? _syncStatus;
  String? get syncStatus => _syncStatus;

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

  void _onConnectivityChanged() async {
    await _updatePendingCount();
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

  Future<void> refreshPendingCount() => _updatePendingCount();

  Future<void> syncData() async {
    if (_isSyncing || !isOnline) return;
    
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final result = await _syncService.bulkSync();
      if (result['success'] != true) {
        _lastErrorMessage = result['message'];
        if (result['isCampRemoved'] == true) {
          await resetCamp();
          _lastErrorMessage = 'Camp removed from admin. Local session reset.';
        }
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
    _syncStatus = 'Downloading data...';
    notifyListeners();
    try {
      final result = await _syncService.bootstrap(campId, onProgress: (msg) {
        _syncStatus = msg;
        notifyListeners();
      });
      
      if (result['success'] == true) {
        _syncStatus = 'Finalizing data...';
        notifyListeners();
        
        // --- Flutter-only Workaround: Hydrate missing fields ---
        try {
          final doctorsResult = await _consultationApi.fetchDoctors();
          if (doctorsResult.success && doctorsResult.doctors.isNotEmpty) {
            _syncStatus = 'Updating doctor profiles...';
            notifyListeners();
            
            final db = await _db.database;
            final batch = db.batch();
            for (var doc in doctorsResult.doctors) {
              batch.update(
                'master_doctors',
                {
                  'doctor_timings': doc.consultationTimings,
                  'consultation_fee': doc.consultationFee,
                  'follow_up_fee': ((double.tryParse(doc.consultationFee) ?? 0) * 0.7).floor().toString(),
                  'available_days': doc.availableDays,
                  'hospital_name': doc.hospitalName,
                  'image_url': doc.imageUrl ?? '',
                },
                where: 'srl_no = ?',
                whereArgs: [doc.srlNo],
              );
            }
            await batch.commit(noResult: true);
          }
        } catch (e) {
          debugPrint('❌ Hydration error: $e');
        }
        _syncStatus = null;
        notifyListeners();
      } else {
        _lastErrorMessage = result['message'];
        _syncStatus = null;
        if (result['isCampRemoved'] == true) {
          await resetCamp();
          _lastErrorMessage = 'Camp removed from admin. Local session reset.';
        }
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      _syncStatus = null;
    } finally {
      _isSyncing = false;
      _syncStatus = null;
      notifyListeners();
    }
  }

  Future<List<dynamic>> fetchAvailableCamps() async {
    _lastErrorMessage = null;
    try {
      final result = await _syncService.fetchAvailableCamps();
      if (result['success'] == true) {
        return result['data'] as List? ?? [];
      } else {
        _lastErrorMessage = result['message'];
        return [];
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      return [];
    }
  }

  Future<bool> selectCamp({
    required String campId,
    required String password,
    required String deviceName,
  }) async {
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      // Use device_info_plus or a random ID
      final identifier = _syncService.generateUuid(); 
      final result = await _syncService.selectCamp(
        campId: campId,
        password: password,
        deviceName: deviceName,
        deviceIdentifier: identifier,
      );
      if (result['success'] == true) {
        _isDeviceRegistered = true;
        _campId = campId;
        notifyListeners();
        return true;
      } else {
        _lastErrorMessage = result['message'];
        return false;
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> registerDevice(String campId, String deviceName) async {
    _lastErrorMessage = "Legacy registration is disabled. Please use camp selection with password.";
    notifyListeners();
  }

  Future<Map<String, dynamic>> createSessionSimple({
    required String name,
    required String location,
  }) async {
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final result = await _syncService.createSessionSimple(
        name: name,
        location: location,
      );
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

  Future<Map<String, dynamic>> createSession({
    required String name,
    required String location,
    required String password,
    required String mrPrefix,
    required int deviceLimit,
  }) async {
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final result = await _syncService.createSession(
        name: name,
        location: location,
        password: password,
        mrPrefix: mrPrefix,
        deviceLimit: deviceLimit,
      );
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

  Future<void> resetCamp() async {
    _isSyncing = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      await _db.clearTable('camp_config');
      await _syncService.clearCampToken();
      _isDeviceRegistered = false;
      _campId = null;
    } catch (e) {
      _lastErrorMessage = e.toString();
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
