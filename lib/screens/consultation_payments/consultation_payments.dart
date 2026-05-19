import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/search/global_search_overlay.dart';
import '../../providers/consultant_payments_provider/consultant_payments_provider.dart';
import '../../models/consultant_payment_model/consultant_payment_model.dart';
import '../../custum widgets/custom_loader.dart';
import '../../custum widgets/animations/animations.dart';
import 'package:animate_do/animate_do.dart';

class ConsultantPaymentsScreen extends StatefulWidget {
  const ConsultantPaymentsScreen({super.key});

  @override
  State<ConsultantPaymentsScreen> createState() => _ConsultantPaymentsScreenState();
}

class _ConsultantPaymentsScreenState extends State<ConsultantPaymentsScreen> {
  static const Color primary  = Color(0xFF00B5AD);
  static const Color bgColor  = Color(0xFFF0F4F8);
  static const Color cardBg   = Colors.white;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Date & filter state ──
  DateTime _fromDate    = DateTime.now();
  DateTime _toDate      = DateTime.now();
  String   _searchQuery = '';
  // Matches React default: 'unpaid'
  String   _paidFilter  = 'unpaid'; // 'all' | 'paid' | 'unpaid'

  late double _sw, _sh, _tp, _bp;
  late bool _isWide;

  double get _pad  => _sw * 0.04;
  double get _sp   => _sw * 0.025;
  double get _fs   => _sw < 360 ? 11.5 : 13.0;
  double get _fsS  => _sw < 360 ? 10.0 : 11.5;
  double get _fsXS => _sw < 360 ?  9.0 : 10.5;
  double get _fsL  => _sw < 360 ? 13.5 : 15.5;

  String _formatPKR(double amount) =>
      NumberFormat('#,##0', 'en_US').format(amount);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  // ── Convert paidFilter string → API paid param (matches React) ──
  // React: paidFilter === 'all' ? undefined : paidFilter === 'paid'
  // → we send String 'true'/'false' or null
  String? get _apiPaidParam {
    if (_paidFilter == 'all') return null;
    if (_paidFilter == 'paid') return 'true';
    return 'false'; // 'unpaid'
  }

  void _loadData() {
    if (!mounted) return;
    context.read<ConsultantPaymentsProvider>().loadDashboardData(
      fromDate: _fromDate,
      toDate: _toDate,
      paid: _apiPaidParam,
    );
  }

