import 'package:flutter/material.dart';

class VisitHistoryModel {
  final String? date;
  final String? time;
  final String? opdService;
  final String? serviceDetail;
  final String? receiptId;
  final dynamic totalAmount;
  final dynamic paid;

  VisitHistoryModel({
    this.date,
    this.time,
    this.opdService,
    this.serviceDetail,
    this.receiptId,
    this.totalAmount,
    this.paid,
  });

  factory VisitHistoryModel.fromJson(Map<String, dynamic> json) {
    return VisitHistoryModel(
      date: json['date']?.toString(),
      time: json['time']?.toString(),
      opdService: json['opd_service']?.toString() ?? json['service_name']?.toString() ?? json['service']?.toString(),
      serviceDetail: json['service_detail']?.toString(),
      receiptId: json['receipt_id']?.toString() ?? json['id']?.toString(),
      totalAmount: json['total_amount'],
      paid: json['paid'],
    );
  }
}

class MrPatientApiModel {
  final int id;
  final String mrNumber;
  final String firstName;
  final String lastName;
  final String? guardianName;
  final String guardianRelation;
  final String? cnic;
  final String? dob;
  final int? age;
  final String gender;
  final String phone;
  final String? email;
  final String? profession;
  final String? education;
  final String? whatsappNo;
  final String? address;
  final String? city;
  final String? bloodGroup;
  final int status;
  final String createdAt;
  final String updatedAt;
  final String? appointmentDate;
  final String patientName;
  final String phoneNumber;
  final String? fatherHusbandName;
  final List<VisitHistoryModel>? history;

  MrPatientApiModel({
    required this.id,
    required this.mrNumber,
    required this.firstName,
    required this.lastName,
    this.guardianName,
    required this.guardianRelation,
    this.cnic,
    this.dob,
    this.age,
    required this.gender,
    required this.phone,
    this.email,
    this.profession,
    this.education,
    this.whatsappNo,
    this.address,
    this.city,
    this.bloodGroup,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.appointmentDate,
    required this.patientName,
    required this.phoneNumber,
    this.fatherHusbandName,
    this.history,
  });

