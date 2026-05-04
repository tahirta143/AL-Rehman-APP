import 'package:flutter/material.dart';
import 'package:hims_app/core/permissions/permission_keys.dart';
import 'package:hims_app/core/providers/permission_provider.dart';
import 'package:hims_app/core/services/auth_storage_service.dart';
import 'package:hims_app/screens/auth/login.dart';
import 'package:provider/provider.dart';

class CustomDrawer extends StatefulWidget {
  final Function(int) onMenuItemTap;
  final int selectedIndex;

  static const Color primaryColor = Color(0xFF00B5AD);
  static const Color darkTeal = Color(0xFF00B5AD);

  const CustomDrawer({
    super.key,
    required this.onMenuItemTap,
    required this.selectedIndex,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  // OPD dropdown indices: 1,3,4,6,7,10
  static const List<int> _opdIndices = [1, 3, 4, 6, 7, 10];
  // Reports dropdown indices: 11
  static const List<int> _reportsIndices = [11];
  // Prescription dropdown indices: 9, 12, 13, 14, 15, 16
  static const List<int> _prescriptionIndices = [9, 12, 13, 14, 15, 16];
  // Pharmacy dropdown indices: 17, 18, 19, 20
  static const List<int> _pharmacyIndices = [17, 18, 19, 20];

  late bool _opdExpanded;
  late bool _reportsExpanded;
  late bool _prescriptionExpanded;
  late bool _pharmacyExpanded;

  @override
  void initState() {
    super.initState();
    // Auto-expand the group that contains the currently selected item
    _opdExpanded = _opdIndices.contains(widget.selectedIndex);
    _reportsExpanded = _reportsIndices.contains(widget.selectedIndex);
    _prescriptionExpanded = _prescriptionIndices.contains(widget.selectedIndex);
    _pharmacyExpanded = _pharmacyIndices.contains(widget.selectedIndex);
  }

  Future<void> _handleLogout(BuildContext context) async {
    context.read<PermissionProvider>().clear();
    await AuthStorageService().clearAll();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = MediaQuery.of(context).padding.top;
    final perm = context.watch<PermissionProvider>();

    // ── Visible OPD sub-items based on permissions ──────────────────────────
    final List<_DrawerItemData> opdItems = [
      if (perm.canAny([Perm.opdReceiptRead, Perm.opdReceiptCreate]))
        const _DrawerItemData(
          icon: Icons.receipt_rounded,
          title: 'OPD Receipt',
          index: 3,
        ),
      if (perm.canAny([Perm.opdPatientRead, Perm.apptRead]))
        const _DrawerItemData(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Consultation Appointment',
          index: 1,
        ),

      if (perm.can(Perm.opdPatientRead))
        const _DrawerItemData(
          icon: Icons.folder_shared_rounded,
          title: 'OPD Records',
          index: 4,
        ),
      if (perm.canAny([Perm.consultantRead, Perm.consultantCreate]))
        const _DrawerItemData(
          icon: Icons.payment_rounded,
          title: 'Consultation Payments',
          index: 6,
        ),
      if (perm.canAny([Perm.expenseRead, Perm.expenseCreate]))
        const _DrawerItemData(
          icon: Icons.money_rounded,
          title: 'Add Expenses',
          index: 2,
        ),
      if (perm.canAny([
        Perm.opdShiftRead,
        Perm.opdShiftCreate,
        Perm.opdShiftCashRead,
      ]))
        const _DrawerItemData(
          icon: Icons.filter_tilt_shift,
          title: 'Shift Management',
          index: 7,
        ),
      if (perm.canAny([Perm.opdReceiptRead, Perm.setupDiscountTypeRead]))
        const _DrawerItemData(
          icon: Icons.discount_outlined,
          title: 'Discount Voucher',
          index: 10,
        ),
    ];

    // ── Visible Reports sub-items ────────────────────────────────────────────
    final List<_DrawerItemData> reportItems = [
      if (perm.canAny([Perm.apptRead]))
        const _DrawerItemData(
          icon: Icons.timelapse_outlined,
          title: 'Appointment Reports',
          index: 11,
        ),
    ];

    // ── Visible Prescription sub-items ───────────────────────────────────────
    final List<_DrawerItemData> prescriptionItems = [
      if (perm.canAny([Perm.prescriptionRead, Perm.prescriptionCreate]))
        const _DrawerItemData(
          icon: Icons.medical_services_outlined,
          title: 'Prescription GP',
          index: 9,
        ),
      if (perm.canAny([
        Perm.prescriptionRead, Perm.prescriptionCreate,
        Perm.eyeRecordRead, Perm.eyeRecordUpdate,
        Perm.eyeDiagnosisRead, Perm.eyeDiagnosisUpdate,
        Perm.eyeOptometristRead, Perm.eyeOptometristUpdate,
        Perm.eyeExaminationRead, Perm.eyeExaminationUpdate,
        Perm.eyeManagementRead, Perm.eyeManagementUpdate,
        Perm.eyeMedicinesRead, Perm.eyeMedicinesUpdate,
        Perm.eyeHistoryRead,
      ]))
        const _DrawerItemData(
          icon: Icons.remove_red_eye_outlined,
          title: 'Eye Prescription',
          index: 12,
        ),
      if (perm.canAny([Perm.prescriptionRead, Perm.prescriptionCreate]))
        const _DrawerItemData(
          icon: Icons.monitor_heart_outlined,
          title: 'Vitals',
          index: 13,
        ),
      if (perm.canAny([Perm.prescriptionRead, Perm.prescriptionCreate]))
        const _DrawerItemData(
          icon: Icons.biotech_outlined,
          title: 'Lab Values',
          index: 14,
        ),
      if (perm.canAny([Perm.prescriptionRead, Perm.prescriptionCreate]))
        const _DrawerItemData(
          icon: Icons.restaurant_menu_outlined,
          title: 'Nutritionist',
          index: 15,
        ),
      if (perm.canAny([Perm.prescriptionRead, Perm.prescriptionCreate]))
        const _DrawerItemData(
          icon: Icons.visibility_outlined,
          title: 'Fundus Examination',
          index: 16,
        ),
    ];

    // ── Visible Pharmacy sub-items ───────────────────────────────────────────
    final List<_DrawerItemData> pharmacyItems = [
      if (perm.can(Perm.medicineRead))
        const _DrawerItemData(
          icon: Icons.medical_services_outlined,
          title: 'Add / Modify Medicines',
          index: 17,
        ),
      if (perm.can(Perm.medicineRead))
        const _DrawerItemData(
          icon: Icons.inventory_2_outlined,
          title: 'Opening Balances',
          index: 18,
        ),
      if (perm.can(Perm.medicineRead))
        const _DrawerItemData(
          icon: Icons.shopping_cart_outlined,
          title: 'Purchase Posting',
          index: 19,
        ),
      if (perm.can(Perm.medicineRead))
        const _DrawerItemData(
          icon: Icons.receipt_long_outlined,
          title: 'Sales Invoice',
          index: 20,
        ),
    ];

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(20, topPadding + 24, 20, 24),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [CustomDrawer.primaryColor, CustomDrawer.darkTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 35),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  if (perm.role != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '⭐ ${perm.role}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    perm.fullName ?? 'HIMS User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Hospital Management System',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            // ── Menu Items ───────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Dashboard — always visible
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    index: 0,
                  ),
                  // MR Details — standalone
                  if (perm.canAny([Perm.mrRead, Perm.mrCreate]))
                    _buildDrawerItem(
                      icon: Icons.person_outline_rounded,
                      title: 'MR Details',
                      index: 8,
                    ),

                  // Sync Dashboard
                  _buildDrawerItem(
                    icon: Icons.sync_rounded,
                    title: 'Sync Dashboard',
                    index: 100,
                  ),

                  // ── Prescription Dropdown ──────────────────────────────────
                  if (prescriptionItems.isNotEmpty)
                    _buildGroupHeader(
                      icon: Icons.description_outlined,
                      title: 'Prescription',
                      isExpanded: _prescriptionExpanded,
                      hasActiveChild: _prescriptionIndices.contains(
                        widget.selectedIndex,
                      ),
                      onTap: () => setState(() => _prescriptionExpanded = !_prescriptionExpanded),
                    ),
                  if (_prescriptionExpanded)
                    ...prescriptionItems.map(
                      (item) => _buildSubDrawerItem(
                        icon: item.icon,
                        title: item.title,
                        index: item.index,
                      ),
                    ),

                  // ── OPD Dropdown ───────────────────────────────────────────
                  if (opdItems.isNotEmpty)
                    _buildGroupHeader(
                      icon: Icons.local_hospital_outlined,
                      title: 'OPD',
                      isExpanded: _opdExpanded,
                      hasActiveChild: _opdIndices.contains(
                        widget.selectedIndex,
                      ),
                      onTap: () => setState(() => _opdExpanded = !_opdExpanded),
                    ),
                  if (_opdExpanded)
                    ...opdItems.map(
                      (item) => _buildSubDrawerItem(
                        icon: item.icon,
                        title: item.title,
                        index: item.index,
                      ),
                    ),

                  // ── Pharmacy Dropdown ──────────────────────────────────────────────
                  if (pharmacyItems.isNotEmpty)
                    _buildGroupHeader(
                      icon: Icons.local_pharmacy_outlined,
                      title: 'Pharmacy',
                      isExpanded: _pharmacyExpanded,
                      hasActiveChild: _pharmacyIndices.contains(
                        widget.selectedIndex,
                      ),
                      onTap: () => setState(() => _pharmacyExpanded = !_pharmacyExpanded),
                    ),
                  if (_pharmacyExpanded)
                    ...pharmacyItems.map(
                      (item) => _buildSubDrawerItem(
                        icon: item.icon,
                        title: item.title,
                        index: item.index,
                      ),
                    ),

                  // Add Expenses — standalone

                  // Emergency Treatment — standalone
                  if (perm.canAny([Perm.emergencyRead, Perm.emergencyCreate]))
                    _buildDrawerItem(
                      icon: Icons.emergency_rounded,
                      title: 'Emergency Treatment',
                      index: 5,
                    ),

                  // MR View — standalone
                  // if (perm.can(Perm.mrRead))
                  //   _buildDrawerItem(
                  //     icon: Icons.visibility_outlined,
                  //     title: 'MR View',
                  //     index: 9,
                  //   ),

                  // ── Reports Dropdown ───────────────────────────────────────
                  if (reportItems.isNotEmpty)
                    _buildGroupHeader(
                      icon: Icons.bar_chart_rounded,
                      title: 'Reports',
                      isExpanded: _reportsExpanded,
                      hasActiveChild: _reportsIndices.contains(
                        widget.selectedIndex,
                      ),
                      onTap: () =>
                          setState(() => _reportsExpanded = !_reportsExpanded),
                    ),
                  if (_reportsExpanded)
                    ...reportItems.map(
                      (item) => _buildSubDrawerItem(
                        icon: item.icon,
                        title: item.title,
                        index: item.index,
                      ),
                    ),
                ],
              ),
            ),

