import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../models/prescription_model/prescription_model.dart';
import '../../models/vitals_model/vitals_model.dart';
import '../../providers/prescription_provider/prescription_provider.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../custum widgets/custom_loader.dart';
import '../../custum widgets/animations/animations.dart';
import 'package:animate_do/animate_do.dart';
import 'widgets/lab_values_sheet.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const kTeal = Color(0xFF00B5AD);
const kTealLight = Color(0xFFE0F7F5);
const kBorder = Color(0xFFCCECE9);
const kBg = Color(0xFFF8F9FA);
const kTextDark = Color(0xFF2D3748);
const kTextMid = Color(0xFF718096);
const kWhite = Colors.white;

// ─── Main Screen ─────────────────────────────────────────────────────────────
class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<PrescriptionProvider>();
        provider.clearForm();
        provider.loadConsultationPatients();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrescriptionProvider>();
    final isMobile = MediaQuery.of(context).size.width < 900;

    return BaseScaffold(
      title: 'Prescription',
      drawerIndex: 9,
      showNotificationIcon: true,
      body: CustomPageTransition(
        child: Stack(
          children: [
            Column(
              children: [
                if (isMobile) _ConsultationDropdown(provider: provider),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 9,
                        child: _PrescriptionBody(tabController: _tabController, provider: provider),
                      ),
                      if (!isMobile)
                        const Expanded(
                          flex: 3,
                          child: _ConsultationSidebar(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (provider.isSaving || provider.isLoading)
              const CustomLoader(color: kTeal,),
          ],
        ),
      ),
    );
  }
}

class _ConsultationDropdown extends StatelessWidget {
  final PrescriptionProvider provider;
  const _ConsultationDropdown({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          isExpanded: true,
          hint: Row(
            children: [
              const Icon(Icons.people_outline, size: 18, color: kTeal),
              const SizedBox(width: 8),
              Text(provider.isLoadingPatients ? 'Loading patients...' : 'Select Consultation Patient', 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextDark)),
            ],
          ),
          value: null,
          onChanged: (val) => provider.selectConsultationPatient(val),
          items: provider.consultationPatients.map((p) {
            return DropdownMenuItem(
              value: p,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(p['patient_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      if (p['token_number'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kTeal,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: kTeal.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1)),
                            ],
                          ),
                          child: Text(
                            'TOKEN #${p['token_number']}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text('MR: ${p['patient_mr_number']} | ${p['receipt_id']}', style: const TextStyle(fontSize: 10, color: kTextMid)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ConsultationSidebar extends StatefulWidget {
  const _ConsultationSidebar();

  @override
  State<_ConsultationSidebar> createState() => _ConsultationSidebarState();
}

class _ConsultationSidebarState extends State<_ConsultationSidebar> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrescriptionProvider>();
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_ind, color: kWhite, size: 16),
                const SizedBox(width: 8),
                const Text('Consultation Patients', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: kWhite.withOpacity(0.8), size: 16),
                  onPressed: provider.loadConsultationPatients,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoadingPatients
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : provider.consultationPatients.isEmpty
                    ? const _SidebarPlaceholder(icon: Icons.history, message: 'No consultations today')
                    : ListView.separated(
                        itemCount: provider.consultationPatients.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final p = provider.consultationPatients[idx];
                          return ListTile(
                            dense: true,
                            onTap: () => provider.selectConsultationPatient(p),
                             title: Row(
                               children: [
                                 Expanded(child: Text(p['patient_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                 if (p['sync_status'] == 'pending') ...[
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                     decoration: BoxDecoration(
                                       color: Colors.orange.shade50,
                                       borderRadius: BorderRadius.circular(4),
                                       border: Border.all(color: Colors.orange.shade200),
                                     ),
                                     child: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Icon(Icons.cloud_off_rounded, size: 10, color: Colors.orange.shade700),
                                         const SizedBox(width: 4),
                                         Text('Pending', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                                       ],
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                 ] else if (p['token_number'] != null) ...[
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                     decoration: BoxDecoration(
                                       color: kTeal,
                                       borderRadius: BorderRadius.circular(12),
                                       boxShadow: [
                                         BoxShadow(color: kTeal.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1)),
                                       ],
                                     ),
                                     child: Text(
                                       '#${p['token_number']}',
                                       style: const TextStyle(
                                         fontSize: 9,
                                         fontWeight: FontWeight.w900,
                                         color: Colors.white,
                                       ),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                 ],
                               ],
                             ),
                            subtitle: Text(p['service_detail'] ?? '', style: const TextStyle(fontSize: 10, color: kTextMid)),
                            trailing: Text(p['patient_mr_number']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SidebarPlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;
  const _SidebarPlaceholder({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: kTextMid.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontSize: 11, color: kTextMid.withOpacity(0.6))),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _PrescriptionBody extends StatelessWidget {
  final TabController tabController;
  final PrescriptionProvider provider;
  const _PrescriptionBody({required this.tabController, required this.provider});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final isTablet = screenW > 600;
    final hPad = screenW * 0.04;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: hPad,
        right: hPad,
        top: mq.size.height * 0.015,
        bottom: mq.size.height * 0.12, // space for bottom nav bar
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date strip ────────────────────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 100), child: _DateStrip(isTablet: isTablet)),
          SizedBox(height: mq.size.height * 0.014),

          // ── Patient Info ──────────────────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 200), child: _PatientInfoCard(isTablet: isTablet, screenW: screenW, provider: provider)),
          SizedBox(height: mq.size.height * 0.018),

          // ── Tabs ──────────────────────────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 300), child: _TabSection(tabController: tabController, isTablet: isTablet, provider: provider)),
          SizedBox(height: mq.size.height * 0.022),

          // ── Save & Print Button (bottom, full width) ──────────────────────
          FadeInUp(delay: const Duration(milliseconds: 400), child: _SavePrintButton(isTablet: isTablet, provider: provider)),
          SizedBox(height: mq.size.height * 0.01),
        ],
      ),
    );
  }
}

// ─── Date Strip ───────────────────────────────────────────────────────────────
class _DateStrip extends StatelessWidget {
  final bool isTablet;
  const _DateStrip({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kTealLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, color: kTeal, size: 15),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formattedDate(),
                style: TextStyle(
                  color: kTeal,
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 11,
                ),
              ),
              Text(
                _formattedTime(),
                style: TextStyle(
                  color: kTeal.withOpacity(0.8),
                  fontSize: isTablet ? 11 : 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String _formattedTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ─── Save & Print Button ──────────────────────────────────────────────────────
class _SavePrintButton extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _SavePrintButton({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    final perm = context.read<PermissionProvider>();
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 52 : 48,
      child: ElevatedButton.icon(
        onPressed: provider.currentPatient == null ? null : () async {
          final success = await provider.savePrescription(
            doctorName: perm.fullName ?? 'Doctor',
            doctorSrlNo: 1, // Defaulting for now
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'Prescription saved successfully' : 'Failed to save prescription'),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
        },
        icon: provider.isSaving 
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
          : const Icon(Icons.print_outlined, size: 18),
        label: Text(
          'Save & Print',
          style: TextStyle(
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kTeal,
          foregroundColor: kWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}

// ─── Patient Info Card ────────────────────────────────────────────────────────
class _PatientInfoCard extends StatelessWidget {
  final bool isTablet;
  final double screenW;
  final PrescriptionProvider provider;
  const _PatientInfoCard({required this.isTablet, required this.screenW, required this.provider});

  @override
  Widget build(BuildContext context) {
    final patient = provider.currentPatient;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: kTeal, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Patient Information',
                  style: TextStyle(
                    color: kTextDark,
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 14 : 13,
                  ),
                ),
                if (provider.tokenNumber != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kTeal, Color(0xFF00968F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: kTeal.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'TOKEN #${provider.tokenNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (provider.isLoading)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kTeal)),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: isTablet ? _tabletGrid(context, patient) : _mobileGrid(context, patient),
          ),
          const SizedBox(height: 14),
          // Vitals
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            // child: _VitalsSection(isTablet: isTablet, provider: provider),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _mobileGrid(BuildContext context, PatientModel? patient) {
    final doctorName = provider.doctorName ?? (provider.currentPatient != null ? (context.read<PermissionProvider>().fullName ?? 'Doctor') : 'Enter doctor name');
    return Column(
      children: [
        _FieldRow(fields: [
          _FieldData('MR No.*', 'Enter MR no.', required: true, initialValue: patient?.mrNumber, onSearch: (val) => provider.searchPatient(val)),
          _FieldData('Patient Name', '', initialValue: patient?.fullName, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          _FieldData('Age / Gender', '', initialValue: patient != null ? '${patient.age ?? ''} / ${patient.gender}' : '', readOnly: true),
          _FieldData('Phone', '', initialValue: patient?.phoneNumber, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          _FieldData('Father / Husband', '', initialValue: patient?.guardianName, readOnly: true),
          _FieldData('Address', '', initialValue: patient?.address, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          _FieldData('Consultant', 'Consultant name', initialValue: doctorName, readOnly: true),
          _FieldData('Receipt ID', 'Receipt ID', initialValue: provider.receiptId, controller: provider.vitalControllers['receiptId']),
        ]),
        const SizedBox(height: 12),
        _VitalsSummaryBox(vitals: provider.currentVitals),
      ],
    );
  }

  Widget _tabletGrid(BuildContext context, PatientModel? patient) {
    final doctorName = provider.doctorName ?? (provider.currentPatient != null ? (context.read<PermissionProvider>().fullName ?? 'Doctor') : 'Enter doctor name');
    return Column(
      children: [
        Row(children: [
          Expanded(child: _InputField(label: 'MR No.*', hint: 'Enter MR no.', required: true, initialValue: patient?.mrNumber, onSubmitted: (val) => provider.searchPatient(val))),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Patient Name', hint: '', initialValue: patient?.fullName, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Age / Gender', hint: '', initialValue: patient != null ? '${patient.age ?? ''} / ${patient.gender}' : '', readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Phone', hint: '', initialValue: patient?.phoneNumber, readOnly: true)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _InputField(label: 'Father / Husband', hint: '', initialValue: patient?.guardianName, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Address', hint: '', initialValue: patient?.address, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Consultant', hint: 'Consultant name', initialValue: doctorName, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Receipt ID', hint: 'Receipt ID', initialValue: provider.receiptId, controller: provider.vitalControllers['receiptId'])),
        ]),
        const SizedBox(height: 12),
        _VitalsSummaryBox(vitals: provider.currentVitals),
      ],
    );
  }
}

// ─── Vitals Summary Widget ────────────────────────────────────────────────────
class _VitalsSummaryBox extends StatelessWidget {
  final VitalsModel? vitals;
  const _VitalsSummaryBox({this.vitals});

  @override
  Widget build(BuildContext context) {
    if (vitals == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // slate-100
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.amber),
            SizedBox(width: 8),
            Text('No vitals recorded for this visit', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    final items = [
      {'label': 'Weight', 'val': '${vitals!.weight ?? '—'}', 'unit': 'kg'},
      {'label': 'Height', 'val': '${vitals!.height ?? '—'}', 'unit': 'in'},
      {'label': 'BMI', 'val': '${vitals!.bmi ?? '—'}', 'unit': ''},
      {'label': 'B.P.', 'val': (vitals!.systolic != null && vitals!.diastolic != null) ? '${vitals!.systolic}/${vitals!.diastolic}' : '—', 'unit': 'mmHg'},
      {'label': 'Pulse', 'val': '${vitals!.pulse ?? '—'}', 'unit': 'bpm'},
      {'label': 'SpO2', 'val': '${vitals!.spo2 ?? '—'}', 'unit': '%'},
      {'label': 'Temp', 'val': '${vitals!.temperature ?? '—'}', 'unit': '°F'},
      {'label': 'Pain', 'val': '${vitals!.painScale}', 'unit': '/10'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // slate-50
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBEAFE)), // blue-100
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 14, color: Color(0xFF3B82F6)), // blue-500
              SizedBox(width: 6),
              Text('VITALS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, lbc) {
            final sw = MediaQuery.of(context).size.width;
            final isT = sw > 600;
            final crossCount = isT ? 8 : 4;
            // Lower aspect ratio means more height per cell
            // 1.2 for small phones, 1.4 for others
            final aspectRatio = isT ? 1.6 : (sw < 380 ? 1.2 : 1.5);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: aspectRatio,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF1F5F9)), // slate-100
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(it['label']!.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))), // slate-400
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(it['val']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: it['val'] == '—' ? const Color(0xFFCBD5E1) : const Color(0xFF334155))), // slate-700
                            if (it['unit'] != '' && it['val'] != '—') ...[
                              const SizedBox(width: 2),
                              Text(it['unit']!, style: const TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

// ─── Field Row (2 columns) ────────────────────────────────────────────────────
class _FieldData {
  final String label;
  final String hint;
  final bool required;
  final String? initialValue;
  final bool readOnly;
  final Function(String)? onSearch;
  final TextEditingController? controller;
  const _FieldData(this.label, this.hint, {this.required = false, this.initialValue, this.readOnly = false, this.onSearch, this.controller});
}

class _FieldRow extends StatelessWidget {
  final List<_FieldData> fields;
  const _FieldRow({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key > 0 ? 10 : 0),
            child: _InputField(
              label: e.value.label,
              hint: e.value.hint,
              required: e.value.required,
              initialValue: e.value.initialValue,
              readOnly: e.value.readOnly,
              onSubmitted: e.value.onSearch,
              controller: e.value.controller,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Input Field ──────────────────────────────────────────────────────────────
class _InputField extends StatefulWidget {
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final String? initialValue;
  final bool readOnly;
  final Function(String)? onSubmitted;
  final TextEditingController? controller;

  const _InputField({
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.initialValue,
    this.readOnly = false,
    this.onSubmitted,
    this.controller,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_InputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue && widget.initialValue != null) {
      _ctrl.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final labelSize = isTablet ? 12.0 : 11.0;
    final inputSize = isTablet ? 13.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: widget.label,
            style: TextStyle(
              color: kTextMid,
              fontSize: labelSize,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
            ),
            children: widget.required
                ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                : [],
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _ctrl,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(fontSize: inputSize, color: widget.readOnly ? kTextMid : kTextDark),
          decoration: InputDecoration(
            hintText: widget.hint.isNotEmpty ? widget.hint : null,
            hintStyle: TextStyle(
              color: kTextMid.withOpacity(0.55),
              fontSize: inputSize,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: widget.maxLines > 1 ? 10 : 9,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: kTeal, width: 1.5),
            ),
            filled: true,
            fillColor: widget.readOnly ? Colors.grey.shade50 : kWhite,
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ─── Vitals Section ───────────────────────────────────────────────────────────
// class _VitalsSection extends StatelessWidget {
//   final bool isTablet;
//   final PrescriptionProvider provider;
//   const _VitalsSection({required this.isTablet, required this.provider});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: kBg,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: kBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'VITALS',
//             style: TextStyle(
//               color: kTextMid,
//               fontSize: isTablet ? 11 : 10,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 1.1,
//             ),
//           ),
//           const SizedBox(height: 10),
//           // Always 3 columns on mobile, 6 on tablet
//           if (isTablet)
//             Row(
//               children: [
//                 Expanded(child: _VitalField(label: 'Temp', hint: '°F', controller: provider.vitalControllers['temp']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'B.P.', hint: '120/80', controller: provider.vitalControllers['bp']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Pulse', hint: 'bpm', controller: provider.vitalControllers['pulse']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Weight', hint: 'kg', controller: provider.vitalControllers['weight']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Height', hint: 'ft', controller: provider.vitalControllers['height']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Blood', hint: 'A+', controller: provider.vitalControllers['blood']!)),
//               ],
//             )
//           else ...[
//             Row(
//               children: [
//                 Expanded(child: _VitalField(label: 'Temp', hint: '°F', controller: provider.vitalControllers['temp']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'B.P.', hint: '120/80', controller: provider.vitalControllers['bp']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Pulse', hint: 'bpm', controller: provider.vitalControllers['pulse']!)),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Expanded(child: _VitalField(label: 'Weight', hint: 'kg', controller: provider.vitalControllers['weight']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Height', hint: 'ft', controller: provider.vitalControllers['height']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Blood', hint: 'A+', controller: provider.vitalControllers['blood']!)),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
//
// class _VitalField extends StatelessWidget {
//   final String label;
//   final String hint;
//   final TextEditingController controller;
//   const _VitalField({required this.label, required this.hint, required this.controller});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             color: kTextMid,
//             fontSize: 10,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         const SizedBox(height: 3),
//         TextField(
//           controller: controller,
//           style: const TextStyle(fontSize: 12, color: kTextDark),
//           decoration: InputDecoration(
//             hintText: hint,
//             hintStyle: TextStyle(
//               color: kTextMid.withOpacity(0.65),
//               fontSize: 11,
//             ),
//             contentPadding:
//             const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: kBorder),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: kTeal, width: 1.5),
//             ),
//             filled: true,
//             fillColor: kWhite,
//             isDense: true,
//           ),
//         ),
//       ],
//     );
//   }
// }

// ─── Tab Section ─────────────────────────────────────────────────────────────
class _TabSection extends StatelessWidget {
  final TabController tabController;
  final bool isTablet;
  final PrescriptionProvider provider;
  const _TabSection({required this.tabController, required this.isTablet, required this.provider});

  static const _tabs = [
    [Icons.notes_outlined, 'Notes'],
    [Icons.medical_information_outlined, 'Diagnosis'],
    [Icons.science_outlined, 'Investigations'],
    [Icons.medication_outlined, 'Medicines'],
    [Icons.assignment_outlined, 'Instructions'],
    [Icons.history_outlined, 'Old Visits'],
    [Icons.biotech_outlined, 'Lab Values'],
    // [Icons.people_outline, 'Waiting List'],
  ];

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: kTeal,
              unselectedLabelColor: kTextMid,
              indicatorColor: kTeal,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontSize: isTablet ? 13 : 11,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: isTablet ? 13 : 11,
                fontWeight: FontWeight.w400,
              ),
              padding: EdgeInsets.zero,
              tabs: _tabs
                  .map(
                    (t) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t[0] as IconData,
                          size: isTablet ? 16 : 14),
                      const SizedBox(width: 5),
                      Text(t[1] as String),
                    ],
                  ),
                ),
              )
                  .toList(),
            ),
          ),

          // Tab views — intrinsic height via IndexedStack
          _TabViewBody(tabController: tabController, isTablet: isTablet, provider: provider),
        ],
      ),
    );
  }
}

// ─── Tab View Body ────────────────────────────────────────────────────────────
class _TabViewBody extends StatefulWidget {
  final TabController tabController;
  final bool isTablet;
  final PrescriptionProvider provider;
  const _TabViewBody(
      {required this.tabController, required this.isTablet, required this.provider});

  @override
  State<_TabViewBody> createState() => _TabViewBodyState();
}

class _TabViewBodyState extends State<_TabViewBody> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!widget.tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.tabController,
      builder: (context, child) {
        return switch (widget.tabController.index) {
          0 => _NotesTab(isTablet: widget.isTablet, provider: widget.provider),
          1 => _DiagnosisTab(isTablet: widget.isTablet, provider: widget.provider),
          2 => _InvestigationsTab(isTablet: widget.isTablet, provider: widget.provider),
          3 => _MedicinesTab(isTablet: widget.isTablet, provider: widget.provider),
          4 => _InstructionsTab(isTablet: widget.isTablet, provider: widget.provider),
          5 => _OldVisitsTab(isTablet: widget.isTablet, provider: widget.provider),
          6 => Padding(
                padding: const EdgeInsets.all(16.0),
                child: LabValuesSheet(
                  mrNumber: widget.provider.currentPatient?.mrNumber ?? '',
                  receiptId: widget.provider.receiptId,
                  readOnly: true,
                ),
              ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

// ─── Investigations Tab ─────────────────────────────────────────────────────
class _InvestigationsTab extends StatefulWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _InvestigationsTab({required this.isTablet, required this.provider});

  @override
  State<_InvestigationsTab> createState() => _InvestigationsTabState();
}

class _InvestigationsTabState extends State<_InvestigationsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.loadTests();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.provider.isLoadingTests) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kTeal)));
    }

    final labTests = widget.provider.labTests.where((t) => 
      t['test_name'].toString().toLowerCase().contains(widget.provider.labSearch.toLowerCase())).toList();
    
    // Support variants like X-Ray, Xray, X Ray
    final xrayTests = widget.provider.radiologyTests.where((t) {
      final cat = t['test_category']?.toString().toLowerCase() ?? '';
      final matchesCat = cat.contains('x-ray') || cat.contains('xray') || cat.contains('x ray');
      final matchesSearch = t['test_name'].toString().toLowerCase().contains(widget.provider.xraySearch.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    // Support variants like Ultrasound, Ultra Sound
    final usTests = widget.provider.radiologyTests.where((t) {
      final cat = t['test_category']?.toString().toLowerCase() ?? '';
      final matchesCat = cat.contains('ultrasound') || cat.contains('ultra sound');
      final matchesSearch = t['test_name'].toString().toLowerCase().contains(widget.provider.ultrasoundSearch.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    // Support variants like CT-Scan, CT Scan, CTScan
    final ctTests = widget.provider.radiologyTests.where((t) {
      final cat = t['test_category']?.toString().toLowerCase() ?? '';
      final matchesCat = cat.contains('ct-scan') || cat.contains('ct scan') || cat.contains('ctscan');
      final matchesSearch = t['test_name'].toString().toLowerCase().contains(widget.provider.ctSearch.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _testSection('LAB TESTS', labTests, 'lab', Icons.science_outlined, Colors.blue, 
            widget.provider.labSearch, widget.provider.updateLabSearch),
          const SizedBox(height: 20),
          _testSection('X-RAYS', xrayTests, 'xray', Icons.settings_overscan, Colors.indigo,
            widget.provider.xraySearch, widget.provider.updateXraySearch),
          const SizedBox(height: 20),
          _testSection('ULTRA SOUND', usTests, 'ultrasound', Icons.waves, Colors.green,
            widget.provider.ultrasoundSearch, widget.provider.updateUltrasoundSearch),
          const SizedBox(height: 20),
          _testSection('CT SCAN', ctTests, 'ct_scan', Icons.biotech, Colors.amber,
            widget.provider.ctSearch, widget.provider.updateCtSearch),
        ],
      ),
    );
  }

  Widget _testSection(String title, List<dynamic> tests, String type, IconData icon, Color color, 
      String searchQuery, Function(String) onSearch) {
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color.withOpacity(0.8), letterSpacing: 1.1)),
              ],
            ),
            if (tests.isNotEmpty || searchQuery.isNotEmpty)
              SizedBox(
                width: 150,
                height: 30,
                child: TextField(
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search, size: 14),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: color, width: 1)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (tests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(searchQuery.isEmpty ? 'No data available in this category' : 'No matches found', 
              style: TextStyle(fontSize: 11, color: kTextMid.withOpacity(0.6), fontStyle: FontStyle.italic)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tests.map((t) {
              final name = t['test_name'];
              final isSelected = widget.provider.selectedInvestigations.any((i) => i.investigationType == type && i.testName == name);
              
              return FilterChip(
                label: Text(name.toString(), style: TextStyle(fontSize: 12, color: isSelected ? kTeal : kTextDark)),
                selected: isSelected,
                onSelected: (_) => widget.provider.toggleInvestigation(type, name),
                selectedColor: kTeal.withOpacity(0.1),
                checkmarkColor: kTeal,
                backgroundColor: kBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? kTeal : kBorder)),
              );
            }).toList(),
          ),
      ],
    );
  }
}


// ─── Instructions Tab ────────────────────────────────────────────────────────
class _InstructionsTab extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _InstructionsTab({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    final TextEditingController instCtrl = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: instCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add instruction...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (val) {
                    provider.addInstruction(val);
                    instCtrl.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  provider.addInstruction(instCtrl.text);
                  instCtrl.clear();
                },
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: kTeal),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.instructions.isEmpty)
            const Center(child: Text('No instructions added.', style: TextStyle(color: kTextMid, fontSize: 13)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.instructions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  tileColor: kBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  title: Text(provider.instructions[index], style: const TextStyle(fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () => provider.removeInstruction(index),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── Old Visits Tab — TREE VIEW (matches React) ──────────────────────────────
class _OldVisitsTab extends StatefulWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _OldVisitsTab({required this.isTablet, required this.provider});

  @override
  State<_OldVisitsTab> createState() => _OldVisitsTabState();
}

class _OldVisitsTabState extends State<_OldVisitsTab> {
  final Map<String, bool> _expanded = {};

  void _toggle(String key) => setState(() => _expanded[key] = !(_expanded[key] ?? false));
  bool _isExpanded(String key) => _expanded[key] ?? false;

  String _fmtDate(String? raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day.toString().padLeft(2,'0')} ${months[d.month-1]} ${d.year}';
    } catch (_) { return raw; }
  }

  bool _isUrdu(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    if (provider.isLoadingHistory) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kTeal)));
    }
    if (provider.prescriptionHistory.isEmpty) {
      return const _PlaceholderTab(label: 'No previous visits found for this patient');
    }

    final visits = provider.prescriptionHistory;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${visits.length} visit(s) found — tap a category to expand',
            style: TextStyle(fontSize: 10, color: kTextMid, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 8),

          // ─── NOTES ───
          _buildCategory(
            key: 'notes',
            title: 'Notes',
            icon: Icons.description_outlined,
            color: const Color(0xFF2563EB),
            entries: visits.where((v) =>
              (v.historyExamination ?? '').toString().isNotEmpty ||
              (v.treatment ?? '').toString().isNotEmpty ||
              (v.consultantNotes ?? '').toString().isNotEmpty ||
              (v.remarks ?? '').toString().isNotEmpty
            ).toList(),
            contentBuilder: (v) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((v.historyExamination ?? '').toString().isNotEmpty)
                  _labelValue('History', v.historyExamination),
                if ((v.treatment ?? '').toString().isNotEmpty)
                  _labelValue('Treatment', v.treatment),
                if ((v.consultantNotes ?? '').toString().isNotEmpty)
                  _labelValue('Notes', v.consultantNotes),
                if ((v.remarks ?? '').toString().isNotEmpty)
                  _labelValue('Remarks', v.remarks),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ─── DIAGNOSIS ───
          _buildCategory(
            key: 'diagnosis',
            title: 'Diagnosis',
            icon: Icons.assignment_outlined,
            color: const Color(0xFF9333EA),
            entries: visits.where((v) {
              final ans = v.diagnosis;
              return ans.isNotEmpty;
            }).toList(),
            contentBuilder: (v) {
              final answers = v.diagnosis;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: answers.map<Widget>((ans) {
                  final qText = ans.questionText.isNotEmpty ? ans.questionText : 'Q#${ans.questionId}';
                  final aText = (ans.answerDisplay ?? ans.answerText ?? ans.answerValue ?? '—').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: RichText(text: TextSpan(
                      style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontFamily: 'Roboto'),
                      children: [
                        TextSpan(text: '$qText: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        TextSpan(text: aText),
                      ],
                    )),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 4),

          // ─── INVESTIGATION ───
          _buildCategory(
            key: 'investigation',
            title: 'Investigation',
            icon: Icons.science_outlined,
            color: const Color(0xFF059669),
            entries: visits.where((v) {
              final inv = v.investigations;
              return inv.isNotEmpty;
            }).toList(),
            contentBuilder: (v) {
              final invs = v.investigations;
              return Wrap(
                spacing: 6,
                runSpacing: 4,
                children: invs.map<Widget>((inv) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: inv.testName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF065F46))),
                    TextSpan(text: ' (${inv.investigationType})', style: const TextStyle(fontSize: 9, color: Color(0xFF6EE7B7))),
                  ])),
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 4),

          // ─── MEDICINES ───
          _buildCategory(
            key: 'medicines',
            title: 'Medicines',
            icon: Icons.medication_outlined,
            color: const Color(0xFFD97706),
            entries: visits.where((v) {
              final meds = v.medicines;
              return meds.isNotEmpty;
            }).toList(),
            contentBuilder: (v) {
              final meds = v.medicines;
              return Table(
                columnWidths: const {
                  0: FixedColumnWidth(24),
                  1: FlexColumnWidth(3),
                  2: FixedColumnWidth(28),
                  3: FixedColumnWidth(28),
                  4: FixedColumnWidth(28),
                  5: FixedColumnWidth(28),
                  6: FixedColumnWidth(36),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                    children: const ['#', 'Medicine', 'M', 'A', 'E', 'N', 'Days']
                      .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(h, textAlign: h == 'Medicine' || h == '#' ? TextAlign.left : TextAlign.center,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      )).toList(),
                  ),
                  ...meds.asMap().entries.map((e) {
                    final m = e.value;
                    final idx = e.key;
                    return TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade50))),
                      children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('${idx+1}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400))),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: m.medicineName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                            if (m.isFormula) const TextSpan(text: ' (F)', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ])),
                        ),
                        _medCell(m.morning > 0 ? '${m.morning}' : '-'),
                        _medCell(m.afternoon > 0 ? '${m.afternoon}' : '-'),
                        _medCell(m.evening > 0 ? '${m.evening}' : '-'),
                        _medCell(m.night > 0 ? '${m.night}' : '-'),
                        _medCell(m.forDays.isNotEmpty ? m.forDays : '-'),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 4),

          // ─── INSTRUCTIONS ───
          _buildCategory(
            key: 'instructions',
            title: 'Instructions',
            icon: Icons.checklist_outlined,
            color: const Color(0xFFE11D48),
            entries: visits.where((v) {
              final inst = v.instructions;
              return inst.isNotEmpty;
            }).toList(),
            contentBuilder: (v) {
              final arr = v.instructions;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: arr.map<Widget>((inst) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $inst', 
                    textAlign: _isUrdu(inst) ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _medCell(String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(val, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
  );

  Widget _labelValue(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(text: TextSpan(
        style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontFamily: 'Roboto'),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          TextSpan(text: '$value'),
        ],
      )),
    );
  }

  Widget _buildCategory({
    required String key,
    required String title,
    required IconData icon,
    required Color color,
    required List<dynamic> entries,
    required Widget Function(dynamic v) contentBuilder,
  }) {
    final isOpen = _isExpanded(key);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggle(key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(isOpen ? Icons.keyboard_arrow_down : Icons.chevron_right, size: 16, color: color),
                  const SizedBox(width: 6),
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  const Spacer(),
                  Text('${entries.length} entries', style: TextStyle(fontSize: 10, color: color.withOpacity(0.6))),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No $title in any visit', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic)),
              )
            else
              ...entries.map((v) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 10, color: color.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(_fmtDate(v.createdAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        const SizedBox(width: 6),
                        Text('—', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        const SizedBox(width: 6),
                        Text(v.doctorName.isNotEmpty ? 'Dr. ${v.doctorName}' : '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: contentBuilder(v),
                    ),
                  ],
                ),
              )),
          ],
        ],
      ),
    );
  }
}


