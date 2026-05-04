import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';
import '../../providers/dashboard/offline_dashboard_provider.dart';
import '../../core/services/camp_sync_service.dart';

const Color _teal = Color(0xFF00B5AD);
const Color _tealDark = Color(0xFF008080);

class OfflineDashboardScreen extends StatelessWidget {
  const OfflineDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Camp Dashboard',
      body: const _OfflineDashboardBody(), drawerIndex: 101,
    );
  }
}

class _OfflineDashboardBody extends StatefulWidget {
  const _OfflineDashboardBody();

  @override
  State<_OfflineDashboardBody> createState() => _OfflineDashboardBodyState();
}

class _OfflineDashboardBodyState extends State<_OfflineDashboardBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OfflineDashboardProvider>().fetchOfflineStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<OfflineDashboardProvider>();

    return RefreshIndicator(
      onRefresh: () => prov.fetchOfflineStats(),
      color: _teal,
      child: prov.isLoading
          ? const Center(child: CustomLoader(size: 50, color: _teal))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Camp Offline Data',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            DateFormat('EEEE, d MMMM').format(DateTime.now()),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                      _buildSyncButton(context),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Stats Grid ──────────────────────────────────────────────────
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 400),
                        child: _StatCard(
                          title: 'Local Patients',
                          value: prov.totalPatients.toDouble(),
                          icon: Icons.person_add_alt_1_rounded,
                          color: Colors.blue,
                        ),
                      ),
                      FadeInDown(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 100),
                        child: _StatCard(
                          title: 'Local Visits',
                          value: prov.totalVisits.toDouble(),
                          icon: Icons.history_edu_rounded,
                          color: Colors.purple,
                        ),
                      ),
                      FadeInDown(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 200),
                        child: _StatCard(
                          title: 'Vitals Recorded',
                          value: prov.totalVitals.toDouble(),
                          icon: Icons.monitor_heart_rounded,
                          color: Colors.orange,
                        ),
                      ),
                      FadeInDown(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 250),
                        child: _StatCard(
                          title: 'Prescriptions Saved',
                          value: prov.totalPrescriptions.toDouble(),
                          icon: Icons.medication_rounded,
                          color: Colors.teal,
                        ),
                      ),
                      FadeInDown(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 300),
                        child: _StatCard(
                          title: 'Unsynced Data',
                          value: prov.pendingSyncCount.toDouble(),
                          icon: Icons.sync_problem_rounded,
                          color: prov.pendingSyncCount > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // ── Action Banner ──────────────────────────────────────────────
                  if (prov.pendingSyncCount > 0)
                    FadeIn(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pending Sync', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  Text(
                                    'You have ${prov.pendingSyncCount} records waiting to be uploaded to the server.',
                                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickAction(
                    context,
                    title: 'New Patient Registration',
                    subtitle: 'Register patient offline',
                    icon: Icons.person_add_alt_1_rounded,
                    color: _teal,
                    onTap: () => Navigator.pushNamed(context, '/mr_details').then((_) => prov.fetchOfflineStats()),
                  ),
                  _buildQuickAction(
                    context,
                    title: 'Lookup Patient',
                    subtitle: 'Search in local database',
                    icon: Icons.search_rounded,
                    color: Colors.blueAccent,
                    onTap: () => Navigator.pushNamed(context, '/mr_details').then((_) => prov.fetchOfflineStats()),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSyncButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        final syncService = CampSyncService();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting bulk sync...'), duration: Duration(seconds: 1)),
        );
        final result = await syncService.bulkSync();
        if (result['success'] == true) {
          context.read<OfflineDashboardProvider>().fetchOfflineStats();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sync completed successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: ${result['message']}')),
          );
        }
      },
      icon: const Icon(Icons.sync_rounded, size: 18),
      label: const Text('Sync Now'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context,
      {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
