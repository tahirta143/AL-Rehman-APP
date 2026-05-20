import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles all secure persistent storage for auth tokens, user info,
/// cached permissions, and the permissions version number.
class AuthStorageService {
  // 🛠️ Optimization: Disabling encryptedSharedPreferences (true) often causes PlatformException 
  // on many Android devices due to KeyStore issues or re-installs.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );
  
  // ─── Internal Safe Read ─────────────────────────────────────────────
  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      print('🔒 AuthStorage Error ($key): $e');
      // If we get a PlatformException, it likely means the storage is corrupted
      // or the key has changed. Returning null allows the app to proceed.
      return null;
    }
  }

  static const _keyToken       = 'auth_token';
  static const _keyUserId      = 'user_id';
  static const _keyUsername    = 'username';
  static const _keyFullName    = 'full_name';
  static const _keyRole        = 'role';
  static const _keyPermissions = 'permissions';
  static const _keyPermVersion = 'permissions_version';
  static const _keyGroups      = 'user_groups';
  static const _keyCampToken    = 'camp_device_token';
  static const _keyActiveCamp   = 'active_camp';

  // ─── Save after login ───────────────────────────────────────────────
  Future<void> saveLoginData({
    required String token,
    required String userId,
    required String username,
    required String fullName,
    required String role,
    List<dynamic>? groups,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _keyToken,    value: token),
        _storage.write(key: _keyUserId,   value: userId),
        _storage.write(key: _keyUsername, value: username),
        _storage.write(key: _keyFullName, value: fullName),
        _storage.write(key: _keyRole,     value: role),
        if (groups != null) _storage.write(key: _keyGroups, value: jsonEncode(groups)),
      ]);
    } catch (e) {
      print('🔒 AuthStorage Save Error: $e');
    }
  }

  // ─── Save after permission fetch ────────────────────────────────────
  Future<void> savePermissions(List<String> perms, int? version) async {
    try {
      await _storage.write(key: _keyPermissions, value: perms.join(','));
      await _storage.write(key: _keyPermVersion, value: (version ?? 0).toString());
    } catch (e) {
      print('🔒 AuthStorage Perm Save Error: $e');
    }
  }

  // ─── Getters ────────────────────────────────────────────────────────
  Future<String?> getToken()    => _safeRead(_keyToken);
  Future<String?> getRole()     => _safeRead(_keyRole);
  Future<String?> getUserId()   => _safeRead(_keyUserId);
  Future<String?> getUsername() => _safeRead(_keyUsername);
  Future<String?> getFullName() => _safeRead(_keyFullName);
  Future<String?> getCampToken() => _safeRead(_keyCampToken);

  Future<List<dynamic>> getGroups() async {
    final raw = await _safeRead(_keyGroups);
    if (raw == null || raw.isEmpty) return [];
    try {
      return jsonDecode(raw) as List;
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCampToken(String token) async {
    await _storage.write(key: _keyCampToken, value: token);
  }

  Future<List<String>> getPermissions() async {
    final raw = await _safeRead(_keyPermissions);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  Future<int> getPermissionsVersion() async {
    final v = await _safeRead(_keyPermVersion);
    return int.tryParse(v ?? '0') ?? 0;
  }

  // ─── Clear on logout ────────────────────────────────────────────────
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('🔒 AuthStorage Clear Error: $e');
    }
  }

  Future<void> clearCampToken() async {
    await _storage.delete(key: _keyCampToken);
  }

  Future<void> saveActiveCamp(Map<String, dynamic> camp) async {
    await _storage.write(key: _keyActiveCamp, value: jsonEncode(camp));
  }

  Future<Map<String, dynamic>?> getActiveCamp() async {
    final raw = await _safeRead(_keyActiveCamp);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveCamp() async {
    await _storage.delete(key: _keyActiveCamp);
  }

  static String campJoinDismissKey(String userId) =>
      'camp_join_dismissed_$userId';

  Future<bool> isCampJoinDismissed(String userId) async {
    final v = await _safeRead(campJoinDismissKey(userId));
    return v == '1';
  }

  Future<void> setCampJoinDismissed(String userId) async {
    await _storage.write(key: campJoinDismissKey(userId), value: '1');
  }
}
