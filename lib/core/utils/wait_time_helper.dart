import 'package:flutter/material.dart';

class WaitTimeHelper {
  static String? getWaitTime(dynamic dateStr, dynamic timeStr) {
    if (timeStr == null || timeStr.toString().isEmpty) return null;
    
    try {
      final now = DateTime.now();
      final timeParts = timeStr.toString().split(':').map((e) => int.parse(e)).toList();
      
      DateTime receiptDate;
      if (dateStr != null && dateStr.toString().isNotEmpty) {
        receiptDate = DateTime.parse(dateStr.toString());
      } else {
        receiptDate = DateTime.now();
      }
      
      receiptDate = DateTime(
        receiptDate.year,
        receiptDate.month,
        receiptDate.day,
        timeParts.length > 0 ? timeParts[0] : 0,
        timeParts.length > 1 ? timeParts[1] : 0,
        timeParts.length > 2 ? timeParts[2] : 0,
      );
      
      final diff = now.difference(receiptDate);
      if (diff.isNegative) return '0m';
      
      final diffMins = diff.inMinutes;
      final h = diffMins ~/ 60;
      final m = diffMins % 60;
      
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    } catch (e) {
      return null;
    }
  }
}
