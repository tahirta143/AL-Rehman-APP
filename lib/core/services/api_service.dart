import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:hims_app/global/global_api.dart';
import 'package:http/http.dart' as http;
import 'auth_storage_service.dart';

/// All API responses from the backend.
class LoginResult {
  final bool success;
  final String? token;
  final String? userId;
  final String? username;
  final String? fullName;
  final String? role;
  final String? message;

  LoginResult({
    required this.success,
    this.token,
    this.userId,
    this.username,
    this.fullName,
    this.role,
    this.message,
  });
}

class PermissionsResult {
  final bool success;
  final List<String> permissions;
  final int? permissionsVersion;
  final String? message;

  PermissionsResult({
    required this.success,
    this.permissions = const [],
    this.permissionsVersion,
    this.message,
  });
}

/// Central HTTP service using the `http` package.
/// Automatically attaches Bearer tokens to protected requests.
class ApiService {
  // TODO: Change this to your actual backend URL
  // static const String baseUrl = 'https://api.afaqhims.com/api';

  final AuthStorageService _storage = AuthStorageService();

  // ─── Helper: build auth headers ───────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── POST /api/auth/login ──────────────────────────────────────────
  Future<LoginResult> login(String username, String password) async {
    try {
      final response = await http
          .post(
        Uri.parse('${GlobalApi.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('🔑 Login Response Keys: ${data.keys.toList()}');
      if (data['success'] == true) {
        debugPrint('🔑 Full Login Data: $data');
      }

      if (response.statusCode == 200 && data['success'] == true) {
        return LoginResult(
          success:  true,
          token:    data['token'] as String?,
          userId:   data['_id']?.toString(),
          username: data['username'] as String?,
          fullName: data['full_name'] as String?,
          role:     data['role'] as String?,
        );
      }

      return LoginResult(
        success: false,
        message: data['message'] as String? ?? 'Login failed',
      );
    } catch (e) {
      return LoginResult(
        success: false,
        message: 'Could not connect to server. Please check your connection.',
      );
    }
  }

  // ─── GET /api/auth/permissions ───────────────────────────────────
  Future<PermissionsResult> fetchPermissions() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('${GlobalApi.baseUrl}/auth/permissions'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return PermissionsResult(
          success: false,
          message: 'Session expired. Please log in again.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final inner = data['data'] as Map<String, dynamic>;
        final perms = List<String>.from(inner['permissions'] ?? []);
        final version = inner['permissions_version'] as int?;
        return PermissionsResult(
          success: true,
          permissions: perms,
          permissionsVersion: version,
        );
      }

      return PermissionsResult(
        success: false,
        message: data['message'] as String? ?? 'Failed to fetch permissions',
      );
    } catch (e) {
      return PermissionsResult(
        success: false,
        message: 'Failed to fetch permissions: $e',
      );
    }
  }
}
