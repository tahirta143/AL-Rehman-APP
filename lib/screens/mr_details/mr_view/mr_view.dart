import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../custum widgets/drawer/base_scaffold.dart';
import '../../../models/mr_model/mr_patient_model.dart';
import '../../../providers/mr_provider/mr_provider.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/permissions/permission_keys.dart';

class MrDataViewScreen extends StatelessWidget {
  const MrDataViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'MR Data View',
      drawerIndex: 22,
      body: const _MrDataViewBody(),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _MrDataViewBody extends StatelessWidget {
  const _MrDataViewBody();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final provider = context.watch<MrProvider>();
    final perm = context.watch<PermissionProvider>();

    if (!perm.hasResource('MR.DATA_VIEW')) {
      return const Center(child: Text("Access Denied"));
    }

    return Container(
      color: const Color(0xFFF0F4F8),
      child: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: screenWidth * 0.15,
                color: Colors.red.shade300),
            SizedBox(height: screenHeight * 0.02),
            Text(provider.errorMessage!,
                style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: Colors.red.shade400)),
            SizedBox(height: screenHeight * 0.02),
            ElevatedButton.icon(
              onPressed: () => provider.loadPatients(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B5AD),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.02,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubHeader(context),
            const SizedBox(height: 16),
            _buildSearchBar(context),
            const SizedBox(height: 16),
            _buildStatsBar(context),
            const SizedBox(height: 16),

            // Table card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Registered Patients',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A202C),
                          ),
                        ),
                        if (provider.isFetchingMore)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00B5AD),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(
                    height: 500,
                    child: _PatientTable(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSubHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B5AD), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B5AD).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MR Data View',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Master Patient Index',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  'View and search all registered patients',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search Patients',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SearchField()),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.refresh_rounded,
                onTap: () => context.read<MrProvider>().clearSearch(),
              ),
              const SizedBox(width: 8),
              if (context.read<PermissionProvider>().can(Perm.mrDataViewPrint))
                _IconActionButton(
                  icon: Icons.print_outlined,
                  onTap: () {},
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context) {
    final provider = context.watch<MrProvider>();
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B5AD), Color(0xFF00897B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B5AD).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icon ──
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.people_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // ── Total count + loaded count ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL PATIENTS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _formatNumber(provider.totalCount), // real total from API
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              Text(
                '${_formatNumber(provider.totalPatients)} loaded', // how many fetched
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Status badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provider.isFetchingMore) ...[
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  provider.hasMorePages
                      ? 'Scroll to load more'
                      : 'All loaded ✓',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      final s = n.toString();
      final thousands = s.substring(0, s.length - 3);
      final rest = s.substring(s.length - 3);
      return '$thousands,$rest';
    }
    return n.toString();
  }
}

// ─── Search Field ─────────────────────────────────────────────────────────────
class _SearchField extends StatefulWidget {
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: (v) => context.read<MrProvider>().setSearchQuery(v),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search by MR No, Name, Phone...',
        hintStyle:
        const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
        prefixIcon:
        const Icon(Icons.search, color: Color(0xFFBDBDBD), size: 20),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFF00B5AD), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}

// ─── Icon Action Button ───────────────────────────────────────────────────────
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF718096)),
      ),
    );
  }
}

// ─── Patient Table with Infinite Scroll ──────────────────────────────────────
class _PatientTable extends StatefulWidget {
  const _PatientTable();

  @override
  State<_PatientTable> createState() => _PatientTableState();
}

