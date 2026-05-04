class VitalsModel {
  final int? id;
  final String mrNumber;
  final String? receiptId;
  final double? weight;
  final double? height;
  final double? bsr;
  final double? bmi;
  final double? bmr;
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final double? spo2;
  final double? temperature;
  final double? waist;
  final double? hip;
  final double? whr;
  final String? heightUnit;
  final String? bpReadingType;
  final DateTime? createdAt;
  final int? painScale;

  VitalsModel({
    this.id,
    required this.mrNumber,
    this.receiptId,
    this.weight,
    this.height,
    this.heightUnit = 'in',
    this.bsr,
    this.bmi,
    this.bmr,
    this.systolic,
    this.diastolic,
    this.bpReadingType = 'regular',
    this.pulse,
    this.spo2,
    this.temperature,
    this.waist,
    this.hip,
    this.whr,
    this.painScale = 0,
    this.createdAt,
  });

  factory VitalsModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    return VitalsModel(
      id: json['id'],
      mrNumber: json['mr_number']?.toString() ?? '',
      receiptId: json['receipt_id']?.toString(),
      weight: parseDouble(json['weight']),
      height: parseDouble(json['height']),
      heightUnit: json['height_unit']?.toString() ?? 'in',
      bsr: parseDouble(json['bsr']),
      bmi: parseDouble(json['bmi']),
      bmr: parseDouble(json['bmr']),
      systolic: parseInt(json['systolic']),
      diastolic: parseInt(json['diastolic']),
      bpReadingType: json['bp_reading_type']?.toString() ?? 'regular',
      pulse: parseInt(json['pulse']),
      spo2: parseDouble(json['spo2']),
      temperature: parseDouble(json['temperature']),
      waist: parseDouble(json['waist']),
      hip: parseDouble(json['hip']),
      whr: parseDouble(json['whr']),
      painScale: parseInt(json['pain_scale']) ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mr_number': mrNumber,
      'receipt_id': receiptId,
      'weight': weight,
      'height': height,
      'height_unit': heightUnit,
      'bsr': bsr,
      'bmi': bmi,
      'bmr': bmr,
      'systolic': systolic,
      'diastolic': diastolic,
      'bp_reading_type': bpReadingType,
      'pulse': pulse,
      'spo2': spo2,
      'temperature': temperature,
      'waist': waist,
      'hip': hip,
      'whr': whr,
      'pain_scale': painScale,
    };
  }
}
