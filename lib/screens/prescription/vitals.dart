import 'package:flutter/material.dart';
import 'package:hims_app/custum%20widgets/drawer/base_scaffold.dart';
import 'package:hims_app/providers/vitals_provider/vitals_provider.dart';
import 'package:provider/provider.dart';
import 'widgets/shared_consultation_widgets.dart';

// ─── Hims Teal Design System ──────────────────────────────────────────────
const kTeal = Color(0xFF00B5AD);
const kTealLight = Color(0xFFE0F7F5);
const kTealBorder = Color(0xFFCCECE9);
const kBg = Color(0xFFF8F9FA);

const kTextDark = Color(0xFF2D3748);
const kTextMid = Color(0xFF718096);
const kTextMuted = Color(0xFFA0AEC0);
const kWhite = Colors.white;

const kCardShadow = [
  BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
];

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final TextEditingController _mrSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VitalsProvider>();
      provider.clearForm();
      provider.fetchConsultationPatients();
    });
  }

  @override
  void dispose() {
    _mrSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VitalsProvider>();
    final isTablet = MediaQuery.of(context).size.width > 1024;

    return BaseScaffold(
      title: 'Patient Vitals',
      drawerIndex: 13,
      body: Container(
        color: kBg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main Dashboard Area ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                child: Column(
                  children: [
                    if (!isTablet) ...[
                      SharedConsultationDropdown(
                        patients: provider.consultationPatients,
                        isLoading: provider.isLoadingConsultations,
                        onSelect: (p) => provider.searchPatient(
                          p['patient_mr_number'].toString(),
                          customReceiptId: p['receipt_id'],
                          customDoctor: p['doctor_name'],
                          tokenNumber: p['token_number']?.toString(),
                        ),
                      ),

                      const SizedBox(height: 16), // spacing here
                    ],

                    _HeaderCard(
                      mrCtrl: _mrSearchCtrl,
                      provider: provider,
                    ),
                    const SizedBox(height: 16),
                    if (provider.currentPatient != null) ...[
                      _VitalsForm(provider: provider),
                      const SizedBox(height: 16),
                      _PainScaleCard(provider: provider),
                      const SizedBox(height: 20),
                      _SaveSection(provider: provider),
                      const SizedBox(height: 40),
                    ] else ...[
                      _NoPatientSelected(),
                    ],
                  ],
                ),
              ),
            ),

            // ── Desktop Consultation Sidebar ─────────────────────────────────
            if (isTablet) SharedConsultationSidebar(
              patients: provider.consultationPatients,
              isLoading: provider.isLoadingConsultations,
              onSelect: (p) => provider.searchPatient(
                p['patient_mr_number'].toString(),
                customReceiptId: p['receipt_id'],
                customDoctor: p['doctor_name'],
                tokenNumber: p['token_number']?.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header Card (Patient Info) ────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final TextEditingController mrCtrl;
  final VitalsProvider provider;
  const _HeaderCard({required this.mrCtrl, required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider.currentPatient;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTealBorder),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.person_pin_outlined, color: kTeal, size: 18),
                const SizedBox(width: 8),
                const Text('PATIENT INFORMATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: 0.5)),
                if (provider.tokenNumber != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kTealLight,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: kTeal.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 12, color: kTeal),
                        const SizedBox(width: 4),
                        Text(
                          'T-${provider.tokenNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: kTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (provider.isLoading) ...[
                  const Spacer(),
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kTeal)),
                ]
              ],
            ),
          ),
          const Divider(height: 1, color: kTealBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: mrCtrl,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark),
                        decoration: InputDecoration(
                          hintText: 'Enter MR Number...',
                          prefixIcon: const Icon(Icons.search, size: 18, color: kTeal),
                          filled: true,
                          fillColor: kTealLight.withOpacity(0.3),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kTeal)),
                        ),
                        onSubmitted: (val) {
                          if (val.isNotEmpty) provider.searchPatient(val.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => provider.searchPatient(mrCtrl.text.trim()),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: kWhite,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                if (p != null) ...[
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    childAspectRatio: 2.2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _InfoItem(label: 'PATIENT NAME', value: p.fullName),
                      _InfoItem(label: 'AGE / GENDER', value: '${p.age ?? '—'} / ${p.gender}'),
                      _InfoItem(label: 'PHONE', value: p.phoneNumber),
                      _InfoItem(label: 'CONSULTANT', value: provider.doctorName ?? 'N/A'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTextMid, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ─── Vitals Form ───────────────────────────────────────────────────────────
class _VitalsForm extends StatelessWidget {
  final VitalsProvider provider;
  const _VitalsForm({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTealBorder),
        boxShadow: kCardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _VitalGroup(
            title: 'BODY MEASUREMENTS',
            icon: Icons.monitor_weight_outlined,
            children: [
              _VitalCard(label: 'Weight', unit: 'Kgs', controller: provider.controllers['weight']!, icon: Icons.scale_rounded),
              _VitalCard(
                label: 'Height', 
                unit: provider.heightUnit == 'in' ? 'Inches' : 'cm', 
                controller: provider.controllers['height']!, 
                icon: Icons.height_rounded,
                trailing: _UnitToggle(
                  value: provider.heightUnit,
                  onChanged: (val) => provider.setHeightUnit(val),
                  options: const ['in', 'cm'],
                ),
              ),
              _VitalComputedCard(label: 'BMI', unit: _getBmiStatus(provider.bmi).label, value: provider.bmi, icon: Icons.speed_rounded, statusColor: _getBmiStatus(provider.bmi).color),
              _VitalComputedCard(label: 'BMR', unit: 'kcal/day', value: provider.bmr, icon: Icons.bolt_rounded, statusColor: kTeal),
              _VitalCard(label: 'Waist', unit: 'cm', controller: provider.controllers['waist']!, icon: Icons.straighten_rounded),
              _VitalCard(label: 'Hip', unit: 'cm', controller: provider.controllers['hip']!, icon: Icons.straighten_rounded),
              _VitalComputedCard(label: 'WHR', unit: _getWhrStatus(provider.whr, provider.currentPatient?.gender).label, value: provider.whr, icon: Icons.donut_large_rounded, statusColor: _getWhrStatus(provider.whr, provider.currentPatient?.gender).color),
            ],
          ),
          const SizedBox(height: 16),
          _VitalGroup(
            title: 'VITAL SIGNS',
            icon: Icons.favorite_border_rounded,
            headerTrailing: _UnitToggle(
              value: provider.bpReadingType,
              onChanged: (val) => provider.setBpReadingType(val),
              options: const ['regular', 'fasting'],
            ),
            children: [
              _VitalCard(label: 'Systolic', unit: 'mmHg', controller: provider.controllers['systolic']!, icon: Icons.favorite_rounded),
              _VitalCard(label: 'Diastolic', unit: 'mmHg', controller: provider.controllers['diastolic']!, icon: Icons.favorite_outline_rounded),
              _VitalCard(label: 'Pulse', unit: 'bpm', controller: provider.controllers['pulse']!, icon: Icons.monitor_heart_rounded),
              _VitalCard(label: 'SpO2', unit: '%', controller: provider.controllers['spo2']!, icon: Icons.air_rounded),
              _VitalCard(label: 'Temp', unit: '°F', controller: provider.controllers['temperature']!, icon: Icons.thermostat_rounded),
            ],
          ),
          const SizedBox(height: 16),
          _VitalGroup(
            title: 'GLYCEMIC',
            icon: Icons.bloodtype_outlined,
            children: [
              _VitalCard(label: 'BSR', unit: 'mg/dl', controller: provider.controllers['bsr']!, icon: Icons.water_drop_rounded),
            ],
          ),
        ],
      ),
    );
  }

  _StatusData _getBmiStatus(String val) {
    if (val == '—') return _StatusData('—', kTextMuted);
    final v = double.tryParse(val) ?? 0;
    if (v < 18.5) return _StatusData('Underweight', Colors.blue);
    if (v < 25) return _StatusData('Normal', Colors.green);
    if (v < 30) return _StatusData('Overweight', Colors.orange);
    return _StatusData('Obese', Colors.red);
  }

  _StatusData _getWhrStatus(String val, String? g) {
    if (val == '—') return _StatusData('—', kTextMuted);
    final v = double.tryParse(val) ?? 0;
    final isM = (g ?? '').toLowerCase().startsWith('m');
    if (isM) {
      if (v < 0.9) return _StatusData('Low Risk', Colors.green);
      if (v < 1.0) return _StatusData('Moderate', Colors.orange);
      return _StatusData('High Risk', Colors.red);
    }
    if (v < 0.8) return _StatusData('Low Risk', Colors.green);
    if (v < 0.85) return _StatusData('Moderate', Colors.orange);
    return _StatusData('High Risk', Colors.red);
  }
}

class _StatusData {
  final String label;
  final Color color;
  _StatusData(this.label, this.color);
}

// ─── Vital Group Component ───────────────────────────────────────────────
class _VitalGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? headerTrailing;
  const _VitalGroup({required this.title, required this.icon, required this.children, this.headerTrailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kTealLight.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kTealBorder.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: kTeal),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kTextMid, letterSpacing: 1))),
              if (headerTrailing != null) headerTrailing!,
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children.map((e) {
              final width = (MediaQuery.of(context).size.width > tabletsThreshold) 
                  ? 140.0 
                  : (MediaQuery.of(context).size.width - 64) / 3; // 3 items per row
              return SizedBox(width: width, child: e);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

const double tabletsThreshold = 1000;

// ─── Individual Vital Cards (Standardized) ──────────────────────────────────
class _VitalCard extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final IconData icon;
  final Widget? trailing;

  const _VitalCard({required this.label, required this.unit, required this.controller, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: kTealBorder), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 2, offset: const Offset(0, 1))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 10, color: kTeal),
                  const SizedBox(width: 4),
                  Text(label.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: kTextMid, letterSpacing: 0.5)),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextDark),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              hintStyle: TextStyle(color: kTextMuted.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              suffixText: unit,
              suffixStyle: const TextStyle(fontSize: 9, color: kTextMid, fontWeight: FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalComputedCard extends StatelessWidget {
  final String label;
  final String unit;
  final String value;
  final IconData icon;
  final Color statusColor;

  const _VitalComputedCard({required this.label, required this.unit, required this.value, required this.icon, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withOpacity(0.25), width: 1.5), boxShadow: [BoxShadow(color: statusColor.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: statusColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label.toUpperCase(), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: statusColor.withOpacity(0.8), letterSpacing: 0.5))),
            ],
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: statusColor)),
                Text(unit, style: TextStyle(fontSize: 8, color: statusColor.withOpacity(0.7), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pain Scale Card ──────────────────────────────────────────────────────
class _PainScaleCard extends StatelessWidget {
  final VitalsProvider provider;
  const _PainScaleCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final int val = provider.painScale;
    final List<String> labels = ['None', 'Mild', 'Mild', 'Moderate', 'Moderate', 'Moderate', 'Severe', 'Severe', 'Very Severe', 'Worst'];
    final String statusText = val == 0 ? 'No Pain' : '${labels[val - 1]} Pain';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTealBorder),
        boxShadow: kCardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_outlined, color: kTeal, size: 18),
              const SizedBox(width: 8),
              const Text('PAIN SCALE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: val == 0 ? kTealBorder : kTeal, borderRadius: BorderRadius.circular(20)),
                child: Text('$val/10', style: const TextStyle(color: kWhite, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: kTeal,
              inactiveTrackColor: kTealBorder,
              thumbColor: kTeal,
              overlayColor: kTeal.withOpacity(0.1),
              trackHeight: 10,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: val.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (v) => provider.setPainScale(v.toInt()),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(11, (i) => 
               GestureDetector(
                 onTap: () => provider.setPainScale(i),
                 child: Container(
                   width: 24,
                   height: 24,
                   decoration: BoxDecoration(
                     color: val == i ? kTeal : kWhite,
                     shape: BoxShape.circle,
                     border: Border.all(color: val == i ? kTeal : kTealBorder),
                   ),
                   alignment: Alignment.center,
                   child: Text('$i', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: val == i ? kWhite : kTextMid)),
                 ),
               ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(statusText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: val == 0 ? kTextMid : kTeal)),
          ),
        ],
      ),
    );
  }
}

// ─── Save Section ─────────────────────────────────────────────────────────
class _SaveSection extends StatelessWidget {
  final VitalsProvider provider;
  const _SaveSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: provider.isSaving ? null : () async {
          final s = await provider.saveVitals();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s ? 'Vitals saved successfully' : 'Failed to save'), backgroundColor: s ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating));
          }
        },
        icon: provider.isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.check_circle_outline_rounded),
        label: Text(provider.isSaving ? 'Saving...' : 'SAVE PATIENT VITALS', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: kWhite, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2),
      ),
    );
  }
}


class _NoPatientSelected extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.monitor_heart_outlined, size: 100, color: kTextMuted.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Search Patient or Select from Consultations', style: TextStyle(color: kTextMid, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('To start recording vital signs', style: TextStyle(color: kTextMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Unit Toggle Widget ──────────────────────────────────────────────────
class _UnitToggle extends StatelessWidget {
  final String value;
  final Function(String) onChanged;
  final List<String> options;

  const _UnitToggle({required this.value, required this.onChanged, required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: kTealLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kTealBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSel = value == opt;
          return GestureDetector(
            onTap: () => onChanged(opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: isSel ? kTeal : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                opt.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: isSel ? kWhite : kTeal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