// ─── Medicines Tab ──────────────────────────────────────────────────────────
class _MedicinesTab extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _MedicinesTab({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MedModeToggle(provider: provider),
              _LanguageIndicator(provider: provider),
            ],
          ),
          const SizedBox(height: 16),
          _MedicineSearchArea(provider: provider),
          const SizedBox(height: 20),
          _MedicineTable(provider: provider),
        ],
      ),
    );
  }
}

class _MedModeToggle extends StatelessWidget {
  final PrescriptionProvider provider;
  const _MedModeToggle({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8), color: kWhite),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBtn('Medicine', 'medicine', Icons.medical_services,Color(0xFF00B5AD),),
          _buildBtn('Formula', 'formula', Icons.science, const Color(0xFF16A34A)),
        ],
      ),
    );
  }

  Widget _buildBtn(String label, String mode, IconData icon, Color activeColor) {
    final isActive = provider.medMode == mode;
    return InkWell(
      onTap: () => provider.setMedMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : kWhite,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isActive ? kWhite : kTextMid),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? kWhite : kTextMid, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _LanguageIndicator extends StatelessWidget {
  final PrescriptionProvider provider;
  const _LanguageIndicator({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.language, size: 14, color: Colors.blue),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF93C5FD))),
          child: Text(provider.inputLang == 'ur' ? 'اردو' : 'English', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
        ),
      ],
    );
  }
}

