import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../providers/prescription_provider/prescription_provider.dart';
import '../../providers/prescription_provider/lab_values_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../discount_vouchers/discount_vouchers.dart';
import 'eye_prescription.dart' hide kBorder;
import 'widgets/lab_values_sheet.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../../custum widgets/custom_loader.dart';
import '../../core/utils/wait_time_helper.dart';

class LabValuesScreen extends StatefulWidget {
  const LabValuesScreen({super.key});

  @override
  State<LabValuesScreen> createState() => _LabValuesScreenState();
}

class _LabValuesScreenState extends State<LabValuesScreen> {
  final TextEditingController _mrSearchCtrl = TextEditingController();
  
  static const kTeal = Color(0xFF00B5AD);
  static const kTealLight = Color(0xFFE6F7F6);
  static const kBorder = Color(0xFFE2E8F0);
  static const kTextDark = Color(0xFF1A202C);
  static const kTextMid = Color(0xFF4A5568);
  static const kBgLight = Color(0xFFF4F7FA);
  static const kWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrescriptionProvider>().loadConsultationPatients();
    });
  }

  @override
  void dispose() {
    _mrSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prescriptionProvider = context.watch<PrescriptionProvider>();
    final labValuesProvider = context.watch<LabValuesProvider>();
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    final patient = prescriptionProvider.currentPatient;

    return BaseScaffold(
      title: 'Lab Values',
      drawerIndex: 14,
      showNotificationIcon: true,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main Content ────────────────────────────────────────────────
          Expanded(
            flex: 9,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card with MR Search
                  FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: _buildPatientSearchCard(prescriptionProvider),
                  ),
                  const SizedBox(height: 16),

                  // Investigation Sheet
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: LabValuesSheet(
                        mrNumber: patient?.mrNumber ?? '',
                        receiptId: prescriptionProvider.receiptId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sidebar (Desktop Only) ──────────────────────────────────────
          if (!isMobile)
             const Expanded(
               flex: 3,
               child: _ConsultationSidebar(),
             ),
        ],
      ),
    );
  }

  Widget _buildPatientSearchCard(PrescriptionProvider provider) {
    final patient = provider.currentPatient;
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('PATIENT LAB VALUES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTeal)),
                  const Spacer(),
                  _buildDateStrip(),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoGrid(provider),
            ],
          ),
        ),
        if (provider.isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CustomLoader(size: 50,color: kTeal,),
            ),
          ),
      ],
    );
  }

  Widget _buildDateStrip() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kTealLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kTeal.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, color: kTeal, size: 14),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppDateFormatter.format(now), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextDark)),
              Text(TimeOfDay.fromDateTime(now).format(context), style: const TextStyle(fontSize: 9, color: kTeal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(PrescriptionProvider provider) {
    final patient = provider.currentPatient;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoField('MR No.*', 'Enter MR no.', 
              controller: _mrSearchCtrl, 
              onSubmitted: (val) {
                final mr = val.trim();
                _mrSearchCtrl.text = mr;
                provider.searchPatient(mr);
              },
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
            _buildInfoField('Patient Name', '', 
              initialValue: patient?.fullName, readOnly: true,
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
            _buildInfoField('Age / Gender', '', 
              initialValue: patient != null ? '${patient.age} / ${patient.gender}' : '', readOnly: true,
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
            _buildInfoField('Phone', '', 
              initialValue: patient?.phoneNumber, readOnly: true,
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
            _buildInfoField('Consultant', '', 
              initialValue: provider.doctorName != null ? 'Dr. ${provider.doctorName}' : '', readOnly: true,
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
          ],
        );
      }
    );
  }

  Widget _buildInfoField(String label, String hint, {TextEditingController? controller, String? initialValue, bool readOnly = false, double width = 150, Function(String)? onSubmitted}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: kTextMid, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: controller ?? (TextEditingController(text: initialValue)..selection = TextSelection.collapsed(offset: (initialValue ?? '').length)),
            readOnly: readOnly,
            onSubmitted: onSubmitted,
            style: TextStyle(fontSize: 12, color: readOnly ? kTextMid : kTextDark),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: readOnly ? kBgLight : kWhite,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kTeal)),
            ),
          ),
        ],
      ),
    );
  }
}

// Reuse sidebar from prescription.dart style
class _ConsultationSidebar extends StatelessWidget {
  const _ConsultationSidebar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrescriptionProvider>();
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF00B5AD), Color(0xFF00968F)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_ind, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text('Consultation Patients', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                  onPressed: () => provider.loadConsultationPatients(),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoadingPatients
                ? const CustomLoader(size: 30)
                : provider.consultationPatients
                        .where((p) => !(p['doctor_department']?.toString().toLowerCase().contains('eye') ?? false))
                        .isEmpty
                    ? const Center(child: Text('No consultations today', style: TextStyle(fontSize: 11, color: Colors.grey)))
                    : ListView.separated(
                        itemCount: provider.consultationPatients
                            .where((p) => !(p['doctor_department']?.toString().toLowerCase().contains('eye') ?? false))
                            .length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final filtered = provider.consultationPatients
                              .where((p) => !(p['doctor_department']?.toString().toLowerCase().contains('eye') ?? false))
                              .toList();
                          final p = filtered[idx];
                          final waitTime = WaitTimeHelper.getWaitTime(p['date'], p['time']);
                          
                          return ListTile(
                            dense: true,
                            onTap: () => provider.selectConsultationPatient(p),
                            title: Row(
                              children: [
                                Expanded(child: Text(p['patient_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                if (p['token_number'] != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.indigo.shade100),
                                    ),
                                    child: Text(
                                      'T-${p['token_number']}',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['service_detail'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                if (waitTime != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time, size: 10, color: Colors.amber.shade700),
                                        const SizedBox(width: 4),
                                        Text(waitTime, style: TextStyle(fontSize: 9, color: Colors.amber.shade800, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(p['patient_mr_number']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: kTeal, fontWeight: FontWeight.bold)),
                                if (p['receipt_id'] != null)
                                  Text(p['receipt_id'].toString(), style: const TextStyle(fontSize: 8, color: Colors.grey, fontFamily: 'monospace')),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
