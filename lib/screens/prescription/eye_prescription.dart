import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../providers/prescription_provider/prescription_provider.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../models/prescription_model/prescription_model.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../models/vitals_model/vitals_model.dart';
import '../../core/utils/date_formatter.dart';
import '../../custum widgets/custom_loader.dart';
import '../../core/services/pdf_eye_prescription_service.dart';
import '../../main.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const kTeal = Color(0xFF00B5AD);
const kTealLight = Color(0xFFE0F7F5);
const kBorder = Color(0xFFCCECE9);
const kBg = Color(0xFFF8F9FA);
const kTextDark = Color(0xFF2D3748);
const kTextMid = Color(0xFF718096);
const kWhite = Colors.white;

class EyePrescriptionScreen extends StatefulWidget {
  const EyePrescriptionScreen({super.key});

  @override
  State<EyePrescriptionScreen> createState() => _EyePrescriptionScreenState();
}

class _EyePrescriptionScreenState extends State<EyePrescriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
      title: 'Eye Prescription',
      drawerIndex: 12,
      body: Stack(
        children: [
          Column(
            children: [
              if (isMobile) _EyeConsultationDropdown(provider: provider),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 9,
                      child: _EyePrescriptionBody(tabController: _tabController, provider: provider),
                    ),
                    if (!isMobile)
                      const Expanded(
                        flex: 3,
                        child: _EyeConsultationSidebar(),
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
    );
  }
}

class _EyeConsultationDropdown extends StatelessWidget {
  final PrescriptionProvider provider;
  const _EyeConsultationDropdown({required this.provider});

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
          onChanged: (val) => provider.selectConsultationPatient(val, department: 'Eye'),
          items: provider.consultationPatients.map((p) {
            return DropdownMenuItem(
              value: p,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p['patient_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

class _EyeConsultationSidebar extends StatefulWidget {
  const _EyeConsultationSidebar();

  @override
  State<_EyeConsultationSidebar> createState() => _EyeConsultationSidebarState();
}

class _EyeConsultationSidebarState extends State<_EyeConsultationSidebar> {
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
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
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kTeal))
                : provider.consultationPatients.isEmpty
                    ? const _EyeSidebarPlaceholder(icon: Icons.history, message: 'No consultations today')
                    : ListView.separated(
                        itemCount: provider.consultationPatients.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final p = provider.consultationPatients[idx];
                          final isPending = p['sync_status'] == 'pending';
                          return ListTile(
                            dense: true,
                            onTap: () => provider.selectConsultationPatient(p, department: 'Eye'),
                            title: Row(
                              children: [
                                Expanded(child: Text(p['patient_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                if (isPending)
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

class _EyeSidebarPlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EyeSidebarPlaceholder({required this.icon, required this.message});

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

class _EyePrescriptionBody extends StatelessWidget {
  final TabController tabController;
  final PrescriptionProvider provider;
  const _EyePrescriptionBody({required this.tabController, required this.provider});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, mq.size.height * 0.12),
      child: Column(
        children: [
          _EyePatientInfoCard(provider: provider),
          const SizedBox(height: 16),
          _EyeTabSection(tabController: tabController, provider: provider),
          const SizedBox(height: 20),
          _EyeSavePrintButton(provider: provider),
        ],
      ),
    );
  }
}

// ─── Patient Info (Minimal version for Eye) ───────────────────────────────────
// ─── Patient Info Card ────────────────────────────────────────────────────────
class _EyePatientInfoCard extends StatelessWidget {
  final PrescriptionProvider provider;
  const _EyePatientInfoCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider.currentPatient;
    final doctorName = provider.doctorName ?? (provider.currentPatient != null ? (context.read<PermissionProvider>().fullName ?? 'Doctor') : 'Enter doctor name');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: kTeal, size: 18),
              const SizedBox(width: 8),
              const Text('Eye Patient Information', style: TextStyle(fontWeight: FontWeight.bold, color: kTextDark)),
              const Spacer(),
              if (provider.isLoading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kTeal)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InputField(
                  label: 'MR Number',
                  hint: 'Search MR...',
                  required: true,
                  initialValue: p?.mrNumber,
                  onSubmitted: (val) => provider.searchPatient(val, department: 'Eye'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputField(label: 'Receipt ID', hint: 'Enter receipt ID', initialValue: provider.receiptId, controller: provider.vitalControllers['receiptId']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _InputField(label: 'Patient Name', hint: '', initialValue: p?.fullName, readOnly: true)),
              const SizedBox(width: 12),
              Expanded(child: _InputField(label: 'Age / Gender', hint: '', initialValue: p != null ? '${p.age ?? ''} / ${p.gender}' : '', readOnly: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _InputField(label: 'Phone', hint: '', initialValue: p?.phoneNumber, readOnly: true)),
              const SizedBox(width: 12),
              Expanded(child: _InputField(label: 'Doctor', hint: '', initialValue: doctorName, readOnly: true)),
            ],
          ),
          const SizedBox(height: 12),
          _InputField(label: 'Address', hint: '', initialValue: p?.address, readOnly: true),
          const SizedBox(height: 16),
          _VitalsSummaryBox(vitals: provider.currentVitals),
        ],
      ),
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
        color: kBg.withOpacity(0.5),
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
              const Text('PATIENT VITALS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, lbc) {
            final sw = MediaQuery.of(context).size.width;
            final isT = sw > 600;
            final crossCount = isT ? 8 : 4;
            // Lower aspect ratio means more height per cell
            final aspectRatio = isT ? 1.6 : (sw < 380 ? 1.2 : 1.4);

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
                    color: kWhite,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF1F5F9)), // slate-100
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 2, offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(it['label']!.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kTextMid)), 
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(it['val']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: it['val'] == '—' ? kTextMid.withOpacity(0.5) : kTextDark)),
                            if (it['unit'] != '' && it['val'] != '—') ...[
                              const SizedBox(width: 2),
                              Text(it['unit']!, style: const TextStyle(fontSize: 8, color: kTextMid)),
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

class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final bool required;
  final String? initialValue;
  final bool readOnly;
  final Function(String)? onSubmitted;
  final TextEditingController? controller;

  const _InputField({
    required this.label,
    required this.hint,
    this.required = false,
    this.initialValue,
    this.readOnly = false,
    this.onSubmitted,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextMid)),
            if (required) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller ?? (initialValue != null ? TextEditingController(text: initialValue) : null),
          readOnly: readOnly,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: readOnly,
            fillColor: readOnly ? kBg : kWhite,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kTeal)),
          ),
        ),
      ],
    );
  }
}

