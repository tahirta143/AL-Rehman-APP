import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../providers/mr_provider/mr_provider.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../custum widgets/custom_loader.dart';
import '../../custum widgets/animations/animations.dart';
import 'package:animate_do/animate_do.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _teal = Color(0xFF00B5AD);
const _tealLight = Color(0xFFE6F7F6);
const _tealDark = Color(0xFF007A75);
const _bg = Color(0xFFF4F7FA);
const _card = Colors.white;
const _textDark = Color(0xFF1A202C);
const _textMid = Color(0xFF4A5568);
const _textLight = Color(0xFF718096);
const _border = Color(0xFFE2E8F0);
const _red = Color(0xFFE53E3E);
const _green = Color(0xFF38A169);
const _purple = Color(0xFF805AD5);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class MrDetailsScreen extends StatelessWidget {
  final bool useScaffold;
  const MrDetailsScreen({super.key, this.useScaffold = true});

  @override
  Widget build(BuildContext context) {
    if (!useScaffold) return const _MrDetailsBody();
    return BaseScaffold(
      title: 'MR Details',
      drawerIndex: 8,
      body: Consumer<PermissionProvider>(
        builder: (context, perm, _) {
          if (!perm.canAny([Perm.mrRead, Perm.mrCreate])) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Color(0xFFCBD5E0)),
                  SizedBox(height: 16),
                  Text('Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A5568))),
                  SizedBox(height: 8),
                  Text('You do not have permission to view MR Details.', style: TextStyle(color: Color(0xFF718096))),
                ],
              ),
            );
          }
          return CustomPageTransition(child: const _MrDetailsBody());
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────
class _MrDetailsBody extends StatefulWidget {
  const _MrDetailsBody();

  @override
  State<_MrDetailsBody> createState() => _MrDetailsBodyState();
}

class _MrDetailsBodyState extends State<_MrDetailsBody>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mrFocusNode = FocusNode();
  final _ageFocusNode = FocusNode();
  final _mrCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  
  // Registration Controllers
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _guardianCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _profCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _eduCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  late TabController _tabController;

  PatientModel? _patient;
  bool _isLoading = false;
  bool _isNewPatient = false;
  List<PatientModel> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Form dropdown states
  String _relation = 'Parent';
  String _gender = 'Male';
  String _bloodGroup = '';
  DateTime? _dob;

  static const _relations = ['Parent', 'Spouse', 'Sibling', 'Child', 'Other'];
  static const _genders = ['Male', 'Female', 'Other'];
  static const _bloodGroups = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _mrFocusNode.addListener(() {
      if (!_mrFocusNode.hasFocus) _lookupMr(_mrCtrl.text);
    });

    // Always fetch latest MR on entry
    context.read<MrProvider>().fetchNextMR();

    // Auto-sync Phone to WhatsApp
    _phoneCtrl.addListener(() {
      if (_whatsappCtrl.text.isEmpty || _whatsappCtrl.text == _phoneCtrl.text) {
        _whatsappCtrl.text = _phoneCtrl.text;
      }
    });

    // Auto-populate when ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPopulateNextMr();
    });

    // Add listener for age -> dob (approximate)
    _ageCtrl.addListener(_onAgeChange);
  }

  void _onAgeChange() {
    if (!_ageFocusNode.hasFocus) return; // Only if user is editing age manually
    final val = _ageCtrl.text.trim();
    if (val.isEmpty) return;
    final age = int.tryParse(val);
    if (age != null && age >= 0) {
      final now = DateTime.now();
      final approxYear = now.year - age;
      // If age was just changed, we set DOB to Jan 1st of that calculated year
      // This is common for patients who don't know exact DOB
      final newDob = DateTime(approxYear, 1, 1);
      if (_dob == null || _dob!.year != approxYear) {
        setState(() {
          _dob = newDob;
        });
      }
    }
  }

  void _autoPopulateNextMr() {
    final prov = context.read<MrProvider>();
    // If we have it already, set it
    if (prov.nextMrNumber != null && _mrCtrl.text.isEmpty && _patient == null) {
      setState(() {
        _isNewPatient = true;
        _mrCtrl.text = prov.nextMrNumber!;
      });
    } else if (prov.nextMrNumber == null && _patient == null) {
      // If not fetched yet, wait for it
      prov.addListener(_onProvChange);
    }
  }

  void _onProvChange() {
    final prov = context.read<MrProvider>();
    if (prov.nextMrNumber != null && mounted && _mrCtrl.text.isEmpty && _patient == null) {
      setState(() {
        _isNewPatient = true;
        _mrCtrl.text = prov.nextMrNumber!;
      });
      prov.removeListener(_onProvChange);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _mrFocusNode.dispose();
    _ageFocusNode.dispose();
    _mrCtrl.dispose();
    _searchCtrl.dispose();
    
    // Dispose registration controllers
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _guardianCtrl.dispose();
    _ageCtrl.dispose();
    _profCtrl.dispose();
    _eduCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _cnicCtrl.dispose();
    _addrCtrl.dispose();
    _cityCtrl.dispose();
    
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────────────────────
  Future<void> _lookupMr(String value, {bool normalize = false}) async {
    final input = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (input.isEmpty) {
      _clearPatient();
      return;
    }

    final formatted = normalize && input.length < 5 ? input.padLeft(5, '0') : input;
    if (formatted != _mrCtrl.text) {
      _mrCtrl.text = formatted;
      _mrCtrl.selection = TextSelection.collapsed(offset: _mrCtrl.text.length);
    }

    setState(() {
      _isLoading = true;
      _isNewPatient = false;
    });

    final prov = context.read<MrProvider>();
    final patient = await prov.findByMrNumber(formatted, normalize: normalize);
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (patient != null) {
      setState(() {
        _patient = patient;
        _isNewPatient = false;
        _populateRegistrationFields(patient);
      });
      prov.selectPatient(patient);
      if (MediaQuery.of(context).size.width > 820) {
        _tabController.animateTo(1);
      }
    } else {
      setState(() {
        _patient = null;
        _isNewPatient = true; // Switch to registration mode if not found
      });
      prov.selectPatient(null);
      _snack('MR# $formatted not found. Ready to register as new.');
    }
  }

  void _clearPatient() {
    _mrCtrl.clear();
    _searchCtrl.clear();
    _clearRegistrationFields();
    final prov = context.read<MrProvider>();
    prov.selectPatient(null);
    setState(() {
      _patient = null;
      _isNewPatient = true; // Default to new patient mode when cleared
      _searchResults = [];
      _isSearching = false;
    });

    // Automatically fetch and fill next MR when clearing
    prov.fetchNextMR().then((_) {
      if (mounted && _mrCtrl.text.isEmpty) {
        setState(() {
          if (prov.nextMrNumber != null) {
            _mrCtrl.text = prov.nextMrNumber!;
          }
        });
      }
    });
  }

  void _populateRegistrationFields(PatientModel p) {
    _firstCtrl.text = p.firstName;
    _lastCtrl.text = p.lastName;
    _guardianCtrl.text = p.guardianName;
    _ageCtrl.text = p.age?.toString() ?? '';
    _profCtrl.text = p.profession;
    _eduCtrl.text = p.education;
    _phoneCtrl.text = p.phoneNumber;
    _whatsappCtrl.text = p.whatsappNo;
    _emailCtrl.text = p.email;
    _cnicCtrl.text = p.cnic;
    _addrCtrl.text = p.address;
    _cityCtrl.text = p.city;
    
    if (p.dateOfBirth.isNotEmpty) {
      try {
        final parts = p.dateOfBirth.split('-');
        if (parts.length == 3) {
           _dob = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
           final partsSlash = p.dateOfBirth.split('/');
           if (partsSlash.length == 3) {
             _dob = DateTime(int.parse(partsSlash[2]), int.parse(partsSlash[1]), int.parse(partsSlash[0]));
           }
        }
      } catch (_) {}
    }
    
    _relation = p.relation;
    _gender = p.gender;
    _bloodGroup = p.bloodGroup;
  }

  void _clearRegistrationFields() {
    _firstCtrl.clear();
    _lastCtrl.clear();
    _guardianCtrl.clear();
    _ageCtrl.clear();
    _profCtrl.clear();
    _eduCtrl.clear();
    _phoneCtrl.clear();
    _whatsappCtrl.clear();
    _emailCtrl.clear();
    _cnicCtrl.clear();
    _addrCtrl.clear();
    _cityCtrl.clear();
    _dob = null;
    _relation = 'Parent';
    _gender = 'Male';
    _bloodGroup = '';
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    final prov = context.read<MrProvider>();
    final messenger = ScaffoldMessenger.of(context);
    
    final patient = await prov.registerPatient(
      mrNumber: _mrCtrl.text,
      firstName: _firstCtrl.text,
      lastName: _lastCtrl.text,
      guardianName: _guardianCtrl.text,
      relation: _relation,
      gender: _gender,
      dateOfBirth: _dob != null
          ? "${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}"
          : '',
      age: int.tryParse(_ageCtrl.text),
      bloodGroup: _bloodGroup,
      profession: _profCtrl.text,
      education: _eduCtrl.text,
      phoneNumber: _phoneCtrl.text,
      whatsappNo: _whatsappCtrl.text,
      email: _emailCtrl.text,
      cnic: _cnicCtrl.text,
      address: _addrCtrl.text,
      city: _cityCtrl.text,
    );

    if (patient != null) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        _snack('Patient Registered Successfully!');
      }
      
      // Auto-refresh for NEXT patient if this was a new registration
      if (_isNewPatient) {
        _clearPatient(); // This will fetchNextMR and clear fields
      } else {
        if (mounted) {
          setState(() {
            _patient = patient;
            _isNewPatient = false;
          });
        }
      }
    } else {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        _snack(prov.errorMessage ?? 'Failed to register patient');
      }
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await context.read<MrProvider>().searchPatients(q);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _selectFromSearch(PatientModel p) async {
    _mrCtrl.text = p.mrNumber;
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    Navigator.pop(context);
    await _lookupMr(p.mrNumber);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Flexible(child: Text(msg, style: const TextStyle(fontSize: 12))),
      ]),
      backgroundColor: _textLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 820;
    return Scaffold(
      backgroundColor: _bg,
      body: isWide ? _buildWide() : _buildMobile(),
    );
  }

  // ══════════════════════════════════════════ WIDE LAYOUT ════════════════════
  Widget _buildWide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MR Details',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _textDark)),
                  Text('Patient Master Index & Medical Record',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
          ),
          if (_patient != null || _isNewPatient)
            OutlinedButton.icon(
              onPressed: _clearPatient,
              icon: const Icon(Icons.close_rounded, size: 14),
              label: const Text('Clear / New',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textLight,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            )
          else 
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isNewPatient = true);
                final prov = context.read<MrProvider>();
                if (prov.nextMrNumber != null) {
                   _mrCtrl.text = prov.nextMrNumber!;
                }
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('New Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        FadeInUp(delay: const Duration(milliseconds: 100), child: _mrSearchBar()),
        const SizedBox(height: 16),
        
        if (_isLoading || context.watch<MrProvider>().isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: CustomLoader(
                size: 50,
                color: _teal,
              ),
            ),
          )
        else if (_patient != null)
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _patientInfoCard()),
              const SizedBox(width: 16),
              SizedBox(width: 300, child: _wideSidebar()),
            ]),
          )
        else if (_isNewPatient)
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _registrationForm()),
              const SizedBox(width: 16),
              SizedBox(width: 300, child: _wideSidebar()),
            ]),
          )
        else
          FadeInUp(delay: const Duration(milliseconds: 200), child: _emptyState()),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── MR Search bar ──────────────────────────────────────────────────────────
  Widget _mrSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (_patient != null || _isNewPatient) ? _teal : _border,
            width: (_patient != null || _isNewPatient) ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(Icons.badge_outlined,
            color: (_patient != null || _isNewPatient) ? _teal : const Color(0xFFCBD5E0),
            size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _mrCtrl,
            focusNode: _mrFocusNode,
            keyboardType: TextInputType.number,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: (_patient != null || _isNewPatient) ? _tealDark : _textDark,
                letterSpacing: 0.5),
            onSubmitted: (v) => _lookupMr(v, normalize: true),
            onChanged: (v) {
               // Only reset if we were showing a valid patient
               if (_patient != null) {
                  setState(() {
                    _patient = null;
                    _isNewPatient = false;
                  });
               }
            },
            decoration: const InputDecoration(
              hintText: 'Enter MR Number and press Enter to lookup',
              hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (_isNewPatient && _mrCtrl.text == context.read<MrProvider>().nextMrNumber)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _chip('AUTO', Colors.amber[800]!, Colors.amber[50]!, icon: Icons.auto_awesome),
          ),
        if (_patient != null || _isNewPatient)
          GestureDetector(
            onTap: _clearPatient,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(11),
                    bottomRight: Radius.circular(11)),
              ),
              child: Icon(_patient != null ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                  color: _teal, size: 20),
            ),
          )
        else
          GestureDetector(
            onTap: () => _lookupMr(_mrCtrl.text, normalize: true),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _teal,
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(11),
                    bottomRight: Radius.circular(11)),
              ),
              child: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
      ]),
    );
  }

  // ── Registration Form ──────────────────────────────────────────────────────
  Widget _registrationForm() {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;
    
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _formHeader(),
          const Divider(height: 1, color: _border),
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Consumer<MrProvider>(
                builder: (context, prov, _) {
                  return Column(
                    children: [
                      _fixedMrField(prov.nextMrNumber),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
              // --- Section: Personal Details ---
              _sectionHeader('Personal Details', Icons.person_outline),
              const SizedBox(height: 16),
              _responsiveGrid([
                _f(ctrl: _firstCtrl, label: 'First Name', required: true, icon: Icons.person_outline),
                _f(ctrl: _lastCtrl, label: 'Last Name', icon: Icons.person_outline),
              ], isMobile),
              const SizedBox(height: 16),
              _responsiveGrid([
                _f(ctrl: _guardianCtrl, label: 'Guardian Name', icon: Icons.people_outline),
                _dd(label: 'Relation', value: _relation, items: _relations, onChanged: (v) => setState(() => _relation = v!)),
              ], isMobile),
              const SizedBox(height: 16),
              _responsiveGrid([
                _dd(label: 'Gender', value: _gender, items: _genders, required: true, onChanged: (v) => setState(() => _gender = v!)),
                _dateWidget(),
              ], isMobile),
              const SizedBox(height: 16),
              _responsiveGrid([
                _f(ctrl: _ageCtrl, label: 'Age', icon: Icons.numbers, type: TextInputType.number, focusNode: _ageFocusNode),
                _dd(label: 'Blood Group', value: _bloodGroup.isEmpty ? null : _bloodGroup, items: _bloodGroups, hint: 'Select', onChanged: (v) => setState(() => _bloodGroup = v ?? '')),
              ], isMobile),
              const SizedBox(height: 16),
              _responsiveGrid([
                _f(ctrl: _profCtrl, label: 'Profession', icon: Icons.work_outline),
                _f(ctrl: _eduCtrl, label: 'Education', icon: Icons.book_outlined),
              ], isMobile),
              
              const SizedBox(height: 32),
              // --- Section: Contact Details ---
              _sectionHeader('Contact Details', Icons.contact_phone_outlined),
              const SizedBox(height: 16),
              _responsiveGrid([
                _f(ctrl: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, type: TextInputType.phone),
                _f(ctrl: _whatsappCtrl, label: 'WhatsApp No', icon: Icons.message_outlined, type: TextInputType.phone),
              ], isMobile),
              const SizedBox(height: 16),
              _responsiveGrid([
                _f(ctrl: _emailCtrl, label: 'Email Address', icon: Icons.email_outlined, type: TextInputType.emailAddress),
                _f(ctrl: _cnicCtrl, label: 'CNIC / ID', icon: Icons.credit_card_outlined, type: TextInputType.number),
              ], isMobile),

              const SizedBox(height: 32),
              // --- Section: Location Details ---
              _sectionHeader('Address Details', Icons.location_on_outlined),
              const SizedBox(height: 16),
              _f(ctrl: _addrCtrl, label: 'Full Address', icon: Icons.location_on_outlined),
              const SizedBox(height: 16),
              _f(ctrl: _cityCtrl, label: 'City', icon: Icons.location_city_outlined),
              
              const SizedBox(height: 40),
              _formActions(),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _formHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_teal, _tealDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: _teal.withOpacity(0.31), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Register New Patient', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
                Text('Enter details to create a new medical record', style: TextStyle(fontSize: 11, color: _textLight)),
              ],
            ),
          ]),
          // 
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: _teal),
      const SizedBox(width: 8),
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _teal, letterSpacing: 1)),
      const SizedBox(width: 8),
      const Expanded(child: Divider(thickness: 1, color: _tealLight)),
    ]);
  }

  Widget _responsiveGrid(List<Widget> children, bool isMobile) {
    if (isMobile) {
      return Column(children: children.asMap().entries.map((e) => Padding(
        padding: EdgeInsets.only(bottom: e.key == children.length - 1 ? 0 : 16),
        child: e.value,
      )).toList());
    }
    return Row(children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList());
  }

  Widget _formActions() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      TextButton(
        onPressed: _clearPatient,
        style: TextButton.styleFrom(
          foregroundColor: _textMid,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      const SizedBox(width: 12),
      Consumer<MrProvider>(builder: (_, prov, __) {
        return ElevatedButton(
          onPressed: prov.isCreating ? null : _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            shadowColor: _teal.withOpacity(0.5),
          ),
          child: prov.isCreating 
            ? const Center(child: CustomLoader(size: 20, color: Colors.white))
            : const Text('Create Patient Record', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      }),
    ]);
  }

  // ── Patient info card & Grid ───────────────────────────────────────────────
  Widget _patientInfoCard() {
    final p = _patient!;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHeader(p),
        const Divider(height: 1, color: _border),
        Padding(padding: const EdgeInsets.all(16), child: _detailGrid(p)),
      ]),
    );
  }

  Widget _cardHeader(PatientModel p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.firstName} ${p.lastName}'.trim().isEmpty ? 'Unknown Patient' : '${p.firstName} ${p.lastName}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textDark)),
            const SizedBox(height: 6),
            Wrap(spacing: 5, runSpacing: 4, children: [
              _chip('MR# ${p.mrNumber}', _teal, _tealLight, icon: Icons.badge_outlined),
              if (p.gender.isNotEmpty) _chip(p.gender, _textMid, const Color(0xFFF0F4F8)),
              if (p.bloodGroup.isNotEmpty) _chip(p.bloodGroup, const Color(0xFFC53030), const Color(0xFFFFF5F5)),
              if (p.age != null) _chip('${p.age} yrs', _green, const Color(0xFFF0FFF4)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _tealLight, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text('${p.totalVisits}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _teal)),
              const Text('Visits', style: TextStyle(fontSize: 9, color: _teal)),
            ]),
          ),
          if (p.visitsToday > 0) ...[
            const SizedBox(height: 4),
            _chip('${p.visitsToday} today', _green, const Color(0xFFF0FFF4)),
          ],
        ]),
      ]),
    );
  }

  Widget _detailGrid(PatientModel p) {
    final items = [
      {'icon': Icons.phone_outlined, 'label': 'Phone', 'value': p.phoneNumber, 'full': false},
      {'icon': Icons.message_outlined, 'label': 'WhatsApp', 'value': p.whatsappNo, 'full': false},
      {'icon': Icons.credit_card_outlined, 'label': 'CNIC', 'value': p.cnic, 'full': false},
      {'icon': Icons.email_outlined, 'label': 'Email', 'value': p.email, 'full': true},
      {'icon': Icons.people_outline, 'label': 'Guardian', 'value': p.guardianName, 'full': false},
      {'icon': Icons.family_restroom_outlined, 'label': 'Relation', 'value': p.relation, 'full': false},
      {'icon': Icons.cake_outlined, 'label': 'Date of Birth', 'value': p.dateOfBirth, 'full': false},
      {'icon': Icons.work_outline, 'label': 'Profession', 'value': p.profession, 'full': false},
      {'icon': Icons.book_outlined, 'label': 'Education', 'value': p.education, 'full': false},
      {'icon': Icons.location_on_outlined, 'label': 'Address', 'value': p.address, 'full': true},
      {'icon': Icons.location_city_outlined, 'label': 'City', 'value': p.city, 'full': false},
    ];

    final rows = <Widget>[];
    for (var i = 0; i < items.length;) {
      final item = items[i];
      if (item['full'] == true) {
        rows.add(_detailItem(item['icon'] as IconData, item['label'] as String, item['value'] as String?));
        i++;
      } else {
        final next = (i + 1 < items.length && items[i + 1]['full'] != true) ? items[i + 1] : null;
        if (next != null) {
          rows.add(Row(children: [
            Expanded(child: _detailItem(item['icon'] as IconData, item['label'] as String, item['value'] as String?)),
            const SizedBox(width: 12),
            Expanded(child: _detailItem(next['icon'] as IconData, next['label'] as String, next['value'] as String?)),
          ]));
          i += 2;
        } else {
          rows.add(_detailItem(item['icon'] as IconData, item['label'] as String, item['value'] as String?));
          i++;
        }
      }
      if (i < items.length) rows.add(const SizedBox(height: 12));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _detailItem(IconData icon, String label, String? value) {
    final val = (value == null || value.trim().isEmpty) ? null : value.trim();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: _tealLight, borderRadius: BorderRadius.circular(7)), child: Icon(icon, size: 13, color: _teal)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _textLight, fontWeight: FontWeight.w500)),
          const SizedBox(height: 1),
          Text(val ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: val != null ? FontWeight.w600 : FontWeight.normal,
                  color: val != null ? _textDark : const Color(0xFFCBD5E0))),
        ]),
      ),
    ]);
  }

  Widget _chip(String text, Color fg, Color bg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: fg.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 9, color: fg), const SizedBox(width: 3)],
        Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }

  // ── Wide sidebar ───────────────────────────────────────────────────────────
  Widget _wideSidebar() {
    final patient = context.watch<MrProvider>().selectedPatient;
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          decoration: const BoxDecoration(color: Color(0xFFF7FAFC), borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)), border: Border(bottom: BorderSide(color: _border))),
          child: TabBar(controller: _tabController, labelColor: _teal, unselectedLabelColor: _textLight, indicatorColor: _teal, indicatorWeight: 2, labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            tabs: [
              const Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search, size: 13), SizedBox(width: 4), Text('Search')])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history_rounded, size: 13), const SizedBox(width: 4), const Text('History'),
                if (patient != null && patient.totalVisits > 0) ...[
                  const SizedBox(width: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFE9D8FD), borderRadius: BorderRadius.circular(10)),
                    child: Text('${patient.totalVisits}', style: const TextStyle(fontSize: 9, color: _purple, fontWeight: FontWeight.bold))),
                ]
              ])),
            ],
          ),
        ),
        SizedBox(height: 550, child: TabBarView(controller: _tabController, children: [
          _wideSearchTab(),
          SingleChildScrollView(child: _HistoryContent(patient: patient)),
        ])),
      ]),
    );
  }

  Widget _wideSearchTab() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(controller: _searchCtrl, onChanged: (q) { setState(() {}); _onSearchChanged(q); }, style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(hintText: 'Search by name or phone...', hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD)), prefixIcon: const Icon(Icons.search, size: 15, color: Color(0xFFBDBDBD)),
          suffixIcon: _searchCtrl.text.isNotEmpty ? GestureDetector(onTap: () { _searchCtrl.clear(); setState(() { _searchResults = []; _isSearching = false; }); }, child: const Icon(Icons.close, size: 15, color: Color(0xFFBDBDBD))) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _teal, width: 1.5)), filled: true, fillColor: const Color(0xFFF7FAFC),
        ),
      )),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Align(alignment: Alignment.centerLeft, child: Text('Min 2 characters', style: TextStyle(fontSize: 9, color: Color(0xFFBDBDBD))))),
      Expanded(child: _SearchResultsList(isSearching: _isSearching, results: _searchResults, query: _searchCtrl.text, onSelect: (p) { _searchCtrl.clear(); setState(() => _searchResults = []); _selectFromSearch(p); })),
    ]);
  }

  // ══════════════════════════════════════════ MOBILE LAYOUT ══════════════════
  Widget _buildMobile() {
    return Column(children: [
      _mobileHeader(),
      Expanded(
        child: (_isLoading || context.watch<MrProvider>().isLoading)
            ? const Center(
                child: CustomLoader(
                  size: 50,
                  color: _teal,
                ),
              )
            : (_patient == null && !_isNewPatient)
            ? _emptyState()
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
          child: Column(children: [
            if (_patient != null) ...[
              _mobilePatientCard(),
              const SizedBox(height: 14),
              _mobileHistorySection(),
            ] else if (_isNewPatient) ...[
              _registrationForm(),
            ],
            const SizedBox(height: 20),
          ]),
        ),
      ),
    ]);
  }

  Widget _mobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(color: _card, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('MR Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark))),
          _iconBtn(icon: Icons.search_rounded, onTap: _openSearchSheet),
          const SizedBox(width: 8),
          _iconBtn(icon: _isNewPatient || _patient != null ? Icons.close_rounded : Icons.add_rounded, 
             onTap: () {
               if (_isNewPatient || _patient != null) {
                  _clearPatient();
               } else {
                  setState(() => _isNewPatient = true);
                  final prov = context.read<MrProvider>();
                  if (prov.nextMrNumber != null) _mrCtrl.text = prov.nextMrNumber!;
               }
             }
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          height: 44,
          decoration: BoxDecoration(color: (_patient != null || _isNewPatient) ? _tealLight : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: (_patient != null || _isNewPatient) ? _teal : _teal.withOpacity(0.35), width: (_patient != null || _isNewPatient) ? 1.5 : 1)),
          child: Row(children: [
            const SizedBox(width: 10),
            Icon(Icons.badge_outlined, color: (_patient != null || _isNewPatient) ? _teal : const Color(0xFFCBD5E0), size: 16),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _mrCtrl, focusNode: _mrFocusNode, keyboardType: TextInputType.number, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: (_patient != null || _isNewPatient) ? _tealDark : _textDark, letterSpacing: 0.5),
              onSubmitted: _lookupMr,
              onChanged: (v) {
                if (_patient != null) {
                   setState(() { _patient = null; _isNewPatient = false; });
                }
              },
              decoration: const InputDecoration(hintText: 'Enter MR Number...', hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 11), border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
            )),
            GestureDetector(onTap: (_patient != null || _isNewPatient) ? _clearPatient : () => _lookupMr(_mrCtrl.text),
              child: Container(width: 44, height: 44, decoration: BoxDecoration(color: (_patient != null || _isNewPatient) ? _teal.withOpacity(0.12) : _teal, borderRadius: const BorderRadius.only(topRight: Radius.circular(9), bottomRight: Radius.circular(9))),
                child: Icon((_patient != null || _isNewPatient) ? (_patient != null ? Icons.check_circle_rounded : Icons.edit_note_rounded) : Icons.search_rounded, color: (_patient != null || _isNewPatient) ? _teal : Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Form Helpers ───────────────────────────────────────────────────────────
  Widget _fixedMrField(String? autoMr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('MR Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMid)),
              if (autoMr != null && _mrCtrl.text == autoMr)
                const Text('Auto-generated', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        TextField(
          controller: _mrCtrl,
          focusNode: _mrFocusNode,
          style: const TextStyle(fontSize: 16, color: _tealDark, fontWeight: FontWeight.bold, letterSpacing: 1),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.badge_outlined, color: _teal, size: 20),
            suffixIcon: autoMr == null && _mrCtrl.text.isEmpty
              ? const Padding(padding: EdgeInsets.all(12), child: CustomLoader(size: 18, color: _teal))
              : const Icon(Icons.edit_note_rounded, color: _teal, size: 18),
            hintText: 'Enter MR Number manually...',
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border.withOpacity(0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _teal, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _f({required TextEditingController ctrl, required String label, IconData? icon, bool required = false, TextInputType type = TextInputType.text, FocusNode? focusNode}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: RichText(text: TextSpan(text: label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMid), children: required ? [const TextSpan(text: ' *', style: TextStyle(color: _red))] : [])),
      ),
      TextFormField(
        controller: ctrl,
        focusNode: focusNode,
        keyboardType: type,
        style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.w500),
        validator: required ? (v) => v?.isEmpty ?? true ? 'Required' : null : null,
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: _teal.withOpacity(0.5), size: 18) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintText: 'Enter $label',
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF8FAFB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _teal, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _red, width: 1)),
        ),
      ),
    ]);
  }

  Widget _dd({required String label, required String? value, required List<String> items, String hint = '', bool required = false, required ValueChanged<String?> onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: RichText(text: TextSpan(text: label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMid), children: required ? [const TextSpan(text: ' *', style: TextStyle(color: _red))] : [])),
      ),
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        hint: Text(hint, style: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 13)),
        style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          filled: true,
          fillColor: const Color(0xFFF8FAFB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _teal, width: 1.5)),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    ]);
  }

  Widget _dateWidget() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 6), child: Text('Date of Birth', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMid))),
      GestureDetector(
        onTap: () async {
          final p = await showDatePicker(
            context: context, 
            initialDate: _dob ?? DateTime(2000), 
            firstDate: DateTime(1900), 
            lastDate: DateTime.now(), 
            builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _teal)), child: child!)
          );
          if (p != null) {
            setState(() { 
              _dob = p; 
              // Precise calculation matching React
              final today = DateTime.now();
              int age = today.year - p.year;
              if (today.month < p.month || (today.month == p.month && today.day < p.day)) {
                age--;
              }
              _ageCtrl.text = age >= 0 ? age.toString() : '0';
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: _teal.withOpacity(0.5)),
            const SizedBox(width: 12),
            Expanded(child: Text(_dob != null ? "${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}" : 'dd/mm/yyyy', style: TextStyle(fontSize: 14, color: _dob != null ? _textDark : Colors.grey.withOpacity(0.4), fontWeight: _dob != null ? FontWeight.w500 : FontWeight.normal))),
          ]),
        ),
      ),
    ]);
  }

  // ── Sheets & Empty states ──────────────────────────────────────────────────
  void _openSearchSheet() => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _SearchSheet(searchCtrl: _searchCtrl, results: _searchResults, isSearching: _isSearching, onChanged: _onSearchChanged, onSelect: _selectFromSearch, onClear: () { _searchCtrl.clear(); setState(() { _searchResults = []; _isSearching = false; }); }));

  Widget _emptyState() => Center(child: Padding(padding: const EdgeInsets.only(top: 80), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.badge_outlined, size: 64, color: _border), const SizedBox(height: 16),
    const Text('Search or Register Patient', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
    const SizedBox(height: 8), const Text('Enter an MR number above to look up a patient\nor click "+" to register a new one.', textAlign: TextAlign.center, style: TextStyle(color: _textLight)),
  ])));

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) => GestureDetector(onTap: onTap, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF4F7FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)), child: Icon(icon, size: 18, color: _textMid)));

  Widget _mobileHistorySection() {
    final patient = context.watch<MrProvider>().selectedPatient;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Visit History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark)),
      const SizedBox(height: 10),
      _HistoryContent(patient: patient),
    ]);
  }

  Widget _mobilePatientCard() {
    final p = _patient!;
    return Container( decoration: BoxDecoration( color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)), ], ), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ _cardHeader(p), const Divider(height: 1, color: _border), Padding( padding: const EdgeInsets.all(14), child: _detailGrid(p), ), ]), );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH RESULTS LIST
