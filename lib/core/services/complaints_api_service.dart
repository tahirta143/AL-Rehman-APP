import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import '../../global/global_api.dart';
import 'auth_storage_service.dart';

class ComplaintsApiService {
  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getGraph({String mode = 'tree'}) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/complaints/graph?mode=$mode'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> syncSidebar() async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/complaints/sync-sidebar'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getNodeComplaints(String nodeKey, {String? status, String? priority}) async {
    try {
      final headers = await _authHeaders();
      final queryParams = <String, String>{};
      if (status != null && status != 'all') queryParams['status'] = status;
      if (priority != null && priority != 'all') queryParams['priority'] = priority;
      
      final uri = Uri.parse('${GlobalApi.baseUrl}/complaints/nodes/${Uri.encodeComponent(nodeKey)}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getComplaint(String id) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/complaints/$id'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createComplaint(Map<String, dynamic> payload) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/complaints'),
        headers: headers,
        body: jsonEncode(payload),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse('${GlobalApi.baseUrl}/complaints/$id/status'),
        headers: headers,
        body: jsonEncode({'status': status}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createComment(String id, String body) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/complaints/$id/comments'),
        headers: headers,
        body: jsonEncode({'body': body}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadAttachments(String id, List<PlatformFile> files, {Map<String, dynamic>? annotationJson}) async {
    try {
      final token = await _storage.getToken();
      final uri = Uri.parse('${GlobalApi.baseUrl}/complaints/$id/attachments');
      final request = http.MultipartRequest('POST', uri);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      for (var file in files) {
        if (file.bytes != null) {
          final multipartFile = http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
          );
          request.files.add(multipartFile);
        } else if (file.path != null) {
          final multipartFile = await http.MultipartFile.fromPath(
            'files',
            file.path!,
            filename: file.name,
          );
          request.files.add(multipartFile);
        }
      }

      if (annotationJson != null) {
        request.fields['annotationJson'] = jsonEncode(annotationJson);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveNodePositions(Map<String, dynamic> payload) async {
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse('${GlobalApi.baseUrl}/complaints/node-positions'),
        headers: headers,
        body: jsonEncode(payload),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
