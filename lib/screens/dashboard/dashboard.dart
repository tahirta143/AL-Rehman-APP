import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:hims_app/custum widgets/drawer/base_scaffold.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../custum widgets/custom_loader.dart';
import '../../providers/opd/consultation_provider/cunsultation_provider.dart';
import '../../providers/mr_provider/mr_provider.dart';
import '../../models/consultation_model/doctor_model.dart';
import '../../models/dashboard_model.dart';
import '../../providers/dashboard/dashboard_provider.dart';
import '../../custum widgets/animations/animations.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../global/global_api.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';

import '../add_expenses/add_expenses.dart';
import '../cunsultations/cunsultations.dart';
import '../cunsultations/widgets/appointment_dialog.dart';
import '../emergency_treatment/emergency_treatment.dart';
import '../mr_details/mr_view/mr_view.dart';
import 'offline_dashboard.dart';

const Color _teal = Color(0xFF00B5AD);

// ─────────────────────────────────────────────
//  ANIMATED COUNTER WIDGET
// ─────────────────────────────────────────────
class _AnimatedCounter extends StatefulWidget {
  final double targetValue;
  final bool isCurrency;
  final TextStyle style;

  const _AnimatedCounter({
    required this.targetValue,
    required this.isCurrency,
    required this.style,
  });

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.targetValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.targetValue != widget.targetValue) {
      _previousValue = old.targetValue;
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.targetValue,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final val = _animation.value;
        final text = widget.isCurrency
            ? 'PKR ${NumberFormat('#,###').format(val.round())}'
            : val.round().toString();
        return Text(text, style: widget.style);
      },
    );
  }
}

