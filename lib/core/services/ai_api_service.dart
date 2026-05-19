import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../global/global_api.dart';
import 'auth_storage_service.dart';

class AiApiService {
  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> summarizePatientHistory(List<dynamic> records, String patientName) async {
    try {
      final headers = await _headers();
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/ai/summarize-history'),
        headers: headers,
        body: jsonEncode({
          'records': records,
          'patientName': patientName,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
