import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';

class CustomFluidBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onItemSelected;

  const CustomFluidBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  State<CustomFluidBottomNavBar> createState() => _CustomFluidBottomNavBarState();
}

class _CustomFluidBottomNavBarState extends State<CustomFluidBottomNavBar>
    with TickerProviderStateMixin {

  static const Color _primary = Color(0xFF00B5AD);
  static const Color _primaryDark = Color(0xFF007A73);

  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnims;
  late AnimationController _slideController;
  late Animation<double> _slideAnim;
  int _prevIndex = 0;

  // All possible nav items with their permission requirements
  static const List<_NavItemDef> _allItems = [
    _NavItemDef(icon: Icons.home_rounded,          label: 'Home',       drawerIndex: 21, permissions: []),
    _NavItemDef(icon: Icons.dashboard_rounded,     label: 'Dashboard',  drawerIndex: 0,  permissions: [Perm.appDashboardRead]),
    _NavItemDef(icon: Icons.warning_amber_rounded, label: 'Emergency',  drawerIndex: 5,  permissions: [Perm.emergencyRead, Perm.emergencyCreate]),
    _NavItemDef(icon: Icons.chat_bubble_rounded,   label: 'Consult',    drawerIndex: 1,  permissions: [Perm.apptRead, Perm.opdPatientRead]),
    _NavItemDef(icon: Icons.people_alt_rounded,    label: 'MR Details', drawerIndex: 8,  permissions: [Perm.mrRead, Perm.mrCreate]),
  ];

  List<_NavItemDef> _visibleItems = [];

  @override
  void initState() {
    super.initState();
    _visibleItems = _allItems;
    final initialVisualIndex = _visibleItems.indexWhere((item) => item.drawerIndex == widget.currentIndex);
    _prevIndex = initialVisualIndex < 0 ? 0 : initialVisualIndex;
    _initAnimations(_visibleItems.length, initialVisualIndex);
  }

  void _initAnimations(int count, int visualIndex) {
    _controllers = List.generate(count, (i) =>
        AnimationController(vsync: this, duration: const Duration(milliseconds: 320)));
    _scaleAnims = _controllers.map((c) =>
        Tween<double>(begin: 1.0, end: 1.12).animate(
            CurvedAnimation(parent: c, curve: Curves.easeOutBack))).toList();

    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    if (visualIndex >= 0 && visualIndex < _controllers.length) {
      _controllers[visualIndex].forward();
    }
    _slideController.value = 1.0;
  }

  @override
  void didUpdateWidget(CustomFluidBottomNavBar old) {
    super.didUpdateWidget(old);

    if (old.currentIndex != widget.currentIndex) {
      final oldVisualIndex = _visibleItems.indexWhere((item) => item.drawerIndex == old.currentIndex);
      final newVisualIndex = _visibleItems.indexWhere((item) => item.drawerIndex == widget.currentIndex);

      if (oldVisualIndex >= 0 && oldVisualIndex < _controllers.length) {
        _controllers[oldVisualIndex].reverse();
      }
      if (newVisualIndex >= 0 && newVisualIndex < _controllers.length) {
        _controllers[newVisualIndex].forward();
      }

      _prevIndex = oldVisualIndex < 0 ? 0 : oldVisualIndex;

      // Reset properly before animating
      _slideController.stop();
      _slideController.reset();
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onTap(int visualIndex) {
    // Pass the drawerIndex so base_scaffold can navigate directly
    final drawerIdx = _visibleItems[visualIndex].drawerIndex;
    if (drawerIdx == widget.currentIndex) return;
    HapticFeedback.lightImpact();
    widget.onItemSelected(drawerIdx);
  }

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionProvider>();

    // Build visible items based on permissions
    final visible = _allItems.where((item) {
      if (item.permissions.isEmpty) return true; // Dashboard always visible
      return perm.canAny(item.permissions);
    }).toList();

    // Re-init animations if item count changed
    if (visible.length != _visibleItems.length) {
      for (final c in _controllers) c.dispose();
      _slideController.dispose();
      _visibleItems = visible;
      final currentVisualIndex = _visibleItems.indexWhere((item) => item.drawerIndex == widget.currentIndex);
      _initAnimations(visible.length, currentVisualIndex);
    } else {
      _visibleItems = visible;
    }

    final items = _visibleItems;
    if (items.isEmpty) return const SizedBox.shrink();

    // Find visual index by matching drawerIndex
    final currentVisualIndex = items.indexWhere((item) => item.drawerIndex == widget.currentIndex);
    final safeCurrentIndex = currentVisualIndex < 0 ? 0 : currentVisualIndex;

    final double width = MediaQuery.of(context).size.width;
    final double itemWidth = width / items.length;
    const double barHeight = 76.0;
    const double floatOffset = 20.0;
    const double circleSize = 46.0;

    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (_, __) {
        final double fromX = _prevIndex.clamp(0, items.length - 1) * itemWidth + itemWidth / 2;
        final double toX   = safeCurrentIndex * itemWidth + itemWidth / 2;
        final double notchX = fromX + (toX - fromX) * _slideAnim.value;

        return SizedBox(
          height: barHeight + floatOffset + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBar(notchX, itemWidth, barHeight, width, items, safeCurrentIndex),
              ),
              Positioned(
                left: notchX - circleSize / 2,
                top: 0,
                child: _buildFloatingCircle(circleSize, items, safeCurrentIndex),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Curved white bar with SafeArea ──
  Widget _buildBar(double notchX, double itemWidth, double barHeight, double width, List<_NavItemDef> items, int currentIndex) {
    return Container(
      decoration: const BoxDecoration(),
      child: ClipPath(
        clipper: _CurvedNavClipper(notchCenterX: notchX),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: barHeight,
              child: Row(
                children: List.generate(
                  items.length,
                  (i) => _buildItem(i, itemWidth, items, currentIndex),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Teal circle that floats in the notch ──
  Widget _buildFloatingCircle(double size, List<_NavItemDef> items, int currentIndex) {
    if (currentIndex >= _controllers.length) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controllers[currentIndex],
      builder: (_, __) {
        return ScaleTransition(
          scale: _scaleAnims[currentIndex],
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_primary, _primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                items[currentIndex].icon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Individual nav item (unselected tabs) ──
  Widget _buildItem(int index, double itemWidth, List<_NavItemDef> items, int currentIndex) {
    final item = items[index];
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => _onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isSelected ? 0.0 : 1.0,
              child: Icon(
                item.icon,
                size: 22,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _primary : Colors.grey.shade400,
                letterSpacing: 0.2,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CURVED CLIPPER
// ─────────────────────────────────────────────
class _CurvedNavClipper extends CustomClipper<Path> {
  final double notchCenterX;

  const _CurvedNavClipper({required this.notchCenterX});

  @override
  Path getClip(Size size) {
    const double notchRadius = 34.0;
    const double notchDepth  = 22.0;
    const double spread      = 48.0;
    const double topRadius   = 22.0;

    final cx = notchCenterX;
    final path = Path();

    // Top-left rounded corner
    path.moveTo(0, topRadius);
    path.quadraticBezierTo(0, 0, topRadius, 0);

    // Flat top → left shoulder of notch
    path.lineTo(cx - spread - 6, 0);

    // Smooth left curve down into notch
    path.cubicTo(
      cx - spread + 8,  0,
      cx - notchRadius, notchDepth,
      cx,               notchDepth,
    );

    // Smooth right curve up out of notch
    path.cubicTo(
      cx + notchRadius, notchDepth,
      cx + spread - 8,  0,
      cx + spread + 6,  0,
    );

    // Flat top → top-right rounded corner
    path.lineTo(size.width - topRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, topRadius);

    // Right side → bottom-right
    path.lineTo(size.width, size.height);

    // Bottom → bottom-left
    path.lineTo(0, size.height);

    // Left side → back to start
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_CurvedNavClipper old) =>
      old.notchCenterX != notchCenterX;
}

class _NavItemDef {
  final IconData icon;
  final String label;
  final int drawerIndex;
  final List<String> permissions;
  const _NavItemDef({required this.icon, required this.label, required this.drawerIndex, required this.permissions});
}