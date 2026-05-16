/// Singleton service — the single source of truth for permission checks.
/// Update via [updatePermissions], then call [can], [canAny], or [canAll].
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Set<String> _permissions = {};

  /// Load/replace the current permission set.
  void updatePermissions(List<String> keys) {
    _permissions = Set<String>.from(keys);
  }

  /// Returns true if user has [key] or is admin (wildcard `*`).
  bool can(String key) {
    if (_permissions.contains('*')) return true;
    return _permissions.contains(key);
  }

  /// Returns true if user has AT LEAST ONE of [keys].
  bool canAny(List<String> keys) {
    if (_permissions.contains('*')) return true;
    return keys.any((k) => _permissions.contains(k));
  }

  /// Returns true only if user has ALL of [keys].
  bool canAll(List<String> keys) {
    if (_permissions.contains('*')) return true;
    return keys.every((k) => _permissions.contains(k));
  }

  bool get isAdmin => _permissions.contains('*');

  bool get hasAnyPermission => _permissions.isNotEmpty;

  /// Returns true if user has ANY permission for the given resource.
  /// e.g. hasResource('MR.DATA_VIEW') returns true if user has 'MR.DATA_VIEW.READ' or 'MR.DATA_VIEW.PRINT'.
  bool hasResource(String resourcePrefix) {
    if (_permissions.contains('*')) return true;
    final prefix = resourcePrefix.endsWith('.') ? resourcePrefix : '$resourcePrefix.';
    return _permissions.any((p) => p.startsWith(prefix));
  }

  void clear() => _permissions = {};
}