// ─────────────────────────────────────────────
//  SUMMARY CARD WIDGET  (compact)
// ─────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String title;
  final double numericValue;
  final bool isCurrency;
  final IconData icon;
  final Color color;
  final String trend;
  final bool trendUp;
  final String subtitle;

  const _SummaryCard({
    required this.title,
    required this.numericValue,
    required this.isCurrency,
    required this.icon,
    required this.color,
    required this.trend,
    required this.trendUp,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AnimatedCounter(
            targetValue: numericValue,
            isCurrency: isCurrency,
            style: TextStyle(
              fontSize: isCurrency ? 13 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'monospace',
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                trendUp ? Icons.arrow_outward_rounded : Icons.south_east_rounded,
                size: 11,
                color: trendUp ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
              ),
              const SizedBox(width: 3),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: trendUp ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EXPENSE BAR WIDGET
// ─────────────────────────────────────────────
class _ExpenseBar extends StatelessWidget {
  final String name;
  final double value;
  final double total;
  final Color color;

  const _ExpenseBar({
    required this.name,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(name,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(3)),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('PKR ${NumberFormat('#,###').format(value)}',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Text('${(pct * 100).round()}%',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DOCTOR CARD WIDGET
// ─────────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final DoctorInfo doctor;
  final int availableSlots;
  final Color primaryColor;
  final VoidCallback onTap;

  const _DoctorCard({
    required this.doctor,
    required this.availableSlots,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double cardWidth = screenSize.width * 0.9;
    final double horizontalPadding = screenSize.width * 0.04;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topRight,
        children: [
          Container(
            width: cardWidth,
            margin: EdgeInsets.only(
              top: screenSize.height * 0.02,
              bottom: screenSize.height * 0.015,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenSize.width * 0.04),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctor.name,
                                style: TextStyle(
                                    fontSize: screenSize.width * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            SizedBox(height: screenSize.height * 0.003),
                            Text(doctor.specialty,
                                style: TextStyle(
                                    fontSize: screenSize.width * 0.035,
                                    color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            SizedBox(height: screenSize.height * 0.008),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: screenSize.width * 0.02,
                                  vertical: screenSize.height * 0.004),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius:
                                BorderRadius.circular(screenSize.width * 0.02),
                              ),
                              child: Text('Rs. ${doctor.consultationFee}',
                                  style: TextStyle(
                                      fontSize: screenSize.width * 0.04,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: screenSize.width * 0.28),
                    ],
                  ),
                  SizedBox(height: screenSize.height * 0.015),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: screenSize.width * 0.035, color: Colors.green),
                      SizedBox(width: screenSize.width * 0.01),
                      Text('$availableSlots Slots Available',
                          style: TextStyle(
                              fontSize: screenSize.width * 0.03,
                              color: Colors.green,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  SizedBox(height: screenSize.height * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDayChip('Mon', screenSize, doctor.availableDays.contains('Mon')),
                      _buildDayChip('Tue', screenSize, doctor.availableDays.contains('Tue')),
                      _buildDayChip('Wed', screenSize, doctor.availableDays.contains('Wed')),
                      _buildDayChip('Thu', screenSize, doctor.availableDays.contains('Thu')),
                      _buildDayChip('Fri', screenSize, doctor.availableDays.contains('Fri')),
                      _buildDayChip('Sat', screenSize, doctor.availableDays.contains('Sat')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -screenSize.height * 0.015,
            right: horizontalPadding,
            child: SizedBox(
              width: screenSize.width * 0.32,
              height: screenSize.width * 0.4,
              child: Builder(
                builder: (context) {
                  final url = GlobalApi.getImageUrl(doctor.imageAsset);
                  if (url != null) {
                    return CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      placeholder: (context, _) =>
                          _buildAvatarFallback(screenSize, isChild: true),
                      errorWidget: (context, _, __) =>
                          _buildAvatarFallback(screenSize, isChild: true),
                    );
                  }
                  return _buildAvatarFallback(screenSize, isChild: true);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(Size screenSize, {bool isChild = false}) {
    final avatar = Container(
      width: screenSize.width * 0.28,
      height: screenSize.width * 0.28,
      decoration: BoxDecoration(
        color: doctor.avatarColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(screenSize.width * 0.05),
      ),
      child: Center(
        child: Text(
          doctor.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join('').toUpperCase(),
          style: TextStyle(
              color: doctor.avatarColor,
              fontWeight: FontWeight.bold,
              fontSize: screenSize.width * 0.08),
        ),
      ),
    );
    if (isChild) return Align(alignment: Alignment.bottomCenter, child: avatar);
    return avatar;
  }

  Widget _buildDayChip(String day, Size screenSize, bool isAvailable) {
    return Container(
      width: screenSize.width * 0.12,
      padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.008),
      decoration: BoxDecoration(
        color: isAvailable ? primaryColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(screenSize.width * 0.025),
      ),
      child: Center(
        child: Text(day,
            style: TextStyle(
                fontSize: screenSize.width * 0.03,
                fontWeight: FontWeight.bold,
                color: isAvailable ? Colors.white : Colors.grey.shade500)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LEGEND DOT  (reusable)
// ─────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  GROUPED BAR CHART  ← NEW (from Orders screen style)
//  3 bars per shift: OPD Revenue | Consult Revenue | Patients
//  X-axis labels: Morning · Evening · Night
// ─────────────────────────────────────────────
class _ShiftGroupedBarChart extends StatelessWidget {
  final DashboardProvider prov;

  const _ShiftGroupedBarChart({required this.prov});

  static const _shifts = ['Morning', 'Evening', 'Night'];

  // Normalise PKR revenue to a 0-55 display scale so bars look proportional.
  // Patients are shown as-is (usually small numbers, clamped to 55).
  List<List<double>> _buildData() {
    double maxRev = 1;
    for (final s in _shifts) {
      final opd = (prov.shiftOpdRevenue[s] ?? 0).toDouble();
      final consult = (prov.shiftConsultRevenue[s] ?? 0).toDouble();
      if (opd > maxRev) maxRev = opd;
      if (consult > maxRev) maxRev = consult;
    }

    return List.generate(_shifts.length, (i) {
      final s = _shifts[i];
      final opd = (prov.shiftOpdRevenue[s] ?? 0).toDouble();
      final consult = (prov.shiftConsultRevenue[s] ?? 0).toDouble();
      final pts = (prov.shiftPatientCount[s] ?? 0).toDouble();
      return [
        (opd / maxRev) * 55,
        (consult / maxRev) * 55,
        pts.clamp(0, 55).toDouble(),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _buildData();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Legend (matches Orders screen style) ─────────────────────────────
        Row(
          children: const [
            _LegendDot(color: Color(0xFF10B981), label: 'OPD Rev'),
            SizedBox(width: 12),
            _LegendDot(color: Colors.indigo, label: 'Consult Rev'),
            SizedBox(width: 12),
            _LegendDot(color: Color(0xFFF59E0B), label: 'Patients'),
          ],
        ),
        const SizedBox(height: 8),

        // ── Bar Chart ─────────────────────────────────────────────────────────
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: 60,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,

              // Grid — horizontal lines only (matches Orders screen)
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 10,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.shade100,
                  strokeWidth: 1,
                ),
              ),

              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.shade100),
              ),

              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 10,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= _shifts.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _shifts[i],
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF94A3B8)),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Tooltip shows actual PKR values (not normalised display values)
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.black87,
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final shift = _shifts[groupIndex];
                    final labels = ['OPD', 'Consult', 'Patients'];
                    final rawValues = [
                      prov.shiftOpdRevenue[shift] ?? 0,
                      prov.shiftConsultRevenue[shift] ?? 0,
                      prov.shiftPatientCount[shift] ?? 0,
                    ];
                    final display = rodIndex < 2
                        ? 'PKR ${NumberFormat('#,###').format(rawValues[rodIndex])}'
                        : rawValues[rodIndex].toString();
                    return BarTooltipItem(
                      '${labels[rodIndex]}\n$display',
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),

              // 3 rods per group — same structure as Orders screen
              barGroups: List.generate(_shifts.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: data[i][0],
                      width: 10,
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    BarChartRodData(
                      toY: data[i][1],
                      width: 10,
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    BarChartRodData(
                      toY: data[i][2],
                      width: 10,
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  DASHBOARD BODY
// ─────────────────────────────────────────────
class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  static const Color primaryColor = Color(0xFF0D9488);
  final DateFormat _dateFormat = DateFormat('EEEE, d MMMM yyyy');

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<DashboardProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      prov.resetToToday();
      prov.resetLoading();
      prov.fetchAvailableShifts(prov.selectedDate);
      prov.fetchCalendarData(prov.selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProv = Provider.of<DashboardProvider>(context);
    final consultationProv = Provider.of<ConsultationProvider>(context);

    return RefreshIndicator(
      onRefresh: () => dashboardProv.refresh(),
      color: _teal,
      child: CustomPageTransition(
        child: dashboardProv.isLoading
            ? Center(
            key: const ValueKey('loader'),
            child: CustomLoader(size: 50, color: _teal))
            : SingleChildScrollView(
          key: const ValueKey('content'),
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _dateFormat.format(dashboardProv.selectedDate),
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.offline_pin_rounded,
                        color: _teal),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, _, __) =>
                        const OfflineDashboardScreen(),
                        transitionDuration: Duration.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Date + shift filters ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dashboardProv.selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null)
                          dashboardProv.setSelectedDate(picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy')
                                  .format(dashboardProv.selectedDate),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: dashboardProv.selectedShiftType,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155)),
                          items: ['All', 'Morning', 'Evening', 'Night']
                              .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                  t == 'All' ? 'All Shifts' : t)))
                              .toList(),
                          onChanged: (val) =>
                              dashboardProv.setSelectedShiftType(val!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── 2×2 summary cards ─────────────────────────────────────
              GridView.count(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.55,
                children: [
                  FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 100),
                    child: _SummaryCard(
                      title: 'OPD Revenue',
                      numericValue: dashboardProv.totalOpdRevenue,
                      isCurrency: true,
                      icon: Icons.attach_money,
                      color: const Color(0xFF10B981),
                      trend: '+4.2%',
                      trendUp: true,
                      subtitle: 'All OPD services',
                    ),
                  ),
                  FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 200),
                    child: _SummaryCard(
                      title: 'Consultations',
                      numericValue: dashboardProv.totalConsultRevenue,
                      isCurrency: true,
                      icon: Icons.medical_services_rounded,
                      color: Colors.indigo,
                      trend: '+1.8%',
                      trendUp: true,
                      subtitle:
                      '${dashboardProv.totalConsultCount} consultations',
                    ),
                  ),
                  FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 300),
                    child: _SummaryCard(
                      title: 'Patients',
                      numericValue:
                      dashboardProv.totalPatients.toDouble(),
                      isCurrency: false,
                      icon: Icons.people_outline_rounded,
                      color: Colors.cyan.shade600,
                      trend: '-0.6%',
                      trendUp: false,
                      subtitle: 'Total OPD entries',
                    ),
                  ),
                  FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 400),
                    child: _SummaryCard(
                      title: 'Expenses',
                      numericValue: dashboardProv.totalExpenses,
                      isCurrency: true,
                      icon: Icons.payments_outlined,
                      color: Colors.amber.shade700,
                      trend: '+2.1%',
                      trendUp: false,
                      subtitle: 'Direct expenses',
                    ),
                  ),
                ],
              ),

              // ── Revenue by Shift — Grouped Bar Chart ──────────────────
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 500),
                child: _buildGlassPanel(
                  title: 'Revenue by Shift',
                  subtitle: 'OPD · Consultation · Patients',
                  child: _ShiftGroupedBarChart(prov: dashboardProv),
                ),
              ),
              const SizedBox(height: 20),

              // ── Monthly Appointments calendar ─────────────────────────
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 600),
                child: _buildCalendarPanel(dashboardProv),
              ),
              const SizedBox(height: 20),

              // ── Revenue Trend (Syncfusion line — unchanged) ───────────
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 700),
                child: _buildGlassPanel(
                  title: 'Revenue Trend',
                  subtitle: 'Intraday estimate',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimatedCounter(
                        targetValue: dashboardProv.totalOpdRevenue,
                        isCurrency: true,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 120,
                        child: SfCartesianChart(
                          key: ValueKey(
                              'trend_${dashboardProv.selectedDate}'),
                          margin: EdgeInsets.zero,
                          plotAreaBorderWidth: 0,
                          primaryXAxis: CategoryAxis(
                            majorGridLines:
                            const MajorGridLines(width: 0),
                            axisLine: const AxisLine(width: 0),
                            majorTickLines:
                            const MajorTickLines(size: 0),
                            labelStyle: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8)),
                          ),
                          primaryYAxis: NumericAxis(isVisible: false),
                          series: <CartesianSeries>[
                            LineSeries<ChartDataPoint, String>(
                              animationDuration: 0,
                              dataSource: dashboardProv.trendData,
                              xValueMapper:
                                  (ChartDataPoint data, _) => data.x,
                              yValueMapper:
                                  (ChartDataPoint data, _) => data.y,
                              dataLabelMapper:
                                  (ChartDataPoint data, _) =>
                              'PKR ${NumberFormat('#,###').format(data.y)}',
                              color: const Color(0xFF10B981),
                              width: 2,
                              markerSettings:
                              const MarkerSettings(isVisible: true),
                              dataLabelSettings:
                              const DataLabelSettings(
                                isVisible: true,
                                textStyle: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Available Doctors ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Available Doctor',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConsultationScreen()),
                    ),
                    child: Text('View all',
                        style: TextStyle(
                            fontSize: 13,
                            color: primaryColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (consultationProv.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (consultationProv.doctors.isEmpty)
                const Center(child: Text('No doctors available'))
              else
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 800),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: consultationProv.doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = consultationProv.doctors[index];
                      return _DoctorCard(
                        doctor: doctor,
                        availableSlots:
                        consultationProv.availableSlotsForDoctor(
                            doctor.name, DateTime.now()),
                        primaryColor: primaryColor,
                        onTap: () => _showDialog(
                            context, consultationProv, doctor),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  // ── Glass panel ───────────────────────────────────────────────────────────
  Widget _buildGlassPanel({
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569))),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  // ── Calendar panel ────────────────────────────────────────────────────────
  Widget _buildCalendarPanel(DashboardProvider prov) {
    return _buildGlassPanel(
      title: 'Monthly Appointments',
      subtitle: 'Click a date to view details',
      trailing: Row(
        children: [
          IconButton(
              onPressed: () => prov.fetchCalendarData(DateTime(
                  prov.selectedDate.year, prov.selectedDate.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded, size: 20)),
          Text(DateFormat('MMM yyyy').format(prov.selectedDate),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold)),
          IconButton(
              onPressed: () => prov.fetchCalendarData(DateTime(
                  prov.selectedDate.year, prov.selectedDate.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded, size: 20)),
        ],
      ),
      child: prov.isCalendarLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCalendarGrid(prov),
    );
  }

  Widget _buildCalendarGrid(DashboardProvider prov) {
    final now = DateTime.now();
    final firstDay =
    DateTime(prov.selectedDate.year, prov.selectedDate.month, 1);
    final daysInMonth =
        DateTime(prov.selectedDate.year, prov.selectedDate.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
              .map((d) => Text(d,
              style:
              TextStyle(fontSize: 10, color: Colors.grey.shade400)))
              .toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4),
          itemCount: daysInMonth + startOffset,
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox();
            final day = index - startOffset + 1;
            final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(
                prov.selectedDate.year, prov.selectedDate.month, day));
            final data = prov.calendarData[dateStr] ?? {};
            final hasAppts = data.isNotEmpty;
            final isToday = day == now.day &&
                prov.selectedDate.month == now.month &&
                prov.selectedDate.year == now.year;

            return GestureDetector(
              onTap:
              hasAppts ? () => _showAppointmentDetails(dateStr, data) : null,
              child: Container(
                decoration: BoxDecoration(
                    color: hasAppts
                        ? const Color(0xFF10B981).withOpacity(0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isToday
                            ? const Color(0xFF10B981)
                            : Colors.transparent)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(day.toString(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF475569))),
                      if (hasAppts)
                        Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle)),
                    ]),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAppointmentDetails(
      String date, Map<String, List<dynamic>> data) {
    final size = MediaQuery.of(context).size;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: size.width * 0.9,
          padding: EdgeInsets.all(size.width * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  DateFormat('EEEE, MMM d').format(DateTime.parse(date)),
                  style: TextStyle(
                      fontSize: size.width * 0.045,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: data.entries
                      .map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(children: [
                          const Icon(Icons.person_rounded,
                              size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis)),
                          Text('${entry.value.length} Appts',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500))
                        ]),
                      ),
                      ...entry.value
                          .map((appt) => Container(
                        margin: const EdgeInsets.only(
                            left: 24, bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius:
                            BorderRadius.circular(12)),
                        child: Row(children: [
                          Expanded(
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                      appt['patient_name'] ??
                                          'Unknown',
                                      style: const TextStyle(
                                          fontSize: 13),
                                      overflow:
                                      TextOverflow.ellipsis),
                                ),
                                if (appt['token_number'] !=
                                    null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                      _teal.withOpacity(0.08),
                                      borderRadius:
                                      BorderRadius.circular(4),
                                      border: Border.all(
                                          color: _teal
                                              .withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      'T-${appt['token_number']}',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight:
                                          FontWeight.bold,
                                          color: _teal),
                                    ),
                                  ),
                                ],
                              ])),
                          const SizedBox(width: 12),
                          Text(
                              (appt['slot_time'] ?? '')
                                  .toString()
                                  .substring(0, 5),
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                  Colors.grey.shade400))
                        ]),
                      ))
                          .toList(),
                    ],
                  ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500))
    ]);
  }

  Widget _shiftRowHeader() {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Shift', 'Pts', 'Consults', 'Rev']
                .map((h) => Text(h.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400)))
                .toList()));
  }

  Widget _shiftRow(String shift, Color color, DashboardProvider prov) {
    final pts = prov.shiftPatientCount[shift] ?? 0;
    final rev = prov.shiftOpdRevenue[shift] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
                width: 6,
                height: 6,
                decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(shift,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          Text(pts.toString(),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          Text((prov.shiftConsultCount[shift] ?? 0).toString(),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          Text(NumberFormat.compact().format(rev),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _metricRow(String icon, String label, String value,
      {bool isNet = false, bool positive = true}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600))
              ]),
              Text(value,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isNet
                          ? (positive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF43F5E))
                          : const Color(0xFF334155),
                      fontFamily: 'monospace'))
            ]));
  }

  void _showDialog(
      BuildContext context, ConsultationProvider prov, DoctorInfo doctor) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: prov),
            ChangeNotifierProvider.value(value: context.read<MrProvider>()),
          ],
          child: AppointmentDialog(
            doctor: doctor,
            availableSlots:
            prov.availableSlotsForDoctor(doctor.name, DateTime.now()),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  HOME SCREEN
// ─────────────────────────────────────────────
class DashboardScreen extends StatelessWidget {
  final bool useScaffold;
  const DashboardScreen({super.key, this.useScaffold = true});

  @override
  Widget build(BuildContext context) {
    if (!useScaffold) return const _DashboardBody();
    return BaseScaffold(
      title: 'Dashboard',
      drawerIndex: 0,
      body: Consumer<PermissionProvider>(
        builder: (context, perm, _) {
          if (!perm.can(Perm.appDashboardRead)) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Color(0xFFCBD5E0)),
                  SizedBox(height: 16),
                  Text('Access Denied',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A5568))),
                  SizedBox(height: 8),
                  Text(
                      'You do not have permission to view the Dashboard.',
                      style: TextStyle(color: Color(0xFF718096))),
                ],
              ),
            );
          }
          return const _DashboardBody();
        },
      ),
    );
  }
}