// ─── Tab Section ─────────────────────────────────────────────────────────────
class _EyeTabSection extends StatelessWidget {
  final TabController tabController;
  final PrescriptionProvider provider;
  const _EyeTabSection({required this.tabController, required this.provider});

  // Mirrors React's tab permission config exactly
  static const _tabDefs = [
    _EyeTabDef(
      label: 'Diagnosis',
      readPerms: [Perm.eyeDiagnosisRead, Perm.eyeDiagnosisUpdate, Perm.eyeRecordRead, Perm.eyeRecordUpdate, Perm.prescriptionRead, Perm.prescriptionCreate],
      writePerms: [Perm.eyeDiagnosisUpdate, Perm.eyeRecordUpdate, Perm.prescriptionCreate],
    ),
    _EyeTabDef(
      label: 'Optometrist',
      readPerms: [Perm.eyeOptometristRead, Perm.eyeOptometristUpdate, Perm.eyeRecordRead, Perm.eyeRecordUpdate, Perm.prescriptionRead, Perm.prescriptionCreate],
      writePerms: [Perm.eyeOptometristUpdate, Perm.eyeRecordUpdate, Perm.prescriptionCreate],
    ),
    _EyeTabDef(
      label: 'Examination',
      readPerms: [Perm.eyeExaminationRead, Perm.eyeExaminationUpdate, Perm.eyeRecordRead, Perm.eyeRecordUpdate, Perm.prescriptionRead, Perm.prescriptionCreate],
      writePerms: [Perm.eyeExaminationUpdate, Perm.eyeRecordUpdate, Perm.prescriptionCreate],
    ),
    _EyeTabDef(
      label: 'Management',
      readPerms: [Perm.eyeManagementRead, Perm.eyeManagementUpdate, Perm.eyeRecordRead, Perm.eyeRecordUpdate, Perm.prescriptionRead, Perm.prescriptionCreate],
      writePerms: [Perm.eyeManagementUpdate, Perm.eyeRecordUpdate, Perm.prescriptionCreate],
    ),
    _EyeTabDef(
      label: 'Medicines',
      readPerms: [Perm.eyeMedicinesRead, Perm.eyeMedicinesUpdate, Perm.eyeRecordRead, Perm.eyeRecordUpdate, Perm.prescriptionRead, Perm.prescriptionCreate],
      writePerms: [Perm.eyeMedicinesUpdate, Perm.eyeRecordUpdate, Perm.prescriptionCreate],
    ),
    _EyeTabDef(
      label: 'Old Visits',
      readPerms: [Perm.eyeHistoryRead, Perm.eyeRecordRead, Perm.prescriptionRead],
      writePerms: [],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionProvider>();

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: kTeal,
            indicatorColor: kTeal,
            unselectedLabelColor: kTextMid,
            tabs: _tabDefs.map((def) {
              final canRead = perm.canAny(def.readPerms);
              return Tab(
                child: Opacity(
                  opacity: canRead ? 1.0 : 0.35,
                  child: Text(
                    def.label,
                    style: TextStyle(
                      color: canRead ? null : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
            onTap: (index) {
              // Prevent switching to a tab the user can't read
              final canRead = perm.canAny(_tabDefs[index].readPerms);
              if (!canRead) {
                // Revert to current tab
                tabController.animateTo(tabController.previousIndex);
              }
            },
          ),
          AnimatedBuilder(
            animation: tabController,
            builder: (context, child) {
              final idx = tabController.index;
              final def = _tabDefs[idx];
              final canRead = perm.canAny(def.readPerms);
              final canWrite = perm.canAny(def.writePerms);

              if (!canRead) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline, size: 40, color: Color(0xFFCBD5E0)),
                        SizedBox(height: 12),
                        Text(
                          'You do not have access to this eye checkup section.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFB7791F), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget tabContent = switch (idx) {
                0 => _DiagnosisTab(provider: provider),
                1 => _OptometristTab(provider: provider),
                2 => _ExaminationTab(provider: provider),
                3 => _ManagementTab(provider: provider),
                4 => _MedicinesTab(provider: provider),
                5 => _OldVisitsTab(provider: provider),
                _ => const SizedBox.shrink(),
              };

              // Wrap non-old-visits tabs in IgnorePointer when read-only
              if (idx != 5 && !canWrite) {
                tabContent = Stack(
                  children: [
                    Opacity(opacity: 0.75, child: tabContent),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_outlined, size: 12, color: Color(0xFFB45309)),
                            SizedBox(width: 4),
                            Text('View Only', style: TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return tabContent;
            },
          ),
        ],
      ),
    );
  }
}

class _EyeTabDef {
  final String label;
  final List<String> readPerms;
  final List<String> writePerms;
  const _EyeTabDef({required this.label, required this.readPerms, required this.writePerms});
}

// ─── Optometrist Tab ──────────────────────────────────────────────────────────
class _OptometristTab extends StatelessWidget {
  final PrescriptionProvider provider;
  const _OptometristTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TabHeader(title: 'History', icon: Icons.history_edu),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
            child: Column(
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 0,
                  children: provider.eyeHistory.keys.map((key) {
                    return SizedBox(
                      width: 140,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: provider.eyeHistory[key],
                            onChanged: (_) => provider.toggleEyeHistory(key),
                            activeColor: kTeal,
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(child: Text(key, style: const TextStyle(fontSize: 11, color: kTextDark))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                _InputField(label: 'Other History', hint: 'Enter other...', initialValue: provider.eyeOtherHistoryCtrl.text),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _TabHeader(title: 'Refraction Matrix', icon: Icons.grid_on),
          const SizedBox(height: 8),
          _RefractionMatrixWidget(side: 'right', label: 'R I G H T', provider: provider),
          const SizedBox(height: 8),
          _RefractionMatrixWidget(side: 'left', label: 'L E F T', provider: provider),
          const SizedBox(height: 8),
          _AddRefractionWidget(provider: provider),
          const SizedBox(height: 20),
          const _TabHeader(title: 'Vision Stats', icon: Icons.remove_red_eye),
          const SizedBox(height: 8),
          _VisionGrid(provider: provider),
        ],
      ),
    );
  }
}

class _TabHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _TabHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kTeal),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark, letterSpacing: 1.1)),
      ],
    );
  }
}

