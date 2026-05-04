import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../providers/opd/opd_reciepts/opd_reciepts.dart';
import '../../custum widgets/custom_loader.dart';
import '../../custum widgets/animations/animations.dart';
import 'package:animate_do/animate_do.dart';

class OpdRecordsScreen extends StatefulWidget {
  final String? initialSearch;
  const OpdRecordsScreen({super.key, this.initialSearch});

  @override
  State<OpdRecordsScreen> createState() => _OpdRecordsScreenState();
}

class _OpdRecordsScreenState extends State<OpdRecordsScreen> {
  static const Color primary = Color(0xFF00B5AD);
  static const Color bgColor = Color(0xFFF0F4F8);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Scroll controller for infinite scroll ──
  final ScrollController _scrollController = ScrollController();

  // ── Filter controllers ──
  final _searchCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedYear  = 'All';
  String _selectedMonth = 'All';

  // ── Active filters ──
  String _fSearch = '';
  DateTime? _fStart;
  DateTime? _fEnd;
  String _fYear  = 'All';
  String _fMonth = 'All';

  // MediaQuery
  late double _sw, _sh, _tp, _bp;
  bool get _isWide => _sw >= 700;

  double get _fs   => _sw < 360 ? 11.0 : 12.5;
  double get _fsS  => _sw < 360 ?  9.5 : 11.0;
  double get _fsXS => _sw < 360 ?  8.5 :  9.5;
  double get _pad  => _sw * 0.04;
  double get _sp   => _sw * 0.02;

