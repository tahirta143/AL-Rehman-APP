import 'package:flutter/material.dart';

class DoctorModel {
  final int srlNo;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialization;
  final String doctorDepartment;
  final String doctorQualification;
  final String doctorPhone;
  final String doctorMobile;
  final String doctorEmail;
  final String doctorAddress;
  final String? imageUrl;
  final int isSurgeon;
  final int isAnesthetist;
  final int activeForOpd;
  final int activeForIndoor;
  final String doctorShare;
  final String consultationFee;
  final int isActive;
  final String createdAt;
  final String updatedAt;
  final String availableDays;
  final String consultationTimings;
  final String consultationTimeFrom;
  final String consultationTimeTo;
  final String hospitalName;

  DoctorModel({
    required this.srlNo,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialization,
    required this.doctorDepartment,
    required this.doctorQualification,
    required this.doctorPhone,
    required this.doctorMobile,
    required this.doctorEmail,
    required this.doctorAddress,
    this.imageUrl,
    required this.isSurgeon,
    required this.isAnesthetist,
    required this.activeForOpd,
    required this.activeForIndoor,
    required this.doctorShare,
    required this.consultationFee,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.availableDays,
    required this.consultationTimings,
    required this.consultationTimeFrom,
    required this.consultationTimeTo,
    required this.hospitalName,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      srlNo: json['srl_no'] ?? 0,
      doctorId: json['doctor_id'] ?? '',
      doctorName: json['doctor_name'] ?? '',
      doctorSpecialization: json['doctor_specialization'] ?? '',
      doctorDepartment: json['doctor_department'] ?? '',
      doctorQualification: json['doctor_qualification'] ?? '',
      doctorPhone: json['doctor_phone'] ?? '',
      doctorMobile: json['doctor_mobile'] ?? '',
      doctorEmail: json['doctor_email'] ?? '',
      doctorAddress: json['doctor_address'] ?? '',
      imageUrl: json['image_url'],
      isSurgeon: json['is_surgeon'] ?? 0,
      isAnesthetist: json['is_anesthetist'] ?? 0,
      activeForOpd: json['active_for_opd'] ?? 0,
      activeForIndoor: json['active_for_indoor'] ?? 0,
      doctorShare: json['doctor_share']?.toString() ?? '0',
      consultationFee: json['consultation_fee']?.toString() ?? '0',
      isActive: json['is_active'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      availableDays: json['available_days'] is List 
          ? (json['available_days'] as List).join(',') 
          : (json['available_days']?.toString() ?? ''),
      consultationTimings: json['consultation_timings']?.toString() ?? '',
      consultationTimeFrom: json['consultation_time_from']?.toString() ?? '',
      consultationTimeTo: json['consultation_time_to']?.toString() ?? '',
      hospitalName: json['hospital_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'srl_no': srlNo,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'doctor_specialization': doctorSpecialization,
      'doctor_department': doctorDepartment,
      'doctor_qualification': doctorQualification,
      'doctor_phone': doctorPhone,
      'doctor_mobile': doctorMobile,
      'doctor_email': doctorEmail,
      'doctor_address': doctorAddress,
      'image_url': imageUrl,
      'is_surgeon': isSurgeon,
      'is_anesthetist': isAnesthetist,
      'active_for_opd': activeForOpd,
      'active_for_indoor': activeForIndoor,
      'doctor_share': doctorShare,
      'consultation_fee': consultationFee,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'available_days': availableDays,
      'consultation_timings': consultationTimings,
      'consultation_time_from': consultationTimeFrom,
      'consultation_time_to': consultationTimeTo,
      'hospital_name': hospitalName,
    };
  }

  // Convert to DoctorInfo for UI compatibility
  DoctorInfo toDoctorInfo({int totalAppointments = 0, String? customFee, String? customFollowUp}) {
    // Parse available days from comma-separated string
    final daysList = availableDays
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    // Generate avatar color based on doctor ID
    final color = _generateColorFromId(srlNo);

    return DoctorInfo(
      id: srlNo.toString(),
      name: 'Dr. $doctorName',
      specialty: doctorSpecialization,
      consultationFee: customFee ?? _formatFee(consultationFee),
      followUpCharges: customFollowUp ?? _calculateFollowUp(consultationFee),
      availableDays: _convertDaysToShort(daysList),
      timings: consultationTimings,
      hospital: hospitalName,
      imageAsset: imageUrl ?? '',
      avatarColor: color,
      department: doctorDepartment,
      totalAppointments: totalAppointments,
    );
  }

  // Helper: format fee (remove decimals if .00)
  String _formatFee(String fee) {
    final parsed = double.tryParse(fee) ?? 0.0;
    if (parsed == parsed.toInt()) {
      return parsed.toInt().toString();
    }
    return parsed.toStringAsFixed(0);
  }

  // Helper: calculate follow-up (70% of consultation fee)
  String _calculateFollowUp(String fee) {
    final parsed = double.tryParse(fee) ?? 0.0;
    final followUp = (parsed * 0.7).toInt();
    return followUp.toString();
  }

  // Helper: convert full day names to short (Mon, Tue, etc.)
  List<String> _convertDaysToShort(List<String> days) {
    const dayMap = {
      'Monday': 'Mon',
      'Tuesday': 'Tue',
      'Wednesday': 'Wed',
      'Thursday': 'Thu',
      'Friday': 'Fri',
      'Saturday': 'Sat',
      'Sunday': 'Sun',
    };

    return days.map((day) => dayMap[day] ?? day.substring(0, 3)).toList();
  }

  // Helper: generate color from ID
  Color _generateColorFromId(int id) {
    const colors = [
      Color(0xFF00B5AD),
      Color(0xFF8E24AA),
      Color(0xFF1E88E5),
      Color(0xFFE53935),
      Color(0xFF43A047),
      Color(0xFFF4511E),
      Color(0xFF00897B),
      Color(0xFFD81B60),
    ];
    return colors[id % colors.length];
  }
}

// DoctorInfo class for UI (existing structure)
class DoctorInfo {
  final String id;
  final String name;
  final String specialty;
  final String consultationFee;
  final String followUpCharges;
  final List<String> availableDays;
  final String timings;
  final String hospital;
  final String imageAsset;
  final Color avatarColor;
  final String department;
  final int totalAppointments;

  const DoctorInfo({
    required this.id,
    required this.name,
    required this.specialty,
    required this.consultationFee,
    required this.followUpCharges,
    required this.availableDays,
    required this.timings,
    required this.hospital,
    required this.imageAsset,
    required this.avatarColor,
    required this.department,
    required this.totalAppointments,
  });
}