// ─────────────────────────────────────────────────────────────────────────────
class _SearchResultsList extends StatelessWidget {
  final bool isSearching;
  final List<PatientModel> results;
  final String query;
  final Function(PatientModel) onSelect;

  const _SearchResultsList({required this.isSearching, required this.results, required this.query, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const Center(
        child: CustomLoader(
          size: 50,
          color: _teal,
        ),
      );
    }
    if (query.length < 2) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_rounded, size: 40, color: _border), SizedBox(height: 8), Text('Type 2+ characters', style: TextStyle(fontSize: 12, color: _textLight))]));
    if (results.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off_rounded, size: 40, color: _border), SizedBox(height: 8), Text('No patients found', style: TextStyle(fontSize: 12, color: _textLight))]));

    return ListView.separated(shrinkWrap: true, itemCount: results.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
      final p = results[i];
      final isPending = p.syncStatus == 'pending';
      return InkWell(onTap: () => onSelect(p), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: _tealLight, child: Text(p.firstName.isNotEmpty ? p.firstName[0] : '?', style: const TextStyle(color: _teal, fontWeight: FontWeight.bold, fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(child: Text('${p.firstName} ${p.lastName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark))),
              if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 10, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text('Pending', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                    ],
                  ),
                ),
            ],
          ),
          Text('MR# ${p.mrNumber} · ${p.phoneNumber}', style: const TextStyle(fontSize: 11, color: _textLight)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _border),
      ])));
    });
  }
}

