import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../custum widgets/drawer/base_scaffold.dart';

// Import all screens for navigation
import '../dashboard/dashboard.dart' as dash;
import '../emergency_treatment/emergency_treatment.dart';
import '../opd_reciepts/opd_reciept.dart';
import '../opd_reciepts/opd_records.dart';
import '../mr_details/mr_details.dart';
import '../cunsultations/cunsultations.dart';
import '../prescription/prescription.dart';
import '../prescription/eye_prescription.dart';
import '../consultation_payments/consultation_payments.dart';
import '../add_expenses/add_expenses.dart';
import '../shift_management/shift_management.dart';

class HomeScreen extends StatelessWidget {
  final bool useScaffold;
  const HomeScreen({super.key, this.useScaffold = true});

  @override
  Widget build(BuildContext context) {
    if (useScaffold) {
      return BaseScaffold(
        title: 'Home',
        drawerIndex: 21,
        showAppBar: false, // Ensure appbar is hidden when used standalone
        body: const _HomeBody(),
      );
    }
    return const _HomeBody();
  }
}

class _NavCard {
  final String label;
  final String desc;
  final IconData icon;
  final int drawerIndex;
  final String? permission;
  final List<String>? anyOf;

  const _NavCard({
    required this.label,
    required this.desc,
    required this.icon,
    required this.drawerIndex,
    this.permission,
    this.anyOf,
  });
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionProvider>();
    final user = perm.fullName ?? 'User';
    final role = perm.role ?? 'Staff';

    final List<_NavCard> allCards = [
      const _NavCard(label: "Dashboard", desc: "Analytics & reports", icon: Icons.bar_chart_rounded, drawerIndex: 0, permission: Perm.appDashboardRead),
      const _NavCard(label: "Emergency", desc: "Treatment & queue", icon: Icons.error_outline_rounded, drawerIndex: 5, permission: Perm.emergencyRead),
      const _NavCard(label: "OPD Receipt", desc: "Create new receipts", icon: Icons.receipt_rounded, drawerIndex: 3, permission: Perm.opdReceiptRead),
      const _NavCard(label: "Patient Records", desc: "View & manage records", icon: Icons.description_outlined, drawerIndex: 4, permission: Perm.opdPatientRead),
      const _NavCard(label: "MR Details", desc: "Patient master records", icon: Icons.person_outline_rounded, drawerIndex: 8, permission: Perm.mrRead),
      const _NavCard(label: "Appointments", desc: "Consultant scheduling", icon: Icons.calendar_today_rounded, drawerIndex: 1, permission: Perm.apptRead),
      const _NavCard(label: "Prescription", desc: "Consultation notes", icon: Icons.medication_outlined, drawerIndex: 9, permission: Perm.prescriptionRead),
      const _NavCard(label: "Consultant Pay", desc: "Doctor payouts", icon: Icons.attach_money_rounded, drawerIndex: 6, permission: Perm.consultantRead),
      const _NavCard(label: "Add Expenses", desc: "Record expenses", icon: Icons.credit_card_rounded, drawerIndex: 2, permission: Perm.expenseRead),
      const _NavCard(label: "Shift Mgmt", desc: "Open/Close shifts", icon: Icons.access_time_rounded, drawerIndex: 7, permission: Perm.opdShiftRead),
      const _NavCard(label: "Eye Prescription", desc: "eye workflow", icon: Icons.remove_red_eye_outlined, drawerIndex: 12, anyOf: [Perm.eyeRecordRead, Perm.eyeRecordUpdate]),
    ];

    final accessibleCards = allCards.where((c) {
      if (c.permission != null) return perm.can(c.permission!);
      if (c.anyOf != null) return perm.canAny(c.anyOf!);
      return true;
    }).toList();

    final size = MediaQuery.of(context).size;