class _VisionGrid extends StatelessWidget {
  final PrescriptionProvider provider;
  const _VisionGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _visionRow('Right Eye', 'right'),
        const SizedBox(height: 12),
        _visionRow('Left Eye', 'left'),
      ],
    );
  }

  Widget _visionRow(String label, String side) {
    final ctrls = provider.visionCtrls[side]!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kBg.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTeal)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _InputField(label: 'VAR', hint: '', controller: ctrls['var'])),
              const SizedBox(width: 8),
              Expanded(child: _InputField(label: 'PH', hint: '', controller: ctrls['ph'])),
              const SizedBox(width: 8),
              Expanded(child: _InputField(label: 'REF', hint: '', controller: ctrls['ref'])),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefractionMatrixWidget extends StatelessWidget {
  final String side;
  final String label;
  final PrescriptionProvider provider;
  const _RefractionMatrixWidget({required this.side, required this.label, required this.provider});

  @override
  Widget build(BuildContext context) {
    final ctrls = provider.refractionCtrls[side]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: [
            _tinyInput(ctrls['sph']!, 'SPH'),
            const SizedBox(width: 4),
            _tinyInput(ctrls['cyl']!, 'CYL'),
            const SizedBox(width: 4),
            _tinyInput(ctrls['axis']!, 'AXIS'),
            const SizedBox(width: 4),
            _tinyInput(ctrls['va']!, 'VA'),
          ],
        ),
      ],
    );
  }

  Widget _tinyInput(TextEditingController ctrl, String hint) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 11),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