  static const List<String> _years  = ['All','2024','2025','2026'];
  static const List<String> _months = [
    'All','January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchCtrl.text = widget.initialSearch!;
      _fSearch = widget.initialSearch!;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Infinite scroll trigger ──
  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      // Only paginate when no filters active (server-side data)
      if (_fSearch.isEmpty &&
          _fStart == null && _fEnd == null &&
          _fYear == 'All' && _fMonth == 'All') {
        context.read<OpdProvider>().loadMoreReceipts();
      }
    }
  }

  // ── Filter logic ──
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    return all.where((r) {
      final name    = (r['patientName'] as String? ?? '').toLowerCase();
      final mr      = (r['mrNo']        as String? ?? '').toLowerCase();
      final svcList = (r['services']    as List? ?? []).join(' ').toLowerCase();
      final date    = r['date']         as DateTime? ?? DateTime.now();

      if (_fSearch.isNotEmpty) {
        final q = _fSearch.toLowerCase();
        if (!name.contains(q) && !mr.contains(q) && !svcList.contains(q)) return false;
      }
      if (_fStart != null      && date.isBefore(_fStart!))                    return false;
      if (_fEnd   != null      && date.isAfter(_fEnd!.add(const Duration(days: 1)))) return false;
      if (_fYear  != 'All'     && date.year.toString() != _fYear)             return false;
      if (_fMonth != 'All') {
        final mIdx = _months.indexOf(_fMonth);
        if (date.month != mIdx) return false;
      }
      return true;
    }).toList();
  }

  void _doSearch() {
    setState(() {
      _fSearch  = _searchCtrl.text.trim();
      _fStart   = _startDate;
      _fEnd     = _endDate;
      _fYear    = _selectedYear;
      _fMonth   = _selectedMonth;
    });
  }

  void _doClear() {
    _searchCtrl.clear();
    setState(() {
      _startDate = null; _endDate = null;
      _selectedYear = 'All'; _selectedMonth = 'All';
      _fSearch = '';
      _fStart = null; _fEnd = null;
      _fYear = 'All'; _fMonth = 'All';
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() { if (isStart) _startDate = picked; else _endDate = picked; });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')} ${_months[d.month].substring(0,3)} ${d.year}';

  // ── Cancel ──
  void _cancelRecord(OpdProvider prov, int realIdx) {
    final rec = prov.receipts[realIdx];
    if (rec['status'] == 'Cancelled') return;

    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cancel receipt ${rec['receiptNo']}?'),
            SizedBox(height: _sh * 0.015),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                _snack('Please enter a reason', err: true);
                return;
              }
              Navigator.pop(ctx);
              _snack('Processing cancellation...');
              final success = await prov.cancelReceipt(realIdx, reasonCtrl.text.trim());
              if (!mounted) return;
              if (success) {
                _snack('Receipt cancelled successfully');
              } else {
                _snack('Failed: ${prov.errorMessage}', err: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  // ── Refund ──
  void _refundRecord(OpdProvider prov, int realIdx) {
    final rec = prov.receipts[realIdx];
    if (rec['status'] == 'Cancelled') {
      _snack('Cannot refund a cancelled receipt', err: true);
      return;
    }

    final amountCtrl = TextEditingController(text: (rec['paid'] ?? 0).toString());
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Refund Process', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: _sh * 0.005),
            Text('${rec['patientName']} (${rec['mrNo']})',
                style: TextStyle(fontSize: _fsS, color: Colors.grey.shade600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Refund Amount', prefixText: 'PKR ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: _sh * 0.015),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Refund Reason', hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                _snack('Please provide a reason', err: true);
                return;
              }
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) {
                _snack('Please enter a valid amount', err: true);
                return;
              }
              Navigator.pop(ctx);
              _snack('Processing refund...');
              final success = await prov.refundReceipt(realIdx, amount, reasonCtrl.text.trim());
              if (!mounted) return;
              if (success) {
                _snack('Refund processed for PKR $amount');
              } else {
                _snack('Failed: ${prov.errorMessage}', err: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err ? Colors.red.shade400 : primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.03)),
      margin: EdgeInsets.all(_pad),
    ));
  }

  // ════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    _sw = mq.size.width; _sh = mq.size.height;
    _tp = mq.padding.top; _bp = mq.padding.bottom;

    return BaseScaffold(
      scaffoldKey: _scaffoldKey,
      title: 'OPD Records',
      drawerIndex: 4,
      showAppBar: false,
      body: CustomPageTransition(
        child: Consumer<OpdProvider>(builder: (_, prov, __) {
          // Show initial load spinner
          if (prov.isLoadingReceipts && prov.receipts.isEmpty) {
            return Column(children: [
              _buildTopBar(),
              const Expanded(
                child: Center(
                  child: CustomLoader(
                    size: 50,
                    color: primary,
                  ),
                ),
              ),
            ]);
          }

          final allReceipts = prov.receipts.toList().reversed.toList();
          final hasActiveFilters = _fSearch.isNotEmpty || _fStart != null || _fEnd != null || _fYear != 'All' || _fMonth != 'All';
          final filtered = hasActiveFilters ? _applyFilters(allReceipts) : <Map<String, dynamic>>[];

          return Column(children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => prov.loadReceipts(),
                color: primary,
                child: CustomScrollView(
                  controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: Padding(
                    padding: EdgeInsets.all(_pad),
                    child: Column(children: [
                      FadeInUp(delay: const Duration(milliseconds: 100), child: _filterCard()),
                      SizedBox(height: _pad * 0.8),
                      FadeInUp(delay: const Duration(milliseconds: 200), child: _statsBar(filtered.length, prov, hasActiveFilters)),
                      SizedBox(height: _pad * 0.8),
                    ]),
                  )),

                  if (filtered.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _emptyState(hasActiveFilters))
                  else if (_isWide)
                    _wideTable(filtered, prov)
                  else
                    _narrowList(filtered, prov),

                  // ── Bottom loading indicator ──
                  if (prov.isFetchingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: _sh * 0.025),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CustomLoader(
                                  size: 24,
                                  color: primary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Loading more records...',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── All loaded footer ──
                  if (!prov.hasMorePages && prov.receipts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: _sh * 0.015),
                        child: Center(
                          child: Text(
                            'All ${prov.totalReceiptsCount} records loaded',
                            style: TextStyle(
                              fontSize: _fsS, color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
          ]);
        }),
      ),
    );
  }

  // ════════════════════════════════════
  //  TOP BAR
  // ════════════════════════════════════
  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomLeft:Radius.circular(20),
            bottomRight:Radius.circular(20),
          ),
        gradient: LinearGradient(
          colors: [Color(0xFF00B5AD), Color(0xFF00B5AD)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: _tp + _sh * 0.014, bottom: _sh * 0.018,
        left: _pad, right: _pad,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            padding: EdgeInsets.all(_sw * 0.022),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(_sw * 0.022),
            ),
            child: Icon(Icons.menu_rounded, color: Colors.white, size: _sw * 0.042),
          ),
        ),
        SizedBox(width: _sp),
        // Container(
        //   padding: EdgeInsets.all(_sw * 0.022),
        //   decoration: BoxDecoration(
        //     color: Colors.white.withOpacity(0.18),
        //     borderRadius: BorderRadius.circular(_sw * 0.022),
        //   ),
        //   // child: Icon(Icons.table_chart_rounded, color: Colors.white, size: _sw * 0.048),
        // ),
        SizedBox(width: _sp),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Patient OPD Records',
              style: TextStyle(fontSize: _sw * 0.045, fontWeight: FontWeight.bold,
                  color: Colors.white, letterSpacing: 0.2)),
        ]),
      ]),
    );
  }

  // ════════════════════════════════════
  //  FILTER CARD
  // ════════════════════════════════════
  Widget _filterCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_sw * 0.04),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: EdgeInsets.all(_pad),
      child: Column(children: [
        _filterField(_searchCtrl, 'Search Patient Name, MR / Receipt No, or Service / Doctor...', Icons.search_rounded),
        SizedBox(height: _sp * 0.8),
        _isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(flex: 3, child: _dateRangeRow()),
          SizedBox(width: _sp),
          Expanded(child: _dropdownFilter('Year',  _years,  _selectedYear,
                  (v) => setState(() => _selectedYear = v!))),
          SizedBox(width: _sp),
          Expanded(child: _dropdownFilter('Month', _months, _selectedMonth,
                  (v) => setState(() => _selectedMonth = v!))),
          SizedBox(width: _sp),
          _actionButtons(),
        ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _dateRangeRow(),
          SizedBox(height: _sp * 0.8),
          Row(children: [
            Expanded(child: _dropdownFilter('Year',  _years,  _selectedYear,
                    (v) => setState(() => _selectedYear = v!))),
            SizedBox(width: _sp),
            Expanded(child: _dropdownFilter('Month', _months, _selectedMonth,
                    (v) => setState(() => _selectedMonth = v!))),
          ]),
          SizedBox(height: _sp * 0.8),
          _actionButtons(),
        ]),
      ]),
    );
  }

  Widget _filterField(TextEditingController ctrl, String hint, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _filterLabel('Search Records'),
      SizedBox(height: _sh * 0.005),
      TextField(
        controller: ctrl,
        style: TextStyle(fontSize: _fs),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: _fs * 0.92),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: _sw * 0.042),
          filled: true, fillColor: bgColor,
          contentPadding: EdgeInsets.symmetric(horizontal: _sw * 0.025, vertical: _sh * 0.012),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(_sw * 0.025),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_sw * 0.025),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_sw * 0.025),
              borderSide: const BorderSide(color: primary, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _filterLabel(String label) => Text(label,
      style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w600, color: Colors.black54));

  Widget _dateRangeRow() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _filterLabel('Date Range'),
      SizedBox(height: _sh * 0.005),
      Row(children: [
        Expanded(child: _dateTile(_startDate, 'Start Date', true)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.015),
          child: Icon(Icons.arrow_forward_rounded, color: Colors.grey.shade400, size: _sw * 0.04),
        ),
        Expanded(child: _dateTile(_endDate, 'End Date', false)),
      ]),
    ]);
  }

  Widget _dateTile(DateTime? date, String hint, bool isStart) {
    return GestureDetector(
      onTap: () => _pickDate(isStart),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.025, vertical: _sh * 0.013),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(_sw * 0.025),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Expanded(child: Text(
            date != null ? _fmtDate(date) : hint,
            style: TextStyle(fontSize: _fs * 0.9,
                color: date != null ? Colors.black87 : Colors.grey.shade400),
          )),
          Icon(Icons.calendar_today_outlined,
              color: Colors.grey.shade400, size: _sw * 0.038),
        ]),
      ),
    );
  }

  Widget _dropdownFilter(String label, List<String> items, String val,
      ValueChanged<String?> onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _filterLabel(label),
      SizedBox(height: _sh * 0.005),
      Container(
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.025),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(_sw * 0.025),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: val, isExpanded: true,
            style: TextStyle(fontSize: _fs, color: Colors.black87),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey, size: _sw * 0.042),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: onChange,
          ),
        ),
      ),
    ]);
  }

  Widget _actionButtons() {
    return Wrap(
      spacing: _sp * 0.6,
      runSpacing: _sp * 0.6,
      alignment: _isWide ? WrapAlignment.start : WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _doSearch,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary, foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: _sw * 0.04, vertical: _sh * 0.014),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.025)),
          ),
          icon: Icon(Icons.search_rounded, size: _sw * 0.042),
          label: Text('Search', style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold)),
        ),
        OutlinedButton.icon(
          onPressed: _doClear,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            side: BorderSide(color: Colors.grey.shade300),
            padding: EdgeInsets.symmetric(horizontal: _sw * 0.032, vertical: _sh * 0.014),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.025)),
          ),
          icon: Icon(Icons.refresh_rounded, size: _sw * 0.038),
          label: Text('Clear', style: TextStyle(fontSize: _fs, fontWeight: FontWeight.w600)),
        ),
        OutlinedButton.icon(
          onPressed: () => _snack('Printing...'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            side: BorderSide(color: Colors.grey.shade300),
            padding: EdgeInsets.symmetric(horizontal: _sw * 0.032, vertical: _sh * 0.014),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.025)),
          ),
          icon: Icon(Icons.print_rounded, size: _sw * 0.038),
          label: Text('Print', style: TextStyle(fontSize: _fs, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ════════════════════════════════════
  //  STATS BAR — shows real total from API or Search results
  // ════════════════════════════════════
  Widget _statsBar(int filteredCount, OpdProvider prov, bool hasActiveFilters) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _pad, vertical: _sh * 0.016),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_sw * 0.03),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _pad, vertical: _sh * 0.016),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B5AD), Color(0xFF00897B)],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(_sw * 0.03),
        ),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(_sw * 0.022),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(_sw * 0.022),
            ),
            child: Icon(hasActiveFilters ? Icons.manage_search_rounded : Icons.table_rows_rounded, 
                color: Colors.white, size: _sw * 0.045),
          ),
          SizedBox(width: _sp),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hasActiveFilters ? 'SEARCHED RECORDS' : 'TOTAL RECORDS',
                style: TextStyle(fontSize: _fsXS, color: Colors.white70,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            // Show real total from API or search count
            Text(
              hasActiveFilters ? _formatNumber(filteredCount) : _formatNumber(prov.totalReceiptsCount),
              style: TextStyle(fontSize: _sw * 0.055,
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
          // Show how many loaded so far
          if (!hasActiveFilters)
            Text(
              '${_formatNumber(prov.receipts.length)} loaded',
              style: const TextStyle(fontSize: 11, color: Colors.white70,
                  fontWeight: FontWeight.w500),
            ),
        ]),
        const Spacer(),
        // Status badge
        if (!hasActiveFilters)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (prov.isFetchingMore) ...[
              const SizedBox(
                width: 10,
                height: 10,
                child: CustomLoader(
                  size: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              prov.hasMorePages ? 'Scroll for more' : 'All loaded ✓',
              style: TextStyle(fontSize: _fsS, color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ]),
    ));
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return n.toString();
  }

  // ════════════════════════════════════
  //  WIDE TABLE
  // ════════════════════════════════════
  Widget _wideTable(List<Map<String, dynamic>> records, OpdProvider prov) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _pad),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_sw * 0.025),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(children: [
            _tableHeader(),
            Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
            ...records.asMap().entries.map((e) =>
                _tableRow(e.key, e.value, prov, records)),
          ]),
        ),
      ),
    );
  }

  Widget _tableHeader() {
    const cols = ['Sr #','Receipt No','MR No','Date','Patient Name',
      'Service','Details','Total','Discount','Age','Gender','Refund','Cancel'];
    const flexes = [1, 2, 2, 2, 3, 2, 3, 2, 2, 1, 1, 2, 2];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _pad, vertical: _sh * 0.014),
      child: Row(children: List.generate(cols.length, (i) => Expanded(
        flex: flexes[i],
        child: Text(cols[i],
            style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w700,
                color: Colors.black54, letterSpacing: 0.3)),
      ))),
    );
  }

  Widget _tableRow(int index, Map<String, dynamic> rec,
      OpdProvider prov, List<Map<String, dynamic>> all) {
    final status      = rec['status'] as String? ?? 'Active';
    final isCancelled = status == 'Cancelled';
    final services    = rec['services'] as List? ?? [];
    final date        = rec['date'] as DateTime? ?? DateTime.now();

    // Find real index in provider's receipts list
    final realIdx = _findRealIndex(prov, rec);

    return Column(children: [
      Container(
        color: index.isOdd ? bgColor.withOpacity(0.5) : Colors.white,
        padding: EdgeInsets.symmetric(horizontal: _pad, vertical: _sh * 0.013),
        child: Row(children: [
          Expanded(flex: 1, child: Text('${index + 1}',
              style: TextStyle(fontSize: _fsS, color: Colors.black54))),
          Expanded(flex: 2, child: Row(
            children: [
              Text(rec['receiptNo'] ?? '',
                  style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w600, color: Colors.black87)),
              if (status == 'Pending Sync') ...[
                const SizedBox(width: 4),
                Icon(Icons.cloud_off_rounded, size: 12, color: Colors.amber.shade700),
              ]
            ],
          )),
          Expanded(flex: 2, child: Text(rec['mrNo'] ?? '',
              style: TextStyle(fontSize: _fsS, color: Colors.black87))),
          Expanded(flex: 2, child: Text(_fmtDate(date),
              style: TextStyle(fontSize: _fsS, color: Colors.black87))),
          Expanded(flex: 3, child: Text(
              ((rec['patientName'] as String?) ?? '').toUpperCase(),
              style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.bold, color: Colors.black87),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(
              services.isNotEmpty ? services.first.toString() : '',
              style: TextStyle(fontSize: _fsS, color: Colors.black87),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text(
              isCancelled
                  ? 'CANCELLED - ${services.isNotEmpty ? services.first : ''}'
                  : (services.isNotEmpty ? services.join(', ') : ''),
              style: TextStyle(fontSize: _fsS,
                  color: isCancelled ? Colors.red.shade400 : Colors.black54),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(
              (rec['total'] as double? ?? 0.0).toStringAsFixed(2),
              style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.bold, color: primary))),
          Expanded(flex: 2, child: Text(
              (rec['discount'] as double? ?? 0.0).toStringAsFixed(0),
              style: TextStyle(fontSize: _fsS, color: Colors.black54))),
          Expanded(flex: 1, child: Text(rec['age'] ?? '-',
              style: TextStyle(fontSize: _fsS, color: Colors.black87))),
          Expanded(flex: 1, child: _genderBadge(rec['gender'] ?? 'M')),
          Expanded(flex: 2, child: _refundBtn(prov, rec, realIdx)),
          Expanded(flex: 2, child: _cancelBtn(prov, rec, realIdx, status)),
        ]),
      ),
      Divider(height: _sh * 0.001, color: const Color(0xFFF5F5F5)),
    ]);
  }

  // ════════════════════════════════════
  //  NARROW LIST
  // ════════════════════════════════════
  Widget _narrowList(List<Map<String, dynamic>> records, OpdProvider prov) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: _pad),
      sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => _mobileCard(i, records[i], prov),
        childCount: records.length,
      )),
    );
  }

  Widget _mobileCard(int index, Map<String, dynamic> rec, OpdProvider prov) {
    final status      = rec['status'] as String? ?? 'Active';
    final isCancelled = status == 'Cancelled';
    final services    = rec['services'] as List? ?? [];
    final date        = rec['date'] as DateTime? ?? DateTime.now();
    final realIdx     = _findRealIndex(prov, rec);

    return Container(
      margin: EdgeInsets.only(bottom: _sh * 0.012),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_sw * 0.03),
        border: Border(left: BorderSide(
            color: isCancelled ? Colors.red.shade300 : primary, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.all(_sw * 0.038),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(((rec['patientName'] as String?) ?? '').toUpperCase(),
                style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold, color: Colors.black87)),
            SizedBox(height: _sh * 0.003),
            Text('${rec['receiptNo'] ?? ''}  •  MR: ${rec['mrNo'] ?? ''}',
                style: TextStyle(fontSize: _fsS, color: Colors.grey.shade500)),
          ])),
          _statusBadge(status),
        ]),
        SizedBox(height: _sh * 0.01),
        Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
        SizedBox(height: _sh * 0.01),
        Wrap(spacing: _sw * 0.04, runSpacing: _sh * 0.007, children: [
          _infoChip(Icons.calendar_today_outlined, _fmtDate(date)),
          _infoChip(Icons.medical_services_outlined,
              services.isNotEmpty ? services.first.toString() : '-'),
          _infoChip(Icons.monetization_on_outlined,
              'PKR ${(rec['total'] as double? ?? 0.0).toStringAsFixed(0)}'),
          _infoChip(Icons.discount_outlined,
              'Disc: ${(rec['discount'] as double? ?? 0.0).toStringAsFixed(0)}'),
          _infoChip(Icons.person_outline_rounded,
              '${rec['gender'] ?? '-'} / ${rec['age'] ?? '-'}y'),
        ]),
        SizedBox(height: _sh * 0.012),
        Row(children: [
          Expanded(child: _refundBtn(prov, rec, realIdx)),
          SizedBox(width: _sp * 0.6),
          Expanded(child: _cancelBtn(prov, rec, realIdx, status)),
        ]),
      ]),
    );
  }

  // ── Find real index in provider's receipt list (by srl_no or receiptNo) ──
  int _findRealIndex(OpdProvider prov, Map<String, dynamic> rec) {
    final allReceipts = prov.receipts;

    // Try matching by srl_no first (most reliable)
    final srlNo = rec['srl_no'];
    if (srlNo != null) {
      final idx = allReceipts.indexWhere((r) => r['srl_no'] == srlNo);
      if (idx != -1) return idx;
    }

    // Fallback: match by receiptNo
    final receiptNo = rec['receiptNo'];
    if (receiptNo != null) {
      final idx = allReceipts.indexWhere((r) => r['receiptNo'] == receiptNo);
      if (idx != -1) return idx;
    }

    return -1;
  }

  // ════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════
  Widget _genderBadge(String gender) {
    final isM = gender.toUpperCase().startsWith('M');
    return Container(
      width: _sw * 0.06, height: _sw * 0.06,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isM ? Colors.blue : Colors.pink).withOpacity(0.12),
        border: Border.all(color: isM ? Colors.blue : Colors.pink, width: 1.5),
      ),
      child: Center(child: Text(isM ? 'M' : 'F',
          style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.bold,
              color: isM ? Colors.blue : Colors.pink))),
    );
  }

  Widget _refundBtn(OpdProvider prov, Map<String, dynamic> rec, int realIdx) {
    final status     = rec['status'] as String? ?? 'Active';
    final isRefunded = status == 'Refunded';

    return OutlinedButton(
      onPressed: (isRefunded || realIdx == -1) ? null : () => _refundRecord(prov, realIdx),
      style: OutlinedButton.styleFrom(
        foregroundColor: isRefunded ? Colors.grey : primary,
        side: BorderSide(color: isRefunded ? Colors.grey.shade300 : primary),
        padding: EdgeInsets.symmetric(vertical: _sh * 0.009),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.02)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(isRefunded ? 'Refunded' : 'Refund',
          style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w600)),
    );
  }

  Widget _cancelBtn(OpdProvider prov, Map<String, dynamic> rec, int realIdx, String status) {
    final isCancelled = status == 'Cancelled';

    return ElevatedButton(
      onPressed: (isCancelled || realIdx == -1) ? null : () => _cancelRecord(prov, realIdx),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCancelled ? Colors.grey.shade300 : Colors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey,
        padding: EdgeInsets.symmetric(vertical: _sh * 0.009),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.02)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(isCancelled ? 'Cancelled' : 'Cancel',
          style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(String status) {
    if (status == 'Active') return const SizedBox.shrink();
    Color c; IconData icon;
    switch (status) {
      case 'Cancelled': c = Colors.red;    icon = Icons.cancel_rounded;        break;
      case 'Refunded':  c = Colors.orange; icon = Icons.undo_rounded;          break;
      case 'Pending Sync': c = Colors.amber.shade800; icon = Icons.cloud_off_rounded; break;
      default:          c = primary;       icon = Icons.check_circle_rounded;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sw * 0.025, vertical: _sh * 0.004),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_sw * 0.05),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: c, size: _sw * 0.032),
        SizedBox(width: _sw * 0.01),
        Text(status, style: TextStyle(fontSize: _fsXS, color: c, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: _sw * 0.033, color: Colors.grey.shade400),
      SizedBox(width: _sw * 0.01),
      Text(label, style: TextStyle(fontSize: _fsS, color: Colors.black54)),
    ]);
  }

  Widget _emptyState(bool hasActiveFilters) {
    return Center(child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(hasActiveFilters ? Icons.search_off_rounded : Icons.manage_search_rounded, 
            color: Colors.grey.shade300, size: _sw * 0.18),
        SizedBox(height: _sh * 0.015),
        Text(hasActiveFilters ? 'No records found' : 'Search for records', style: TextStyle(
            fontSize: _fs * 1.1, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
        SizedBox(height: _sh * 0.006),
        Text(hasActiveFilters ? 'Try adjusting your filters' : 'Use the search box and filters above to view records',
            style: TextStyle(fontSize: _fsS, color: Colors.grey.shade400), textAlign: TextAlign.center),
      ],
    )));
  }
}