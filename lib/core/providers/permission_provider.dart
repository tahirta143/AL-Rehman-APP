import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/auth_storage_service.dart';
import '../services/permission_service.dart';

/// ChangeNotifier that wraps [PermissionService] and exposes
/// reactive state to the widget tree via Provider.
class PermissionProvider extends ChangeNotifier {
  final _storage = AuthStorageService();
  final _service = PermissionService();
  final _api     = ApiService();

  bool _isLoading = false;
  String? _error;
  String? _fullName;
  String? _role;
  List<dynamic> _groups = [];

  bool    get isLoading => _isLoading;
  String? get error     => _error;
  bool    get isAdmin   => _service.isAdmin;
  String? get fullName  => _fullName;
  String? get role      => _role;
  List<dynamic> get groups => _groups;

  // ─── Permission check helpers ────────────────────────────────────
  bool can(String key)           => _service.can(key);
  bool canAny(List<String> keys) => _service.canAny(keys);
  bool canAll(List<String> keys) => _service.canAll(keys);
  bool hasResource(String prefix) => _service.hasResource(prefix);

  // ─── Load from secure storage (offline/startup) ───────────────────
  Future<void> loadFromStorage() async {
    final perms = await _storage.getPermissions();
    _fullName = await _storage.getFullName();
    _role = await _storage.getRole();
    _groups = await _storage.getGroups();
    _service.updatePermissions(perms);
    notifyListeners();
  }

  // ─── Sync from server (login / app resume) ────────────────────────
  /// Returns true on success. On failure, falls back to cached permissions.
  Future<bool> syncFromServer() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.fetchPermissions();

      if (!result.success) {
        // Server error → fall back to cache
        await loadFromStorage();
        _error = result.message;
        return false;
      }

      final serverVersion = result.permissionsVersion ?? 0;
      final localVersion  = await _storage.getPermissionsVersion();

      // Always update the in-memory service with the latest permissions from server
      _service.updatePermissions(result.permissions);
      
      // Update local name, role and groups
      _fullName = await _storage.getFullName();
      _role = await _storage.getRole();
      _groups = await _storage.getGroups();

      // Save to storage only if version changed or first load
      if (localVersion == 0 || serverVersion != localVersion) {
        await _storage.savePermissions(result.permissions, serverVersion);
      }

      return true;
    } catch (e) {
      _error = e.toString();
      await loadFromStorage(); // fallback
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Clear on logout ──────────────────────────────────────────────
  void clear() {
    _service.clear();
    _error = null;
    _fullName = null;
    _role = null;
    _groups = [];
    notifyListeners();
  }
}