class _AddRefractionWidget extends StatelessWidget {
  final PrescriptionProvider provider;
  const _AddRefractionWidget({required this.provider});

  @override
  Widget build(BuildContext context) {
    final add01 = provider.refractionCtrls['add01']!;
    final add02 = provider.refractionCtrls['add02']!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(right: 8),
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('D', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('D', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    _tinyInput(add01['sph']!, 'SPH'),
                    const SizedBox(width: 4),
                    _tinyInput(add01['cyl']!, 'CYL'),
                    const SizedBox(width: 4),
                    _tinyInput(add01['axis']!, 'AXIS'),
                    const SizedBox(width: 4),
                    _tinyInput(add01['va']!, 'VA'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _tinyInput(add02['sph']!, 'SPH'),
                    const SizedBox(width: 4),
                    _tinyInput(add02['cyl']!, 'CYL'),
                    const SizedBox(width: 4),
                    _tinyInput(add02['axis']!, 'AXIS'),
                    const SizedBox(width: 4),
                    _tinyInput(add02['va']!, 'VA'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyInput(TextEditingController ctrl, String hint) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 11),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

// ─── Diagnosis Tab ───────────────────────────────────────────────────────────
class _DiagnosisTab extends StatelessWidget {
  final PrescriptionProvider provider;
  const _DiagnosisTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.diagnosisQuestions.isEmpty) {
      return const Center(child: Text('No diagnosis questions found for Eye.'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: provider.diagnosisQuestions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final q = provider.diagnosisQuestions[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kBg.withOpacity(0.5), borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q['question_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark)),
              const SizedBox(height: 10),
              if (q['question_mode'] == 'text')
                _InputField(label: 'Answer', hint: 'Type answer...', onSubmitted: (val) => provider.setDiagnosisAnswer(q['id'], val))
              else if (q['question_mode'] == 'mcq' || q['question_mode'] == 'checkbox')
                Wrap(
                  spacing: 12,
                  children: (q['options'] as List? ?? []).map((opt) {
                    final isSelected = (provider.diagnosisAnswers[q['id']] is List) 
                      ? (provider.diagnosisAnswers[q['id']] as List).contains(opt['id'])
                      : provider.diagnosisAnswers[q['id']] == opt['id'];
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            if (q['question_mode'] == 'mcq') {
                              provider.setDiagnosisAnswer(q['id'], opt['id']);
                            } else {
                              final current = (provider.diagnosisAnswers[q['id']] as List? ?? []).toList();
                              if (val == true) current.add(opt['id']); else current.remove(opt['id']);
                              provider.setDiagnosisAnswer(q['id'], current);
                            }
                          },
                          activeColor: kTeal,
                        ),
                        Text(opt['option_text'] ?? '', style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Examination Tab ─────────────────────────────────────────────────────────
class _ExaminationTab extends StatelessWidget {
  final PrescriptionProvider provider;
  const _ExaminationTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TabHeader(title: 'Examination Details', icon: Icons.search),
          const SizedBox(height: 16),
          _InputField(
            label: 'Presenting Complaints', 
            hint: 'Describe complaints...', 
            controller: provider.presentingComplaintsCtrl,
          ),
          const SizedBox(height: 20),
          _SideSelector(
            title: 'Complaints',
            selectedItems: provider.eyeComplaints,
            suggestions: provider.eyeSetupComplaints,
            onAdd: (name, side) => provider.addEyeItem('complaint', name, side),
            onRemove: (idx) => provider.removeEyeItem('complaint', idx),
          ),
          const SizedBox(height: 20),
          _SideSelector(
            title: 'Examinations',
            selectedItems: provider.eyeExaminations,
            suggestions: provider.eyeSetupExaminations,
            onAdd: (name, side) => provider.addEyeItem('examination', name, side),
            onRemove: (idx) => provider.removeEyeItem('examination', idx),
          ),
        ],
      ),
    );
  }
}

// ─── Management Tab ──────────────────────────────────────────────────────────
class _ManagementTab extends StatelessWidget {
  final PrescriptionProvider provider;
  const _ManagementTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TabHeader(title: 'Management & Advised', icon: Icons.healing),
          const SizedBox(height: 16),
          _SideSelector(
            title: 'Diagnosis / Disease',
            selectedItems: provider.eyeDiagnosis,
            suggestions: provider.eyeSetupDiagnosis,
            onAdd: (name, side) => provider.addEyeItem('diagnosis', name, side),
            onRemove: (idx) => provider.removeEyeItem('diagnosis', idx),
          ),
          const SizedBox(height: 20),
          _SideSelector(
            title: 'Advised Items',
            selectedItems: provider.eyeAdvised,
            suggestions: provider.eyeSetupAdvised,
            onAdd: (name, side) => provider.addEyeItem('advised', name, side),
            onRemove: (idx) => provider.removeEyeItem('advised', idx),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Treatment Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMid)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: provider.eyeTreatmentType.isEmpty ? null : provider.eyeTreatmentType,
                          onChanged: (v) => provider.setEyeTreatmentType(v!),
                          items: ['No Treatment', 'Consultation', 'Medication', 'Surgery'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.eyeTreatmentType == 'Surgery') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Operation Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMid)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                          if (date != null) provider.setOperationDate(date);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                          child: Row(
                            children: [
                              Text(provider.eyeOperationDate != null ? provider.eyeOperationDate!.toString().split(' ')[0] : 'Select date', style: const TextStyle(fontSize: 12)),
                              const Spacer(),
                              const Icon(Icons.calendar_today, size: 14, color: kTeal),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (provider.eyeTreatmentType == 'Surgery') ...[
            const SizedBox(height: 16),
            _SurgeryInput(provider: provider),
          ],
          const SizedBox(height: 16),
          _InputField(label: 'Remarks', hint: 'Add remarks...', controller: provider.eyeRemarksCtrl),
        ],
      ),
    );
  }
}

// ─── Side Selector Widget ─────────────────────────────────────────────────────
class _SideSelector extends StatefulWidget {
  final String title;
  final List<EyeSideItem> selectedItems;
  final List<String> suggestions;
  final Function(String, String) onAdd;
  final Function(int) onRemove;

  const _SideSelector({
    required this.title, 
    required this.selectedItems, 
    required this.suggestions,
    required this.onAdd, 
    required this.onRemove
  });

  @override
  State<_SideSelector> createState() => _SideSelectorState();
}

class _SideSelectorState extends State<_SideSelector> {
  String _selectedSide = 'B';
  TextEditingController? _autoCompleteCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kTextMid, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                  return widget.suggestions.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (String selection) {
                  _autoCompleteCtrl?.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  _autoCompleteCtrl = controller;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search or enter name...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                        decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(option, style: const TextStyle(fontSize: 12)),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSide,
                  onChanged: (v) => setState(() => _selectedSide = v!),
                  items: ['L', 'R', 'B'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () {
                final text = _autoCompleteCtrl?.text ?? '';
                if (text.isNotEmpty) {
                  widget.onAdd(text, _selectedSide);
                  _autoCompleteCtrl?.clear();
                }
              },
              style: IconButton.styleFrom(backgroundColor: kTeal, foregroundColor: kWhite),
            ),
          ],
        ),
        if (widget.selectedItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.selectedItems.asMap().entries.map((e) {
              return Chip(
                label: Text('${e.value.name} (${e.value.side})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTeal)),
                onDeleted: () => widget.onRemove(e.key),
                deleteIcon: const Icon(Icons.close, size: 12, color: kTeal),
                backgroundColor: kTealLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kTeal)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ─── Medicines Tab ───────────────────────────────────────────────────────────
class _MedicinesTab extends StatelessWidget {
  final PrescriptionProvider provider;
  const _MedicinesTab({required this.provider});

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
              _EyeMedModeToggle(provider: provider),
              _EyeLanguageIndicator(provider: provider),
            ],
          ),
          const SizedBox(height: 16),
          _EyeMedicineSearchArea(provider: provider),
          const SizedBox(height: 20),
          _EyeMedicineTable(provider: provider),
        ],
      ),
    );
  }
}

class _EyeMedModeToggle extends StatelessWidget {
  final PrescriptionProvider provider;
  const _EyeMedModeToggle({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8), color: kWhite),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBtn('Medicine', 'medicine', Icons.medical_services, const Color(0xFF2563EB)),
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

class _EyeLanguageIndicator extends StatelessWidget {
  final PrescriptionProvider provider;
  const _EyeLanguageIndicator({required this.provider});

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

class _EyeMedicineSearchArea extends StatefulWidget {
  final PrescriptionProvider provider;
  const _EyeMedicineSearchArea({required this.provider});

  @override
  State<_EyeMedicineSearchArea> createState() => _EyeMedicineSearchAreaState();
}

class _EyeMedicineSearchAreaState extends State<_EyeMedicineSearchArea> {
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

class _EyeMedicineTable extends StatelessWidget {
  final PrescriptionProvider provider;
  const _EyeMedicineTable({required this.provider});

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

// ─── Old Visits Tab ──────────────────────────────────────────────────────────
class _OldVisitsTab extends StatelessWidget {
  final PrescriptionProvider provider;
  const _OldVisitsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoadingHistory) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator(color: kTeal)),
      );
    }

    if (provider.prescriptionHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: kTextMid.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text(
                provider.currentPatient != null ? 'No previous visits found.' : 'Search a patient to see history',
                style: TextStyle(color: kTextMid.withOpacity(0.6), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: provider.prescriptionHistory.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final rx = provider.prescriptionHistory[index];
        return _OldVisitCard(rx: rx, provider: provider);
      },
    );
  }
}

class _OldVisitCard extends StatelessWidget {
  final PrescriptionModel rx;
  final PrescriptionProvider provider;
  const _OldVisitCard({required this.rx, required this.provider});

  String _formatSideItems(List<EyeSideItem>? items) {
    if (items == null || items.isEmpty) return '';
    return items.map((e) => '${e.name} (${e.side})').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final eye = rx.eyeDetails;
    final history = <String>[];
    if (eye != null) {
      eye.history.forEach((key, val) {
        if (val) history.add(key);
      });
      if (eye.otherHistory.isNotEmpty) history.add(eye.otherHistory);
    }

    final hasOptometrist = eye != null &&
        ([eye.rightRefraction, eye.leftRefraction, eye.add01Refraction, eye.add02Refraction].any((r) =>
                r.sph.isNotEmpty ||
                r.cyl.isNotEmpty ||
                r.axis.isNotEmpty ||
                r.va.isNotEmpty ||
                r.addition.isNotEmpty) ||
            [eye.rightVision, eye.leftVision].any((v) => v.varValue.isNotEmpty || v.ph.isNotEmpty || v.ref.isNotEmpty));

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kBg.withOpacity(0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: const Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rx.createdAt != null ? rx.createdAt!.split('T')[0] : 'No Date',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark),
                    ),
                    Text(
                      'Dr. ${rx.doctorName}',
                      style: const TextStyle(fontSize: 10, color: kTextMid),
                    ),
                  ],
                ),
                const Spacer(),
                if (rx.receiptId != null)
                  Text('Receipt: ${rx.receiptId}',
                      style: const TextStyle(fontSize: 10, color: kTextMid, fontStyle: FontStyle.italic)),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => provider.printOldPrescription(context, rx),
                  icon: const Icon(Icons.print, size: 12),
                  label: const Text('Print', style: TextStyle(fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kWhite,
                    foregroundColor: kTeal,
                    elevation: 0,
                    side: const BorderSide(color: kTeal),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // History
                if (history.isNotEmpty) ...[
                  _sectionTitle('History'),
                  Text(history.join(', '), style: const TextStyle(fontSize: 11, color: kTextDark)),
                  const SizedBox(height: 12),
                ],

                // Grid for main details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rx.historyExamination != null || (eye?.presentingComplaints.isNotEmpty ?? false))
                      Expanded(
                        child: _infoBox('Presenting Complaints', eye?.presentingComplaints ?? rx.historyExamination ?? ''),
                      ),
                    if (rx.treatment != null || (eye?.treatmentType.isNotEmpty ?? false)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _infoBox('Treatment', eye?.treatmentType ?? rx.treatment ?? ''),
                      ),
                    ],
                  ],
                ),

