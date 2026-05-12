import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../models/eye_model/fundus_examination_model.dart';
import '../../providers/eye_provider/fundus_provider.dart';
import '../../providers/prescription_provider/prescription_provider.dart';
import '../../core/providers/permission_provider.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../custum widgets/custom_loader.dart';
import 'widgets/shared_consultation_widgets.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const kTeal = Color(0xFF00B5AD);
const kTealLight = Color(0xFFE0F7F5);
const kBorder = Color(0xFFCCECE9);
const kBg = Color(0xFFF8F9FA);
const kTextDark = Color(0xFF2D3748);
const kTextMid = Color(0xFF718096);
const kWhite = Colors.white;

class FundusExaminationScreen extends StatefulWidget {
  const FundusExaminationScreen({super.key});

  @override
  State<FundusExaminationScreen> createState() => _FundusExaminationScreenState();
}

class _FundusExaminationScreenState extends State<FundusExaminationScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fundusProvider = context.read<FundusProvider>();
      final prescriptionProvider = context.read<PrescriptionProvider>();
      fundusProvider.startConsultationTimer(prescriptionProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fundusProvider = context.watch<FundusProvider>();
    final prescriptionProvider = context.watch<PrescriptionProvider>();
    final mq = MediaQuery.of(context);
    final isMobile = mq.size.width < 900;
    final hPad = mq.size.width * 0.04;
    
    return BaseScaffold(
      title: 'Fundus Examination',
      drawerIndex: 16,
      showNotificationIcon: true,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main Content ──────────────────────────────────────────────────
          Expanded(
            flex: isMobile ? 1 : 9,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: hPad,
                right: isMobile ? hPad : 8,
                top: mq.size.height * 0.02,
                bottom: mq.size.height * 0.15,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (isMobile) ...[
                     SharedConsultationDropdown(
                       department: 'Eye',
                       onSelect: (p) {
                         prescriptionProvider.selectConsultationPatient(p, department: 'Eye');
                         fundusProvider.fetchHistory(p['patient_mr_number']);
                       },
                     ),
                     const SizedBox(height: 16),
                   ],
 
                   // ── Patient Info ──────────────────────────────────────────
                   FadeInUp(
                     duration: const Duration(milliseconds: 400),
                     child: _PatientInfoCard(
                       isTablet: !isMobile,
                       screenW: mq.size.width,
                       prescriptionProvider: prescriptionProvider,
                       fundusProvider: fundusProvider,
                     ),
                   ),
                   const SizedBox(height: 20),
 
                   // ── Examination Form ──────────────────────────────────────
                   FadeInUp(
                     delay: const Duration(milliseconds: 100),
                     child: _ExaminationForm(
                       provider: fundusProvider,
                       prescriptionProvider: prescriptionProvider,
                       isMobile: isMobile,
                     ),
                   ),
                 ],
               ),
             ),
           ),
 
           // ── Sidebar (Desktop Only) ────────────────────────────────────────
           if (!isMobile)
             Expanded(
               flex: 3,
               child: SharedConsultationSidebar(
                 department: 'Eye',
                 onSelect: (p) {
                   prescriptionProvider.selectConsultationPatient(p, department: 'Eye');
                   fundusProvider.fetchHistory(p['patient_mr_number']);
                 },
               ),
             ),
         ],
       ),
     );
   }
 }


// ─── Patient Info Card ────────────────────────────────────────────────────────

class _PatientInfoCard extends StatelessWidget {
  final bool isTablet;
  final double screenW;
  final PrescriptionProvider prescriptionProvider;
  final FundusProvider fundusProvider;

  const _PatientInfoCard({
    required this.isTablet,
    required this.screenW,
    required this.prescriptionProvider,
    required this.fundusProvider,
  });

