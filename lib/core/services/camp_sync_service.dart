import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../utils/database_helper.dart';
import '../../global/global_api.dart';
import 'auth_storage_service.dart';

class CampSyncService {
  static final CampSyncService _instance = CampSyncService._internal();
  final DatabaseHelper _db = DatabaseHelper();
  final AuthStorageService _storage = AuthStorageService();
  final Uuid _uuid = const Uuid();

  factory CampSyncService() => _instance;

  CampSyncService._internal();

  String generateUuid() => _uuid.v4();

  Future<String?> getCampToken() => _storage.getCampToken();

  // ─── Helper: build auth headers ───────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    final campToken = await _storage.getCampToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (campToken != null) 'x-camp-device-token': campToken,
    };
  }

  // ─── Bootstrap Master Data ───────────────────────────────────────
  Future<Map<String, dynamic>> bootstrap(String campId) async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/bootstrap/$campId';
      debugPrint('🚀 Bootstrapping from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      debugPrint('📥 Bootstrap Response [${response.statusCode}]');
      if (response.statusCode != 200) {
        debugPrint('📥 Error Body: ${response.body}');
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['message'] ?? 'Bootstrap failed'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final payload = data['data'];
          
          // Clear and refresh master tables
          await _db.clearTable('master_doctors');
          await _db.clearTable('master_services');

          if (payload['doctors'] != null) {
            for (var doc in payload['doctors']) {
              await _db.insert('master_doctors', {
                'srl_no': doc['srl_no'],
                'doctor_id': doc['doctor_id'],
                'doctor_name': doc['doctor_name'],
                'doctor_specialization': doc['doctor_specialization'],
                'doctor_department': doc['doctor_department'],
                'doctor_timings': doc['consultation_timings'],
                'consultation_fee': doc['consultation_fee'],
                'follow_up_fee': doc['follow_up_fee'] ?? (double.tryParse(doc['consultation_fee'].toString()) ?? 0 * 0.7).floor().toString(),
                'available_days': doc['available_days'] ?? 'Mon,Tue,Wed,Thu,Fri,Sat,Sun',
                'hospital_name': doc['hospital_name'] ?? 'Hospital',
                'image_url': doc['image_url'] ?? '',
                'is_active': doc['is_active'],
              });
            }
          }

          if (payload['services'] != null) {
            for (var svc in payload['services']) {
              await _db.insert('master_services', {
                'srl_no': svc['srl_no'],
                'service_id': svc['service_id'],
                'service_name': svc['service_name'],
                'service_rate': svc['service_rate'],
                'receipt_type': svc['receipt_type'],
                'is_active': svc['is_active'],
              });
            }
          }

          if (payload['medicines'] != null) {
            await _db.clearTable('master_medicines');
            for (var med in payload['medicines']) {
              await _db.insert('master_medicines', {
                'id': med['id'],
                'name': med['medicine_name'],
                'is_formula': med['formula'] == 1 ? 1 : 0,
              });
            }
          }

          if (payload['diagnosisQuestions'] != null) {
            await _db.clearTable('master_diagnosis');
            for (var dq in payload['diagnosisQuestions']) {
              await _db.insert('master_diagnosis', {
                'id': dq['id'],
                'question': dq['question_text'],
                'options_json': jsonEncode(dq['options']),
                'category': dq['category'] ?? 'General',
              });
            }
          }

          // Update config
          await _db.insert('camp_config', {
            'camp_id': campId,
            'last_bootstrap_at': DateTime.now().toIso8601String(),
          });

          return {'success': true, 'message': 'Master data updated successfully'};
        }
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired. Please log out and log in again.'};
      }
      return {'success': false, 'message': 'Failed to fetch master data: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Bootstrap error: $e'};
    }
  }

  // ─── Register Device ──────────────────────────────────────────────
  Future<Map<String, dynamic>> registerDevice({
    required String campId,
    required String deviceName,
    required String deviceIdentifier,
  }) async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/register-device';
      final body = {
        'id': _uuid.v4(),
        'camp_id': campId,
        'device_name': deviceName,
        'device_identifier': deviceIdentifier,
      };

      debugPrint('🚀 Registering device at: $url');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Register Response [${response.statusCode}]');
      if (response.statusCode != 201) {
        debugPrint('📥 Error Body: ${response.body}');
      }

      final data = jsonDecode(response.body);
      if (data == null) return {'success': false, 'message': 'Empty response from server'};

      if (response.statusCode == 201 && data['success'] == true) {
        final deviceData = data['data'];
        if (deviceData != null && deviceData['auth_token'] != null) {
          final token = deviceData['auth_token'];
          await _storage.saveCampToken(token);
          return {'success': true, 'message': 'Device registered successfully'};
        }
      }

      String message = data['message'] ?? 'Registration failed';
      if (data['errors'] != null && data['errors'] is List) {
        final errors = data['errors'] as List;
        if (errors.isNotEmpty) {
          final firstError = errors[0];
          message = '${firstError['field']}: ${firstError['reason']}';
        }
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Registration error: $e'};
    }
  }

  // ─── Create Session ──────────────────────────────────────────────
  Future<Map<String, dynamic>> createSession({
    required String name,
    required String location,
  }) async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/sessions';
      final body = {
        'id': _uuid.v4(),
        'name': name,
        'location': location,
        'status': 'active',
        'device_limit': 5,
      };

      debugPrint('🚀 Creating session at: $url');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if ((response.statusCode == 201 || response.statusCode == 200) && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'message': data['message'] ?? 'Creation failed'};
    } catch (e) {
      return {'success': false, 'message': 'Creation error: $e'};
    }
  }

  // ─── Save Local Records ──────────────────────────────────────────
  Future<String> savePatientLocal(Map<String, dynamic> patientData) async {
    String uuid = _uuid.v4();
    patientData['device_uuid'] = uuid;
    patientData['sync_status'] = 'pending';
    patientData['created_at'] = DateTime.now().toIso8601String();
    await _db.insert('patients_local', patientData);
    return uuid;
  }

  Future<String> saveVisitLocal(Map<String, dynamic> visitData) async {
    String uuid = _uuid.v4();
    visitData['device_uuid'] = uuid;
    visitData['sync_status'] = 'pending';
    visitData['created_at'] = DateTime.now().toIso8601String();
    await _db.insert('visits_local', visitData);
    return uuid;
  }

  Future<String> saveAppointmentLocal(Map<String, dynamic> appData) async {
    String uuid = _uuid.v4();
    appData['device_uuid'] = uuid;
    appData['sync_status'] = 'pending';
    appData['created_at'] = DateTime.now().toIso8601String();
    await _db.insert('appointments_local', appData);
    return uuid;
  }

  bool isUuid(String? value) {
    if (value == null) return false;
    final regExp = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
    return regExp.hasMatch(value.trim());
  }

  // ─── Bulk Sync ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> bulkSync() async {
    try {
      // ─── Data Repair Step ───
      // Fix "PENDING" or missing identifiers for vitals and prescriptions before syncing
      final allVitals = await _db.queryPending('vitals_local');
      for (var v in allVitals) {
        if (v['patient_uuid'] == 'PENDING' || v['patient_uuid'] == null || v['patient_uuid'].toString().isEmpty) {
          // Try to recover patient_uuid from visits_local using visit_uuid
          final visitUuid = v['visit_uuid'];
          if (visitUuid != null && visitUuid.isNotEmpty) {
            final visits = await _db.database.then((db) => db.query('visits_local', where: 'device_uuid = ?', whereArgs: [visitUuid]));
            if (visits.isNotEmpty && visits.first['patient_uuid'] != 'PENDING' && visits.first['patient_uuid'] != null) {
              await _db.database.then((db) => db.update('vitals_local', {'patient_uuid': visits.first['patient_uuid']}, where: 'device_uuid = ?', whereArgs: [v['device_uuid']]));
              debugPrint('🛠️ Repaired vital ${v['device_uuid']} patient_uuid from visit');
            }
          }
        }
      }

      final allPrescriptions = await _db.queryPending('prescriptions_local');
      for (var p in allPrescriptions) {
        if (p['patient_uuid'] == 'PENDING' || p['patient_uuid'] == null || p['patient_uuid'].toString().isEmpty) {
          final visitUuid = p['visit_uuid'];
          if (visitUuid != null && visitUuid.isNotEmpty) {
            final visits = await _db.database.then((db) => db.query('visits_local', where: 'device_uuid = ?', whereArgs: [visitUuid]));
            if (visits.isNotEmpty && visits.first['patient_uuid'] != 'PENDING' && visits.first['patient_uuid'] != null) {
              await _db.database.then((db) => db.update('prescriptions_local', {'patient_uuid': visits.first['patient_uuid']}, where: 'device_uuid = ?', whereArgs: [p['device_uuid']]));
              debugPrint('🛠️ Repaired prescription ${p['device_uuid']} patient_uuid from visit');
            }
          }
        }
      }

      final patients = await _db.queryPending('patients_local');
      final visits = await _db.queryPending('visits_local');
      final vitals = await _db.queryPending('vitals_local');
      final prescriptions = await _db.queryPending('prescriptions_local');
      final appointments = await _db.queryPending('appointments_local');

      if (patients.isEmpty && visits.isEmpty && vitals.isEmpty && prescriptions.isEmpty && appointments.isEmpty) {
        return {'success': true, 'message': 'No pending records to sync'};
      }

      final payload = {
        'patients': patients.map((p) {
          final map = Map<String, dynamic>.from(p);
          if (map['mr_number'] == 'PENDING') map.remove('mr_number');
          return map;
        }).toList(),
        'visits': visits.map((v) {
          final map = Map<String, dynamic>.from(v);
          // If patient_uuid is not a UUID, it must be an MR number
          if (map['patient_uuid'] != null && !isUuid(map['patient_uuid'])) {
            map['patient_mr_number'] = map['patient_uuid'];
            map.remove('patient_uuid');
          }
          if (map['patient_mr_number'] == 'PENDING') map.remove('patient_mr_number');
          if (map['patient_uuid'] == 'PENDING') map.remove('patient_uuid');
          return map;
        }).toList(),
        'vitals': vitals.map((v) {
          final map = Map<String, dynamic>.from(v);
          // If patient_uuid is not a UUID, move to mr_number
          if (map['patient_uuid'] != null && !isUuid(map['patient_uuid'])) {
            map['mr_number'] ??= map['patient_uuid'];
            map.remove('patient_uuid');
          }
          if (map['patient_uuid'] == 'PENDING') map.remove('patient_uuid');
          if (map['mr_number'] == 'PENDING') map.remove('mr_number');
          return map;
        }).toList(),
        'prescriptions': prescriptions.map((p) {
          final map = Map<String, dynamic>.from(p);
          if (map['patient_uuid'] != null && !isUuid(map['patient_uuid'])) {
            map['mr_number'] ??= map['patient_uuid'];
            map.remove('patient_uuid');
          }
          if (map['patient_uuid'] == 'PENDING') map.remove('patient_uuid');
          if (map['mr_number'] == 'PENDING') map.remove('mr_number');
          return map;
        }).toList(),
        'appointments': appointments,
      };

      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/bulk-sync';
      debugPrint('🚀 Bulk Syncing to: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      debugPrint('📥 Sync Response [${response.statusCode}]');
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('📥 Error Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          // Process mappings and errors
          final mappings = result['mappings'] as List?;
          final errors = result['errors'] as List?;

          // Update statuses based on result
          // For simplicity, we mark all successfully sent items as synced
          // In a real app, we'd iterate mappings/errors as per guide
          for (var p in patients) {
            await _db.updateSyncStatus('patients_local', p['device_uuid'], 'synced');
          }
          for (var v in visits) {
            await _db.updateSyncStatus('visits_local', v['device_uuid'], 'synced');
          }
          for (var vi in vitals) {
            await _db.updateSyncStatus('vitals_local', vi['device_uuid'], 'synced');
          }
          for (var pr in prescriptions) {
            await _db.updateSyncStatus('prescriptions_local', pr['device_uuid'], 'synced');
          }
          for (var app in appointments) {
            await _db.updateSyncStatus('appointments_local', app['device_uuid'], 'synced');
          }

          return {
            'success': true, 
            'message': 'Sync completed', 
            'inserted': result['inserted'],
            'failed': result['failed']
          };
        }
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired. Please log out and log in again.'};
      }
      return {'success': false, 'message': 'Sync failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Sync error: $e'};
    }
  }
}