                if ((eye?.surgeryName?.isNotEmpty ?? false) || (eye?.remarks.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eye?.surgeryName?.isNotEmpty ?? false)
                        Expanded(
                            child: _infoBox('Surgery',
                                '${eye!.surgeryName}${eye.operationDate != null ? " | ${eye.operationDate}" : ""}')),
                      if (eye?.remarks != null && eye!.remarks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _infoBox('Remarks', eye.remarks)),
                      ],
                    ],
                  ),
                ],

                // Questionnaire
                if (rx.diagnosis.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionTitle('Questionnaire Diagnosis'),
                  ...rx.diagnosis.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 11, color: kTextDark),
                            children: [
                              TextSpan(text: '${d.questionText}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: d.answerText ?? (d.answerValue?.toString() ?? '-')),
                            ],
                          ),
                        ),
                      )),
                ],

                // Side Items Grid
                if (eye != null &&
                    (eye.complaints.isNotEmpty ||
                        eye.examinations.isNotEmpty ||
                        eye.diagnosis.isNotEmpty ||
                        eye.advised.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (eye.complaints.isNotEmpty) _sideItemsBox('Complaints', eye.complaints),
                      if (eye.examinations.isNotEmpty) _sideItemsBox('Examinations', eye.examinations),
                      if (eye.diagnosis.isNotEmpty) _sideItemsBox('Diagnosis / Disease', eye.diagnosis),
                      if (eye.advised.isNotEmpty) _sideItemsBox('Advised', eye.advised),
                    ],
                  ),
                ],

                // Optometrist
                if (hasOptometrist) ...[
                  const SizedBox(height: 12),
                  _sectionTitle('Optometrist Details'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _optometristSide('Right Eye', eye!.rightRefraction, eye.rightVision)),
                      const SizedBox(width: 8),
                      Expanded(child: _optometristSide('Left Eye', eye.leftRefraction, eye.leftVision)),
                    ],
                  ),
                ],

                // Investigations
                if (rx.investigations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionTitle('Investigations'),
                  Wrap(
                    spacing: 6,
                    children: rx.investigations
                        .map((inv) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: kBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: kBorder)),
                              child: Text(inv.testName,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTeal)),
                            ))
                        .toList(),
                  ),
                ],

                // Medicines
                if (rx.medicines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionTitle('Medicines'),
                  ...rx.medicines.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 11, color: kTextDark),
                            children: [
                              TextSpan(text: m.medicineName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(
                                  text:
                                      ' | M:${m.morning.toInt()} A:${m.afternoon.toInt()} E:${m.evening.toInt()} N:${m.night.toInt()} | ${m.forDays} Days',
                                  style: const TextStyle(color: kTextMid)),
                            ],
                          ),
                        ),
                      )),
                ],

                // Instructions
                if (rx.instructions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionTitle('Instructions'),
                  ...rx.instructions.map((ins) => Text('• $ins', style: const TextStyle(fontSize: 11, color: kTextDark))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(title.toUpperCase(),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTextMid, letterSpacing: 1.1)),
    );
  }

  Widget _infoBox(String label, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: kBg.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kTextMid)),
          const SizedBox(height: 2),
          Text(content, style: const TextStyle(fontSize: 11, color: kTextDark)),
        ],
      ),
    );
  }

  Widget _sideItemsBox(String label, List<EyeSideItem> items) {
    return Container(
      width: 170, // Fixed width for wrap
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: kBg.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kTextMid)),
          const SizedBox(height: 2),
          Text(_formatSideItems(items), style: const TextStyle(fontSize: 10, color: kTextDark)),
        ],
      ),
    );
  }

  Widget _optometristSide(String label, RefractionMatrix ref, VisionStats vis) {
    final refStr = [
      if (ref.sph.isNotEmpty) 'Sph ${ref.sph}',
      if (ref.cyl.isNotEmpty) 'Cyl ${ref.cyl}',
      if (ref.axis.isNotEmpty) 'Axis ${ref.axis}',
      if (ref.va.isNotEmpty) 'VA ${ref.va}',
      if (ref.addition.isNotEmpty) 'Add ${ref.addition}',
    ].join(', ');

    final visStr = [
      if (vis.varValue.isNotEmpty) 'VAR ${vis.varValue}',
      if (vis.ph.isNotEmpty) 'PH ${vis.ph}',
      if (vis.ref.isNotEmpty) 'REF ${vis.ref}',
    ].join(', ');

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: kBg.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kTeal)),
          if (refStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Refraction: $refStr', style: const TextStyle(fontSize: 10, color: kTextDark)),
          ],
          if (visStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Vision: $visStr', style: const TextStyle(fontSize: 10, color: kTextDark)),
          ],
        ],
      ),
    );
  }
}

