import 'dart:convert';

import 'package:flutter/cupertino.dart';

// ─── GP Prescription Models ──────────────────────────────────────────────────

class PrescriptionMedicine {
  final int? sr;
  final String medicineName;
  final int? medicineId;
  final bool isFormula;
  final String dosage;
  final double morning;
  final double afternoon;
  final double evening;
  final double night;
  final String forDays;
  final String qty;

  PrescriptionMedicine({
    this.sr,
    required this.medicineName,
    this.medicineId,
    this.isFormula = false,
    this.dosage = '',
    this.morning = 0,
    this.afternoon = 0,
    this.evening = 0,
    this.night = 0,
    this.forDays = '',
    this.qty = '',
  });

  Map<String, dynamic> toJson() => {
    'sr': sr,
    'medicine_name': medicineName,
    'medicine_id': medicineId,
    'is_formula': isFormula,
    'dosage': dosage,
    'morning': morning,
    'afternoon': afternoon,
    'evening': evening,
    'night': night,
    'for_days': forDays,
    'qty': qty,
  };

  factory PrescriptionMedicine.fromJson(Map<String, dynamic> json) => PrescriptionMedicine(
    sr: json['sr'],
    medicineName: json['medicine_name'] ?? '',
    medicineId: json['medicine_id'],
    isFormula: json['is_formula'] ?? false,
    dosage: json['dosage'] ?? '',
    morning: (json['morning'] ?? 0).toDouble(),
    afternoon: (json['afternoon'] ?? 0).toDouble(),
    evening: (json['evening'] ?? 0).toDouble(),
    night: (json['night'] ?? 0).toDouble(),
    forDays: json['for_days']?.toString() ?? '',
    qty: json['qty']?.toString() ?? '',
  );
}

class PrescriptionInvestigation {
  final String investigationType;
  final String testName;

  PrescriptionInvestigation({
    required this.investigationType,
    required this.testName,
  });

  Map<String, dynamic> toJson() => {
    'investigation_type': investigationType,
    'test_name': testName,
  };

  factory PrescriptionInvestigation.fromJson(Map<String, dynamic> json) => PrescriptionInvestigation(
    investigationType: json['investigation_type'] ?? '',
    testName: json['test_name'] ?? '',
  );
}

class PrescriptionDiagnosis {
  final int questionId;
  final String questionText;
  final String? answerText;
  final String? answerDisplay;
  final List<int>? answerOptions;

  PrescriptionDiagnosis({
    required this.questionId,
    required this.questionText,
    this.answerText,
    this.answerDisplay,
    this.answerOptions,
  });

  Map<String, dynamic> toJson() => {
    'question_id': questionId,
    'question_text': questionText,
    'answer_text': answerText,
    'answer_display': answerDisplay,
    'answer_options': answerOptions,
  };

  factory PrescriptionDiagnosis.fromJson(Map<String, dynamic> json) {
    dynamic optionsRaw = json['answer_options'] ?? json['answer_value'];
    List<int>? options;
    if (optionsRaw != null) {
      if (optionsRaw is List) {
        options = optionsRaw.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
      } else if (optionsRaw is String && optionsRaw.startsWith('[')) {
        try {
          final decoded = jsonDecode(optionsRaw);
          if (decoded is List) {
            options = decoded.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
          }
        } catch (_) {}
      }
    }

    return PrescriptionDiagnosis(
      questionId: json['question_id'] ?? 0,
      questionText: json['question_text'] ?? '',
      answerText: json['answer_text']?.toString(),
      answerDisplay: json['answer_display']?.toString(),
      answerOptions: options,
    );
  }
}

// ─── Eye Prescription Models ─────────────────────────────────────────────────

class RefractionMatrix {
  String sph;
  String cyl;
  String axis;
  String va;
  String addition;

  RefractionMatrix({
    this.sph = '',
    this.cyl = '',
    this.axis = '',
    this.va = '',
    this.addition = '',
  });

  Map<String, dynamic> toJson() => {
    'sph': sph,
    'cyl': cyl,
    'axis': axis,
    'va': va,
    'addition': addition,
  };

  factory RefractionMatrix.fromJson(Map<String, dynamic> json) => RefractionMatrix(
    sph: (json['sph'] ?? '').toString(),
    cyl: (json['cyl'] ?? '').toString(),
    axis: (json['axis'] ?? '').toString(),
    va: (json['va'] ?? '').toString(),
    addition: (json['addition'] ?? '').toString(),
  );
}

