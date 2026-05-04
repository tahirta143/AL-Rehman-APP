import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'hims_offline.db');
    return await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Add missing doctor columns
      final columns = ['doctor_timings', 'follow_up_fee', 'available_days', 'hospital_name', 'image_url'];
      for (var col in columns) {
        try {
          await db.execute('ALTER TABLE master_doctors ADD COLUMN $col TEXT');
        } catch (e) {
          // Column might already exist if onCreate was partially run
        }
      }

      // 2. Create appointments table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS appointments_local (
          device_uuid TEXT PRIMARY KEY,
          patient_uuid TEXT,
          doctor_srl_no INTEGER,
          appointment_date TEXT,
          appointment_time TEXT,
          reason TEXT,
          sync_status TEXT,
          last_sync_attempt_at TEXT,
          last_error TEXT,
          created_at TEXT
        )
      ''');
    }
    
    if (oldVersion < 3) {
      final appCols = [
        'mr_number TEXT',
        'patient_name TEXT',
        'patient_contact TEXT',
        'patient_address TEXT',
        'fee TEXT',
        'follow_up_charges TEXT',
        'is_first_visit INTEGER'
      ];
      for (var col in appCols) {
        try {
          await db.execute('ALTER TABLE appointments_local ADD COLUMN $col');
        } catch (e) {
          // Skip if column already exists
        }
      }
    }
    
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE appointments_local ADD COLUMN token_number INTEGER');
      } catch (e) {
        // Skip if column already exists
      }
    }

    if (oldVersion < 5) {
      // 1. Add missing vitals columns
      final vitalCols = [
        'height REAL',
        'bmi REAL',
        'bmr REAL',
        'spo2 REAL',
        'waist REAL',
        'hip REAL',
        'whr REAL',
        'pain_scale INTEGER'
      ];
      for (var col in vitalCols) {
        try {
          await db.execute('ALTER TABLE vitals_local ADD COLUMN $col');
        } catch (e) {}
      }

      // 2. Create cached consultations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_consultations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_mr_number TEXT,
          patient_name TEXT,
          receipt_id TEXT,
          doctor_name TEXT,
          service_detail TEXT,
          token_number INTEGER,
          doctor_department TEXT,
          cached_at TEXT
        )
      ''');
    }

    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE vitals_local ADD COLUMN mr_number TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE prescriptions_local ADD COLUMN mr_number TEXT');
      } catch (e) {}
    }

    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE visits_local ADD COLUMN mr_number TEXT');
      } catch (e) {}
    }
  }

  Future _onCreate(Database db, int version) async {
    // ... Existing tables ...
    // Note: I should ensure onCreate also creates these latest schemas
    // But for now, let's just make sure migration works.
    // 1. Camp Config
    await db.execute('''
      CREATE TABLE camp_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        camp_id INTEGER,
        device_id TEXT,
        device_token TEXT,
        last_bootstrap_at TEXT,
        last_sync_at TEXT
      )
    ''');

    // 2. Master Data (Cached)
    await db.execute('''
      CREATE TABLE master_doctors (
        srl_no INTEGER PRIMARY KEY,
        doctor_id TEXT,
        doctor_name TEXT,
        doctor_specialization TEXT,
        doctor_department TEXT,
        doctor_timings TEXT,
        consultation_fee TEXT,
        follow_up_fee TEXT,
        available_days TEXT,
        hospital_name TEXT,
        image_url TEXT,
        is_active INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE master_services (
        srl_no INTEGER PRIMARY KEY,
        service_id TEXT,
        service_name TEXT,
        service_rate TEXT,
        receipt_type TEXT,
        is_active INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE master_medicines (
        id INTEGER PRIMARY KEY,
        name TEXT,
        is_formula INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE master_diagnosis (
        id INTEGER PRIMARY KEY,
        question TEXT,
        options_json TEXT,
        category TEXT
      )
    ''');

    // 3. Local Transactional Data
    await db.execute('''
      CREATE TABLE patients_local (
        device_uuid TEXT PRIMARY KEY,
        mr_number TEXT,
        first_name TEXT,
        last_name TEXT,
        guardian_name TEXT,
        gender TEXT,
        phone TEXT,
        address TEXT,
        city TEXT,
        blood_group TEXT,
        sync_status TEXT,
        last_sync_attempt_at TEXT,
        last_error TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE visits_local (
        device_uuid TEXT PRIMARY KEY,
        patient_uuid TEXT,
        receipt_id TEXT,
        date TEXT,
        time TEXT,
        patient_name TEXT,
        doctor_srl_no INTEGER,
        opd_service TEXT,
        total_amount REAL,
        paid REAL,
        mr_number TEXT,
        sync_status TEXT,
        last_sync_attempt_at TEXT,
        last_error TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vitals_local (
        device_uuid TEXT PRIMARY KEY,
        patient_uuid TEXT,
        visit_uuid TEXT,
        bsr REAL,
        systolic REAL,
        diastolic REAL,
        pulse REAL,
        weight REAL,
        temp REAL,
        mr_number TEXT,
        sync_status TEXT,
        last_sync_attempt_at TEXT,
        last_error TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE prescriptions_local (
        device_uuid TEXT PRIMARY KEY,
        patient_uuid TEXT,
        visit_uuid TEXT,
        doctor_srl_no INTEGER,
        treatment TEXT,
        medicines_json TEXT,
        investigations_json TEXT,
        mr_number TEXT,
        sync_status TEXT,
        last_sync_attempt_at TEXT,
        created_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE appointments_local (
        device_uuid TEXT PRIMARY KEY,
        patient_uuid TEXT,
        mr_number TEXT,
        patient_name TEXT,
        patient_contact TEXT,
        patient_address TEXT,
        doctor_srl_no INTEGER,
        appointment_date TEXT,
        appointment_time TEXT,
        fee TEXT,
        follow_up_charges TEXT,
        is_first_visit INTEGER,
        token_number INTEGER,
        reason TEXT,
        sync_status TEXT,
        last_sync_attempt_at TEXT,
        last_error TEXT,
        created_at TEXT
      )
    ''');
  }

  // Generic methods
  Future<int> insert(String table, Map<String, dynamic> data) async {
    Database db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    Database db = await database;
    return await db.query(table);
  }

  Future<List<Map<String, dynamic>>> queryPending(String table) async {
    Database db = await database;
    return await db.query(table, where: 'sync_status = ?', whereArgs: ['pending']);
  }

  Future<int> updateSyncStatus(String table, String uuid, String status, {String? error}) async {
    Database db = await database;
    return await db.update(
      table,
      {
        'sync_status': status,
        'last_sync_attempt_at': DateTime.now().toIso8601String(),
        'last_error': error,
      },
      where: 'device_uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> updateDoctorDetails({
    required int srlNo,
    required String timings,
    required String fee,
    required String days,
    required String hospital,
    required String imageUrl,
  }) async {
    final db = await database;
    return await db.update(
      'master_doctors',
      {
        'doctor_timings': timings,
        'consultation_fee': fee,
        'follow_up_fee': ((double.tryParse(fee) ?? 0) * 0.7).floor().toString(),
        'available_days': days,
        'hospital_name': hospital,
        'image_url': imageUrl,
      },
      where: 'srl_no = ?',
      whereArgs: [srlNo],
    );
  }

  Future<void> clearTable(String table) async {
    Database db = await database;
    await db.delete(table);
  }
}