  List<DoctorBreakdownModel> _getFilteredBreakdown(List<DoctorBreakdownModel> list) {
    return list.where((d) =>
        d.doctorName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  List<PayoutRecordModel> _getFilteredRecords(List<PayoutRecordModel> list) {
    return list.where((r) =>
    r.doctorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        r.patientName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    _sw = mq.size.width;
    _sh = mq.size.height;
    _tp = mq.padding.top;
    _bp = mq.padding.bottom;
    _isWide = _sw >= 900;

    return BaseScaffold(
      scaffoldKey: _scaffoldKey,
      title: 'Consultant Payments',
      drawerIndex: 6,
      showAppBar: false,
      body: CustomPageTransition(
        child: Consumer<ConsultantPaymentsProvider>(
          builder: (context, provider, _) {
            return Column(children: [
              _buildHeader(provider),
              _buildFiltersAndStats(provider),
              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child: CustomLoader(
                          size: 50,
                          color: primary,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        color: primary,
                        child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(_pad, 0, _pad, 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          SizedBox(height: _sh * 0.02),
                          FadeInUp(delay: const Duration(milliseconds: 100), child: _buildDoctorBreakdown(provider)),
                          SizedBox(height: _sh * 0.03),
                          FadeInUp(delay: const Duration(milliseconds: 200), child: _buildRawRecords(provider)),
                          SizedBox(height: _sh * 0.02),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              )]);
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════
  Widget _buildHeader(ConsultantPaymentsProvider provider) {
    final now = DateTime.now();
    return Container(
      decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.only(
            bottomLeft:Radius.circular(20),
            bottomRight:Radius.circular(20),
          )
      ),

      padding: EdgeInsets.only(
        top: _tp + _sh * 0.012,
        bottom: _sh * 0.014,
        left: _pad,
        right: _pad,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            padding: EdgeInsets.all(_sw * 0.022),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(_sw * 0.022),
            ),
            child: Icon(Icons.menu_rounded, color: Colors.white, size: _sw * 0.04),
          ),
        ),
        SizedBox(width: _sp),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Consultant Payments',
                style: TextStyle(fontSize: _fsL, fontWeight: FontWeight.bold,
                    color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            // Text('Doctor share tracking and management',
            //     style: TextStyle(fontSize: _fsS, color: Colors.white70)),
          ]),
        ),
        // Global Search button
        GestureDetector(
          onTap: () => showGlobalSearchOverlay(context),
          child: Container(
            padding: EdgeInsets.all(_sw * 0.022),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(_sw * 0.022),
            ),
            child: Icon(Icons.search_rounded, color: Colors.white, size: _sw * 0.04),
          ),
        ),
        SizedBox(width: _sw * 0.02),
        // Refresh button (matches React)
        GestureDetector(
          onTap: provider.isLoading ? null : _loadData,
          child: Container(
            padding: EdgeInsets.all(_sw * 0.022),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(_sw * 0.022),
            ),
            child: Icon(Icons.refresh_rounded, color: Colors.white, size: _sw * 0.04),
          ),
        ),
        SizedBox(width: _sw * 0.02),
        // Date pill
        Container(
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.022, vertical: _sh * 0.007),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(_sw * 0.025),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_rounded, color: Colors.white, size: _sw * 0.033),
            SizedBox(width: _sw * 0.012),
            Text(DateFormat('MMM dd, yyyy').format(now),
                style: TextStyle(fontSize: _fsS, color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  // ════════════════════════════════════
  //  FILTERS + STATS
  // ════════════════════════════════════
  Widget _buildFiltersAndStats(ConsultantPaymentsProvider provider) {
    return Container(
      color: bgColor,
      padding: EdgeInsets.fromLTRB(_pad, _sh * 0.015, _pad, _sh * 0.01),
      child: Column(children: [
        FadeInUp(delay: const Duration(milliseconds: 50), child: _buildStatsRow(provider.analytics)),
        SizedBox(height: _sh * 0.015),
        FadeInUp(delay: const Duration(milliseconds: 100), child: _buildFiltersRow()),
      ]),
    );
  }

  Widget _buildStatsRow(ConsultantPaymentAnalytics? analytics) {
    if (analytics == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _buildStatCard(icon: Icons.people_rounded,       label: 'DOCTORS',          value: analytics.totalDoctors.toString(), color: Colors.blue),
        SizedBox(width: _sp),
        _buildStatCard(icon: Icons.receipt_rounded,      label: 'TOTAL AMOUNT',     value: 'PKR ${_formatPKR(analytics.totalAmount)}',         color: Colors.purple),
        SizedBox(width: _sp),
        _buildStatCard(icon: Icons.person_rounded,       label: 'DOCTOR SHARE',     value: 'PKR ${_formatPKR(analytics.totalDoctorShare)}',    color: Colors.green),
        SizedBox(width: _sp),
        _buildStatCard(icon: Icons.local_hospital_rounded, label: 'HOSPITAL REVENUE', value: 'PKR ${_formatPKR(analytics.totalHospitalRevenue)}', color: Colors.orange),
        if (_isWide) ...[
          SizedBox(width: _sp),
          _buildStatCard(icon: Icons.calendar_today_rounded, label: 'APPOINTMENTS',  value: analytics.totalAppointments.toString(), color: Colors.teal),
        ],
      ]),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: _isWide ? _sw * 0.18 : _sw * 0.4,
      padding: EdgeInsets.symmetric(horizontal: _sw * 0.02, vertical: _sh * 0.012),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(_sw * 0.02),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: EdgeInsets.all(_sw * 0.01),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(_sw * 0.015),
            ),
            child: Icon(icon, color: color, size: _sw * 0.03),
          ),
          SizedBox(width: _sw * 0.01),
          Expanded(child: Text(label,
              style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        SizedBox(height: _sh * 0.008),
        Text(value,
            style: TextStyle(fontSize: _fsL * 0.9, fontWeight: FontWeight.bold,
                color: Colors.black87),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        // Search
        Container(
          width: _isWide ? _sw * 0.4 : _sw * 0.58,
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.02),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_sw * 0.02),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(fontSize: _fs),
            decoration: InputDecoration(
              hintText: 'Search by doctor or patient...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: _fs * 0.93),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: _sw * 0.05),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: _sh * 0.01),
            ),
          ),
        ),
        SizedBox(width: _sp),
        _buildDatePicker('From', _fromDate, (date) {
          setState(() => _fromDate = date);
          _loadData();
        }),
        SizedBox(width: _sp),
        _buildDatePicker('To', _toDate, (date) {
          setState(() => _toDate = date);
          _loadData();
        }),
        SizedBox(width: _sp),
        // Paid filter dropdown — matches React options: unpaid | paid | all
        Container(
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.02),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_sw * 0.02),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _paidFilter,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
              style: TextStyle(fontSize: _fs, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                DropdownMenuItem(value: 'paid',   child: Text('Paid')),
                DropdownMenuItem(value: 'all',    child: Text('All')),
              ],
              onChanged: (v) {
                setState(() => _paidFilter = v!);
                _loadData();
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onSelected) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) onSelected(picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.02, vertical: _sh * 0.01),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_sw * 0.02),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_rounded, color: primary, size: _sw * 0.03),
          SizedBox(width: _sw * 0.01),
          Text(DateFormat('MM/dd/yyyy').format(date),
              style: TextStyle(fontSize: _fs, color: Colors.black87)),
        ]),
      ),
    );
  }

  // ════════════════════════════════════
  //  DOCTOR BREAKDOWN TABLE
  // ════════════════════════════════════
  Widget _buildDoctorBreakdown(ConsultantPaymentsProvider provider) {
    final filtered = _getFilteredBreakdown(provider.breakdown);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.pie_chart_rounded, color: primary, size: _sw * 0.048),
        SizedBox(width: _sw * 0.02),
        Text('Doctor Breakdown',
            style: TextStyle(fontSize: _fsL, fontWeight: FontWeight.bold, color: Colors.black87)),
      ]),
      SizedBox(height: _sh * 0.015),

      if (!_isWide)
        ...filtered.map((p) => _buildDoctorCard(p, provider))
      else
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(_sw * 0.02),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_sw * 0.02),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Header ──
                Container(
                  color: primary.withValues(alpha: 0.08),
                  padding: EdgeInsets.symmetric(horizontal: _sw * 0.025, vertical: _sh * 0.015),
                  child: Row(children: [
                    _headerCell('DOCTOR',       _sw * 0.28),
                    _headerCell('DEPT',         _sw * 0.22),
                    _headerCell('APPOINTMENTS', _sw * 0.22),
                    _headerCell('TOTAL',        _sw * 0.22),
                    _headerCell('DOCTOR SHARE', _sw * 0.22),
                    _headerCell('HOSPITAL',     _sw * 0.22),
                    _headerCell('ACTION',       _sw * 0.28, center: true),
                  ]),
                ),

                // ── Rows ──
                if (filtered.isEmpty)
                  SizedBox(
                    width: _sw * 1.7,
                    child: _emptyState('No doctor payments found'),
                  )
                else
                  ...filtered.asMap().entries.map((entry) {
                    final i = entry.key;
                    final payment = entry.value;
                    return _buildDoctorRow(payment, provider, isEven: i.isEven);
                  }),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _buildDoctorCard(DoctorBreakdownModel payment, ConsultantPaymentsProvider provider) {
    final isPaidView = _paidFilter == 'paid';
    final isThisSubmitting = provider.isDoctorSubmitting(payment.doctorName);

    return Container(
      margin: EdgeInsets.only(bottom: _sh * 0.015),
      padding: EdgeInsets.all(_sw * 0.04),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(_sw * 0.03),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(payment.doctorName, style: TextStyle(fontSize: _fsL, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(payment.department.isNotEmpty ? payment.department : 'No Department',
                style: TextStyle(fontSize: _fsS, color: Colors.grey.shade500)),
          ])),
          if (isPaidView) _viewButton(payment.doctorName)
          else _markPaidButton(payment.doctorName, provider, isThisSubmitting),
        ]),
        SizedBox(height: _sh * 0.015),
        const Divider(),
        SizedBox(height: _sh * 0.01),
        Row(children: [
          _cardInfoItem(Icons.calendar_today_rounded, 'Appointments', payment.appointments.toString(), Colors.blue),
          _cardInfoItem(Icons.payments_rounded, 'Total Amount', 'PKR ${_formatPKR(payment.totalAmount)}', Colors.purple),
        ]),
        SizedBox(height: _sh * 0.01),
        Row(children: [
          _cardInfoItem(Icons.account_balance_wallet_rounded, 'Doctor Share', 'PKR ${_formatPKR(payment.doctorShare)}', Colors.green, isBold: true),
          _cardInfoItem(Icons.local_hospital_rounded, 'Hospital Revenue', 'PKR ${_formatPKR(payment.hospitalRevenue)}', Colors.orange),
        ]),
      ]),
    );
  }

  Widget _cardInfoItem(IconData icon, String label, String value, Color color, {bool isBold = false}) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: _sw * 0.03, color: color.withValues(alpha: 0.6)),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ]),
        SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: _fsS, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: isBold ? color : Colors.black87)),
      ]),
    );
  }

  Widget _buildDoctorRow(
      DoctorBreakdownModel payment,
      ConsultantPaymentsProvider provider, {
        required bool isEven,
      }) {
    // Matches React: if paidFilter == 'paid' → show "View" button
    //                else → show "Mark Paid" button
    final isPaidView = _paidFilter == 'paid';
    final isThisSubmitting = provider.isDoctorSubmitting(payment.doctorName);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sw * 0.025, vertical: _sh * 0.018),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : bgColor.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(children: [
        // Doctor name + department
        SizedBox(
          width: _sw * 0.28,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(payment.doctorName,
                style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold,
                    color: Colors.black87),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        // Department (from DoctorBreakdownModel if available)
        SizedBox(
          width: _sw * 0.22,
          child: Text(payment.department.isNotEmpty ? payment.department : '---',
              style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        SizedBox(
          width: _sw * 0.22,
          child: Text(payment.appointments.toString(),
              style: TextStyle(fontSize: _fs, color: Colors.black87)),
        ),
        SizedBox(
          width: _sw * 0.22,
          child: Text('PKR ${_formatPKR(payment.totalAmount)}',
              style: TextStyle(fontSize: _fs, color: Colors.black87)),
        ),
        SizedBox(
          width: _sw * 0.22,
          child: Text('PKR ${_formatPKR(payment.doctorShare)}',
              style: TextStyle(fontSize: _fs, fontWeight: FontWeight.w600,
                  color: Colors.green.shade700)),
        ),
        SizedBox(
          width: _sw * 0.22,
          child: Text('PKR ${_formatPKR(payment.hospitalRevenue)}',
              style: TextStyle(fontSize: _fs, color: Colors.black87)),
        ),
        // ── ACTION BUTTON ────────────────────────────────────────────────────
        SizedBox(
          width: _sw * 0.28,
          child: Center(
            child: isPaidView
            // "View" button when filter = paid
                ? _viewButton(payment.doctorName)
            // "Mark Paid" button when filter = unpaid / all
                : _markPaidButton(payment.doctorName, provider, isThisSubmitting),
          ),
        ),
      ]),
    );
  }

  // ── Mark Paid button — matches React's "Mark Paid" ElevatedButton ──
  Widget _markPaidButton(
      String doctorName,
      ConsultantPaymentsProvider provider,
      bool isThisSubmitting,
      ) {
    final anySubmitting = provider.isSubmitting;

    return SizedBox(
      height: _sh * 0.042,
      child: ElevatedButton.icon(
        onPressed: (anySubmitting) ? null : () => _handleMarkPaid(doctorName, provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.025),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_sw * 0.02)),
        ),
        icon: isThisSubmitting
            ? const CustomLoader(size: 20, color: Colors.white)
            : Icon(Icons.receipt_long_rounded, size: _sw * 0.035),
        label: Text(
          isThisSubmitting ? 'Processing...' : 'Mark Paid',
          style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── View button shown when filter = 'paid' ──
  Widget _viewButton(String doctorName) {
    return SizedBox(
      height: _sh * 0.042,
      child: OutlinedButton.icon(
        onPressed: () {
          // Filter raw records by this doctor
          setState(() => _searchQuery = doctorName);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.025),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_sw * 0.02)),
        ),
        icon: Icon(Icons.visibility_outlined, size: _sw * 0.035),
        label: Text('View', style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── handleMarkPaid — mirrors React's handleMarkPaid exactly ──
  Future<void> _handleMarkPaid(
      String doctorName,
      ConsultantPaymentsProvider provider,
      ) async {
    final result = await provider.markDoctorPaid(
      doctorName: doctorName,
      fromDate: _fromDate,
      toDate: _toDate,
      createdBy: null, // pass username from auth if available
      paidFilter: _apiPaidParam,
    );

    if (!mounted) return;

    if (result.success) {
      _snack('Payout created for $doctorName');
      // Optionally show payout ID (like React navigates to receipt)
      if (result.payoutId != null) {
        _snack('Payout #${result.payoutId} created for $doctorName ✓');
      }
    } else {
      _snack(result.message ?? 'Failed to create payout', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err ? Colors.red.shade400 : primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.03)),
      margin: EdgeInsets.all(_pad),
      duration: Duration(seconds: err ? 4 : 3),
    ));
  }

  // ════════════════════════════════════
  //  RAW RECORDS TABLE
  // ════════════════════════════════════
  Widget _buildRawRecords(ConsultantPaymentsProvider provider) {
    final filtered = _getFilteredRecords(provider.records);
    final today = DateTime.now();
    final sameDay = _fromDate.toIso8601String().split('T')[0] ==
        _toDate.toIso8601String().split('T')[0];
    final title = sameDay
        ? 'Raw Share Records (${DateFormat('dd MMM yyyy').format(today)})'
        : 'Raw Share Records (${DateFormat('dd MMM').format(_fromDate)} – ${DateFormat('dd MMM yyyy').format(_toDate)})';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.history_rounded, color: primary, size: _sw * 0.048),
        SizedBox(width: _sw * 0.02),
        Expanded(child: Text(title,
            style: TextStyle(fontSize: _fsL, fontWeight: FontWeight.bold,
                color: Colors.black87),
            maxLines: 2)),
      ]),
      SizedBox(height: _sh * 0.015),

      if (!_isWide)
        ...filtered.map((r) => _buildRecordCard(r))
      else
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(_sw * 0.02),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_sw * 0.02),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Header ──
                Container(
                  color: bgColor,
                  padding: EdgeInsets.symmetric(horizontal: _sw * 0.025, vertical: _sh * 0.015),
                  child: Row(children: [
                    _headerCell('TIME',       _sw * 0.30, bold: true, dark: true),
                    _headerCell('DOCTOR',     _sw * 0.25, bold: true, dark: true),
                    _headerCell('PATIENT',    _sw * 0.25, bold: true, dark: true),
                    _headerCell('SERVICE',    _sw * 0.35, bold: true, dark: true),
                    _headerCell('SHARE',      _sw * 0.22, bold: true, dark: true),
                    _headerCell('TOTAL BILL', _sw * 0.22, bold: true, dark: true),
                    _headerCell('STATUS',     _sw * 0.18, bold: true, dark: true, center: true),
                  ]),
                ),

                if (filtered.isEmpty)
                  SizedBox(width: _sw * 1.8, child: _emptyState('No share records found'))
                else
                  ...filtered.asMap().entries.map((entry) {
                    final i = entry.key;
                    final record = entry.value;
                    return _buildRecordRow(record, isEven: i.isEven);
                  }),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _buildRecordCard(PayoutRecordModel record) {
    final isCancelled = record.opdCancelled == true;

    return Container(
      margin: EdgeInsets.only(bottom: _sh * 0.012),
      decoration: BoxDecoration(
        color: isCancelled ? Colors.orange.withValues(alpha: 0.04) : cardBg,
        borderRadius: BorderRadius.circular(_sw * 0.025),
        border: Border.all(color: isCancelled ? Colors.orange.withValues(alpha: 0.15) : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.all(_sw * 0.035),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.access_time_rounded, size: _sw * 0.035, color: Colors.grey.shade400),
            SizedBox(width: 6),
            Text('${record.date}  •  ${record.time}',
                style: TextStyle(fontSize: _fsS, color: Colors.grey.shade500, fontFamily: 'monospace', fontWeight: FontWeight.w500)),
          ]),
          _recordStatusBadge(record),
        ]),
        SizedBox(height: _sh * 0.012),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Doctor', style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade400)),
            Text(record.doctorName, style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.bold, color: isCancelled ? Colors.orange.shade700 : Colors.black87)),
            Text(record.shareType == 'fixed' ? 'Share: Fixed' : 'Share: ${record.paymentShare}%', 
              style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade400)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Patient', style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade400)),
            Text(record.patientName, style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w600, color: isCancelled ? Colors.orange.shade500 : Colors.black87)),
            Text(record.patientId, style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade300)),
          ])),
        ]),
        SizedBox(height: _sh * 0.01),
        Container(
          padding: EdgeInsets.all(_sw * 0.02),
          decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Service Detail', style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade500)),
            Text(record.serviceDetail, style: TextStyle(fontSize: _fsS, color: isCancelled ? Colors.orange.shade400 : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        SizedBox(height: _sh * 0.012),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total Bill', style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade400)),
            Text('PKR ${_formatPKR(record.totalAmount)}',
                style: TextStyle(fontSize: _fsS, color: Colors.grey.shade500, decoration: isCancelled ? TextDecoration.lineThrough : null)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Doctor Share', style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade400)),
            Text('PKR ${_formatPKR(record.doctorShare)}',
                style: TextStyle(fontSize: _fsL, fontWeight: FontWeight.bold, color: isCancelled ? Colors.orange.shade400 : Colors.green.shade700, decoration: isCancelled ? TextDecoration.lineThrough : null)),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildRecordRow(PayoutRecordModel record, {required bool isEven}) {
    final isCancelled = record.opdCancelled == true;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sw * 0.025, vertical: _sh * 0.018),
      decoration: BoxDecoration(
        color: isCancelled
            ? Colors.orange.shade50.withValues(alpha: 0.4)
            : (isEven ? Colors.white : bgColor.withValues(alpha: 0.3)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(children: [
        // Time
        SizedBox(
          width: _sw * 0.30,
          child: Text('${record.date}  ${record.time}',
              style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade500,
                  fontFamily: 'monospace')),
        ),
        // Doctor
        SizedBox(
          width: _sw * 0.25,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.doctorName,
                style: TextStyle(
                  fontSize: _fsS,
                  fontWeight: FontWeight.bold,
                  color: isCancelled ? Colors.orange.shade700 : Colors.black87,
                  fontStyle: isCancelled ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(record.shareType == 'fixed' ? 'Share: Fixed' : 'Share: ${record.paymentShare}%',
                style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade400)),
          ]),
        ),
        // Patient
        SizedBox(
          width: _sw * 0.25,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.patientName,
                style: TextStyle(
                  fontSize: _fsS,
                  color: isCancelled ? Colors.orange.shade500 : Colors.black87,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(record.patientId,
                style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade400)),
          ]),
        ),
        // Service
        SizedBox(
          width: _sw * 0.35,
          child: Text(record.serviceDetail,
              style: TextStyle(
                fontSize: _fsS,
                color: isCancelled ? Colors.orange.shade400 : Colors.grey.shade700,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        // Doctor share amount
        SizedBox(
          width: _sw * 0.22,
          child: Text('PKR ${_formatPKR(record.doctorShare)}',
              style: TextStyle(
                fontSize: _fs,
                fontWeight: FontWeight.bold,
                color: isCancelled ? Colors.orange.shade400 : Colors.green.shade700,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
              )),
        ),
        // Total bill
        SizedBox(
          width: _sw * 0.22,
          child: Text('PKR ${_formatPKR(record.totalAmount)}',
              style: TextStyle(
                fontSize: _fsS,
                color: isCancelled ? Colors.orange.shade300 : Colors.grey.shade500,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
              )),
        ),
        // Status badge (matches React: Cancelled | Settled | Active)
        SizedBox(
          width: _sw * 0.18,
          child: Center(child: _recordStatusBadge(record)),
        ),
      ]),
    );
  }

  Widget _recordStatusBadge(PayoutRecordModel record) {
    final isCancelled = record.opdCancelled == true;
    final isSettled = record.shiftClosed == true;

    Color bgCol, textCol;
    String label;

    if (isCancelled) {
      bgCol   = Colors.orange.shade100;
      textCol = Colors.orange.shade700;
      label   = 'Cancelled';
    } else if (isSettled) {
      bgCol   = Colors.grey.shade100;
      textCol = Colors.grey.shade500;
      label   = 'Settled';
    } else {
      bgCol   = Colors.green.shade500;
      textCol = Colors.white;
      label   = 'Active';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sw * 0.015, vertical: _sh * 0.004),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(_sw * 0.015),
      ),
      child: Text(label,
          style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.bold, color: textCol),
          textAlign: TextAlign.center),
    );
  }

  // ════════════════════════════════════
  //  SHARED HELPERS
  // ════════════════════════════════════
  Widget _headerCell(String text, double width,
      {bool center = false, bool bold = false, bool dark = false}) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: _fsXS,
            fontWeight: bold ? FontWeight.bold : FontWeight.w700,
            color: dark ? Colors.black54 : primary,
            letterSpacing: 0.3,
          )),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_pad * 2),
        child: Column(children: [
          Icon(Icons.inbox_rounded, color: Colors.grey.shade300, size: _sw * 0.1),
          SizedBox(height: _sh * 0.02),
          Text(message, style: TextStyle(color: Colors.grey.shade400, fontSize: _fs)),
        ]),
      ),
    );
  }
}