class VisionStats {
  String varValue;
  String ph;
  String ref;

  VisionStats({
    this.varValue = '',
    this.ph = '',
    this.ref = '',
  });

  Map<String, dynamic> toJson() => {
    'var': varValue,
    'ph': ph,
    'ref': ref,
  };

  factory VisionStats.fromJson(Map<String, dynamic> json) => VisionStats(
    varValue: (json['var'] ?? '').toString(),
    ph: (json['ph'] ?? '').toString(),
    ref: (json['ref'] ?? '').toString(),
  );
}

class EyeSideItem {
  final String name;
  final String side; // L, R, B

  EyeSideItem({required this.name, required this.side});

  Map<String, dynamic> toJson() => {'name': name, 'side': side};

  factory EyeSideItem.fromJson(Map<String, dynamic> json) => EyeSideItem(
    name: (json['name'] ?? '').toString(),
    side: (json['side'] ?? 'B').toString(),
  );
}

class EyePrescriptionDetails {
  Map<String, bool> history;
  String otherHistory;
  
  // Refraction
  RefractionMatrix rightRefraction;
  RefractionMatrix leftRefraction;
  RefractionMatrix add01Refraction;
  RefractionMatrix add02Refraction;

  // Vision
  VisionStats rightVision;
  VisionStats leftVision;

  // Examination
  String presentingComplaints;
  List<EyeSideItem> complaints;
  List<EyeSideItem> examinations;

  // Management
  List<EyeSideItem> diagnosis;
  List<EyeSideItem> advised;
  String treatmentType;
  String remarks;
  String? operationDate;
  String? surgeryName;

  EyePrescriptionDetails({
    required this.history,
    this.otherHistory = '',
    required this.rightRefraction,
    required this.leftRefraction,
    required this.add01Refraction,
    required this.add02Refraction,
    required this.rightVision,
    required this.leftVision,
    this.presentingComplaints = '',
    required this.complaints,
    required this.examinations,
    required this.diagnosis,
    required this.advised,
    this.treatmentType = '',
    this.remarks = '',
    this.operationDate,
    this.surgeryName,
  });

  Map<String, dynamic> toJson() => {
    'optometrist': {
      'history': history,
      'otherHistory': otherHistory,
      'refraction': {
        'right': rightRefraction.toJson(),
        'left': leftRefraction.toJson(),
        'add01': add01Refraction.toJson(),
        'add02': add02Refraction.toJson(),
      },
      'vision': {
        'right': rightVision.toJson(),
        'left': leftVision.toJson(),
      },
    },
    'examination': {
      'presentingComplaints': presentingComplaints,
      'complaints': complaints.map((e) => e.toJson()).toList(),
      'examinations': examinations.map((e) => e.toJson()).toList(),
    },
    'management': {
      'diagnosis': diagnosis.map((e) => e.toJson()).toList(),
      'advised': advised.map((e) => e.toJson()).toList(),
      'treatmentType': treatmentType,
      'remarks': remarks,
      'operationDate': operationDate,
      'surgeryName': surgeryName,
    },
  };

  factory EyePrescriptionDetails.fromJson(Map<String, dynamic> json) {
    final opto = json['optometrist'] as Map<String, dynamic>? ?? {};
    final exam = json['examination'] as Map<String, dynamic>? ?? {};
    final mang = json['management'] as Map<String, dynamic>? ?? {};
    final refr = opto['refraction'] as Map<String, dynamic>? ?? {};
    final visi = opto['vision'] as Map<String, dynamic>? ?? {};

    return EyePrescriptionDetails(
      history: Map<String, bool>.from(opto['history'] ?? {}),
      otherHistory: opto['otherHistory'] ?? '',
      rightRefraction: RefractionMatrix.fromJson(refr['right'] ?? {}),
      leftRefraction: RefractionMatrix.fromJson(refr['left'] ?? {}),
      add01Refraction: RefractionMatrix.fromJson(refr['add01'] ?? refr['add'] ?? refr['ADD'] ?? {}),
      add02Refraction: RefractionMatrix.fromJson(refr['add02'] ?? {}),
      rightVision: VisionStats.fromJson(visi['right'] ?? {}),
      leftVision: VisionStats.fromJson(visi['left'] ?? {}),
      presentingComplaints: exam['presentingComplaints'] ?? '',
      complaints: (exam['complaints'] as List? ?? []).map((e) => EyeSideItem.fromJson(e)).toList(),
      examinations: (exam['examinations'] as List? ?? []).map((e) => EyeSideItem.fromJson(e)).toList(),
      diagnosis: (mang['diagnosis'] as List? ?? []).map((e) => EyeSideItem.fromJson(e)).toList(),
      advised: (mang['advised'] as List? ?? []).map((e) => EyeSideItem.fromJson(e)).toList(),
      treatmentType: mang['treatmentType'] ?? '',
      remarks: mang['remarks'] ?? '',
      operationDate: mang['operationDate'],
      surgeryName: mang['surgeryName'],
    );
  }
}