class _PatientTableState extends State<_PatientTable> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<MrProvider>().loadMorePatients();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MrProvider>();
    final patients = provider.patients;

    if (patients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: Color(0xFFCBD5E0)),
            SizedBox(height: 12),
            Text(
              'No patients found',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF718096)),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // ── Fixed Header ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: 1000,
              color: const Color(0xFFF7FAFC),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              child: const Row(
                children: [
                  _HeaderCell('#', flex: 1),
                  _HeaderCell('MR No', flex: 2),
                  _HeaderCell('Patient', flex: 3),
                  _HeaderCell('Guardian', flex: 2),
                  _HeaderCell('Phone', flex: 2),
                  _HeaderCell('CNIC', flex: 2),
                  _HeaderCell('Age', flex: 1),
                  _HeaderCell('Gender', flex: 1),
                  _HeaderCell('City', flex: 2),
                  _HeaderCell('Actions',
                      flex: 2, align: TextAlign.center),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Scrollable Rows ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1000,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: patients.length +
                      (provider.isFetchingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Bottom loading spinner
                    if (index == patients.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00B5AD),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Loading more patients...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return _PatientRow(
                      index: index + 1,
                      patient: patients[index],
                      isEven: index % 2 == 0,
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Footer: all loaded ──
          if (!provider.hasMorePages && patients.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF7FAFC),
                border:
                Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Center(
                child: Text(
                  'All ${_formatNumber(provider.totalCount)} patients loaded',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      final s = n.toString();
      final thousands = s.substring(0, s.length - 3);
      final rest = s.substring(s.length - 3);
      return '$thousands,$rest';
    }
    return n.toString();
  }
}

// ─── Header Cell ─────────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;

  const _HeaderCell(this.text,
      {this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF718096),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Table Row ────────────────────────────────────────────────────────────────
class _PatientRow extends StatelessWidget {
  final int index;
  final PatientModel patient;
  final bool isEven;

  const _PatientRow({
    required this.index,
    required this.patient,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text('$index',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF718096))),
          ),
          Expanded(
            flex: 2,
            child: Text(
              patient.mrNumber,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              patient.fullName.isEmpty ? '-' : patient.fullName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              patient.guardianName.isEmpty ? '-' : patient.guardianName,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF4A5568)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              patient.phoneNumber.isEmpty ? '-' : patient.phoneNumber,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF4A5568)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              patient.cnic.isEmpty ? '-' : patient.cnic,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF4A5568)),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              patient.age != null ? patient.age.toString() : '-',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF4A5568)),
            ),
          ),
          Expanded(
            flex: 1,
            child: _GenderBadge(gender: patient.gender),
          ),
          Expanded(
            flex: 2,
            child: Text(
              patient.city.isEmpty ? '-' : patient.city,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF4A5568)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionIcon(
                  icon: Icons.visibility_outlined,
                  color: const Color(0xFF00B5AD),
                  onTap: () => _showPatientDetails(context, patient),
                ),
                const SizedBox(width: 4),
                if (context.read<PermissionProvider>().can(Perm.mrDelete))
                  _ActionIcon(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFE53E3E),
                    onTap: () => _confirmDelete(context, patient),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPatientDetails(BuildContext context, PatientModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFF00B5AD).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Color(0xFF00B5AD), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName.isEmpty ? p.mrNumber : p.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MR Number: ${p.mrNumber}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF718096)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDetailTile(Icons.person, 'Gender', p.gender),
                  _buildDetailTile(
                      Icons.cake, 'Age', p.age?.toString() ?? '-'),
                  _buildDetailTile(Icons.phone, 'Phone',
                      p.phoneNumber.isEmpty ? '-' : p.phoneNumber),
                  _buildDetailTile(Icons.badge, 'CNIC',
                      p.cnic.isEmpty ? '-' : p.cnic),
                  _buildDetailTile(Icons.family_restroom, 'Guardian',
                      p.guardianName.isEmpty ? '-' : p.guardianName),
                  _buildDetailTile(Icons.location_city, 'City',
                      p.city.isEmpty ? '-' : p.city),
                  _buildDetailTile(Icons.bloodtype, 'Blood Group',
                      p.bloodGroup.isEmpty ? '-' : p.bloodGroup),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
            Icon(icon, size: 18, color: const Color(0xFF718096)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF718096))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PatientModel p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Patient?'),
        content: Text(
            'Are you sure you want to remove ${p.fullName.isEmpty ? p.mrNumber : p.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF718096)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                    child: CircularProgressIndicator()),
              );
              final success = await context
                  .read<MrProvider>()
                  .deletePatient(p.mrNumber);
              if (context.mounted) Navigator.pop(context);
              if (success) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Patient removed successfully'),
                      backgroundColor: Color(0xFF00B5AD),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  final errorMsg =
                      context.read<MrProvider>().errorMessage ??
                          'Failed to delete patient';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: Colors.red.shade400,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Gender Badge ─────────────────────────────────────────────────────────────
class _GenderBadge extends StatelessWidget {
  final String gender;
  const _GenderBadge({required this.gender});

  @override
  Widget build(BuildContext context) {
    final isFemale =
        gender.toLowerCase() == 'female' || gender.toLowerCase() == 'f';
    final isMale =
        gender.toLowerCase() == 'male' || gender.toLowerCase() == 'm';

    Color color;
    if (isFemale) {
      color = const Color(0xFFED64A6);
    } else if (isMale) {
      color = const Color(0xFF00B5AD);
    } else {
      color = const Color(0xFF718096);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        gender.isEmpty ? '-' : gender,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Action Icon ──────────────────────────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}