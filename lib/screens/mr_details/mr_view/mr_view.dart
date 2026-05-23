import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../custum widgets/drawer/base_scaffold.dart';
import '../../../models/mr_model/mr_patient_model.dart';
import '../../../providers/mr_provider/mr_provider.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/permissions/permission_keys.dart';
import '../../../custum widgets/custom_loader.dart';
import '../mr_details.dart';
import '../../opd_reciepts/opd_reciept.dart';

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
    final provider = context.watch<MrProvider>();
    final perm = context.watch<PermissionProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    if (!perm.hasResource('MR.DATA_VIEW')) {
      return const Center(child: Text("Access Denied"));
    }

    return Container(
      color: const Color(0xFFF0F4F8),
      child: provider.isLoading
          ? const Center(child: CustomLoader(color: Color(0xFF00B5AD)))
          : provider.errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(provider.errorMessage!,
                style: TextStyle(fontSize: 14, color: Colors.red.shade400)),
            const SizedBox(height: 12),
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
          : RefreshIndicator(
        onRefresh: () => provider.loadPatients(),
        color: const Color(0xFF00B5AD),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : screenWidth * 0.04,
            vertical: isMobile ? 12 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubHeader(context, isMobile),
              const SizedBox(height: 10),
              _buildSearchBar(context, isMobile),
              const SizedBox(height: 10),
              _buildStatsBar(context, isMobile),
              const SizedBox(height: 10),

              // Table card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Registered Patients',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          if (provider.isFetchingMore)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00B5AD),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    SizedBox(
                      height: 480,
                      child: _PatientTable(isMobile: isMobile),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubHeader(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B5AD), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B5AD).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.people_alt_rounded, color: Colors.white, size: isMobile ? 22 : 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MR Data View',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 15 : 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Master Patient Index',
                  style: TextStyle(color: Colors.white70, fontSize: isMobile ? 11 : 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _SearchField()),
          const SizedBox(width: 8),
          _IconActionButton(
            icon: Icons.refresh_rounded,
            onTap: () => context.read<MrProvider>().clearSearch(),
          ),
          if (context.read<PermissionProvider>().can(Perm.mrDataViewPrint)) ...[
            const SizedBox(width: 6),
            _IconActionButton(icon: Icons.print_outlined, onTap: () {}),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context, bool isMobile) {
    final provider = context.watch<MrProvider>();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 14,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B5AD), Color(0xFF00897B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B5AD).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.people_outline, color: Colors.white, size: isMobile ? 20 : 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL PATIENTS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                _formatNumber(provider.totalCount),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 22 : 26,
                ),
              ),
              Text(
                '${_formatNumber(provider.totalPatients)} loaded',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provider.isFetchingMore) ...[
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  provider.hasMorePages ? 'Loading...' : 'All loaded ✓',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isMobile ? 10 : 11,
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
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
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
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search by MR No, Name, Phone...',
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
        prefixIcon: const Icon(Icons.search, color: Color(0xFFBDBDBD), size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00B5AD), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF718096)),
      ),
    );
  }
}