// ─── Main Prescription Model ─────────────────────────────────────────────────

class PrescriptionModel {
  final int? id;
  final String mrNumber;
  final String doctorName;
  final int? doctorSrlNo;
  final String? receiptId;
  final String? createdAt;
  
  // Vitals
  final Map<String, String> vitals;

  // Notes
  final String? historyExamination;
  final String? treatment;
  final String? consultantNotes;
  final String? remarks;
  final String? referTo;

  // Lists
  final List<PrescriptionMedicine> medicines;
  final List<PrescriptionInvestigation> investigations;
  final List<String> instructions;
  final List<PrescriptionDiagnosis> diagnosis;

  // Eye specifics
  final EyePrescriptionDetails? eyeDetails;

  PrescriptionModel({
    this.id,
    required this.mrNumber,
    required this.doctorName,
    this.doctorSrlNo,
    this.receiptId,
    this.createdAt,
    required this.vitals,
    this.historyExamination,
    this.treatment,
    this.consultantNotes,
    this.remarks,
    this.referTo,
    required this.medicines,
    required this.investigations,
    required this.instructions,
    required this.diagnosis,
    this.eyeDetails,
  });

  Map<String, dynamic> toJson() => {
    'prescription_id': id,
    'mr_number': mrNumber,
    'doctor_name': doctorName,
    'doctor_srl_no': doctorSrlNo,
    'receipt_id': receiptId,
    'created_at': createdAt,
    'vitals': vitals,
    'history_examination': historyExamination,
    'treatment': treatment,
    'consultant_notes': consultantNotes,
    'remarks': remarks,
    'refer_to': referTo,
    'medicines': medicines.map((e) => e.toJson()).toList(),
    'investigations': investigations.map((e) => e.toJson()).toList(),
    'instructions': instructions,
    'diagnosis_answers': diagnosis.map((e) => e.toJson()).toList(),
    'eye_details': eyeDetails?.toJson(),
  };

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    dynamic rawEye = json['eye_details'];
    EyePrescriptionDetails? eye;
    if (rawEye != null) {
      if (rawEye is String) {
        try {
          eye = EyePrescriptionDetails.fromJson(jsonDecode(rawEye));
        } catch (e) {
          debugPrint('Error decoding eye_details string: $e');
        }
      } else if (rawEye is Map<String, dynamic>) {
        eye = EyePrescriptionDetails.fromJson(rawEye);
      }
    }

    return PrescriptionModel(
      id: json['id'] ?? json['prescription_id'],
      mrNumber: json['mr_number'] ?? '',
      doctorName: json['doctor_name'] ?? '',
      doctorSrlNo: json['doctor_srl_no'],
      receiptId: json['receipt_id'],
      createdAt: json['created_at'],
      vitals: Map<String, String>.from(json['vitals'] ?? {}),
      historyExamination: json['history_examination'],
      treatment: json['treatment'],
      consultantNotes: json['consultant_notes'],
      remarks: json['remarks'],
      referTo: json['refer_to'],
      medicines: (json['medicines'] as List? ?? []).map((e) => PrescriptionMedicine.fromJson(e)).toList(),
      investigations: (json['investigations'] as List? ?? []).map((e) => PrescriptionInvestigation.fromJson(e)).toList(),
      instructions: List<String>.from(json['instructions'] ?? []),
      diagnosis: (json['diagnosis_answers'] as List? ?? []).map((e) => PrescriptionDiagnosis.fromJson(e)).toList(),
      eyeDetails: eye,
    );
  }
}