class _MedicineSearchArea extends StatefulWidget {
  final PrescriptionProvider provider;
  const _MedicineSearchArea({required this.provider});

  @override
  State<_MedicineSearchArea> createState() => _MedicineSearchAreaState();
}

class _MedicineSearchAreaState extends State<_MedicineSearchArea> {
  final TextEditingController _searchCtrl = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  final Map<String, TextEditingController> _doseCtrls = {
    'm': TextEditingController(text: '0'),
    'a': TextEditingController(text: '0'),
    'e': TextEditingController(text: '0'),
    'n': TextEditingController(text: '0'),
    'days': TextEditingController(text: '5'),
    'qty': TextEditingController(text: '1'),
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (var c in _doseCtrls.values) c.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: widget.provider.medicineSearchResults.length,
                itemBuilder: (context, index) {
                  final med = widget.provider.medicineSearchResults[index];
                  // Handle different API response structures if any
                  final name = med['medicine_name'] ?? med['name'] ?? '';
                  return ListTile(
                    dense: true,
                    title: Text(name, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      _searchCtrl.text = name;
                      _hideOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 12),
              onChanged: (val) {
                widget.provider.updateMedSearch(val);
                if (val.isNotEmpty) _showOverlay(); else _hideOverlay();
              },
              decoration: InputDecoration(
                hintText: widget.provider.medMode == 'medicine' ? 'Search medicine...' : 'Search formula...',
                prefixIcon: Icon(widget.provider.medMode == 'medicine' ? Icons.medical_services_outlined : Icons.science_outlined, size: 16),
                isDense: true,
                filled: true,
                fillColor: kWhite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _doseInput('m', 'صبح'),
                _doseInput('a', 'دوپہر'),
                _doseInput('e', 'شام'),
                _doseInput('n', 'رات'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _doseCtrls['days'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(hintText: 'Days', isDense: true, labelText: 'Days', labelStyle: const TextStyle(fontSize: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () {
                    if (_searchCtrl.text.isNotEmpty) {
                      final med = PrescriptionMedicine(
                        medicineName: _searchCtrl.text,
                        medicineId: null,
                        dosage: '${_doseCtrls['m']!.text}-${_doseCtrls['a']!.text}-${_doseCtrls['e']!.text}-${_doseCtrls['n']!.text}',
                        forDays: _doseCtrls['days']!.text,
                        qty: _doseCtrls['qty']!.text,
                        morning: double.tryParse(_doseCtrls['m']!.text) ?? 0,
                        afternoon: double.tryParse(_doseCtrls['a']!.text) ?? 0,
                        evening: double.tryParse(_doseCtrls['e']!.text) ?? 0,
                        night: double.tryParse(_doseCtrls['n']!.text) ?? 0,
                        isFormula: widget.provider.medMode == 'formula',
                      );
                      widget.provider.addMedicine(med);
                      _searchCtrl.clear();
                    }
                  },
                  style: IconButton.styleFrom(backgroundColor: kTeal, foregroundColor: kWhite),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _doseInput(String key, String urduLabel) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Column(
          children: [
            Text(urduLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTeal)),
            const SizedBox(height: 2),
            TextField(
              controller: _doseCtrls[key],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineTable extends StatelessWidget {
  final PrescriptionProvider provider;
  const _MedicineTable({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.prescribedMedicines.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(10), color: kWhite),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
            child: const Row(children: [
              Expanded(child: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 80, child: Text('Doses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 40, child: Text('Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 40),
            ]),
          ),
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.prescribedMedicines.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final med = provider.prescribedMedicines[idx];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(med.medicineName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                subtitle: Text(med.isFormula ? 'Formula' : 'Medicine', style: const TextStyle(fontSize: 9, color: kTextMid)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 80, child: Text(med.dosage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTeal))),
                    SizedBox(width: 40, child: Text('${med.forDays}D', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                    IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.red), onPressed: () => provider.removeMedicine(idx)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


// ─── Waiting List Tab ────────────────────────────────────────────────────────
// class _WaitingListTab extends StatefulWidget {
//   final bool isTablet;
//   final PrescriptionProvider provider;
//   const _WaitingListTab({required this.isTablet, required this.provider});
//
//   @override
//   State<_WaitingListTab> createState() => _WaitingListTabState();
// }
//
// class _WaitingListTabState extends State<_WaitingListTab> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       widget.provider.loadConsultationPatients();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (widget.provider.isLoadingPatients) {
//       return const Center(child: Padding(
//         padding: EdgeInsets.all(20.0),
//         child: CircularProgressIndicator(color: kTeal),
//       ));
//     }
//
//     if (widget.provider.consultationPatients.isEmpty) {
//       return const _PlaceholderTab(label: 'No patients in waiting list');
//     }
//
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: ListView.separated(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         itemCount: widget.provider.consultationPatients.length,
//         separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
//         itemBuilder: (context, index) {
//           final p = widget.provider.consultationPatients[index];
//           return ListTile(
//             leading: CircleAvatar(
//               backgroundColor: kTeal.withOpacity(0.1),
//               child: const Icon(Icons.person, color: kTeal, size: 20),
//             ),
//             title: Text(p['full_name'] ?? 'Unknown', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
//             subtitle: Text('MR: ${p['mr_number']} | Token: ${p['token_no'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
//             trailing: const Icon(Icons.chevron_right, size: 18),
//             onTap: () {
//               widget.provider.searchPatient(p['mr_number'].toString());
//             },
//           );
//         },
//       ),
//     );
//   }
// }
//

// ─── Notes Tab ────────────────────────────────────────────────────────────────
class _NotesTab extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _NotesTab({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final gap = mq.size.height * 0.016;

    return Padding(
      padding: EdgeInsets.all(mq.size.width * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextAreaField(label: 'History / Examination', hint: 'Enter history...', controller: provider.noteControllers['history']!),
          SizedBox(height: gap),
          _TextAreaField(label: 'Treatment', hint: 'Treatment plan...', controller: provider.noteControllers['treatment']!),
          SizedBox(height: gap),
          _TextAreaField(label: 'Consultant Notes', hint: 'Notes...', controller: provider.noteControllers['notes']!),
          SizedBox(height: gap),
          _TextAreaField(label: 'Remarks', hint: 'Remarks...', controller: provider.noteControllers['remarks']!),
          SizedBox(height: gap),
          _ReferToField(isTablet: isTablet, controller: provider.noteControllers['referTo']!, provider: provider),
        ],
      ),
    );
  }
}

class _TextAreaField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  const _TextAreaField({required this.label, required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final fontSize = isTablet ? 13.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: kTextDark,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 3,
          minLines: 3,
          style: TextStyle(fontSize: fontSize, color: kTextDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: kTextMid.withOpacity(0.55),
              fontSize: fontSize,
            ),
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kTeal, width: 1.5),
            ),
            filled: true,
            fillColor: kWhite,
          ),
        ),
      ],
    );
  }
}

class _ReferToField extends StatelessWidget {
  final bool isTablet;
  final TextEditingController controller;
  final PrescriptionProvider provider;
  const _ReferToField({required this.isTablet, required this.controller, required this.provider});

  @override
  Widget build(BuildContext context) {
    final fontSize = isTablet ? 13.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Refer To',
          style: TextStyle(
            color: kTextDark,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: fontSize, color: kTextDark),
            onChanged: (_) => provider.notifyListeners(), // Refresh checkbox on manual type
            decoration: InputDecoration(
              hintText: 'Refer to...',
              hintStyle: TextStyle(
                color: kTextMid.withOpacity(0.55),
                fontSize: fontSize,
              ),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kTeal, width: 1.5),
              ),
              filled: true,
              fillColor: kWhite,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => provider.setAdmissionReferral(!provider.isAdmissionReferral),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: Checkbox(
                    value: provider.isAdmissionReferral,
                    onChanged: (val) => provider.setAdmissionReferral(val ?? false),
                    activeColor: kTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: kBorder, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Refer patient to Admission',
                  style: TextStyle(
                    color: kTextMid,
                    fontSize: fontSize - 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Diagnosis Tab ────────────────────────────────────────────────────────────
class _DiagnosisTab extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _DiagnosisTab({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.diagnosisQuestions.isEmpty) {
      return const _PlaceholderTab(label: 'Select a patient to load diagnosis questions');
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: provider.diagnosisQuestions.map((q) {
          final qId = q['id'];
          final qText = q['question_text'];
          final qType = q['question_type']; // 'text' or 'choice'
          final qOptions = q['options'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qText,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: kTextDark),
                ),
                const SizedBox(height: 8),
                if (qType == 'choice' && qOptions is List)
                  Wrap(
                    spacing: 8,
                    children: qOptions.map((opt) {
                      final isSelected = provider.diagnosisAnswers[qId] == opt;
                      return ChoiceChip(
                        label: Text(opt.toString()),
                        selected: isSelected,
                        onSelected: (val) {
                          provider.setDiagnosisAnswer(qId, val ? opt : null);
                        },
                        selectedColor: kTeal.withOpacity(0.2),
                        checkmarkColor: kTeal,
                        labelStyle: TextStyle(
                          color: isSelected ? kTeal : kTextMid,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  )
                else
                  TextField(
                    onChanged: (val) => provider.setDiagnosisAnswer(qId, val),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter answer...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kTeal, width: 1.5),
                      ),
                      filled: true,
                      fillColor: kWhite,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Placeholder Tab ──────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              color: kTeal.withOpacity(0.35),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kTextMid.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}