class _EyeSavePrintButton extends StatelessWidget {
  final PrescriptionProvider provider;
  const _EyeSavePrintButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final perm = context.read<PermissionProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: provider.currentPatient == null ? null : () async {
              final patient = provider.currentPatient;
              try {
                final success = await provider.savePrescription(
                  isEye: true,
                  doctorName: perm.fullName ?? 'Doctor',
                  doctorSrlNo: 1, 
                );
                
                if (!context.mounted) return;
                
                if (success) {
                  final rx = provider.lastSavedPrescription;
                  if (rx != null && patient != null) {
                    // IMPORTANT: We MUST NOT show a SnackBar here. 
                    // The Printing.layoutPdf dialog pauses the app immediately.
                    // If a SnackBar is animating when the app pauses, Flutter crashes.
                    await PDFEyePrescriptionService.printPrescription(rx, patient);
                  }
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    snackbarKey.currentState?.showSnackBar(const SnackBar(
                      content: Text('Failed to save prescription. Check your connection.'),
                      backgroundColor: Colors.red,
                    ));
                  });
                }
              } catch (e) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  snackbarKey.currentState?.showSnackBar(SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ));
                });
              }
            },
            icon: provider.isSaving 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
              : const Icon(Icons.print),
            label: const Text('Save & Print Prescription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal, 
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: provider.currentPatient == null ? null : () async {
              final patient = provider.currentPatient;
              try {
                final success = await provider.savePrescription(
                  isEye: true,
                  doctorName: perm.fullName ?? 'Doctor',
                  doctorSrlNo: 1, 
                );
                
                if (!context.mounted) return;
                
                if (success) {
                  final rx = provider.lastSavedPrescription;
                  if (rx != null && patient != null) {
                    await PDFEyePrescriptionService.sharePrescription(rx, patient);
                  }
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    snackbarKey.currentState?.showSnackBar(const SnackBar(
                      content: Text('Failed to save prescription.'),
                      backgroundColor: Colors.red,
                    ));
                  });
                }
              } catch (e) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  snackbarKey.currentState?.showSnackBar(SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ));
                });
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Save to PDF / Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kTeal,
              side: const BorderSide(color: kTeal),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurgeryInput extends StatefulWidget {
  final PrescriptionProvider provider;
  const _SurgeryInput({required this.provider});

  @override
  State<_SurgeryInput> createState() => _SurgeryInputState();
}

