import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../core/providers/permission_provider.dart';
import '../drawer/base_scaffold.dart';

class SearchableItem {
  final String label;
  final int drawerIndex;
  final String group;
  final String? permission;

  const SearchableItem({
    required this.label,
    required this.drawerIndex,
    required this.group,
    this.permission,
  });
}

const List<SearchableItem> searchableItems = [
  SearchableItem(label: 'Home', drawerIndex: 21, group: 'Main'),
  SearchableItem(label: 'Dashboard', drawerIndex: 0, group: 'Main', permission: Perm.appDashboardRead),
  SearchableItem(label: 'MR Details', drawerIndex: 8, group: 'Main', permission: Perm.mrRead),
  SearchableItem(label: 'MR Data View', drawerIndex: 22, group: 'Main', permission: Perm.mrDataViewRead),
  SearchableItem(label: 'Consultant Appointment', drawerIndex: 1, group: 'Main', permission: Perm.apptRead),
  SearchableItem(label: 'Emergency Treatment', drawerIndex: 5, group: 'Main', permission: Perm.emergencyRead),
  
  SearchableItem(label: 'OPD Receipt', drawerIndex: 3, group: 'OPD', permission: Perm.opdReceiptRead),
  SearchableItem(label: 'Patient Records', drawerIndex: 4, group: 'OPD', permission: Perm.opdPatientRead),
  SearchableItem(label: 'Discount Approval', drawerIndex: 10, group: 'OPD', permission: Perm.opdDiscountApprovalRead),
  SearchableItem(label: 'Consultant Payments', drawerIndex: 6, group: 'OPD', permission: Perm.consultantRead),
  SearchableItem(label: 'Counter Expenses', drawerIndex: 2, group: 'OPD', permission: Perm.expenseRead),
  SearchableItem(label: 'Shift Management', drawerIndex: 7, group: 'OPD', permission: Perm.opdShiftRead),

  SearchableItem(label: 'Vitals', drawerIndex: 13, group: 'Prescription', permission: Perm.vitalsRead),
  SearchableItem(label: 'Lab Values', drawerIndex: 14, group: 'Prescription', permission: Perm.labValuesRead),
  SearchableItem(label: 'Prescription GP', drawerIndex: 9, group: 'Prescription', permission: Perm.prescriptionRead),
  SearchableItem(label: 'Nutritionist', drawerIndex: 15, group: 'Prescription', permission: Perm.nutritionistRead),
  SearchableItem(label: 'Eye Prescription', drawerIndex: 12, group: 'Prescription', permission: Perm.eyeRecordRead),
  SearchableItem(label: 'Fundus Examination', drawerIndex: 16, group: 'Prescription', permission: Perm.fundusRead),
  
  SearchableItem(label: 'Add / Modify Medicines', drawerIndex: 17, group: 'Pharmacy', permission: Perm.medicineRead),
  SearchableItem(label: 'Opening Balances', drawerIndex: 18, group: 'Pharmacy', permission: Perm.medicineRead),
  SearchableItem(label: 'Purchase Posting', drawerIndex: 19, group: 'Pharmacy', permission: Perm.medicineRead),
  SearchableItem(label: 'Sales Invoice', drawerIndex: 20, group: 'Pharmacy', permission: Perm.medicineRead),

  SearchableItem(label: 'Appointment Report', drawerIndex: 11, group: 'Reports', permission: Perm.opdReportsRead),
  SearchableItem(label: 'Camp Sync', drawerIndex: 100, group: 'Camps', permission: Perm.campDashboardRead),
  SearchableItem(label: 'Complaints Board', drawerIndex: 23, group: 'Complaints', permission: Perm.complaintsBoardRead),
];

void showGlobalSearchOverlay(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Search Overlay',
    barrierColor: Colors.black.withValues(alpha: 0.3),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (dialogContext, anim1, anim2) {
      return GlobalSearchOverlay(parentContext: context);
    },
    transitionBuilder: (dialogContext, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    },
  );
}

class GlobalSearchOverlay extends StatefulWidget {
  final BuildContext parentContext;
  const GlobalSearchOverlay({super.key, required this.parentContext});

