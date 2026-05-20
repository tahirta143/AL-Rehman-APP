import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
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
  Future<void> clearCampToken() => _storage.clearCampToken();

  // ─── Helper: build auth headers (Staff JWT) ────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Helper: build camp device headers (Device Token) ──────────────
  Future<Map<String, String>> _campHeaders() async {
    final campToken = await _storage.getCampToken();
    return {
      'Content-Type': 'application/json',
      if (campToken != null) 'Authorization': 'Bearer $campToken',
    };
  }


  // ─── Bootstrap Master Data ───────────────────────────────────────
  Future<Map<String, dynamic>> bootstrap(String campId, {Function(String)? onProgress}) async {
    try {
      final headers = await _campHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/bootstrap/$campId';
      debugPrint('🚀 Bootstrapping from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));


      debugPrint('📥 Bootstrap Response [${response.statusCode}]');
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('📥 Error Body: ${response.body}');
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['message'] ?? 'Bootstrap failed'};
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final payload = data['data'];
          
          // Clear and refresh master tables
          await _db.clearTable('master_doctors');
          await _db.clearTable('master_services');

          if (payload['doctors'] != null) {
            onProgress?.call('Saving doctors...');
            final List<Map<String, dynamic>> doctors = [];
            for (var doc in payload['doctors']) {
              doctors.add({
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
            await _db.batchInsert('master_doctors', doctors);
          }

          if (payload['services'] != null) {
            onProgress?.call('Saving services...');
            final List<Map<String, dynamic>> services = [];
            for (var svc in payload['services']) {
              services.add({
                'srl_no': svc['srl_no'],
                'service_id': svc['service_id'],
                'service_name': svc['service_name'],
                'service_rate': svc['service_rate'],
                'receipt_type': svc['receipt_type'],
                'is_active': svc['is_active'],
              });
            }
            await _db.batchInsert('master_services', services);
          }

          if (payload['medicines'] != null) {
            onProgress?.call('Saving medicines...');
            await _db.clearTable('master_medicines');
            final List<Map<String, dynamic>> medicines = [];
            for (var med in payload['medicines']) {
              medicines.add({
                'id': med['id'],
                'name': med['medicine_name'],
                'is_formula': med['formula'] == 1 ? 1 : 0,
              });
            }
            await _db.batchInsert('master_medicines', medicines);
          }

          // Support both 'diagnosisQuestions' and 'diagnosis_catalog' key names
          final diagnosisRaw = payload['diagnosisQuestions'] ?? payload['diagnosis_catalog'];
          if (diagnosisRaw != null) {
            onProgress?.call('Saving diagnosis questions...');
            await _db.clearTable('master_diagnosis');
            
            List<dynamic> diagList = [];
            if (diagnosisRaw is List) {
              diagList = diagnosisRaw;
            } else if (diagnosisRaw is Map) {
              if (diagnosisRaw.containsKey('questions') && diagnosisRaw.containsKey('options')) {
                final List<dynamic> questions = diagnosisRaw['questions'] ?? [];
                final List<dynamic> options = diagnosisRaw['options'] ?? [];
                
                for (var q in questions) {
                  final qId = q['id'];
                  final qOptions = options.where((o) => o['question_id'] == qId).map((o) => o['option_text']).toList();
                  diagList.add({
                    ...q,
                    'options': qOptions,
                    'question_text': q['question_text'] ?? q['question'] ?? '',
                  });
                }
              } else {
                diagnosisRaw.forEach((category, questions) {
                  if (questions is List) {
                    for (var q in questions) {
                      if (q is Map) {
                        diagList.add({...q, 'category': q['category'] ?? category});
                      }
                    }
                  }
                });
              }
            }

            final List<Map<String, dynamic>> diagnosis = [];
            for (var dq in diagList) {
              final questionText = dq['question_text'] ?? dq['question'] ?? dq['title'] ?? '';
              final rawOptions = dq['options'] ?? dq['choices'] ?? [];
              final category = dq['category'] ?? 'General';
              final questionType = dq['question_mode'] ?? dq['question_type'] ?? 'choice';
              
              String optionsJson;
              try {
                optionsJson = jsonEncode(rawOptions is List ? rawOptions : []);
              } catch (_) {
                optionsJson = '[]';
              }
              diagnosis.add({
                'id': dq['id'],
                'question': questionText,
                'options_json': optionsJson,
                'category': category,
                'question_type': questionType,
              });
            }
            await _db.batchInsert('master_diagnosis', diagnosis);
          }

          if (payload['investigations'] != null) {
            onProgress?.call('Saving investigations...');
            await _db.clearTable('master_investigations');
            final invList = payload['investigations'] as List;
            final List<Map<String, dynamic>> investigations = [];
            for (var inv in invList) {
              investigations.add({
                'srl_no': inv['srl_no'] ?? inv['id'],
                'test_id': inv['test_id']?.toString() ?? inv['id']?.toString(),
                'test_name': inv['test_name'],
                'test_category': inv['test_category'] ?? inv['investigation_type'],
                'test_type': inv['test_type'] ?? inv['investigation_type'],
              });
            }
            await _db.batchInsert('master_investigations', investigations);
          }

          if (payload['eyeSetup'] != null) {
            onProgress?.call('Saving eye setup...');
            await _db.clearTable('master_eye_setup');
            final List<Map<String, dynamic>> eyeSetup = [];
            for (var item in payload['eyeSetup']) {
              eyeSetup.add({
                'id': item['id'],
                'item_name': item['item_name'],
                'item_type': item['item_type'],
              });
            }
            await _db.batchInsert('master_eye_setup', eyeSetup);
          }

          // Update config
          await _db.insert('camp_config', {
            'camp_id': campId,
            'mr_prefix': payload['camp']['mr_prefix'],
            'mr_sequence': payload['camp']['mr_sequence'] ?? 0,
            'last_bootstrap_at': DateTime.now().toIso8601String(),
          });

          // Fetch and cache full diagnosis questions (with options) from live API
          await _fetchAndCacheDiagnosisQuestions(headers, ['General', 'Eye'], onProgress: onProgress);

          return {'success': true, 'message': 'Master data updated successfully'};
        }
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired. Please log out and log in again.'};
      }
      if (response.statusCode == 404) {
        return {'success': false, 'message': 'Camp session not found on server.', 'isCampRemoved': true};
      }
      return {'success': false, 'message': 'Failed to fetch master data: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Bootstrap error: $e'};
    }
  }

  // ─── Fetch & Cache Diagnosis Questions ───────────────────────────
  Future<void> _fetchAndCacheDiagnosisQuestions(Map<String, String> headers, List<String> departments, {Function(String)? onProgress}) async {
    for (final dept in departments) {
      try {
        final url = '${GlobalApi.baseUrl}/diagnosis/questions/department/${Uri.encodeComponent(dept)}';
        final res = await http.get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true) {
            final questions = data['data'] as List? ?? [];
            if (questions.isNotEmpty) {
              onProgress?.call('Caching $dept diagnosis...');
              final db = await _db.database;
              await db.delete('master_diagnosis',
                  where: 'LOWER(category) = ?', whereArgs: [dept.toLowerCase()]);
              
              final List<Map<String, dynamic>> batch = [];
              for (var q in questions) {
                String optionsJson;
                try {
                  optionsJson = jsonEncode(q['options'] ?? q['choices'] ?? []);
                } catch (_) {
                  optionsJson = '[]';
                }
                batch.add({
                  'id': q['id'],
                  'question': q['question_text'] ?? q['question'] ?? '',
                  'options_json': optionsJson,
                  'category': dept,
                  'question_type': q['question_mode'] ?? q['question_type'] ?? 'choice',
                });
              }
              await _db.batchInsert('master_diagnosis', batch);
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to cache diagnosis for $dept: $e');
      }
    }
  }

  // ─── Web camp mode (staff JWT, no device password) ───────────────
  Future<Map<String, dynamic>> fetchWebAvailableCamps() async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/web/available-camps';
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {
        'success': false,
        'message': 'Failed to fetch camps: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Fetch camps error: $e'};
    }
  }

  Future<Map<String, dynamic>> webSelectCamp(String campId) async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/web/select-camp';
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({'camp_id': campId}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Camp selection failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Select camp error: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchWebCampPatients({
    required String campId,
    int limit = 200,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${GlobalApi.baseUrl}/camp-sync/web/patients')
          .replace(queryParameters: {
        'camp_id': campId,
        'limit': limit.toString(),
      });
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {
        'success': false,
        'message': 'Failed to fetch camp patients: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Camp patients error: $e'};
    }
  }

  Future<Map<String, dynamic>> createWebCampPatient({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/web/patients';
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Camp patient error: $e'};
    }
  }

  /// Create camp with name + location only (matches React CampDashboard).
  Future<Map<String, dynamic>> createSessionSimple({
    required String name,
    required String location,
  }) async {
    return createSession(
      name: name,
      location: location,
      password: '',
      mrPrefix: '',
      deviceLimit: 5,
    );
  }

  // ─── Fetch Available Camps ───────────────────────────────────────
  Future<Map<String, dynamic>> fetchAvailableCamps() async {
    try {
      // Health check ping
      try {
        final healthUrl = '${GlobalApi.baseUrl}/health';
        final healthRes = await http.get(Uri.parse(healthUrl)).timeout(const Duration(seconds: 5));
        debugPrint('🩺 Health Check [$healthUrl]: ${healthRes.statusCode}');
      } catch (e) {
        debugPrint('🩺 Health Check Failed: $e');
      }

      final url = '${GlobalApi.baseUrl}/camp-sync/available-camps';
      debugPrint('🚀 Fetching camps from: $url');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 15));



      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      debugPrint('📥 Camps Error Body: ${response.body}');
      return {'success': false, 'message': 'Failed to fetch camps: ${response.statusCode}'};

    } catch (e) {
      return {'success': false, 'message': 'Fetch camps error: $e'};
    }
  }

  // ─── Select Camp With Password ────────────────────────────────────
  Future<Map<String, dynamic>> selectCamp({
    required String campId,
    required String password,
    required String deviceName,
    required String deviceIdentifier,
  }) async {
    try {
      final url = '${GlobalApi.baseUrl}/camp-sync/select-camp';
      if (campId.isEmpty) {
        return {'success': false, 'message': 'Camp ID is missing.'};
      }

      final body = {
        'camp_id': campId,
        'password': password,
        'device_name': deviceName,
        'device_identifier': deviceIdentifier,
      };

      debugPrint('🚀 Selecting camp payload: ${jsonEncode(body)}');

      debugPrint('🚀 Selecting camp at: $url');
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Select Camp Response [${response.statusCode}]');
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('📥 Error Body: ${response.body}');
      }
      final data = jsonDecode(response.body);
      
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        final payload = data['data'];
        final camp = payload['camp'];
        final device = payload['device'];
        final token = payload['auth_token'];

        if (token != null) {
          await _storage.saveCampToken(token);
          
          // Save camp metadata to local config
          final db = await _db.database;
          await db.insert('camp_config', {
            'camp_id': camp['id'],
            'device_id': device['id'],
            'device_token': token,
            'mr_prefix': camp['mr_prefix'],
            'mr_sequence': camp['mr_sequence'] ?? 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          
          return {'success': true, 'message': 'Camp selected successfully', 'data': payload};
        }
      }

      String message = data['message'] ?? 'Camp selection failed';
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Select camp error: $e'};
    }
  }

  // ─── Register Device (Legacy - Keep for compatibility if needed) ──────────
  Future<Map<String, dynamic>> registerDevice({
    required String campId,
    required String deviceName,
    required String deviceIdentifier,
  }) async {
    // Redirect to selectCamp if possible, or keep as is if still supported by backend
    // For now, let's keep it but mark as legacy
    debugPrint('⚠️ registerDevice is deprecated, use selectCamp instead');
    return {'success': false, 'message': 'Please use selectCamp with password authentication.'};
  }

  // ─── Create Session ──────────────────────────────────────────────
  Future<Map<String, dynamic>> createSession({
    required String name,
    required String location,
    required String password,
    required String mrPrefix,
    required int deviceLimit,
  }) async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/sessions';
      final body = {
        'id': _uuid.v4(),
        'name': name,
        'location': location,
        'password': password,
        'mr_prefix': mrPrefix,
        'device_limit': deviceLimit,
        'status': 'active',
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

  // ─── Local MR Number Generation ─────────────────────────────────
  Future<String?> getNextMrNumberLocal() async {
    try {
      final db = await _db.database;
      final config = await db.query('camp_config', limit: 1);
      if (config.isEmpty) return null;

      final String? prefix = config.first['mr_prefix']?.toString();
      final int currentSeq = int.tryParse(config.first['mr_sequence']?.toString() ?? '0') ?? 0;
      
      if (prefix == null) return null;

      final int nextSeq = currentSeq + 1;
      
      // Update local sequence
      await db.update('camp_config', {'mr_sequence': nextSeq});
      
      return '$prefix-$nextSeq';
    } catch (e) {
      debugPrint('❌ Local MR generation error: $e');
      return null;
    }
  }

  Future<String?> peekNextMrNumberLocal() async {
    try {
      final db = await _db.database;
      final config = await db.query('camp_config', limit: 1);
      if (config.isEmpty) return null;

      final String? prefix = config.first['mr_prefix']?.toString();
      final int currentSeq = int.tryParse(config.first['mr_sequence']?.toString() ?? '0') ?? 0;
      
      if (prefix == null) return null;

      final int nextSeq = currentSeq + 1;
      return '$prefix-$nextSeq';
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateLocalSequenceFromMr(String mrNumber) async {
    try {
      final parts = mrNumber.split('-');
      if (parts.length != 2) return;
      
      final String prefix = parts[0];
      final int seq = int.tryParse(parts[1]) ?? 0;
      if (seq == 0) return;

      final db = await _db.database;
      final config = await db.query('camp_config', limit: 1);
      if (config.isEmpty) return;

      final String? currentPrefix = config.first['mr_prefix']?.toString();
      final int currentSeq = int.tryParse(config.first['mr_sequence']?.toString() ?? '0') ?? 0;

      // If prefix matches and the new sequence is higher or equal, update it
      if (prefix == currentPrefix && seq > currentSeq) {
        await db.update('camp_config', {'mr_sequence': seq});
        debugPrint('📈 Updated local sequence to: $seq (from MR: $mrNumber)');
      }
    } catch (e) {
      debugPrint('⚠️ Error updating sequence from MR: $e');
    }
  }

  // ─── Save Local Records ──────────────────────────────────────────
  Future<Map<String, String>> savePatientLocal(Map<String, dynamic> patientData) async {
    String uuid = _uuid.v4();
    patientData['device_uuid'] = uuid;
    patientData['sync_status'] = 'pending';
    patientData['created_at'] = DateTime.now().toIso8601String();
    
    // Auto-generate local MR number if not provided, otherwise ensure sequence is updated
    if (patientData['mr_number'] == null || patientData['mr_number'] == 'PENDING' || patientData['mr_number'].toString().isEmpty) {
      final localMr = await getNextMrNumberLocal();
      if (localMr != null) {
        patientData['mr_number'] = localMr;
        debugPrint('🆕 Assigned local MR number: $localMr');
      }
    } else {
      // User provided an MR number (or it was auto-filled), ensure we don't re-use this sequence
      await _updateLocalSequenceFromMr(patientData['mr_number'].toString());
    }

    await _db.insert('patients_local', patientData);
    return {
      'uuid': uuid,
      'mr_number': patientData['mr_number']?.toString() ?? '',
    };
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

  bool isUuid(dynamic value) {
    if (value == null) return false;
    final regExp = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
    return regExp.hasMatch(value.toString().trim());
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

      final headers = await _campHeaders();
      final url = '${GlobalApi.baseUrl}/camp-sync/bulk-sync';

      debugPrint('🚀 Bulk Syncing to: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 120));

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

          // ─── Process Mappings ───
          if (mappings != null) {
            for (var mapping in mappings) {
              final String entity = mapping['entity']?.toString() ?? '';
              final String deviceUuid = mapping['device_uuid']?.toString() ?? '';
              final String? mrNumber = (mapping['mr_number'] ?? mapping['server_id'])?.toString(); // server_id might be used as MR for some entities
              
              if (entity == 'patient' && mrNumber != null) {
                // Update the patient's MR number locally
                await (await _db.database).update(
                  'patients_local',
                  {'mr_number': mrNumber, 'sync_status': 'synced'},
                  where: 'device_uuid = ?',
                  whereArgs: [deviceUuid],
                );
                
                // CRITICAL: Also update related records that might be waiting for this MR number
                // This ensures they are ready for the next sync or correctly identified locally
                await (await _db.database).update(
                  'visits_local',
                  {'mr_number': mrNumber, 'patient_uuid': deviceUuid},
                  where: 'patient_uuid = ? AND (mr_number = "PENDING" OR mr_number IS NULL OR mr_number = "")',
                  whereArgs: [deviceUuid],
                );
                await (await _db.database).update(
                  'vitals_local',
                  {'mr_number': mrNumber, 'patient_uuid': deviceUuid},
                  where: 'patient_uuid = ? AND (mr_number = "PENDING" OR mr_number IS NULL OR mr_number = "")',
                  whereArgs: [deviceUuid],
                );
                await (await _db.database).update(
                  'prescriptions_local',
                  {'mr_number': mrNumber, 'patient_uuid': deviceUuid},
                  where: 'patient_uuid = ? AND (mr_number = "PENDING" OR mr_number IS NULL OR mr_number = "")',
                  whereArgs: [deviceUuid],
                );
                debugPrint('✅ Updated local MR number to $mrNumber for $deviceUuid');
              } else {
                // Generic sync status update for other entities
                String table = '';
                if (entity == 'visit') table = 'visits_local';
                else if (entity == 'vital') table = 'vitals_local';
                else if (entity == 'prescription') table = 'prescriptions_local';
                else if (entity == 'appointment') table = 'appointments_local';
                
                if (table.isNotEmpty) {
                  await _db.updateSyncStatus(table, deviceUuid, 'synced');
                }
              }
            }
          }

          // ─── Process Errors ───
          if (errors != null) {
            for (var err in errors) {
              final String entity = err['entity']?.toString() ?? '';
              final String deviceUuid = err['device_uuid']?.toString() ?? '';
              final String reason = err['reason']?.toString() ?? 'Server validation failed';

              String table = '';
              if (entity == 'patient') table = 'patients_local';
              else if (entity == 'visit') table = 'visits_local';
              else if (entity == 'vital') table = 'vitals_local';
              else if (entity == 'prescription') table = 'prescriptions_local';
              else if (entity == 'appointment') table = 'appointments_local';

              if (table.isNotEmpty) {
                await _db.updateSyncStatus(table, deviceUuid, 'failed', error: reason);
                debugPrint('❌ Sync Failed for $entity $deviceUuid: $reason');
              }
            }
          }

          // Fallback: mark remaining as synced if they were in the payload and NOT in errors
          // But only if we are reasonably sure they succeeded. 
          // The backend should return mappings for all successful inserts.
          
          return {
            'success': true, 
            'message': 'Sync completed', 
            'inserted': result['inserted'] ?? 0,
            'failed': result['failed'] ?? 0,
            'duplicates': result['duplicates'] ?? 0,
          };
        }
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired. Please log out and log in again.'};
      }
      if (response.statusCode == 404) {
        return {'success': false, 'message': 'Camp session not found on server.', 'isCampRemoved': true};
      }
      return {'success': false, 'message': 'Sync failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Sync error: $e'};
    }
  }
}