class _SurgeryInputState extends State<_SurgeryInput> {
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _hideOverlay();
    _focusNode.dispose();
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
              child: widget.provider.surgerySearchResults.isEmpty 
                ? const Padding(padding: EdgeInsets.all(12), child: Text('No surgeries found', style: TextStyle(fontSize: 12, color: kTextMid)))
                : ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: widget.provider.surgerySearchResults.length,
                  itemBuilder: (context, index) {
                    final name = widget.provider.surgerySearchResults[index];
                    return ListTile(
                      dense: true,
                      title: Text(name, style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        widget.provider.eyeSurgeryNameCtrl.text = name;
                        _hideOverlay();
                        _focusNode.unfocus();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Surgery Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMid)),
          const SizedBox(height: 4),
          TextField(
            controller: widget.provider.eyeSurgeryNameCtrl,
            focusNode: _focusNode,
            style: const TextStyle(fontSize: 12),
            onChanged: (val) {
              widget.provider.updateSurgerySearch(val);
              if (val.isNotEmpty) _showOverlay(); else _hideOverlay();
            },
            onTap: () {
              if (widget.provider.eyeSurgeryNameCtrl.text.isNotEmpty) {
                widget.provider.updateSurgerySearch(widget.provider.eyeSurgeryNameCtrl.text);
                _showOverlay();
              }
            },
            decoration: InputDecoration(
              hintText: 'Search or type surgery name...',
              prefixIcon: const Icon(Icons.search, size: 16),
              isDense: true,
              filled: true,
              fillColor: kWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
            ),
          ),
        ],
      ),
    );
  }
}