    return Container(
      color: const Color(0xFFF8F9FA),
      child: Stack(
        children: [
          // ── Scrollable Body (Modules) ──
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spacer to push content below the fixed header and cards
                  SizedBox(height: size.height * 0.42 + 25),

                  // ── Modules Section ──
                  FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Modules',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Grid ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 27),
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: accessibleCards.length,
                      itemBuilder: (context, index) {
                        return FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          delay: Duration(milliseconds: 100 + (index * 50)),
                          child: _ModuleCard(card: accessibleCards[index], index: index),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),

          // ── Fixed Header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeroHeader(context, size, user, role, accessibleCards.length),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, Size size, String user, String role, int modulesCount) {
    final tp = MediaQuery.of(context).padding.top;
    final headerHeight = size.height * 0.42; // Dynamic height for half screen effect

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Blue/Teal Background
        Container(
          width: double.infinity,
          height: headerHeight,
          decoration: const BoxDecoration(
            color: Color(0xFF00B5AD), // Matching App Color
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(35),
              bottomRight: Radius.circular(35),
            ),
          ),
        ),

        // Background decorative circles (optional for more depth)
        Positioned(
          top: -20,
          right: -40,
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),

        // Top App Bar
        Positioned(
          top: tp + 12,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  Scaffold.of(context).openDrawer();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.menu_rounded, color: Color(0xFF00B5AD), size: 22),
                ),
              ),
              const Text(
                "Dashboard",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert_rounded, color: Color(0xFF00B5AD), size: 22),
              ),
            ],
          ),
        ),

        // ── Decorative Circle Behind Image ──
        Positioned(
          right: -30,
          bottom: 20,
          child: Container(
            width: size.width * 0.6,
            height: size.width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),

        // ── Doctor Image (Right Aligned) ──
        Positioned(
          right: 0,
          bottom: 0, // Sits just behind the top edge of the glass cards
          child: Image.asset(
            'assets/images/doctor2.png',
            height: headerHeight * 0.75, // Scale nicely inside the header
            fit: BoxFit.contain,
            alignment: Alignment.bottomRight,
          ),
        ),

        // ── Content: Details (Left) ──
        Positioned(
          top: tp + 80,
          left: 20,
          right: size.width * 0.45, // Prevent text from overlapping the doctor image
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.isNotEmpty ? user : "User",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "Active Session",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Glassmorphism Overlapping Cards ──
        // Sitting exactly on the bottom edge
        Positioned(
          bottom: -25,
          left: 20,
          right: 20,
          child: Row(
            children: [
              _buildStatCard(modulesCount.toString(), "Modules"),
              const SizedBox(width: 12),
              _buildStatCard("Online", "Status"),
              const SizedBox(width: 12),
              _buildStatCard("Access", "Verified"),
            ],
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
          color: Colors.white.withValues(alpha: 0.85), // Glass effect
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A202C),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF718096),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final _NavCard card;
  final int index;
  const _ModuleCard({required this.card, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Simple push navigation works safely without requiring private state access
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => _getScreen(card.drawerIndex)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDF2F7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Mono Index
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Color(0xFFCBD5E0),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon box
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F6), // Very light teal
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    card.icon,
                    size: 18,
                    color: const Color(0xFF00B5AD), // Match app theme
                  ),
                ),
                const Spacer(),
                Text(
                  card.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3748),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            // Tiny Arrow
            const Positioned(
              bottom: 0,
              right: 0,
              child: Icon(
                Icons.north_east_rounded,
                size: 12,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0: return const dash.DashboardScreen();
      case 5: return const EmergencyTreatmentScreen();
      case 3: return const OpdReceiptScreen();
      case 4: return const OpdRecordsScreen();
      case 8: return const MrDetailsScreen();
      case 1: return const ConsultationScreen();
      case 9: return const PrescriptionScreen();
      case 12: return const EyePrescriptionScreen();
      case 6: return const ConsultantPaymentsScreen();
      case 2: return const ExpensesScreen();
      case 7: return const ShiftManagementScreen();
      default: return const dash.DashboardScreen();
    }
  }
}
