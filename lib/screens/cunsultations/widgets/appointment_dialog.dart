import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/consultation_model/doctor_model.dart';
import '../../../models/consultation_model/appointment_model.dart';
import '../../../providers/opd/consultation_provider/cunsultation_provider.dart';
import '../../../providers/mr_provider/mr_provider.dart';
import '../../../../custum widgets/custom_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/dashboard/dashboard_provider.dart';
import '../../../../global/global_api.dart';

class AppointmentDialog extends StatefulWidget {
  final DoctorInfo doctor;
  final int availableSlots;
  final ConsultationAppointment? editAppointment;

  const AppointmentDialog({
    super.key,
    required this.doctor,
    required this.availableSlots,
    this.editAppointment,
  });

  @override
  State<AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<AppointmentDialog> {
  static const Color primary = Color(0xFF00B5AD);

  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;
  String _selectedType = 'In-Person';
  bool _isFirstVisit = true;
  bool _patientFound = false;
  bool _patientNotFound = false;

  final _mrCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mrFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.editAppointment != null) {
      final appt = widget.editAppointment!;
      _mrCtrl.text = appt.mrNo;
      _nameCtrl.text = appt.patientName;
      _contactCtrl.text = appt.contactNo;
      _addressCtrl.text = appt.address;
      _isFirstVisit = appt.isFirstVisit;
      _selectedDate = appt.appointmentDate;
      _selectedSlot = appt.timeSlot;
      _patientFound = true;
      
      // Fetch visit history for existing patient
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && appt.mrNo.isNotEmpty) {
          context.read<ConsultationProvider>().fetchPatientHistory(appt.mrNo);
        }
      });
    }
    // No MR padding as per React parity
  }


  @override
  void dispose() {
    _mrCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _mrFocusNode.dispose();
    super.dispose();
  }

  void _onMrChanged(String val) async {
    final raw = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) {
      setState(() {
        _patientFound = false;
        _patientNotFound = false;
      });
      _nameCtrl.clear();
      _contactCtrl.clear();
      _addressCtrl.clear();
      return;
    }

    // Auto-pad if input is short and has significant length (e.g., > 0)
    // We'll also handle this in onSubmitted for immediate effect
    String formatted = raw;
    if (raw.isNotEmpty && raw.length < 5) {
      // We don't pad immediately on change as it makes typing hard, 
      // but we use the padded version for looking up.
    }

    final mrProv = Provider.of<MrProvider>(context, listen: false);
    final patient = await mrProv.findByMrNumber(raw);

    if (!mounted) return;

    if (patient != null) {
      setState(() {
        _patientFound = true;
        _patientNotFound = false;
        _isFirstVisit = false;
      });
      _nameCtrl.text = patient.fullName;
      _contactCtrl.text = patient.phoneNumber;
      _addressCtrl.text = patient.address;
      
      // Fetch visit history
      context.read<ConsultationProvider>().fetchPatientHistory(raw);
    } else {
      setState(() {
        _patientFound = false;
        _patientNotFound = raw.length >= 3;
        _isFirstVisit = true;
      });
      _nameCtrl.clear();
      _contactCtrl.clear();
      _addressCtrl.clear();
    }
  }

  Future<void> _pickDate() async {
    DateTime tempMonth = DateTime(_selectedDate.year, _selectedDate.month);
    DateTime tempDate = _selectedDate;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, sd) {
        final firstDay = DateTime(tempMonth.year, tempMonth.month, 1);
        final daysInMonth = DateTime(tempMonth.year, tempMonth.month + 1, 0).day;
        final startWeekday = firstDay.weekday % 7;
        const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final today = DateTime.now();

        final cells = <Widget>[];
        for (int i = 0; i < startWeekday; i++) cells.add(const SizedBox());
        for (int d = 1; d <= daysInMonth; d++) {
          final date = DateTime(tempMonth.year, tempMonth.month, d);
          final dayName = dayNames[date.weekday % 7];
          final fullDayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
          final fullDayName = fullDayNames[date.weekday % 7];
          final isAvail = widget.doctor.availableDays.contains(dayName) || 
                          widget.doctor.availableDays.contains(fullDayName);
          final isPast =
              date.isBefore(DateTime(today.year, today.month, today.day));
          final isSel = date.year == tempDate.year &&
              date.month == tempDate.month &&
              date.day == tempDate.day;
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
          cells.add(GestureDetector(
            onTap: isAvail && !isPast ? () => sd(() => tempDate = date) : null,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSel
                    ? primary
                    : isToday
                        ? primary.withOpacity(0.15)
                        : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text('$d',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSel
                            ? Colors.white
                            : isPast || !isAvail
                                ? Colors.grey.shade300
                                : Colors.black87,
                      ))),
            ),
          ));
        }
        const months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December'
        ];

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.calendar_month_rounded,
                    color: primary, size: 22),
                const SizedBox(width: 8),
                const Text('Select Date',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: Colors.grey)),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(
                  onTap: () => sd(() => tempMonth =
                      DateTime(tempMonth.year, tempMonth.month - 1)),
                  child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: primary)),
                ),
                Text('${months[tempMonth.month - 1]} ${tempMonth.year}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                GestureDetector(
                  onTap: () => sd(() => tempMonth =
                      DateTime(tempMonth.year, tempMonth.month + 1)),
                  child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.chevron_right_rounded,
                          color: primary)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(
                  children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                      .map((d) => Expanded(
                              child: Center(
                                  child: Text(d,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade500)))))
                      .toList()),
              const SizedBox(height: 4),
              GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1,
                  children: cells),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, tempDate),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Confirm Date',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_mrCtrl.text.isEmpty) {
      _snack('Please enter MR No', err: true);
      return;
    }
    if (_nameCtrl.text.isEmpty) {
      _snack('Please enter patient name', err: true);
      return;
    }
    if (_contactCtrl.text.isEmpty) {
      _snack('Please enter contact no', err: true);
      return;
    }
    if (_selectedSlot == null) {
      _snack('Please select a time slot', err: true);
      return;
    }

    final prov = Provider.of<ConsultationProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Material(
        color: Colors.black.withOpacity(0.3),
        child: const Center(child: CustomLoader(size: 80)),
      ),
    );

    final appointment = ConsultationAppointment(
      id: widget.editAppointment?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      consultantName: widget.doctor.name,
      specialty: widget.doctor.specialty,
      consultationFee: widget.doctor.consultationFee,
      followUpCharges: widget.doctor.followUpCharges,
      availableDays: widget.doctor.availableDays,
      timings: widget.doctor.timings,
      hospital: widget.doctor.hospital,
      mrNo: _mrCtrl.text,
      patientName: _nameCtrl.text.trim(),
      contactNo: _contactCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      isFirstVisit: _isFirstVisit,
      appointmentDate: _selectedDate,
      timeSlot: _selectedSlot!,
      type: _selectedType,
      status: widget.editAppointment?.status ?? 'Upcoming',
      tokenNumber: widget.editAppointment?.tokenNumber,
    );

    bool success;
    if (widget.editAppointment != null) {
      success = await prov.updateAppointment(widget.editAppointment!.id, appointment);
    } else {
      success = await prov.addAppointment(appointment);
    }

    // Refresh Dashboard if success
    if (success) {
      try {
        final dashProv = Provider.of<DashboardProvider>(context, listen: false);
        await dashProv.fetchCalendarData(appointment.appointmentDate);
      } catch (e) {
        debugPrint('Error refreshing dashboard: $e');
      }
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (mounted) Navigator.pop(context); // Close loader

    if (success) {
      _snackWithMessenger(scaffoldMessenger, widget.editAppointment != null ? 'Appointment updated successfully!' : 'Appointment booked successfully!', err: false);
      if (mounted) Navigator.pop(context); // Close dialog
    } else {
      _snackWithMessenger(scaffoldMessenger, prov.errorMessage ?? 'Operation failed', err: true);
    }
  }

  void _snackWithMessenger(ScaffoldMessengerState messenger, String msg, {required bool err}) {
    messenger.showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err ? Colors.red.shade400 : primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _snack(String msg, {required bool err}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err ? Colors.red.shade400 : primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _initials(String name) {
    final parts = name.replaceAll('Dr. ', '').split(' ');
    return parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}' : parts[0][0];
  }

  String _dateLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const wdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildFeeInfo(String label, String value, IconData icon, double fsS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: primary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: fsS, fontWeight: FontWeight.bold, color: const Color(0xFF2D3748))),
      ],
    );
  }

  Widget _buildPlaceholder(double sw) {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_rounded, color: Colors.grey.shade400, size: sw * 0.12),
          Text(
            _initials(widget.doctor.name),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: sw * 0.03,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final prov = Provider.of<ConsultationProvider>(context);
    final allSlots = prov.generateTimeSlots(widget.doctor.timings);
    // Ensure selected slot exists in items to prevent crash
    if (_selectedSlot != null && !allSlots.contains(_selectedSlot)) {
      allSlots.add(_selectedSlot!);
      allSlots.sort(); // Keep it tidy if possible
    }
    final booked = prov.bookedSlots(_selectedDate, widget.doctor.name);

    final double fs = sw < 360 ? 11.5 : 13.0;
    final double fsS = sw < 360 ? 10.0 : 11.5;
    final double fsXS = sw < 360 ? 9.0 : 10.5;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
          horizontal: sw >= 720 ? sw * 0.08 : sw * 0.025,
          vertical: sh * 0.025),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          constraints: BoxConstraints(maxHeight: sh * 0.92),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(sw * 0.05),
          ),
          child: Column(children: [
          Container(
            padding: EdgeInsets.all(sw * 0.04),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00B5AD), Color(0xFF00897B)]),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(sw * 0.05),
                topRight: Radius.circular(sw * 0.05),
              ),
            ),
            child: Row(children: [
              Icon(Icons.event_note_rounded,
                  color: Colors.white, size: sw * 0.048),
              SizedBox(width: sw * 0.02),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Appointment Schedule',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: sw * 0.042,
                            fontWeight: FontWeight.bold)),
                    Text('Book with ${widget.doctor.name}',
                        style: TextStyle(color: Colors.white70, fontSize: fsS)),
                  ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(sw * 0.018),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white, size: sw * 0.042),
                ),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(sw * 0.035),
              child: Column(children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: sw * 0.04, vertical: sh * 0.013),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(sw * 0.03),
                      border: Border.all(color: primary.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8)
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        padding: EdgeInsets.all(sw * 0.02),
                        decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(sw * 0.02)),
                        child: Icon(Icons.calendar_today_rounded,
                            color: primary, size: sw * 0.042),
                      ),
                      SizedBox(width: sw * 0.025),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Appointment Date',
                                style: TextStyle(
                                    fontSize: fsXS,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600)),
                            Text(_dateLabel(_selectedDate),
                                style: TextStyle(
                                    fontSize: fs,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                          ])),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: sw * 0.025, vertical: sh * 0.006),
                        decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(sw * 0.02)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_calendar_rounded,
                              color: Colors.white, size: sw * 0.032),
                          SizedBox(width: sw * 0.008),
                          Text('Change',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: fsXS,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                SizedBox(height: sw * 0.03),
                Container(
                  padding: EdgeInsets.all(sw * 0.035),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(sw * 0.04),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Doctor Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.doctor.name,
                              style: TextStyle(
                                fontSize: sw * 0.042,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3748),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.doctor.specialty.toUpperCase(),
                              style: TextStyle(
                                fontSize: fsXS,
                                color: primary.withOpacity(0.8),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: fs, color: primary.withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.doctor.hospital,
                                    style: TextStyle(
                                      fontSize: fsXS,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildFeeInfo('Cons.', 'Rs. ${widget.doctor.consultationFee}', Icons.payments_outlined, fsS),
                                const SizedBox(width: 12),
                                _buildFeeInfo('F.Up', 'Rs. ${widget.doctor.followUpCharges}', Icons.history_rounded, fsS),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: widget.doctor.availableDays.map((day) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Right: Large Image
                      Hero(
                        tag: 'doctor_img_${widget.doctor.id}',
                        child: Container(
                          width: sw * 0.3,
                          height: sw * 0.4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(sw * 0.03),
                            boxShadow: [
                              // BoxShadow(
                              //   color: Colors.black.withOpacity(0.08),
                              //   blurRadius: 10,
                              //   offset: const Offset(4, 4),
                              // )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(sw * 0.03),
                            child: Builder(
                              builder: (context) {
                                final url = GlobalApi.getImageUrl(widget.doctor.imageAsset);
                                if (url != null && url.isNotEmpty) {
                                  return CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (context, _) => _buildPlaceholder(sw),
                                    errorWidget: (context, _, __) => _buildPlaceholder(sw),
                                  );
                                }
                                return _buildPlaceholder(sw);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sw * 0.03),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(sw * 0.018),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03), blurRadius: 4)
                    ],
                  ),
                  padding: EdgeInsets.all(sw * 0.02),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.schedule_rounded,
                              color: primary, size: sw * 0.03),
                          SizedBox(width: sw * 0.008),
                          Text('Select Time Slots',
                              style: TextStyle(
                                  fontSize: fs * 0.85,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                          const Spacer(),
                          if (allSlots.isNotEmpty) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: sw * 0.025, vertical: sw * 0.012),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF43A047),
                                    Color(0xFF2E7D32)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(sw * 0.025),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF43A047)
                                        .withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child:
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: sw * 0.022),
                                SizedBox(width: sw * 0.006),
                                Text(
                                    '${allSlots.length - booked.length} Available',
                                    style: TextStyle(
                                        fontSize: fsXS * 0.85,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3)),
                              ]),
                            ),
                            SizedBox(width: sw * 0.008),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: sw * 0.025, vertical: sw * 0.012),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.shade600,
                                    Colors.red.shade800
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(sw * 0.025),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.shade600.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child:
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.event_busy_rounded,
                                    color: Colors.white, size: sw * 0.022),
                                SizedBox(width: sw * 0.006),
                                Text('${booked.length} Booked',
                                    style: TextStyle(
                                        fontSize: fsXS * 0.85,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3)),
                              ]),
                            ),
                          ],
                        ]),
                        SizedBox(height: sh * 0.006),
                        if (allSlots.isEmpty)
                          Center(
                              child: Padding(
                            padding: EdgeInsets.symmetric(vertical: sh * 0.006),
                            child: Text('No slots available',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: fsS * 0.9,
                                    fontWeight: FontWeight.w500)),
                          ))
                        else
                          Container(
                            constraints: BoxConstraints(minWidth: sw * 0.25),
                            height: sh * 0.04,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(sw * 0.014),
                              border: Border.all(
                                  color: _selectedSlot != null
                                      ? primary
                                      : Colors.grey.shade400,
                                  width: _selectedSlot != null ? 1.5 : 1),
                            ),
                            padding:
                                EdgeInsets.symmetric(horizontal: sw * 0.015),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSlot,
                                isExpanded: true,
                                hint: Row(children: [
                                  Icon(Icons.schedule_rounded,
                                      color: Colors.grey.shade500,
                                      size: sw * 0.026),
                                  SizedBox(width: sw * 0.008),
                                  Text('Choose time',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: fs * 0.8,
                                          fontWeight: FontWeight.w500)),
                                ]),
                                icon: Container(
                                  padding: EdgeInsets.all(sw * 0.004),
                                  decoration: BoxDecoration(
                                    color: _selectedSlot != null
                                        ? primary.withOpacity(0.1)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(sw * 0.02),
                                  ),
                                  child: Icon(Icons.keyboard_arrow_down_rounded,
                                      color: _selectedSlot != null
                                          ? primary
                                          : Colors.grey.shade500,
                                      size: sw * 0.03),
                                ),
                                dropdownColor: Colors.white,
                                menuMaxHeight: sh * 0.3,
                                borderRadius: BorderRadius.circular(sw * 0.02),
                                menuWidth: sw * 0.45,
                                items: allSlots
                                    .where((slot) => !booked.contains(slot) || slot == _selectedSlot)
                                    .map((slot) {
                                  return DropdownMenuItem<String>(
                                    value: slot,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: sw * 0.02,
                                          vertical: sh * 0.006),
                                      constraints:
                                          BoxConstraints(minWidth: sw * 0.4),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(sw * 0.01),
                                      ),
                                      child: Row(children: [
                                        Container(
                                          padding: EdgeInsets.all(sw * 0.006),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF43A047)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(sw * 0.01),
                                          ),
                                          child: Icon(Icons.access_time_rounded,
                                              size: sw * 0.022,
                                              color: const Color(0xFF43A047)),
                                        ),
                                        SizedBox(width: sw * 0.015),
                                        Expanded(
                                          child: Text(slot,
                                              style: TextStyle(
                                                  fontSize: fs * 0.85,
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.w500)),
                                        ),
                                      ]),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedSlot = v);
                                  }
                                },
                              ),
                            ),
                          ),
                      ]),
                ),
                SizedBox(height: sw * 0.03),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(sw * 0.03),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04), blurRadius: 8)
                    ],
                  ),
                  padding: EdgeInsets.all(sw * 0.035),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.person_pin_rounded,
                              color: primary, size: sw * 0.04),
                          SizedBox(width: sw * 0.015),
                          Text('Patient Information',
                              style: TextStyle(
                                  fontSize: fs,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                        ]),
                        SizedBox(height: sw * 0.03),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        SizedBox(height: sw * 0.03),
                        _lbl('MR No', fsS, sw),
                        TextFormField(
                          controller: _mrCtrl,
                          focusNode: _mrFocusNode,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              fontSize: fs, fontWeight: FontWeight.bold),
                          decoration: _dec('e.g. 00001', sw, fs).copyWith(
                            suffixIcon: _patientFound
                                ? const Icon(Icons.check_circle_rounded,
                                    color: Colors.green, size: 20)
                                : _patientNotFound
                                    ? Icon(Icons.search_off_rounded,
                                        color: Colors.orange.shade400, size: 20)
                                    : Icon(Icons.badge_rounded,
                                        color: Colors.grey.shade400, size: 20),
                            filled: true,
                            fillColor: _patientFound
                                ? Colors.green.withOpacity(0.04)
                                : Colors.white,
                          ),
                          onChanged: _onMrChanged,
                        ),
                        if (_patientFound)
                          _chipMsg(
                              Icons.check_circle_rounded,
                              'Patient found — fields auto-filled',
                              Colors.green,
                              fsXS,
                              sw),
                        if (_patientNotFound)
                          _chipMsg(Icons.info_rounded,
                              'Not found — fill manually', Colors.orange, fsXS, sw),
                        SizedBox(height: sw * 0.025),
                        _lbl('Patient Name *', fsS, sw),
                        _tf(_nameCtrl, 'Enter full name', fs, sw,
                            filled: _patientFound),
                        SizedBox(height: sw * 0.025),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    _lbl('Contact No *', fsS, sw),
                                    _tf(_contactCtrl, '03XX-XXXXXXX', fs, sw,
                                        type: TextInputType.phone,
                                        filled: _patientFound),
                                  ])),
                              SizedBox(width: sw * 0.025),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    _lbl('Address', fsS, sw),
                                    _tf(_addressCtrl, 'Enter address', fs, sw,
                                        filled: _patientFound),
                                  ])),
                            ]),
                        SizedBox(height: sw * 0.025),
                        Row(children: [
                          const Expanded(child: SizedBox()),
                          SizedBox(width: sw * 0.025),
                          Column(children: [
                            _lbl('First Visit', fsS, sw),
                            Transform.scale(
                              scale: 0.9,
                              child: Switch(
                                  value: _isFirstVisit,
                                  onChanged: (v) =>
                                      setState(() => _isFirstVisit = v),
                                  activeColor: primary),
                            ),
                          ]),
                        ]),
                      ]),
                ),
                SizedBox(height: sw * 0.03),
                _buildVisitHistory(prov, sw, fsS),
                SizedBox(height: sw * 0.04),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: EdgeInsets.symmetric(vertical: sh * 0.015),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(sw * 0.025)),
                    ),
                    icon: Icon(Icons.close_rounded, size: sw * 0.04),
                    label: Text('Cancel',
                        style: TextStyle(
                            fontSize: fs, fontWeight: FontWeight.w600)),
                  )),
                  SizedBox(width: sw * 0.025),
                  Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: sh * 0.015),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(sw * 0.025)),
                        ),
                        icon: Icon(Icons.check_rounded, size: sw * 0.04),
                        label: Text(widget.editAppointment != null ? 'Update Appointment' : 'Book Appointment',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                      )),
                ]),
                SizedBox(height: sw * 0.02),
              ]),
            ),
          ),
        ]),
      )
    ));
  }

  Widget _chipMsg(
      IconData icon, String msg, Color color, double fsXS, double sw) {
    return Padding(
      padding: EdgeInsets.only(top: sw * 0.012),
      child: Row(children: [
        Icon(icon, color: color, size: 13),
        SizedBox(width: sw * 0.012),
        Flexible(
            child: Text(msg,
                style: TextStyle(
                    fontSize: fsXS, color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _lbl(String text, double fsS, double sw) {
    return Padding(
      padding: EdgeInsets.only(bottom: sw * 0.012),
      child: Text(text,
          style: TextStyle(
              fontSize: fsS,
              fontWeight: FontWeight.w600,
              color: Colors.black54)),
    );
  }

  Widget _tf(TextEditingController ctrl, String hint, double fs, double sw,
      {TextInputType type = TextInputType.text, bool filled = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: TextStyle(fontSize: fs, color: Colors.black87),
      decoration: _dec(hint, sw, fs).copyWith(
        filled: true,
        fillColor: filled ? Colors.green.withOpacity(0.04) : Colors.white,
      ),
    );
  }

  InputDecoration _dec(String hint, double sw, double fs) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: fs * 0.95),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            EdgeInsets.symmetric(horizontal: sw * 0.03, vertical: sw * 0.032),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(sw * 0.022),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(sw * 0.022),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(sw * 0.022),
            borderSide: const BorderSide(color: primary, width: 1.5)),
      );

  Widget _buildVisitHistory(ConsultationProvider prov, double sw, double fsS) {
    if (!_patientFound || (prov.patientHistory.isEmpty && !prov.isLoadingHistory)) {
      return const SizedBox();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(sw * 0.03),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      padding: EdgeInsets.all(sw * 0.035),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.history_rounded, color: primary, size: sw * 0.042),
            SizedBox(width: sw * 0.02),
            Text('Visit History',
                style: TextStyle(
                    fontSize: sw * 0.035,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const Spacer(),
            if (prov.isLoadingHistory)
              const SizedBox(
                  width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: primary)),
          ]),
          const SizedBox(height: 12),
          if (prov.patientHistory.isEmpty && !prov.isLoadingHistory)
            const Text('No previous visits found.', style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prov.patientHistory.length > 3 ? 3 : prov.patientHistory.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (_, i) {
                final visit = prov.patientHistory[i];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(visit.consultantName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(
                            '${_dateLabel(visit.appointmentDate)} at ${visit.timeSlot}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          if (visit.tokenNumber != null)
                            Text(
                              'Token No: ${visit.tokenNumber}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                            ),
                        ],
                      ),
                    ),
                    // Container(
                    //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    //   decoration: BoxDecoration(
                    //     color: _getStatusColor(visit.status).withOpacity(0.1),
                    //     borderRadius: BorderRadius.circular(4),
                    //   ),
                    //   child: Text(
                    //     visit.status,
                    //     style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getStatusColor(visit.status)),
                    //   ),
                    // ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // Color _getStatusColor(String status) {
  //   switch (status.toLowerCase()) {
  //     case 'completed': return Colors.green;
  //     case 'cancelled': return Colors.red;
  //     case 'upcoming': return Colors.blue;
  //     case 'booked': return Colors.blue;
  //     case 'booked (upcoming)': return Colors.blue;
  //     default: return Colors.grey;
  //   }
  // }
}
