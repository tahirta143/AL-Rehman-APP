import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../models/consultation_model/appointment_model.dart';
import '../../models/consultation_model/doctor_model.dart';
import '../../providers/opd/consultation_provider/cunsultation_provider.dart';
import '../../providers/mr_provider/mr_provider.dart';
import '../../core/utils/date_formatter.dart';
import 'widgets/appointment_dialog.dart';
import '../../custum widgets/custom_loader.dart';
import '../../custum widgets/animations/animations.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../global/global_api.dart';

const Color _teal = Color(0xFF00B5AD);
const Color _textDark = Color(0xFF1A202C);

class ConsultationScreen extends StatefulWidget {
  final bool useScaffold;
  const ConsultationScreen({super.key, this.useScaffold = true});
  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<ConsultationProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        prov.resetLoading();
        prov.loadDoctors();
        prov.loadAppointments();
      }
    });
  }

  String _todayLabel() {
    return AppDateFormatter.formatWithDay(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<ConsultationProvider>(context);
    final sw   = MediaQuery.of(context).size.width;
    final sh   = MediaQuery.of(context).size.height;
    final tp   = MediaQuery.of(context).padding.top;

    final content = Column(
      children: [
        // ── STICKY HEADER — outside scroll, never moves ──
        _buildHeader(sw, sh, tp),

        // ── SCROLLABLE BODY ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await prov.loadDoctors();
              await prov.loadAppointments();
            },
            color: _teal,
            child: prov.isLoading
                ? Center(
                    child: CustomLoader(
                      size: 50,
                      color: _teal,
                    ),
                  )
                : prov.errorMessage != null
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: sh * 0.2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: sw * 0.15, color: Colors.red.shade300),
                                SizedBox(height: sh * 0.02),
                                Text(prov.errorMessage!,
                                    style: TextStyle(
                                        fontSize: sw * 0.04,
                                        color: Colors.red.shade400)),
                                SizedBox(height: sh * 0.02),
                                ElevatedButton.icon(
                                  onPressed: () => prov.loadDoctors(),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary cards
                FadeInUp(delay: const Duration(milliseconds: 100), child: _buildSummary(prov, sw, sh)),

                // Section heading
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        sw * 0.04, sh * 0.018, sw * 0.04, sh * 0.012),
                    child: Row(children: [
                      Icon(Icons.people_alt_rounded,
                          color: _teal, size: sw * 0.045),
                      SizedBox(width: sw * 0.02),
                      Text('Our Consultants',
                          style: TextStyle(
                              fontSize: sw * 0.042,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ]),
                  ),
                ),

                // Doctor grid — 2 per row, column layout cards
                prov.doctors.isEmpty
                    ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(sw * 0.1),
                    child: Text('No doctors available',
                        style: TextStyle(
                            fontSize: sw * 0.04,
                            color: Colors.grey.shade500)),
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  clipBehavior: Clip.none, // Allow pop-outs to overflow list boundaries
                  itemCount: prov.doctors.length,
                  itemBuilder: (_, i) {
                    final doctor = prov.doctors[i];
                    final today = DateTime.now();
                    return Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 20, left: 16, right: 16),
                      child: FadeInUp(
                        delay: Duration(milliseconds: 100 + (i * 50)),
                        child: _DoctorCard(
                          doctor: doctor,
                          bookedSlots: prov.bookedSlots(today, doctor.name).length,
                          availableSlots: prov.availableSlotsForDoctor(doctor.name, today),
                          onTap: () => _showDialog(context, prov, doctor, sw, sh),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
        )],
    );

    if (!widget.useScaffold) return content;

    return BaseScaffold(
      scaffoldKey: _scaffoldKey,
      title: 'Consultations',
      drawerIndex: 1,
      showAppBar: false,
      body: CustomPageTransition(
        child: content,
      ),
    );
  }

  // ════════════════════════════════════════
  //  STICKY HEADER
  // ════════════════════════════════════════
  Widget _buildHeader(double sw, double sh, double tp) {
    return Container(
      decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomLeft:Radius.circular(20),
            bottomRight:Radius.circular(20),
          ),
        color: Color(0xFF00B5AD)
      ),
      padding: EdgeInsets.only(
          top: tp + sh * 0.016,
          left: sw * 0.04,
          right: sw * 0.04,
          bottom: sh * 0.022),
      child: Row(children: [
        GestureDetector(
          onTap: () => Scaffold.of(context).openDrawer(),
          child: Container(
            padding: EdgeInsets.all(sw * 0.022),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(sw * 0.025),
            ),
            child: Icon(Icons.menu_rounded, color: Colors.white, size: sw * 0.05),
          ),
        ),
        SizedBox(width: sw * 0.03),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Appointments',
              style: TextStyle(color: Colors.white, fontSize: sw * 0.055,
                  fontWeight: FontWeight.bold, letterSpacing: 0.2)),
          SizedBox(height: sh * 0.003),
          Text(_todayLabel(),
              style: TextStyle(color: Colors.white70, fontSize: sw * 0.028,
                  fontWeight: FontWeight.w500)),
        ])),
        Container(
          padding: EdgeInsets.all(sw * 0.022),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(sw * 0.025),
          ),
          child: Icon(Icons.notifications_outlined,
              color: Colors.white, size: sw * 0.05),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════
  //  SUMMARY CARDS
  // ════════════════════════════════════════
  Widget _buildSummary(ConsultationProvider prov, double sw, double sh) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          horizontal: sw * 0.04, vertical: sh * 0.018),
      child: Row(children: [
        _SummaryCard(label: 'Total\nConsultations',
            value: prov.totalConsultations.toString(),
            icon: Icons.receipt_long_rounded, color: _teal, sw: sw),
        SizedBox(width: sw * 0.025),
        _SummaryCard(label: 'Upcoming\nAppointments',
            value: prov.upcomingAppointments.toString(),
            icon: Icons.schedule_rounded,
            color: const Color(0xFF1E88E5), sw: sw),
        SizedBox(width: sw * 0.025),
        _SummaryCard(label: 'Completed\nAppointments',
            value: prov.completedAppointments.toString(),
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF43A047), sw: sw),
      ]),
    );
  }

  void _showDialog(BuildContext context, ConsultationProvider prov,
      DoctorInfo doctor, double sw, double sh) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: prov),
          ChangeNotifierProvider.value(value: context.read<MrProvider>()),
        ],
        child: AppointmentDialog(
          doctor: doctor,
          availableSlots: prov.availableSlotsForDoctor(doctor.name, DateTime.now()),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  SUMMARY CARD
// ════════════════════════════════════════════════
class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final double sw;
  const _SummaryCard({required this.label, required this.value,
    required this.icon, required this.color, required this.sw});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(sw * 0.03),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(sw * 0.035),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: EdgeInsets.all(sw * 0.018),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(sw * 0.02),
            ),
            child: Icon(icon, color: color, size: sw * 0.038),
          ),
          SizedBox(height: sw * 0.018),
          Text(value, style: TextStyle(fontSize: sw * 0.052,
              fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: sw * 0.004),
          Text(label, style: TextStyle(fontSize: sw * 0.023,
              color: color.withOpacity(0.75),
              fontWeight: FontWeight.w600, height: 1.3),
              maxLines: 2),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  DOCTOR CARD — column layout, NO book button
// ════════════════════════════════════════════════
class _DoctorCard extends StatelessWidget {
  final DoctorInfo doctor;
  final int bookedSlots;
  final int availableSlots;
  final VoidCallback onTap;

  const _DoctorCard({
    required this.doctor,
    required this.bookedSlots,
    required this.availableSlots,
    required this.onTap,
  });

  String _initials(String name) {
    if (name.trim().isEmpty) return '?';
    final clean = name.replaceAll('Dr. ', '').trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cw = constraints.maxWidth;
      final Color baseColor = doctor.avatarColor;

      // Extract current dates for the schedule highlight
      final now = DateTime.now();
      final List<DateTime> weekDates = List.generate(7, (i) => now.add(Duration(days: i)));
      final List<String> shortDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return GestureDetector(
        onTap: onTap,
        child: Container(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Main Card Body ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(130, 16, 16, 16), // Large left pad for image
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctor.name,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctor.specialty,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Consultation',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                  ),
                                  Text(
                                    'Rs. ${doctor.consultationFee}',
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Follow-up',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                  ),
                                  Text(
                                    'Rs. ${doctor.followUpCharges}',
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(Icons.call_made_rounded, color: Color(0xFF1A1A1A), size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ── Bottom Section: Schedule ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border(top: BorderSide(color: Colors.grey.shade100)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          constraints: BoxConstraints(minWidth: cw - 32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Schedule',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ...weekDates.map((date) {
                                final dayName = shortDayNames[date.weekday - 1];
                                final fullDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                                final fullDayName = fullDayNames[date.weekday - 1];
                                final isAvailable = doctor.availableDays.contains(dayName) || 
                                                    doctor.availableDays.contains(fullDayName);
                                return Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: isAvailable ? const Color(0xFF00B5AD) : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isAvailable ? const Color(0xFF00B5AD) : Colors.grey.shade200),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      color: isAvailable ? Colors.white : Colors.grey.shade400,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Popping Doctor Image ──
              Positioned(
                left: 16,
                top: -15, 
                bottom: 53, // Touches the schedule section top border
                child: Hero(
                  tag: 'doc_${doctor.id}',
                  child: Container(
                    width: 100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Builder(
                        builder: (context) {
                          final url = GlobalApi.getImageUrl(doctor.imageAsset);
                          if (url != null) {
                            return CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              placeholder: (_, __) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: baseColor)),
                              errorWidget: (_, __, ___) => Icon(Icons.person, size: 50, color: baseColor),
                            );
                          }
                          return Icon(Icons.person, size: 50, color: baseColor);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _detailRow(IconData icon, String text, double cw, DoctorInfo doctor) {
    return Row(children: [
      Icon(icon, size: cw * 0.055, color: doctor.avatarColor.withOpacity(0.7)),
      SizedBox(width: cw * 0.025),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: cw * 0.052,
              color: Colors.black54, fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _miniStat(String val, String label, Color color, double cw) {
    return Column(children: [
      Text(val, style: TextStyle(fontSize: cw * 0.065,
          fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: cw * 0.048,
          color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
    ]);
  }
}