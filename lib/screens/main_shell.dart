import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../custum widgets/drawer/base_scaffold.dart';
import '../providers/dashboard/dashboard_provider.dart';
import '../providers/opd/consultation_provider/cunsultation_provider.dart';
import '../core/providers/permission_provider.dart';
import '../core/permissions/permission_keys.dart';
import 'dashboard/dashboard.dart' as dash;
import 'emergency_treatment/emergency_treatment.dart';
import 'cunsultations/cunsultations.dart';
import 'mr_details/mr_details.dart';
import 'home/home_screen.dart' as landing;

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentBtmIndex = 0;

  @override
  void initState() {
    super.initState();
    // Default is index 0 (Home)
  }

  // The main screens for the bottom navigation
  final List<Widget> _screens = [
    const landing.HomeScreen(useScaffold: false),
    const dash.DashboardScreen(useScaffold: false),
    const EmergencyTreatmentScreen(useScaffold: false),
    const ConsultationScreen(useScaffold: false),
    const MrDetailsScreen(useScaffold: false),
  ];

  final List<String> _titles = [
    'Home',
    'Dashboard',
    'Emergency Treatment',
    'Consultations',
    'MR Details',
  ];

  // Mapping bottom index to drawer index for consistent state
  final List<int> _drawerIndices = [21, 0, 5, 1, 8];

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: _titles[_currentBtmIndex],
      drawerIndex: _drawerIndices[_currentBtmIndex],
      showAppBar: _currentBtmIndex != 0 && _currentBtmIndex != 2 && _currentBtmIndex != 3,
      onBottomNavTap: (drawerIndex) {
        // Convert drawer index to bottom index
        final btmIndex = _drawerIndices.indexOf(drawerIndex);
        if (btmIndex < 0) return;

        if (btmIndex == 1) { // Dashboard
          final prov = context.read<DashboardProvider>();
          prov.resetToToday();
          prov.resetLoading();
          prov.refresh();
        } else if (btmIndex == 3) { // Consultation
          final prov = context.read<ConsultationProvider>();
          prov.resetLoading();
          prov.loadDoctors();
          prov.loadAppointments();
        }
        setState(() {
          _currentBtmIndex = btmIndex;
        });
      },
      body: IndexedStack(
        index: _currentBtmIndex,
        children: _screens,
      ),
    );
  }
}
