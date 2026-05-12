import 'package:flutter/cupertino.dart';

class OpdReceiptApiModel {
  final int srlNo;
  final String receiptId;
  final String patientMrNumber;
  final String patientName;
  final String phoneNumber;
  final int? patientAge;
  final String patientGender;
  final String? patientAddress;
  final String date;
  final String time;
  final String opdService;
  final String serviceDetail;
  final double totalAmount;
  final double discount;
  final double paid;
  final double? payable; // Make optional
  final String status;
  final bool? opdCancelled; // Make optional
  final bool? paidToDoctor; // Make optional
  final Map<String, dynamic>? tokens;

  OpdReceiptApiModel({
    required this.srlNo,
    required this.receiptId,
    required this.patientMrNumber,
    required this.patientName,
    required this.phoneNumber,
    required this.patientAge,
    required this.patientGender,
    required this.patientAddress,
    required this.date,
    required this.time,
    required this.opdService,
    required this.serviceDetail,
    required this.totalAmount,
    required this.discount,
    required this.paid,
    this.payable, // Now optional
    required this.status,
    this.opdCancelled, // Now optional
    this.paidToDoctor, // Now optional
    this.tokens,
  });

  factory OpdReceiptApiModel.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) =>
        double.tryParse(v?.toString() ?? '0') ?? 0.0;

    bool _toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v == 1;
      if (v is String) return v.toLowerCase() == 'true' || v == '1';
      return false;
    }

    debugPrint('📦 Parsing receipt JSON: $json');
    debugPrint('📦 Available keys: ${json.keys.toList()}');

    // CRITICAL: Get srl_no from API
    int srlNo = 0;
    if (json['srl_no'] != null) {
      srlNo = json['srl_no'] is int
          ? json['srl_no'] as int
          : int.tryParse(json['srl_no'].toString()) ?? 0;
      debugPrint('✅ Found srl_no: $srlNo');
    } else {
      debugPrint('❌ ERROR: No srl_no found in receipt!');
    }

    return OpdReceiptApiModel(
      srlNo: srlNo,
      receiptId: json['receipt_id'] as String? ??
          json['receipt_no'] as String? ?? '',
      patientMrNumber: json['patient_mr_number'] as String? ??
          json['mr_number'] as String? ??
          json['mr_no'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ??
          json['phone'] as String? ??
          '',
      patientAge: json['patient_age'] != null
          ? (json['patient_age'] is int
          ? json['patient_age'] as int
          : int.tryParse(json['patient_age'].toString()))
          : null,
      patientGender: json['patient_gender'] as String? ??
          json['gender'] as String? ??
          '',
      patientAddress: json['patient_address'] as String? ??
          json['address'] as String?,
      date: json['date'] as String? ?? json['shift_date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      opdService: json['opd_service'] as String? ?? '',
      serviceDetail: json['service_detail'] as String? ?? '',
      totalAmount: _toDouble(json['total_amount']),
      discount: _toDouble(json['discount']),
      paid: _toDouble(json['paid']),
      payable: _toDouble(json['payable']), // This will default to 0.0 if not present
      status: json['status'] as String? ?? 'Active',
      opdCancelled: _toBool(json['opd_cancelled']),
      paidToDoctor: _toBool(json['paid_to_doctor']),
      tokens: json['tokens'] as Map<String, dynamic>?,
    );
  }
}