            // ── Footer / Logout ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              child: _buildLogoutItem(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Group header (collapsible) ─────────────────────────────────────────────
  Widget _buildGroupHeader({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required bool hasActiveChild,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: hasActiveChild
            ? CustomDrawer.primaryColor.withOpacity(0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasActiveChild
                ? CustomDrawer.primaryColor.withOpacity(0.15)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: hasActiveChild
                ? CustomDrawer.primaryColor
                : Colors.grey.shade500,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: hasActiveChild ? CustomDrawer.primaryColor : Colors.black87,
            fontWeight: hasActiveChild ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: hasActiveChild
                ? CustomDrawer.primaryColor
                : Colors.grey.shade400,
            size: 20,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // ── Sub-item (indented, under a group) ────────────────────────────────────
  Widget _buildSubDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final bool isSelected = widget.selectedIndex == index;

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 12, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? CustomDrawer.primaryColor.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? CustomDrawer.primaryColor.withOpacity(0.15)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 17,
            color: isSelected
                ? CustomDrawer.primaryColor
                : Colors.grey.shade500,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? CustomDrawer.primaryColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: CustomDrawer.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            : null,
        onTap: () => widget.onMenuItemTap(index),
      ),
    );
  }

  // ── Regular top-level item ─────────────────────────────────────────────────
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final bool isSelected = widget.selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? CustomDrawer.primaryColor.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? CustomDrawer.primaryColor.withOpacity(0.15)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? CustomDrawer.primaryColor
                : Colors.grey.shade500,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? CustomDrawer.primaryColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: CustomDrawer.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            : null,
        onTap: () => widget.onMenuItemTap(index),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Widget _buildLogoutItem(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.logout_rounded,
            size: 20,
            color: Colors.red.shade400,
          ),
        ),
        title: Text(
          'Logout',
          style: TextStyle(
            color: Colors.red.shade400,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () => _handleLogout(context),
      ),
    );
  }
}

// ── Simple data class for drawer items ────────────────────────────────────────
class _DrawerItemData {
  final IconData icon;
  final String title;
  final int index;
  const _DrawerItemData({
    required this.icon,
    required this.title,
    required this.index,
  });
}