// ─── Patient Table with Infinite Scroll ──────────────────────────────────────
class _PatientTable extends StatefulWidget {
  final bool isMobile;
  const _PatientTable({required this.isMobile});

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
            Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFCBD5E0)),
            SizedBox(height: 10),
            Text(
              'No patients found',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF718096)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Fixed Header ──
        _buildHeader(),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // ── Scrollable Rows ──
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: patients.length + (provider.isFetchingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == patients.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00B5AD),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Loading more...',
                          style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
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
                isMobile: widget.isMobile,
              );
            },
          ),
        ),

        // ── Footer ──
        if (!provider.hasMorePages && patients.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF7FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Center(
              child: Text(
                'All ${_formatNumber(provider.totalCount)} patients loaded',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    if (widget.isMobile) {
      // Mobile: only show essential columns
      return Container(
        color: const Color(0xFFF7FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: const Row(
          children: [
            _HeaderCell('Sr #', flex: 1),
            _HeaderCell('MR No', flex: 2),
            _HeaderCell('Patient Name', flex: 4),
            // _HeaderCell('Phone', flex: 3),
            _HeaderCell('Gender', flex: 2),
            _HeaderCell('Actions', flex: 2, align: TextAlign.center),
          ],
        ),
      );
    }

    // Desktop/Tablet: full columns with horizontal scroll
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 1000,
        color: const Color(0xFFF7FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: const Row(
          children: [
            _HeaderCell('Sr #', flex: 1),
            _HeaderCell('MR No', flex: 2),
            _HeaderCell('Patient', flex: 3),
            _HeaderCell('Guardian', flex: 2),
            // _HeaderCell('Phone', flex: 2),
            _HeaderCell('CNIC', flex: 2),
            _HeaderCell('Age', flex: 1),
            _HeaderCell('Gender', flex: 1),
            _HeaderCell('City', flex: 2),
            _HeaderCell('Actions', flex: 2, align: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return n.toString();
  }
}

// ─── Header Cell ─────────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;

  const _HeaderCell(this.text, {this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 10,
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
  final bool isMobile;

  const _PatientRow({
    required this.index,
    required this.patient,
    required this.isEven,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return isMobile ? _buildMobileRow(context) : _buildDesktopRow(context);
  }

  // ── Mobile: compact row, no horizontal scroll ──
  Widget _buildMobileRow(BuildContext context) {
    return Container(
      color: isEven ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // Sr No
          SizedBox(
            width: 30,
            child: Text(
              index.toString(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF718096)),
            ),
          ),
          const SizedBox(width: 4),
          // MR No
          SizedBox(
            width: 54,
            child: Text(
              patient.mrNumber,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF00B5AD),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName.isEmpty ? '-' : patient.fullName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A202C),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (patient.phoneNumber.isNotEmpty)
                  Text(
                    patient.phoneNumber,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF718096)),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 0),
          // Gender
          SizedBox(
            width: 40,
            child: _GenderBadge(gender: patient.gender),
          ),
          const SizedBox(width: 29),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIcon(
                icon: Icons.visibility_outlined,
                color: const Color(0xFF00B5AD),
                onTap: () {
                  context.read<MrProvider>().selectPatient(patient);
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const MrDetailsScreen(),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
              if (context.read<PermissionProvider>().can(Perm.opdReceiptCreate)) ...[
                const SizedBox(width: 4),
                _ActionIcon(
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFF38A169),
                  onTap: () {
                    context.read<MrProvider>().selectPatient(patient);
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const OpdReceiptScreen(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Desktop: full columns with horizontal scroll wrapper ──
  Widget _buildDesktopRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1000,
        child: Container(
          color: isEven ? Colors.white : const Color(0xFFFAFAFA),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(index.toString(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
              ),
              Expanded(
                flex: 2,
                child: Text(patient.mrNumber,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A202C))),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  patient.fullName.isEmpty ? '-' : patient.fullName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A202C)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  patient.guardianName.isEmpty ? '-' : patient.guardianName,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  patient.phoneNumber.isEmpty ? '-' : patient.phoneNumber,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  patient.cnic.isEmpty ? '-' : patient.cnic,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  patient.age != null ? patient.age.toString() : '-',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
                ),
              ),
              Expanded(flex: 1, child: _GenderBadge(gender: patient.gender)),
              Expanded(
                flex: 2,
                child: Text(
                  patient.city.isEmpty ? '-' : patient.city,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
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
                      onTap: () {
                        context.read<MrProvider>().selectPatient(patient);
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const MrDetailsScreen(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
                    ),
                    if (context.read<PermissionProvider>().can(Perm.opdReceiptCreate)) ...[
                      const SizedBox(width: 4),
                      _ActionIcon(
                        icon: Icons.receipt_long_outlined,
                        color: const Color(0xFF38A169),
                        onTap: () {
                          context.read<MrProvider>().selectPatient(patient);
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const OpdReceiptScreen(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
    final isFemale = gender.toLowerCase() == 'female' || gender.toLowerCase() == 'f';
    final isMale = gender.toLowerCase() == 'male' || gender.toLowerCase() == 'm';

    final color = isFemale
        ? const Color(0xFFED64A6)
        : isMale
        ? const Color(0xFF00B5AD)
        : const Color(0xFF718096);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        gender.isEmpty ? '-' : gender,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ─── Action Icon ──────────────────────────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}