  factory MrPatientApiModel.fromJson(Map<String, dynamic> json) {
    return MrPatientApiModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      mrNumber: (json['mr_number'] as String?) ?? '',
      firstName: (json['first_name'] as String?) ?? (json['patient_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      guardianName: json['guardian_name'] as String?,
      guardianRelation: (json['guardian_relation'] as String?) ?? 'Parent',
      cnic: json['cnic'] as String?,
      dob: json['dob'] as String?,
      age: json['age'] is int ? json['age'] : (int.tryParse(json['age']?.toString() ?? '')),
      gender: (json['gender'] as String?) ?? 'Male',
      phone: (json['phone'] as String?) ?? (json['phone_number'] as String?) ?? '',
      email: json['email'] as String?,
      profession: json['profession'] as String?,
      education: json['education'] as String?,
      whatsappNo: (json['whatsapp_no'] as String?) ?? (json['whatsapp'] as String?) ?? (json['phone'] as String?),
      address: json['address'] as String?,
      city: json['city'] as String?,
      bloodGroup: json['blood_group'] as String?,
      status: (json['status'] as int?) ?? 1,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
      appointmentDate: json['appointment_date'] as String?,
      patientName: (json['patient_name'] as String?) ?? (json['first_name'] as String?) ?? '',
      phoneNumber: (json['phone_number'] as String?) ?? (json['phone'] as String?) ?? '',
      fatherHusbandName: json['father_husband_name'] as String?,
      history: json['history'] != null
          ? (json['history'] as List)
              .map((i) => VisitHistoryModel.fromJson(i as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mr_number': mrNumber,
      'first_name': firstName,
      'last_name': lastName,
      'guardian_name': guardianName,
      'guardian_relation': guardianRelation,
      'cnic': cnic,
      'dob': dob,
      'age': age,
      'gender': gender,
      'phone': phone,
      'email': email,
      'profession': profession,
      'education': education,
      'whatsapp_no': whatsappNo,
      'address': address,
      'city': city,
      'blood_group': bloodGroup,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'appointment_date': appointmentDate,
      'patient_name': patientName,
      'phone_number': phoneNumber,
      'father_husband_name': fatherHusbandName,
    };
  }

  // Convert to PatientModel for UI compatibility
  PatientModel toPatientModel() {
    // Parse date of birth if available
    DateTime? parsedDob;
    if (dob != null && dob!.isNotEmpty) {
      try {
        parsedDob = DateTime.parse(dob!);
      } catch (_) {
        // If parsing fails, leave as null
      }
    }

    // Parse registration date
    DateTime registeredAt;
    try {
      registeredAt = DateTime.parse(createdAt);
    } catch (_) {
      registeredAt = DateTime.now();
    }

    int totalVisitsCount = history?.length ?? 0;
    int visitsTodayCount = 0;
    
    if (history != null) {
      final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      for (var v in history!) {
        if (v.date != null && v.date!.startsWith(todayStr)) {
          visitsTodayCount++;
        }
      }
    }

    return PatientModel(
      mrNumber: mrNumber,
      firstName: firstName,
      lastName: lastName,
      guardianName: guardianName ?? fatherHusbandName ?? '',
      relation: guardianRelation,
      gender: gender,
      dateOfBirth: dob ?? '',
      age: age,
      bloodGroup: bloodGroup ?? '',
      profession: profession ?? '',
      education: education ?? '',
      whatsappNo: whatsappNo ?? phone,
      phoneNumber: phone,
      email: email ?? '',
      cnic: cnic ?? '',
      address: address ?? '',
      city: city ?? '',
      registeredAt: registeredAt,
      totalVisits: totalVisitsCount,
      visitsToday: visitsTodayCount,
      visitHistory: history,
    );
  }
}

// PatientModel class for UI (existing structure)
class PatientModel {
  final String mrNumber;
  final String firstName;
  final String lastName;
  final String guardianName;
  final String relation;
  final String gender;
  final String dateOfBirth;
  final int? age;
  final String bloodGroup;
  final String profession;
  final String education;
  final String whatsappNo;
  final String phoneNumber;
  final String email;
  final String cnic;
  final String address;
  final String city;
  final DateTime registeredAt;
  int totalVisits;
  int visitsToday;
  final List<VisitHistoryModel>? visitHistory;
  final String? syncStatus;
  final String? deviceUuid;

  PatientModel({
    required this.mrNumber,
    required this.firstName,
    required this.lastName,
    this.guardianName = '',
    this.relation = 'Parent',
    required this.gender,
    this.dateOfBirth = '',
    this.age,
    this.bloodGroup = '',
    this.profession = '',
    this.education = '',
    this.whatsappNo = '',
    this.phoneNumber = '',
    this.email = '',
    this.cnic = '',
    this.address = '',
    this.city = '',
    required this.registeredAt,
    this.syncStatus,
    this.deviceUuid,
    this.totalVisits = 0,
    this.visitsToday = 0,
    this.visitHistory,
  });

  factory PatientModel.fromLocalMap(Map<String, dynamic> v) {
    return PatientModel(
      mrNumber: v['mr_number'] ?? 'PENDING',
      deviceUuid: v['device_uuid'],
      firstName: v['first_name'] ?? '',
      lastName: v['last_name'] ?? '',
      guardianName: v['guardian_name'] ?? '',
      relation: v['guardian_relation'] ?? 'Parent',
      gender: v['gender'] ?? 'Male',
      phoneNumber: v['phone'] ?? '',
      age: v['age'] is int ? v['age'] : int.tryParse(v['age']?.toString() ?? ''),
      address: v['address'] ?? '',
      city: v['city'] ?? '',
      registeredAt: DateTime.tryParse(v['created_at']?.toString() ?? '') ?? DateTime.now(),
      syncStatus: v['sync_status'],
      totalVisits: 0,
      visitsToday: 0,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  // Convert to API request format for create/update
  Map<String, dynamic> toApiRequest() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'guardian_name': guardianName.isEmpty ? null : guardianName,
      'guardian_relation': relation,
      'cnic': cnic.isEmpty ? null : cnic,
      'dob': dateOfBirth.isEmpty ? null : _convertDateToApiFormat(dateOfBirth),
      'age': age,
      'gender': gender,
      'phone': phoneNumber,
      'whatsapp_no': whatsappNo.isEmpty ? null : whatsappNo,
      'email': email.isEmpty ? null : email,
      'profession': profession.isEmpty ? null : profession,
      'education': education.isEmpty ? null : education,
      'address': address.isEmpty ? null : address,
      'city': city.isEmpty ? null : city,
      'blood_group': bloodGroup.isEmpty ? null : bloodGroup,
      'status': 1,
    };
  }

  // Helper: convert date from DD/MM/YYYY to YYYY-MM-DD
  String? _convertDateToApiFormat(String date) {
    if (date.isEmpty) return null;
    try {
      final parts = date.split('/');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        return '$year-$month-$day';
      }
    } catch (_) {}
    return null;
  }
}