class _SearchSheet extends StatefulWidget {
  final TextEditingController searchCtrl;
  final List<PatientModel> results;
  final bool isSearching;
  final Function(String) onChanged;
  final Function(PatientModel) onSelect;
  final VoidCallback onClear;
  const _SearchSheet({required this.searchCtrl, required this.results, required this.isSearching, required this.onChanged, required this.onSelect, required this.onClear});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(height: MediaQuery.of(context).size.height * 0.85, decoration: const BoxDecoration(color: _card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          const Text('Search Patients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)), const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: widget.searchCtrl, autofocus: true, onChanged: widget.onChanged, decoration: InputDecoration(hintText: 'Search by name or phone...', prefixIcon: const Icon(Icons.search), suffixIcon: widget.searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { widget.onClear(); setState(() {}); }) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
        Expanded(child: _SearchResultsList(isSearching: widget.isSearching, results: widget.results, query: widget.searchCtrl.text, onSelect: widget.onSelect)),
      ]),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  final PatientModel? patient;
  const _HistoryContent({this.patient});

  @override
  Widget build(BuildContext context) {
    if (patient == null) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No patient selected', style: TextStyle(color: _textLight))));
    final visits = patient!.visitHistory;
    if (visits == null || visits.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No visit history found', style: TextStyle(color: _textLight))));

    return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: visits.length, itemBuilder: (_, i) {
      final v = visits[i];
      final isLast = i == visits.length - 1;
      return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 18, child: Column(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle)),
          if (!isLast) Expanded(child: Container(width: 1.5, color: _border)),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Container(margin: EdgeInsets.only(bottom: isLast ? 0 : 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF7FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(v.opdService ?? 'Consultation', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
              const Spacer(),
              Text(v.date ?? '', style: const TextStyle(fontSize: 10, color: _textLight)),
            ]),
            if (v.serviceDetail != null && v.serviceDetail!.isNotEmpty) ...[const SizedBox(height: 4), Text(v.serviceDetail!, style: const TextStyle(fontSize: 10, color: _textMid))],
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: _chip('PKR ${v.totalAmount ?? v.paid ?? 0}', _green, const Color(0xFFF0FFF4))),
          ]),
        )),
      ]));
    });
  }
  
  Widget _chip(String text, Color fg, Color bg) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)), child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)));
}