import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../providers/camp_provider.dart';

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

  static const List<_NavItemDef> _allItems = [
    _NavItemDef(
      icon: Icons.home_rounded,
      label: 'Home',
      drawerIndex: 21,
      permissions: [],
    ),
    _NavItemDef(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
      drawerIndex: 0,
      permissions: [Perm.appDashboardRead],
    ),
    _NavItemDef(
      icon: Icons.warning_amber_rounded,
      label: 'Emergency',
      drawerIndex: 5,
      permissions: [Perm.emergencyRead, Perm.emergencyCreate],
    ),
    _NavItemDef(
      icon: Icons.chat_bubble_rounded,
      label: 'Consult',
      drawerIndex: 1,
      permissions: [Perm.apptRead, Perm.opdPatientRead],
    ),
    _NavItemDef(
      icon: Icons.people_alt_rounded,
      label: 'MR Details',
      drawerIndex: 8,
      permissions: [Perm.mrRead, Perm.mrCreate],
    ),
  ];

  static const List<_NavItemDef> _campItems = [
    _NavItemDef(
      icon: Icons.person_outline_rounded,
      label: 'MR Details',
      drawerIndex: 8,
      permissions: [],
    ),
    _NavItemDef(
      icon: Icons.monitor_heart_outlined,
      label: 'Vitals',
      drawerIndex: 13,
      permissions: [],
    ),
    _NavItemDef(
      icon: Icons.medication_outlined,
      label: 'Prescription',
      drawerIndex: 9,
      permissions: [],
    ),
  ];

  List<_NavItemDef> _visibleItems = [];
  List<AnimationController> _controllers = [];
  List<Animation<double>> _scaleAnims = [];
  AnimationController? _slideController;
  Animation<double>? _slideAnim;
  int _prevIndex = 0;
  int _lastBuiltCount = 0;
  bool _reinitScheduled = false;

  @override
  void initState() {
    super.initState();
    _visibleItems = [_allItems.first];
    _initAnimations(_visibleItems.length, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibleItems());
  }

  @override
  void didUpdateWidget(CustomFluidBottomNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _animateSelectionChange(old.currentIndex);
    }
    _syncVisibleItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibleItems();
  }

  List<_NavItemDef> _computeVisibleItems() {
    final perm = context.read<PermissionProvider>();
    final camp = context.read<CampProvider>();

    if (camp.isCampMode) {
      return _campItems.where((item) {
        switch (item.drawerIndex) {
          case 8:
            return perm.canAny([Perm.mrRead, Perm.mrCreate]);
          case 13:
            return perm.hasResource('PRESCRIPTION.VITALS');
          case 9:
            return perm.hasResource('PRESCRIPTION.GP_RECORD');
          default:
            return true;
        }
      }).toList();
    }

    return _allItems.where((item) {
      if (item.permissions.isEmpty) return true;
      return perm.canAny(item.permissions);
    }).toList();
  }

  void _syncVisibleItems() {
    final visible = _computeVisibleItems();
    if (visible.isEmpty) {
      visible.add(_allItems.first);
    }

    if (visible.length == _lastBuiltCount &&
        _listsEqual(visible, _visibleItems)) {
      return;
    }

    if (_reinitScheduled) return;
    _reinitScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reinitScheduled = false;
      if (!mounted) return;

      var nextVisible = _computeVisibleItems();
      if (nextVisible.isEmpty) {
        nextVisible = [_allItems.first];
      }

      final visualIndex = nextVisible
          .indexWhere((item) => item.drawerIndex == widget.currentIndex);
      final safeIndex = visualIndex < 0 ? 0 : visualIndex;

      _disposeAnimations();
      _visibleItems = nextVisible;
      _lastBuiltCount = nextVisible.length;
      _prevIndex = safeIndex;
      _initAnimations(nextVisible.length, safeIndex);
      setState(() {});
    });
  }

  bool _listsEqual(List<_NavItemDef> a, List<_NavItemDef> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].drawerIndex != b[i].drawerIndex) return false;
    }
    return true;
  }

  void _animateSelectionChange(int oldDrawerIndex) {
    final oldVisualIndex =
        _visibleItems.indexWhere((item) => item.drawerIndex == oldDrawerIndex);
    final newVisualIndex = _visibleItems
        .indexWhere((item) => item.drawerIndex == widget.currentIndex);

    if (oldVisualIndex >= 0 && oldVisualIndex < _controllers.length) {
      _controllers[oldVisualIndex].reverse();
    }
    if (newVisualIndex >= 0 && newVisualIndex < _controllers.length) {
      _controllers[newVisualIndex].forward();
    }

    _prevIndex = oldVisualIndex < 0 ? 0 : oldVisualIndex;

    _slideController?.stop();
    _slideController?.reset();
    _slideController?.forward();
  }

  void _initAnimations(int count, int visualIndex) {
    _controllers = List.generate(
      count,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      ),
    );
    _scaleAnims = _controllers
        .map(
          (c) => Tween<double>(begin: 1.0, end: 1.12).animate(
            CurvedAnimation(parent: c, curve: Curves.easeOutBack),
          ),
        )
        .toList();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    );

    if (visualIndex >= 0 && visualIndex < _controllers.length) {
      _controllers[visualIndex].forward();
    }
    _slideController!.value = 1.0;
  }

  void _disposeAnimations() {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers = [];
    _scaleAnims = [];
    _slideController?.dispose();
    _slideController = null;
    _slideAnim = null;
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  void _onTap(int visualIndex) {
    final drawerIdx = _visibleItems[visualIndex].drawerIndex;
    if (drawerIdx == widget.currentIndex) return;
    HapticFeedback.lightImpact();
    widget.onItemSelected(drawerIdx);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<PermissionProvider>();
    context.watch<CampProvider>();

    final items = _visibleItems;
    if (items.isEmpty || _controllers.isEmpty || _slideAnim == null) {
      return const SizedBox(
        height: 84,
        child: ColoredBox(color: Colors.white),
      );
    }

    final currentVisualIndex =
        items.indexWhere((item) => item.drawerIndex == widget.currentIndex);
    final safeCurrentIndex = currentVisualIndex < 0 ? 0 : currentVisualIndex;

    final double width = MediaQuery.of(context).size.width;
    final double itemWidth = width / items.length;
    const double barHeight = 76.0;
    const double floatOffset = 20.0;
    const double circleSize = 46.0;

    return AnimatedBuilder(
      animation: _slideAnim!,
      builder: (_, __) {
        final double fromX =
            _prevIndex.clamp(0, items.length - 1) * itemWidth + itemWidth / 2;
        final double toX = safeCurrentIndex * itemWidth + itemWidth / 2;
        final double notchX = fromX + (toX - fromX) * _slideAnim!.value;

        return SizedBox(
          height: barHeight + floatOffset + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBar(
                  notchX,
                  itemWidth,
                  barHeight,
                  width,
                  items,
                  safeCurrentIndex,
                ),
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

  Widget _buildBar(
    double notchX,
    double itemWidth,
    double barHeight,
    double width,
    List<_NavItemDef> items,
    int currentIndex,
  ) {
    return ClipPath(
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
    );
  }

  Widget _buildFloatingCircle(
    double size,
    List<_NavItemDef> items,
    int currentIndex,
  ) {
    if (currentIndex >= _controllers.length) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controllers[currentIndex],
      builder: (_, __) {
        return ScaleTransition(
          scale: _scaleAnims[currentIndex],
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
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

  Widget _buildItem(
    int index,
    double itemWidth,
    List<_NavItemDef> items,
    int currentIndex,
  ) {
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
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurvedNavClipper extends CustomClipper<Path> {
  final double notchCenterX;

  const _CurvedNavClipper({required this.notchCenterX});

  @override
  Path getClip(Size size) {
    const double notchRadius = 34.0;
    const double notchDepth = 22.0;
    const double spread = 48.0;
    const double topRadius = 22.0;

    final cx = notchCenterX;
    final path = Path();

    path.moveTo(0, topRadius);
    path.quadraticBezierTo(0, 0, topRadius, 0);
    path.lineTo(cx - spread - 6, 0);
    path.cubicTo(
      cx - spread + 8,
      0,
      cx - notchRadius,
      notchDepth,
      cx,
      notchDepth,
    );
    path.cubicTo(
      cx + notchRadius,
      notchDepth,
      cx + spread - 8,
      0,
      cx + spread + 6,
      0,
    );
    path.lineTo(size.width - topRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, topRadius);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_CurvedNavClipper old) => old.notchCenterX != notchCenterX;
}

class _NavItemDef {
  final IconData icon;
  final String label;
  final int drawerIndex;
  final List<String> permissions;
  const _NavItemDef({
    required this.icon,
    required this.label,
    required this.drawerIndex,
    required this.permissions,
  });
}
