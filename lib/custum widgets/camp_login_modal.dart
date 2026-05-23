import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camp_provider.dart';
import '../screens/mr_details/mr_details.dart';

const _kTeal = Color(0xFF00B5AD);

class CampLoginModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  /// When true, renders only dialog content (for [showDialog]).
  final bool embeddedInDialog;

  const CampLoginModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    this.embeddedInDialog = false,
  });

  /// Opens the join-camp dialog (use from Home and other screens).
  static void showJoinDialog(BuildContext context) {
    showCampJoinDialog(context);
  }

  @override
  State<CampLoginModal> createState() => _CampLoginModalState();
}

class _CampLoginModalState extends State<CampLoginModal> {
  List<Map<String, dynamic>> _camps = [];
  bool _loadingCamps = false;
  String? _selectedCampId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCamps());
    }
  }

  @override
  void didUpdateWidget(CampLoginModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _loadCamps();
      _selectedCampId = null;
    }
  }

  Future<void> _loadCamps() async {
    setState(() {
      _loadingCamps = true;
      _camps = [];
    });
    final camps = await context.read<CampProvider>().fetchAvailableCamps();
    if (mounted) {
      // Filter by today's day — only show camps that include today or have no days set
      final todayName = _todayDayName();
      final filtered = camps.where((camp) {
        final days = (camp['days'] ?? '').toString();
        if (days.isEmpty) return true; // no restriction = every day
        return days.split(',').map((d) => d.trim()).contains(todayName);
      }).toList();
      setState(() {
        _camps = filtered;
        _loadingCamps = false;
      });
    }
  }

  String _todayDayName() {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    // DateTime.weekday: 1=Monday … 7=Sunday
    return names[DateTime.now().weekday - 1];
  }

  Future<void> _submit() async {
    if (_selectedCampId == null) return;
    setState(() => _isSubmitting = true);
    final result =
        await context.read<CampProvider>().loginToCamp(_selectedCampId!);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      widget.onClose();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MrDetailsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Failed to join camp'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final card = Container(
              width: widget.embeddedInDialog
                  ? null
                  : MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: widget.embeddedInDialog
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _kTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.festival, color: _kTeal),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Join Camp',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Select an active online camp',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        // IconButton(
                        //   onPressed: widget.onClose,
                        //   icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        // ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _loadingCamps
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: _kTeal),
                                SizedBox(height: 12),
                                Text('Loading active camps...'),
                              ],
                            ),
                          )
                        : _camps.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade100),
                                ),
                                child: Text(
                                  'No active  ${_todayDayName()}.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Select Camp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCampId,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    hint: const Text('-- Select an active camp --'),
                                    items: _camps.map((camp) {
                                      final id = camp['id']?.toString() ?? '';
                                      final name =
                                          camp['camp_name'] ?? camp['name'] ?? 'Camp';
                                      final loc = camp['location']?.toString();
                                      final days = (camp['days'] ?? '').toString();
                                      String label = loc != null && loc.isNotEmpty
                                          ? '$name - $loc'
                                          : name.toString();
                                      if (days.isNotEmpty) {
                                        final abbrs = days.split(',').map((d) {
                                          const a = {'Monday':'Mon','Tuesday':'Tue','Wednesday':'Wed','Thursday':'Thu','Friday':'Fri','Saturday':'Sat','Sunday':'Sun'};
                                          return a[d.trim()] ?? d.trim();
                                        }).join(', ');
                                        label = '$label ($abbrs)';
                                      }
                                      return DropdownMenuItem(
                                        value: id,
                                        child: Text(label, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (v) =>
                                        setState(() => _selectedCampId = v),
                                  ),
                                ],
                              ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: widget.onClose,
                          child: const Text('Clinical Mood'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _selectedCampId == null || _isSubmitting
                              ? null
                              : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Camp Mode'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

    if (widget.embeddedInDialog) return card;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black54),
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: card,
            ),
          ),
        ),
      ],
    );
  }
}

/// In-memory flag — shows the popup once per app session, resets on logout.
bool _campJoinShownThisSession = false;

/// Call on logout so the popup shows again on next login.
void resetCampJoinSession() => _campJoinShownThisSession = false;

/// Shows join-camp modal once per app session for ALL logged-in users.
/// Matches React behavior: no permission check, anyone can join a camp.
Future<void> maybeShowCampJoinPrompt(BuildContext context) async {
  if (_campJoinShownThisSession) return;

  final camp = context.read<CampProvider>();
  if (camp.isCampMode || camp.loading) return;

  _campJoinShownThisSession = true;

  if (!context.mounted) return;
  showCampJoinDialog(context);
}

void showCampJoinDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: CampLoginModal(
        isOpen: true,
        embeddedInDialog: true,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}