  @override
  State<GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends State<GlobalSearchOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  int _activeIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {
      _query = query;
      _activeIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final perm = Provider.of<PermissionProvider>(context, listen: false);

    // 1. Filter items by permissions first
    final List<SearchableItem> allowedItems = searchableItems.where((item) {
      if (item.permission == null) return true;
      if (item.permission!.endsWith('.READ')) {
        final resource = item.permission!.substring(0, item.permission!.length - 5);
        return perm.hasResource(resource);
      }
      return perm.can(item.permission!);
    }).toList();

    // 2. Filter items by search query
    final List<SearchableItem> filteredItems = _query.trim().isEmpty
        ? []
        : allowedItems.where((item) {
            final q = _query.toLowerCase().trim();
            return item.label.toLowerCase().contains(q) ||
                item.group.toLowerCase().contains(q);
          }).toList();

    // Grouping filtered items to display properly
    final Map<String, List<SearchableItem>> groupedItems = {};
    for (var item in filteredItems) {
      if (!groupedItems.containsKey(item.group)) {
        groupedItems[item.group] = [];
      }
      groupedItems[item.group]!.add(item);
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (filteredItems.isNotEmpty) {
              setState(() {
                _activeIndex = (_activeIndex + 1) % filteredItems.length;
              });
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (filteredItems.isNotEmpty) {
              setState(() {
                _activeIndex = (_activeIndex - 1 + filteredItems.length) %
                    filteredItems.length;
              });
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (filteredItems.isNotEmpty && _activeIndex < filteredItems.length) {
              final selected = filteredItems[_activeIndex];
              Navigator.pop(context);
              BaseScaffold.navigateTo(widget.parentContext, selected.drawerIndex);
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Backdrop click detector to dismiss dialog
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.pop(context),
                child: Container(),
              ),
            ),
            // Centered dialog container
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 100.0, left: 16.0, right: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 560),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Input Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF718096),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    onChanged: _onQueryChanged,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF1A202C),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Search pages, settings, reports...',
                                      hintStyle: TextStyle(
                                        color: Color(0xA3718096),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF2F7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Text(
                                    'ESC',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      color: Color(0xFF718096),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFEDF2F7)),
                          // Results List
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: _query.trim().isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 36.0),
                                    child: Center(
                                      child: Text(
                                        'Start typing to search pages and settings…',
                                        style: TextStyle(
                                          color: Color(0xFFA0AEC0),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  )
                                : filteredItems.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
                                        child: Center(
                                          child: Text(
                                            'No results found for "${_query.trim()}"',
                                            style: const TextStyle(
                                              color: Color(0xFFA0AEC0),
                                              fontSize: 13,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        controller: _scrollController,
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        itemCount: groupedItems.keys.length,
                                        itemBuilder: (context, groupIndex) {
                                          final groupName = groupedItems.keys.elementAt(groupIndex);
                                          final groupList = groupedItems[groupName]!;

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Group label (Category)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 16.0,
                                                  top: 8.0,
                                                  bottom: 4.0,
                                                ),
                                                child: Text(
                                                  groupName.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF4A5568),
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                              ),
                                              ...groupList.map((item) {
                                                // Calculate overall flat index to see if active
                                                final flatIndex = filteredItems.indexOf(item);
                                                final isActive = flatIndex == _activeIndex;

                                                return InkWell(
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    BaseScaffold.navigateTo(widget.parentContext, item.drawerIndex);
                                                  },
                                                  onHover: (hovered) {
                                                    if (hovered) {
                                                      setState(() {
                                                        _activeIndex = flatIndex;
                                                      });
                                                    }
                                                  },
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 10.0,
                                                    ),
                                                    color: isActive
                                                        ? const Color(0xFFEDF2F7)
                                                        : Colors.transparent,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: RichText(
                                                            text: _highlightMatch(
                                                              item.label,
                                                              _query.trim(),
                                                            ),
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.arrow_forward_rounded,
                                                          size: 14,
                                                          color: isActive
                                                              ? const Color(0xFF00B5AD)
                                                              : const Color(0xFFCBD5E0),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          );
                                        },
                                      ),
                          ),
                          const Divider(height: 1, color: Color(0xFFEDF2F7)),
                          // Shortcuts Footer
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                            child: Row(
                              children: [
                                _footerShortcut('↑↓', 'navigate'),
                                const SizedBox(width: 14),
                                _footerShortcut('Enter', 'select'),
                                const SizedBox(width: 14),
                                _footerShortcut('ESC', 'close'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerShortcut(String keyText, String actionText) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            keyText,
            style: const TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: Color(0xFF718096),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          actionText,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF718096),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  InlineSpan _highlightMatch(String text, String query) {
    if (query.isEmpty) return TextSpan(text: text, style: const TextStyle(color: Color(0xFF2D3748), fontSize: 13.5, fontWeight: FontWeight.w500));
    final int index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index == -1) return TextSpan(text: text, style: const TextStyle(color: Color(0xFF2D3748), fontSize: 13.5, fontWeight: FontWeight.w500));

    final String before = text.substring(0, index);
    final String matched = text.substring(index, index + query.length);
    final String after = text.substring(index + query.length);

    return TextSpan(
      style: const TextStyle(color: Color(0xFF2D3748), fontSize: 13.5, fontWeight: FontWeight.w500),
      children: [
        TextSpan(text: before),
        TextSpan(
          text: matched,
          style: const TextStyle(
            backgroundColor: Color(0xFFFEFCBF), // Light yellow matching marking
            color: Color(0xFFB7791F),
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(text: after),
      ],
    );
  }
}
