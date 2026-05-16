import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../core/services/api_service.dart';
import '../../custum widgets/custom_loader.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const kTeal = Color(0xFF00B5AD);
const kTealLight = Color(0xFFE0F7F5);
const kWhite = Colors.white;
const kTextDark = Color(0xFF2D3748);
const kTextMid = Color(0xFF718096);
const kBorder = Color(0xFFEDF2F7);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  // Change Password state
  bool _showPasswordForm = false;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _loading = true);
    final res = await _api.fetchProfile();
    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _profile = res['data'];
        } else {
          _error = res['message'] ?? 'Failed to load profile';
        }
        _loading = false;
      });
    }
  }

  Future<void> _handlePasswordChange() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('New passwords do not match', isError: true);
      return;
    }
    if (_newPasswordController.text.length < 4) {
      _showSnackBar('Password must be at least 4 characters', isError: true);
      return;
    }

    setState(() => _passwordLoading = true);
    final res = await _api.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    if (mounted) {
      setState(() => _passwordLoading = false);
      if (res['success'] == true) {
        _showSnackBar('Password updated successfully');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _showPasswordForm = false);
      } else {
        _showSnackBar(res['message'] ?? 'Failed to update password', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : kTeal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionProvider>();
    final canChangePassword = perm.can(Perm.profilePasswordUpdate);
    final size = MediaQuery.of(context).size;

    if (_loading) return const Scaffold(body: Center(child: CustomLoader()));

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: kTextMid)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchProfile,
                style: ElevatedButton.styleFrom(backgroundColor: kTeal),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // ── Scrollable Body ──
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Spacer for hero header
                  SizedBox(height: size.height * 0.42 + 25),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 20),
                        _buildGroupsCard(),
                        if (canChangePassword) ...[
                          const SizedBox(height: 20),
                          _buildSecurityCard(),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Fixed Hero Header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeroHeader(context, size),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, Size size) {
    final tp = MediaQuery.of(context).padding.top;
    final headerHeight = size.height * 0.42;
    
    final username = _profile?['username'] ?? 'User';
    final fullName = _profile?['full_name'] ?? username;
    final role = _profile?['role'] ?? 'Staff';
    final memberSince = _formatDateShort(_profile?['created_at']);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Teal Background
        Container(
          width: double.infinity,
          height: headerHeight,
          decoration: const BoxDecoration(
            color: kTeal,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(35),
              bottomRight: Radius.circular(35),
            ),
          ),
        ),

        // Decorative Circles
        Positioned(
          top: -20,
          right: -40,
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),

        // App Bar / Top Actions
        Positioned(
          top: tp + 12,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: kTeal, size: 22),
                ),
              ),
              const Text(
                "My Profile",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 44), // Placeholder for symmetry
            ],
          ),
        ),

        // Doctor Image (Right Aligned)
        Positioned(
          right: 0,
          bottom: 0,
          child: FadeInRight(
            duration: const Duration(milliseconds: 600),
            child: Image.asset(
              'assets/images/dotor.png',
              height: headerHeight * 0.75,
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
            ),
          ),
        ),

        // User Info (Left)
        Positioned(
          top: tp + 80,
          left: 20,
          right: size.width * 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeInLeft(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  fullName,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, color: Color(0xFFFFC107), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      "@$username",
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Glassmorphism Stat Cards
        Positioned(
          bottom: -25,
          left: 20,
          right: 20,
          child: FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 200),
            child: Row(
              children: [
                _buildStatCard(username, "Username"),
                const SizedBox(width: 12),
                _buildStatCard(role, "Role"),
                const SizedBox(width: 12),
                _buildStatCard(memberSince, "Joined"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A202C)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF718096)),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final infoItems = [
      {'label': 'Username', 'value': _profile?['username'], 'icon': Icons.person_outline},
      {'label': 'Full Name', 'value': _profile?['full_name'] ?? '—', 'icon': Icons.badge_outlined},
      {'label': 'Role', 'value': _profile?['role'], 'icon': Icons.shield_outlined},
      {'label': 'Member Since', 'value': _formatDate(_profile?['created_at']), 'icon': Icons.calendar_today_outlined},
      if (_profile?['doctor_id'] != null)
        {'label': 'Doctor ID', 'value': _profile?['doctor_id'], 'icon': Icons.medical_services_outlined},
      if (_profile?['employee_id'] != null)
        {'label': 'Employee ID', 'value': _profile?['employee_id'], 'icon': Icons.badge_outlined},
    ];

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          border: Border.all(color: const Color(0xFFEDF2F7)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: kTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.info_outline, color: kTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                      Text('Your personal details', style: TextStyle(fontSize: 11, color: kTextMid)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDF2F7)),
            ...infoItems.map((item) => _buildInfoItem(item['label'] as String, item['value']?.toString() ?? '—', item['icon'] as IconData)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: kTextMid),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsCard() {
    final groups = _profile?['groups'] as List? ?? [];
    final role = _profile?['role'];

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 100),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          border: Border.all(color: const Color(0xFFEDF2F7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching React emerald-50/emerald-600 style
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5), // emerald-50
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded, color: Color(0xFF059669), size: 22), // emerald-600
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                      Text('Assigned permission groups', style: TextStyle(fontSize: 11, color: kTextMid)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDF2F7)),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (role == 'admin')
                    // System Admin block matching React amber-50 style
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB), // amber-50
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)), // amber-200
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 22), // amber-600
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('System Administrator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E))),
                                Text('Full access to all modules', style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (groups.isNotEmpty)
                    ...groups.map((g) {
                      final name = g['name'] ?? 'Group';
                      final code = g['code'] ?? 'CODE';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC), // slate-50
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE), // blue-100
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 18), // blue-600
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))), // slate-900
                                  Text(code, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B))), // slate-500
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No groups assigned', style: TextStyle(color: kTextMid)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          border: Border.all(color: const Color(0xFFEDF2F7)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.key, color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                          Text('Manage password', style: TextStyle(fontSize: 11, color: kTextMid)),
                        ],
                      ),
                    ],
                  ),
                  if (!_showPasswordForm)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showPasswordForm = true),
                      icon: const Icon(Icons.lock_outline, size: 16),
                      label: const Text('Change Password'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTeal,
                        side: const BorderSide(color: kTeal),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDF2F7)),
            if (_showPasswordForm)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPasswordField('Current Password', _currentPasswordController, _showCurrent, (val) => setState(() => _showCurrent = val)),
                    const SizedBox(height: 16),
                    _buildPasswordField('New Password', _newPasswordController, _showNew, (val) => setState(() => _showNew = val)),
                    const SizedBox(height: 16),
                    _buildPasswordField('Confirm New Password', _confirmPasswordController, false, null, isConfirm: true),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _showPasswordForm = false),
                          child: const Text('Cancel', style: TextStyle(color: kTextMid)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _passwordLoading ? null : _handlePasswordChange,
                          icon: _passwordLoading ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 16, color: Colors.white),
                          label: const Text('Update Password', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: kTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Click "Change Password" to update your account credentials. You\'ll need your current password to confirm the change.',
                  style: TextStyle(fontSize: 13, color: kTextMid),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool show, Function(bool)? onToggle, {bool isConfirm = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isConfirm ? true : !show,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: const Color(0xFFEDF2F7))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: const Color(0xFFEDF2F7))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: isConfirm
                ? null
                : IconButton(
                    icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey),
                    onPressed: () => onToggle!(!show),
                  ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDateShort(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
