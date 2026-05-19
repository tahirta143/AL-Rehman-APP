import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../providers/nutrition_provider/nutrition_provider.dart';
import '../../providers/prescription_provider/prescription_provider.dart';
import '../../core/providers/permission_provider.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../models/vitals_model/vitals_model.dart';
import '../../core/services/pdf_nutrition_service.dart';
import '../../custum widgets/custom_loader.dart';
import '../../core/utils/wait_time_helper.dart';
import 'widgets/shared_consultation_widgets.dart';
import '../../models/nutrition_model/nutrition_prescription_model.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const kTeal = Color(0xFF00B5AD);
const kTealLight = Color(0xFFE0F7F5);
const kBorder = Color(0xFFCCECE9);
const kBg = Color(0xFFF8F9FA);
const kTextDark = Color(0xFF2D3748);
const kTextMid = Color(0xFF718096);
const kWhite = Colors.white;

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  String _activeTab = 'current';
  String? _lastFetchedMr;
  late PrescriptionProvider _prescriptionProvider;

  @override
  void initState() {
    super.initState();
    _prescriptionProvider = context.read<PrescriptionProvider>();
    _prescriptionProvider.addListener(_onPrescriptionProviderChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nutritionProvider = context.read<NutritionProvider>();
      nutritionProvider.startConsultationTimer(_prescriptionProvider);
      if (_prescriptionProvider.currentPatient != null) {
        _onPrescriptionProviderChanged();
      }
    });
  }

  void _onPrescriptionProviderChanged() {
    if (!mounted) return;
    final nutritionProvider = context.read<NutritionProvider>();
    final mr = _prescriptionProvider.currentPatient?.mrNumber;
    if (mr != _lastFetchedMr) {
      _lastFetchedMr = mr;
      if (mr != null) {
        nutritionProvider.fetchHistory(mr);
      } else {
        nutritionProvider.clearHistory();
      }
    }
  }

  @override
  void dispose() {
    _prescriptionProvider.removeListener(_onPrescriptionProviderChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nutritionProvider = context.watch<NutritionProvider>();
    final prescriptionProvider = context.watch<PrescriptionProvider>();
    final mq = MediaQuery.of(context);
    final isMobile = mq.size.width < 900;

    return BaseScaffold(
      title: 'Nutrition Assessment',
      drawerIndex: 15,
      showNotificationIcon: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: mq.size.width * 0.04,
          right: mq.size.width * 0.04,
          top: mq.size.height * 0.02,
          bottom: mq.size.height * 0.15,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile) const SharedConsultationDropdown(),
                  if (isMobile) const SizedBox(height: 16),

                  // ── Patient Info ──────────────────────────────────────────
                  FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: _PatientInfoCard(
                      isTablet: !isMobile,
                      screenW: mq.size.width,
                      provider: prescriptionProvider,
                      nutritionProvider: nutritionProvider,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Tab Selector ──────────────────────────────────────────
                  _buildTabSelector(nutritionProvider, prescriptionProvider),
                  const SizedBox(height: 16),

                  if (_activeTab == 'current') ...[
                    // ── Nutritional Assessment & Plan ─────────────────────
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: _buildSectionCard(
                        title: 'Nutritional Assessment & Plan',
                        icon: Icons.scale_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSubHeader('MACRONUTRIENT GOALS', Icons.local_fire_department_outlined),
                            const SizedBox(height: 6),
                            _buildMacroRow(nutritionProvider),
                            const SizedBox(height: 12),

                            _buildSubHeader('DIET SPECIFICATIONS', Icons.opacity_outlined),
                            const SizedBox(height: 6),
                            _buildSpecsRow(mq.size.width, nutritionProvider),
                            const SizedBox(height: 12),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: 'Dietary Recommendations',
                                    hint: 'Enter recommendations...',
                                    maxLines: 2,
                                    controller: nutritionProvider.controllers['dietaryRec'],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _InputField(
                                    label: 'Lifestyle Recommendations',
                                    hint: 'Enter suggestions...',
                                    maxLines: 2,
                                    controller: nutritionProvider.controllers['lifestyleRec'],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Diet Plan Schedule ────────────────────────────────
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildSectionCard(
                        title: 'Diet Plan Schedule',
                        icon: Icons.calendar_today_outlined,
                        child: _buildScheduleList(mq.size.width, nutritionProvider),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Save & Print Button ───────────────────────────────
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: _SavePrintButton(
                        isTablet: !isMobile,
                        onPressed: () async {
                          final savedId = await nutritionProvider.savePrescription(prescriptionProvider);
                          if (savedId != null) {
                            if (!mounted) return;
                            _showSuccessDialog(context, nutritionProvider, savedId);
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to save prescription. Ensure a patient is selected.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        isLoading: nutritionProvider.isSaving,
                        isEnabled: prescriptionProvider.currentPatient != null,
                      ),
                    ),
                  ] else ...[
                    // ── Old Visits ────────────────────────────────────────
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: _buildOldVisitsSection(nutritionProvider, prescriptionProvider),
                    ),
                  ],
                ],
              ),
            ),
            if (!isMobile)
              const Expanded(
                flex: 3,
                child: SharedConsultationSidebar(),
              ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, NutritionProvider provider, dynamic savedId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Prescription Saved'),
          ],
        ),
        content: const Text('Would you like to print the prescription now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                Navigator.pop(ctx);
                await Future.delayed(const Duration(milliseconds: 300));
                final fullRx = await provider.fetchPrescriptionById(savedId);
                if (fullRx != null) {
                  await PDFNutritionService.printPrescription(fullRx);
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not fetch prescription details for printing.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            icon: const Icon(Icons.print),
            label: const Text('Print Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kTeal, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: kTextDark, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: kBorder, height: 1),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildSubHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.orange.shade700),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ── FIXED: Use Row instead of GridView for macros to avoid oversized cells ──
  Widget _buildMacroRow(NutritionProvider provider) {
    final fields = [
      {'label': 'Kilocalories', 'hint': '0', 'suffix': 'kcal', 'key': 'kcal'},
      {'label': 'Carbs', 'hint': '0', 'suffix': 'g', 'key': 'carbs'},
      {'label': 'Proteins', 'hint': '0', 'suffix': 'g', 'key': 'proteins'},
      {'label': 'Fats', 'hint': '0', 'suffix': 'g', 'key': 'fats'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 500;
        if (isSmall) {
          return Column(
            children: [
              Row(
                children: fields.sublist(0, 2).map((f) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: f == fields[0] ? 8 : 0),
                    child: _InputField(
                      label: f['label']!,
                      hint: f['hint']!,
                      suffix: f['suffix'],
                      controller: provider.controllers[f['key']],
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: fields.sublist(2).map((f) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: f == fields[2] ? 8 : 0),
                    child: _InputField(
                      label: f['label']!,
                      hint: f['hint']!,
                      suffix: f['suffix'],
                      controller: provider.controllers[f['key']],
                    ),
                  ),
                )).toList(),
              ),
            ],
          );
        }
        return Row(
          children: fields.asMap().entries.map((e) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: e.key < fields.length - 1 ? 8 : 0),
                child: _InputField(
                  label: e.value['label']!,
                  hint: e.value['hint']!,
                  suffix: e.value['suffix'],
                  controller: provider.controllers[e.value['key']],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── FIXED: Use Row instead of GridView for specs to avoid oversized cells ──
  Widget _buildSpecsRow(double sw, NutritionProvider provider) {
    final fields = [
      {'label': 'Fluid', 'hint': 'e.g. 2.5L', 'suffix': 'L', 'key': 'fluid'},
      {'label': 'Diet Order', 'hint': 'e.g. NPO...', 'suffix': null, 'key': 'dietOrder'},
      {'label': 'Diet Type', 'hint': 'e.g. Keto...', 'suffix': null, 'key': 'dietType'},
    ];

    final isSmall = sw < 500;
    if (isSmall) {
      return Column(
        children: [
          Row(
            children: fields.sublist(0, 2).map((f) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: f == fields[0] ? 8 : 0),
                child: _InputField(
                  label: f['label']!,
                  hint: f['hint']!,
                  suffix: f['suffix'],
                  controller: provider.controllers[f['key']],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InputField(
                  label: fields[2]['label']!,
                  hint: fields[2]['hint']!,
                  suffix: fields[2]['suffix'],
                  controller: provider.controllers[fields[2]['key']],
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      );
    }

    return Row(
      children: fields.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key < fields.length - 1 ? 8 : 0),
            child: _InputField(
              label: e.value['label']!,
              hint: e.value['hint']!,
              suffix: e.value['suffix'],
              controller: provider.controllers[e.value['key']],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScheduleList(double sw, NutritionProvider provider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: _tableHeader('MEAL PART')),
              Expanded(flex: 2, child: _tableHeader('TIME')),
              Expanded(flex: 5, child: _tableHeader('FOOD ITEMS')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...provider.dietPlans.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    item.mealPart,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextDark),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time != null) {
                        provider.updateMealTime(idx, time.format(context));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.mealTime,
                              style: const TextStyle(fontSize: 10, color: kTextDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.access_time, size: 12, color: kTeal),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: item.foodController,
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Enter recommended food items...',
                      hintStyle: TextStyle(fontSize: 11, color: kTextMid.withOpacity(0.5)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: kTeal),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextMid, letterSpacing: 0.5),
    );
  }

  Widget _buildTabSelector(NutritionProvider nutritionProvider, PrescriptionProvider prescriptionProvider) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Current Plan',
            icon: Icons.scale_outlined,
            isSelected: _activeTab == 'current',
            onTap: () => setState(() => _activeTab = 'current'),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'Old Visits',
            icon: Icons.history_outlined,
            isSelected: _activeTab == 'old_visits',
            badgeCount: nutritionProvider.visitHistory.length,
            onTap: () => setState(() => _activeTab = 'old_visits'),
          ),
        ],
      ),
    );
  }

  Widget _buildOldVisitsSection(NutritionProvider nutritionProvider, PrescriptionProvider prescriptionProvider) {
    final patient = prescriptionProvider.currentPatient;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Old Nutritionist Visits',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark),
            ),
            if (patient != null && nutritionProvider.visitHistory.isNotEmpty)
              ElevatedButton.icon(
                onPressed: nutritionProvider.analyzingVisits
                    ? null
                    : () async {
                  final success = await nutritionProvider.summarizeVisitsWithAI(patient.fullName);
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to generate AI analysis.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: nutritionProvider.analyzingVisits
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: kTeal),
                )
                    : const Icon(Icons.auto_awesome, size: 12),
                label: const Text('AI Analysis', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBg,
                  foregroundColor: kTeal,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (nutritionProvider.isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(color: kTeal),
                  SizedBox(height: 12),
                  Text('Loading nutritionist visit history...', style: TextStyle(fontSize: 11, color: kTextMid)),
                ],
              ),
            ),
          )
        else if (patient == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.history_outlined, size: 40, color: kTextMid.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  const Text('Search a patient first', style: TextStyle(fontSize: 11, color: kTextMid)),
                ],
              ),
            ),
          )
        else if (nutritionProvider.visitHistory.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.history_outlined, size: 40, color: kTextMid.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    const Text('No previous nutritionist visits', style: TextStyle(fontSize: 11, color: kTextMid)),
                  ],
                ),
              ),
            )
          else ...[
              _buildAiAnalysisBox(nutritionProvider),
              ...nutritionProvider.visitHistory.map((visit) => _OldVisitCard(
                visit: visit,
                formatMealTime: _formatMealTime,
                formatDate: _formatDate,
              )),
            ],
      ],
    );
  }

  Widget _buildAiAnalysisBox(NutritionProvider provider) {
    if (provider.visitAnalysis.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF00B5AD), size: 16),
              const SizedBox(width: 6),
              Text(
                'AI ANALYSIS & RECOMMENDATIONS',
                style: TextStyle(
                  color: Color(0xFF00B5AD),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            provider.visitAnalysis,
            style: const TextStyle(color: Color(0xFF334155), fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year.toString().substring(2)}';
    } catch (_) {
      return '—';
    }
  }

  String _formatMealTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '--:--') return '';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final h = hour % 12 == 0 ? 12 : hour % 12;
      return '$h:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return timeStr;
    }
  }
}