  @override
  Widget build(BuildContext context) {
    final patient = prescriptionProvider.currentPatient;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: kTeal, size: 18),
                const SizedBox(width: 6),
                Text('Patient Information', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600, fontSize: isTablet ? 14 : 13)),
                const Spacer(),
                if (prescriptionProvider.isLoading)
                  const SizedBox(width: 14, height: 14, child: CustomLoader(size: 14, color: kTeal)),
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
        ],
      ),
    );
  }

  Widget _mobileGrid(BuildContext context, PatientModel? patient) {
    return Column(
      children: [
        _Row(children: [
          _InputField(label: 'MR No.*', hint: 'Search...', required: true, initialValue: patient?.mrNumber, onSubmitted: (val) {
            final mr = val.trim();
            prescriptionProvider.searchPatient(mr);
            fundusProvider.fetchHistory(mr);
          }),
          const SizedBox(width: 10),
          _InputField(label: 'Patient Name', hint: '', initialValue: patient?.fullName, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _Row(children: [
          _InputField(label: 'Age / Gender', hint: '', initialValue: patient != null ? '${patient.age ?? ''} / ${patient.gender}' : '', readOnly: true),
          const SizedBox(width: 10),
          _InputField(label: 'Phone', hint: '', initialValue: patient?.phoneNumber, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _Row(children: [
          _InputField(label: 'Doctor', hint: '', initialValue: prescriptionProvider.doctorName, readOnly: true),
          const SizedBox(width: 10),
          _InputField(label: 'Receipt ID', hint: '', initialValue: prescriptionProvider.receiptId, readOnly: true),
        ]),
      ],
    );
  }

  Widget _tabletGrid(BuildContext context, PatientModel? patient) {
    return Column(
      children: [
        Row(children: [
          Expanded(flex: 2, child: _InputField(label: 'MR No.*', hint: 'Search...', required: true, initialValue: patient?.mrNumber, onSubmitted: (val) {
             final mr = val.trim();
             prescriptionProvider.searchPatient(mr);
             fundusProvider.fetchHistory(mr);
          })),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _InputField(label: 'Patient Name', hint: '', initialValue: patient?.fullName, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _InputField(label: 'Age / Gender', hint: '', initialValue: patient != null ? '${patient.age ?? ''} / ${patient.gender}' : '', readOnly: true)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _InputField(label: 'Phone', hint: '', initialValue: patient?.phoneNumber, readOnly: true)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _InputField(label: 'Father / Husband', hint: '', initialValue: patient?.guardianName, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Address', hint: '', initialValue: patient?.address, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Doctor', hint: '', initialValue: prescriptionProvider.doctorName, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Receipt ID', hint: '', initialValue: prescriptionProvider.receiptId, readOnly: true)),
        ]),
      ],
    );
  }
}

// ─── Examination Form Components ───────────────────────────────────────────────

class _ExaminationForm extends StatelessWidget {
  final FundusProvider provider;
  final PrescriptionProvider prescriptionProvider;
  final bool isMobile;

  const _ExaminationForm({required this.provider, required this.prescriptionProvider, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return Container(
        padding: const EdgeInsets.all(100),
        child: const Center(child: CustomLoader(size: 50, color: kTeal)),
      );
    }

    if (prescriptionProvider.currentPatient == null) {
      return _buildPlaceholder();
    }

    return Column(
      children: [
        _buildSectionCard(
          title: 'Examination History & Analysis',
          icon: Icons.analytics_outlined,
          action: ElevatedButton.icon(
            onPressed: () => _showDatePicker(context),
            icon: const Icon(Icons.add_circle_outline, size: 14),
            label: const Text('Add Date', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal, 
              foregroundColor: kWhite, 
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          child: provider.records.isEmpty
              ? _buildEmptyState()
              : _buildComparisonTable(context),
        ),
        const SizedBox(height: 24),
        _buildSaveButton(context),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text('Search a patient first to manage fundus examinations', style: TextStyle(color: kTextMid, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(40.0),
      child: Center(child: Text('No examination records added. Use "Add Date" button to start.', style: TextStyle(color: kTextMid))),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: provider.isSaving ? null : () async {
          final success = await provider.saveBatch(prescriptionProvider.currentPatient!.mrNumber, prescriptionProvider.receiptId);
          if (context.mounted) {
            if (success) {
              _showSuccessDialog(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to save examinations.'), backgroundColor: Colors.red)
              );
            }
          }
        },
        icon: provider.isSaving 
            ? const SizedBox(width: 18, height: 18, child: CustomLoader(size: 18, color: kWhite)) 
            : const Icon(Icons.save_outlined),
        label: Text(provider.isSaving ? 'Saving...' : 'Save Examinations', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kTeal, 
          foregroundColor: kWhite, 
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: kTeal, size: 80),
            const SizedBox(height: 16),
            const Text('Success!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
            const SizedBox(height: 8),
            const Text('Fundus examination records have been saved successfully.', textAlign: TextAlign.center, style: TextStyle(color: kTextMid)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: kWhite, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: DateTime.now(), 
      firstDate: DateTime(2000), 
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: kTeal)), child: child!),
    );
    if (picked != null) {
      provider.addDateColumn(
        picked.toIso8601String().split('T')[0], 
        prescriptionProvider.doctorName,
        prescriptionProvider.doctorSrlNo,
        prescriptionProvider.receiptId,
      );
    }
  }

  Widget _buildComparisonTable(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final maxRecords = sw < 400 ? 1 : 2;
    final displayRecords = isMobile ? provider.records.take(maxRecords).toList() : provider.records;
    
    final labelFlex = isMobile ? 2.5 : 3.0;
    const cellFlex = 1.0; // Each Y/N column
    final recordFlex = 4.0; // 4 sub-columns per record (R-Y, R-N, L-Y, L-N)

    return Column(
      children: [
        if (isMobile && provider.records.length > maxRecords)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('* Showing last $maxRecords records on mobile to fit screen', style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontStyle: FontStyle.italic)),
          ),
        
        // ── Header High-Level (Dates) ──
        Container(
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Expanded(flex: labelFlex.toInt(), child: const Padding(padding: EdgeInsets.all(12), child: Text('Finding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kTextMid)))),
              ...displayRecords.map((r) => Expanded(
                flex: recordFlex.toInt(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.1)))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(r.examinationDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: kTeal))),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => provider.removeRecord(provider.records.indexOf(r)), 
                        icon: const Icon(Icons.close, color: Colors.red, size: 12), 
                        padding: EdgeInsets.zero, 
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),

        // ── Header Mid-Level (R | L) ──
        Row(
          children: [
            Expanded(flex: labelFlex.toInt(), child: const SizedBox()),
            ...displayRecords.expand((r) => [
              Expanded(flex: 2, child: Center(child: Text('RIGHT EYE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kTeal.withOpacity(0.7))))),
              Expanded(flex: 2, child: Center(child: Text('LEFT EYE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1).withOpacity(0.7))))),
            ]),
          ],
        ),

        // ── Header Sub-Level (Y | N) ──
        Row(
          children: [
            Expanded(flex: labelFlex.toInt(), child: const SizedBox()),
            ...List.generate(displayRecords.length * 4, (index) => Expanded(
              flex: 1, 
              child: Center(child: Text(index % 2 == 0 ? 'Y' : 'N', style: TextStyle(fontSize: 7, color: kTextMid.withOpacity(0.5)))),
            )),
          ],
        ),
        
        const Divider(height: 8, color: Colors.transparent),

        Table(
          columnWidths: {
            0: FlexColumnWidth(labelFlex),
            for (int i = 1; i <= displayRecords.length * 4; i++) i: const FlexColumnWidth(cellFlex),
          },
          border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.withOpacity(0.05))),
          children: [
            ..._buildSection('DM FUNDUS', DM_FINDINGS, displayRecords),
            ..._buildSection('HTN FUNDUS', HTN_FINDINGS, displayRecords),
            ..._buildSection('COMPLICATIONS', COMPLICATIONS, displayRecords),
          ],
        ),

        // ── Other Findings Row ──
        const SizedBox(height: 8),
        ...displayRecords.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: labelFlex.toInt(),
                child: Padding(padding: const EdgeInsets.only(left: 12, top: 8), child: Text('Notes (${r.examinationDate})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
              ),
              Expanded(
                flex: recordFlex.toInt(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: TextField(
                    maxLines: 2,
                    style: const TextStyle(fontSize: 10),
                    decoration: InputDecoration(
                      hintText: 'Enter additional findings here...', 
                      filled: true, 
                      fillColor: kBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), 
                      contentPadding: const EdgeInsets.all(8),
                    ),
                    onChanged: (val) => provider.updateOtherFindings(provider.records.indexOf(r), val),
                  ),
                ),
              ),
              // Empty space to align with other records if multiple
              ...List.generate((displayRecords.length - 1) * 4, (_) => const Spacer()),
            ],
          ),
        )),
      ],
    );
  }

  List<TableRow> _buildSection(String title, List<Map<String, dynamic>> items, List<FundusRecord> displayRecords) {
    return [
      TableRow(
        children: [
          TableCell(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTeal, letterSpacing: 0.8)))),
          ...List.generate(displayRecords.length * 4, (_) => const TableCell(child: SizedBox())),
        ],
      ),
      ...items.map((item) => TableRow(
        children: [
          TableCell(
            child: Padding(
              padding: EdgeInsets.only(left: 12.0 + (item['indent'] as int) * 12, top: 2, bottom: 2),
              child: Text(item['label'], style: TextStyle(fontSize: 10, color: kTextDark.withOpacity(0.8))),
            ),
          ),
          ...displayRecords.expand((record) {
            final findingSize = isMobile ? 16.0 : 20.0;
            final recordIdx = provider.records.indexOf(record);
            final finding = record.findings[item['key']] ?? FundusFinding();
            
            return [
              // R-Yes
              _SimpleCheckbox(value: finding.right == true, size: findingSize, onChanged: (v) => provider.toggleFinding(recordIdx, item['key'], 'right', v ? true : null)),
              // R-No
              _SimpleCheckbox(value: finding.right == false, size: findingSize, onChanged: (v) => provider.toggleFinding(recordIdx, item['key'], 'right', v ? false : null)),
              // L-Yes
              _SimpleCheckbox(value: finding.left == true, size: findingSize, onChanged: (v) => provider.toggleFinding(recordIdx, item['key'], 'left', v ? true : null)),
              // L-No
              _SimpleCheckbox(value: finding.left == false, size: findingSize, onChanged: (v) => provider.toggleFinding(recordIdx, item['key'], 'left', v ? false : null)),
            ];
          }),
        ],
      )),
    ];
  }
}

// ─── Reusable UI Helpers ───────────────────────────────────────────────────────

class _SimpleCheckbox extends StatelessWidget {
  final bool value;
  final double size;
  final Function(bool) onChanged;

  const _SimpleCheckbox({required this.value, required this.size, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: kTeal,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: Colors.grey.shade300, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
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

  const _InputField({
    required this.label,
    required this.hint,
    this.required = false,
    this.initialValue,
    this.readOnly = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.width > 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(color: kTextMid, fontSize: isTablet ? 12 : 11, fontWeight: FontWeight.w500),
            children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            readOnly: readOnly,
            controller: TextEditingController(text: initialValue),
            onSubmitted: onSubmitted,
            style: TextStyle(fontSize: isTablet ? 13 : 12, color: kTextDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: kTextMid.withOpacity(0.5), fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: kTeal, width: 1.5)),
              filled: true,
              fillColor: readOnly ? Colors.grey.shade50 : kWhite,
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final List<Widget> children;
  const _Row({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((w) => Expanded(child: w)).toList(),
    );
  }
}

Widget _buildSectionCard({required String title, required IconData icon, Widget? action, required Widget child}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: kWhite,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: kTeal, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextDark)),
              const Spacer(),
              if (action != null) action,
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ],
    ),
  );
}

// ─── Static Data ────────────────────────────────────────────────────────────

const DM_FINDINGS = [
  {'key': 'dm_fundus', 'label': 'DM Fundus Examination', 'indent': 0},
  {'key': 'normal', 'label': 'Normal', 'indent': 1},
  {'key': 'bgdr', 'label': 'BGDR', 'indent': 1},
  {'key': 'maculopathy', 'label': 'Maculopathy', 'indent': 1},
  {'key': 'focal', 'label': 'a. Focal', 'indent': 2},
  {'key': 'diffuse', 'label': 'b. Diffuse', 'indent': 2},
  {'key': 'csme', 'label': 'c. CSME', 'indent': 2},
  {'key': 'ppdr', 'label': 'PPDR', 'indent': 1},
  {'key': 'pdr', 'label': 'PDR', 'indent': 1},
];

const HTN_FINDINGS = [
  {'key': 'htn_normal', 'label': 'a. Normal', 'indent': 1},
  {'key': 'htn_grade1', 'label': 'a. Grade I', 'indent': 1},
  {'key': 'htn_grade2', 'label': 'a. Grade II', 'indent': 1},
  {'key': 'htn_grade3', 'label': 'a. Grade III', 'indent': 1},
  {'key': 'htn_grade4', 'label': 'a. Grade IV', 'indent': 1},
];

const COMPLICATIONS = [
  {'key': 'vid_hemorrhages', 'label': 'a. Vitreous Hemorrhages', 'indent': 1},
  {'key': 'trrd', 'label': 'b. TrRD', 'indent': 1},
  {'key': 'rubeosis', 'label': 'c. Rubeosis', 'indent': 1},
];