// ─── Save & Print Button ──────────────────────────────────────────────────────
class _SavePrintButton extends StatelessWidget {
  final bool isTablet;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;

  const _SavePrintButton({
    required this.isTablet,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 52 : 48,
      child: ElevatedButton.icon(
        onPressed: (isLoading || !isEnabled) ? null : onPressed,
        icon: isLoading
            ? const SizedBox(width: 18, height: 18, child: CustomLoader(size: 18, color: kWhite))
            : const Icon(Icons.save_outlined, size: 18),
        label: Text(
          isLoading ? 'Saving...' : 'Save & Print',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.4),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kTeal,
          foregroundColor: kWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          disabledBackgroundColor: kTeal.withOpacity(0.3),
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
  final NutritionProvider nutritionProvider;

  const _PatientInfoCard({
    required this.isTablet,
    required this.screenW,
    required this.provider,
    required this.nutritionProvider,
  });

  @override
  Widget build(BuildContext context) {
    final patient = provider.currentPatient;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
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
                Text(
                  'Patient Information',
                  style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold, fontSize: isTablet ? 14 : 13),
                ),
                const Spacer(),
                if (provider.isLoading)
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _VitalsSummaryBox(vitals: provider.currentVitals),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _mobileGrid(BuildContext context, PatientModel? patient) {
    final doctorName = provider.doctorName ??
        (provider.currentPatient != null
            ? (context.read<PermissionProvider>().fullName ?? 'Doctor')
            : 'Enter doctor name');
    return Column(
      children: [
        _FieldRow(fields: [
          _FieldData('MR No.*', 'Enter MR no.',
              required: true,
              initialValue: patient?.mrNumber,
              onSearch: (val) => provider.searchPatient(val)),
          _FieldData('Patient Name', '', initialValue: patient?.fullName, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          _FieldData('Age / Gender', '',
              initialValue: patient != null ? '${patient.age ?? ''} / ${patient.gender}' : '',
              readOnly: true),
          _FieldData('Phone', '', initialValue: patient?.phoneNumber, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          _FieldData('Father / Husband', '', initialValue: patient?.guardianName, readOnly: true),
          _FieldData('Address', '', initialValue: patient?.address, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          _FieldData('Consultant', 'Consultant name',
              initialValue: doctorName,
              controller: nutritionProvider.controllers['doctorName']),
          _FieldData('Receipt ID', 'Receipt ID',
              initialValue: provider.receiptId,
              controller: provider.vitalControllers['receiptId']),
        ]),
      ],
    );
  }

  Widget _tabletGrid(BuildContext context, PatientModel? patient) {
    final doctorName = provider.doctorName ??
        (provider.currentPatient != null
            ? (context.read<PermissionProvider>().fullName ?? 'Doctor')
            : 'Enter doctor name');
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _InputField(
                label: 'MR No.*',
                hint: 'Enter MR no.',
                required: true,
                initialValue: patient?.mrNumber,
                onSubmitted: (val) => provider.searchPatient(val)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InputField(label: 'Patient Name', hint: '', initialValue: patient?.fullName, readOnly: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InputField(
                label: 'Age / Gender',
                hint: '',
                initialValue: patient != null ? '${patient.age ?? ''} / ${patient.gender}' : '',
                readOnly: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InputField(label: 'Phone', hint: '', initialValue: patient?.phoneNumber, readOnly: true),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _InputField(
                label: 'Father / Husband', hint: '', initialValue: patient?.guardianName, readOnly: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InputField(label: 'Address', hint: '', initialValue: patient?.address, readOnly: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InputField(
                label: 'Consultant',
                hint: 'Consultant name',
                initialValue: doctorName,
                controller: nutritionProvider.controllers['doctorName']),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InputField(
                label: 'Receipt ID',
                hint: 'Receipt ID',
                initialValue: provider.receiptId,
                controller: provider.vitalControllers['receiptId']),
          ),
        ]),
      ],
    );
  }
}

// ─── Vitals Summary ───────────────────────────────────────────────────────────
class _VitalsSummaryBox extends StatelessWidget {
  final VitalsModel? vitals;
  const _VitalsSummaryBox({this.vitals});

  @override
  Widget build(BuildContext context) {
    if (vitals == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'No vitals recorded for this visit',
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    final items = [
      {'label': 'Weight', 'val': '${vitals!.weight ?? '—'}', 'unit': 'kg'},
      {'label': 'Height', 'val': '${vitals!.height ?? '—'}', 'unit': 'in'},
      {'label': 'BMI', 'val': '${vitals!.bmi ?? '—'}', 'unit': ''},
      {
        'label': 'B.P.',
        'val': (vitals!.systolic != null && vitals!.diastolic != null)
            ? '${vitals!.systolic}/${vitals!.diastolic}'
            : '—',
        'unit': 'mmHg'
      },
      {'label': 'Pulse', 'val': '${vitals!.pulse ?? '—'}', 'unit': 'bpm'},
      {'label': 'SpO2', 'val': '${vitals!.spo2 ?? '—'}', 'unit': '%'},
      {'label': 'Temp', 'val': '${vitals!.temperature ?? '—'}', 'unit': '°F'},
      {'label': 'Pain', 'val': '${vitals!.painScale}', 'unit': '/10'},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 14, color: Color(0xFF3B82F6)),
              SizedBox(width: 6),
              Text('VITALS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it['label']!.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${it['val']} ${it['unit']}',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ),
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

// ─── Field Helpers ────────────────────────────────────────────────────────────
class _FieldData {
  final String label;
  final String hint;
  final bool required;
  final String? initialValue;
  final bool readOnly;
  final Function(String)? onSearch;
  final TextEditingController? controller;

  const _FieldData(
      this.label,
      this.hint, {
        this.required = false,
        this.initialValue,
        this.readOnly = false,
        this.onSearch,
        this.controller,
      });
}

class _FieldRow extends StatelessWidget {
  final List<_FieldData> fields;
  const _FieldRow({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Row(
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
  final String? suffix;

  const _InputField({
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.initialValue,
    this.readOnly = false,
    this.onSubmitted,
    this.controller,
    this.suffix,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label,
            style: const TextStyle(color: kTextMid, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        TextField(
          controller: _ctrl,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(fontSize: 11, color: widget.readOnly ? kTextMid : kTextDark),
          decoration: InputDecoration(
            hintText: widget.hint.isNotEmpty ? widget.hint : null,
            hintStyle: TextStyle(color: kTextMid.withOpacity(0.4), fontSize: 11),
            suffixText: widget.suffix,
            suffixStyle: const TextStyle(fontSize: 9, color: kTextMid, fontWeight: FontWeight.bold),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: kTeal, width: 1.2)),
            filled: true,
            fillColor: widget.readOnly ? Colors.grey.shade50 : kWhite,
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ─── Tab Button ───────────────────────────────────────────────────────────────
class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final int? badgeCount;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? kTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? kWhite : kTextMid, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? kWhite : kTextMid,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (badgeCount != null && badgeCount! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? kWhite.withOpacity(0.2) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      color: isSelected ? kWhite : const Color(0xFF1E40AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Old Visit Card ───────────────────────────────────────────────────────────
class _OldVisitCard extends StatelessWidget {
  final NutritionPrescriptionModel visit;
  final String Function(String?) formatMealTime;
  final String Function(String?) formatDate;

  const _OldVisitCard({
    required this.visit,
    required this.formatMealTime,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final vitalsItems = <Map<String, String>>[];
    if (visit.weight != null && visit.weight!.isNotEmpty) vitalsItems.add({'label': 'Weight', 'val': '${visit.weight} kg'});
    if (visit.height != null && visit.height!.isNotEmpty) vitalsItems.add({'label': 'Height', 'val': '${visit.height} in'});

    double? w = double.tryParse(visit.weight ?? '');
    double? h = double.tryParse(visit.height ?? '');
    if (w != null && h != null && h > 0) {
      double meters = h * 0.0254;
      double bmi = w / (meters * meters);
      vitalsItems.add({'label': 'BMI', 'val': bmi.toStringAsFixed(1)});
    }
    if (visit.bp != null && visit.bp!.isNotEmpty) vitalsItems.add({'label': 'B.P.', 'val': visit.bp!});
    if (visit.pulse != null && visit.pulse!.isNotEmpty) vitalsItems.add({'label': 'Pulse', 'val': '${visit.pulse} bpm'});
    if (visit.temp != null && visit.temp!.isNotEmpty) vitalsItems.add({'label': 'Temp', 'val': '${visit.temp} °F'});
    if (visit.bloodGroup != null && visit.bloodGroup!.isNotEmpty) vitalsItems.add({'label': 'BG', 'val': visit.bloodGroup!});

    final assessmentItems = <Map<String, String>>[];
    if (visit.totalKilocalories != null && visit.totalKilocalories!.isNotEmpty)
      assessmentItems.add({'label': 'Kcal', 'val': '${visit.totalKilocalories} kcal'});
    if (visit.totalCarbs != null && visit.totalCarbs!.isNotEmpty)
      assessmentItems.add({'label': 'Carbs', 'val': '${visit.totalCarbs}g'});
    if (visit.totalProteins != null && visit.totalProteins!.isNotEmpty)
      assessmentItems.add({'label': 'Protein', 'val': '${visit.totalProteins}g'});
    if (visit.totalFats != null && visit.totalFats!.isNotEmpty)
      assessmentItems.add({'label': 'Fats', 'val': '${visit.totalFats}g'});
    if (visit.totalFluidIntake != null && visit.totalFluidIntake!.isNotEmpty)
      assessmentItems.add({'label': 'Fluid', 'val': '${visit.totalFluidIntake} L'});
    if (visit.dietOrder != null && visit.dietOrder!.isNotEmpty)
      assessmentItems.add({'label': 'Order', 'val': visit.dietOrder!});
    if (visit.dietType != null && visit.dietType!.isNotEmpty)
      assessmentItems.add({'label': 'Type', 'val': visit.dietType!});

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDate(visit.createdAt),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextDark)),
                    if (visit.receiptId != null && visit.receiptId!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Receipt: ${visit.receiptId}',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.grey.shade400)),
                    ],
                  ],
                ),
                Text(
                  visit.doctorName.isNotEmpty ? 'Dr. ${visit.doctorName}' : '—',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTeal),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vitalsItems.isNotEmpty) ...[
                  const Text('VITALS',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kTextMid, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: vitalsItems.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                        child: Text('${item['label']}: ${item['val']}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (assessmentItems.isNotEmpty ||
                    (visit.dietaryRecommendations != null && visit.dietaryRecommendations!.isNotEmpty) ||
                    (visit.lifestyleRecommendations != null && visit.lifestyleRecommendations!.isNotEmpty)) ...[
                  const Text('NUTRITIONAL ASSESSMENT & SPECIFICATIONS',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kTextMid, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  if (assessmentItems.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: assessmentItems.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Text('${item['label']}: ${item['val']}',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00B5AD))),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (visit.dietaryRecommendations != null && visit.dietaryRecommendations!.isNotEmpty)
                    _buildRecommendationRow('Dietary:', visit.dietaryRecommendations!),
                  if (visit.lifestyleRecommendations != null && visit.lifestyleRecommendations!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildRecommendationRow('Lifestyle:', visit.lifestyleRecommendations!),
                  ],
                  const SizedBox(height: 12),
                ],
                if (visit.dietPlans.isNotEmpty) ...[
                  const Text('DIET PLAN SCHEDULE',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kTextMid, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: visit.dietPlans.map((plan) {
                        final formattedTime = formatMealTime(plan.mealTime);
                        final timeStr = formattedTime.isNotEmpty ? ' ($formattedTime)' : '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${plan.mealPart}$timeStr: ',
                                  style: const TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.bold, color: kTextDark)),
                              Expanded(
                                child: Text(
                                  plan.foodItems.isNotEmpty ? plan.foodItems : '—',
                                  style: const TextStyle(fontSize: 10, color: kTextMid),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationRow(String label, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label ', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextDark)),
        Expanded(child: Text(content, style: const TextStyle(fontSize: 10, color: kTextMid))),
      ],
    );
  }
}