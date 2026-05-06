// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/mobile_auth_provider.dart';
// import '../../custum widgets/custom_loader.dart';
// import '../dashboard/dashboard.dart';
// import '../patient/patient_dashboard.dart';
// import '../doctor/mobile_doctor_dashboard.dart';
// import 'mobile_sign_up_screen.dart';
//
// class MobileLoginScreen extends StatefulWidget {
//   const MobileLoginScreen({super.key});
//
//   @override
//   State<MobileLoginScreen> createState() => _MobileLoginScreenState();
// }
//
// class _MobileLoginScreenState extends State<MobileLoginScreen> {
//   final _phoneController = TextEditingController();
//   final _passwordOrOtpController = TextEditingController();
//   bool _obscurePassword = true;
//
//   @override
//   void dispose() {
//     _phoneController.dispose();
//     _passwordOrOtpController.dispose();
//     super.dispose();
//   }
//
//   void _showSnackBar(String message, {bool isError = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isError ? Colors.red : const Color(0xFF00B5AD),
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   Future<void> _handleLogin() async {
//     final authProvider = context.read<MobileAuthProvider>();
//     final phone = _phoneController.text.trim();
//     final input = _passwordOrOtpController.text.trim();
//
//     if (phone.isEmpty) {
//       _showSnackBar('Please enter your phone number', isError: true);
//       return;
//     }
//
//     if (authProvider.otpSent) {
//       if (input.isEmpty) {
//         _showSnackBar('Please enter the OTP', isError: true);
//         return;
//       }
//       final result = await authProvider.verifyOTP(phone, input);
//       if (result['success'] == true) {
//         _navigateToDashboard();
//       } else {
//         _showSnackBar(result['message'] ?? 'Verification failed', isError: true);
//       }
//       return;
//     }
//
//     if (input.isNotEmpty) {
//       // Doctor Login
//       final result = await authProvider.loginDoctor(phone, input);
//       if (result['success'] == true) {
//         _navigateToDashboard();
//       } else {
//         _showSnackBar(result['message'] ?? 'Login failed', isError: true);
//       }
//     } else {
//       // Patient OTP Send
//       final result = await authProvider.sendOTP(phone);
//       if (result['success'] == true) {
//         _showSnackBar('OTP sent successfully to WhatsApp!');
//       } else {
//         _showSnackBar(result['message'] ?? 'Failed to send OTP', isError: true);
//       }
//     }
//   }
//
//   void _navigateToDashboard() {
//     final user = context.read<MobileAuthProvider>().currentUser;
//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (_) {
//         if (user?.role == 'patient') return const PatientDashboard();
//         if (user?.role == 'doctor') return const MobileDoctorDashboard();
//         return const HomeScreen();
//       }),
//       (_) => false,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final mq = MediaQuery.of(context);
//     final authProvider = context.watch<MobileAuthProvider>();
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF00B5AD),
//         elevation: 0,
//         title: const Text('Mobile Login', style: TextStyle(color: Colors.white)),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const SizedBox(height: 40),
//             const Text(
//               'Welcome back',
//               style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00B5AD)),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 8),
//             const Text(
//               'Login as Patient (OTP) or Doctor (Password)',
//               style: TextStyle(color: Colors.grey),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 48),
//
//             // Phone Field
//             TextField(
//               controller: _phoneController,
//               keyboardType: TextInputType.phone,
//               decoration: InputDecoration(
//                 labelText: 'Phone Number',
//                 prefixIcon: const Icon(Icons.phone_outlined),
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//               ),
//             ),
//             const SizedBox(height: 20),
//
//             // Password / OTP Field
//             TextField(
//               controller: _passwordOrOtpController,
//               obscureText: authProvider.otpSent ? false : _obscurePassword,
//               decoration: InputDecoration(
//                 labelText: authProvider.otpSent ? 'Enter OTP' : 'Password (for Doctors)',
//                 helperText: authProvider.otpSent ? 'Sent to your WhatsApp' : 'Leave blank for Patient OTP login',
//                 prefixIcon: Icon(authProvider.otpSent ? Icons.sms_outlined : Icons.lock_outline),
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                 suffixIcon: authProvider.otpSent ? null : IconButton(
//                   icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
//                   onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 32),
//
//             ElevatedButton(
//               onPressed: authProvider.isLoading ? null : _handleLogin,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF00B5AD),
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               ),
//               child: authProvider.isLoading
//                 ? const CustomLoader(size: 20, color: Colors.white)
//                 : Text(authProvider.otpSent ? 'Verify OTP' : (authProvider.isLoading ? 'Processing...' : 'Login / Send OTP')),
//             ),
//
//             const SizedBox(height: 24),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Text("New patient? "),
//                 GestureDetector(
//                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileSignUpScreen())),
//                   child: const Text('Sign up here', style: TextStyle(color: Color(0xFF00B5AD), fontWeight: FontWeight.bold)),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/mobile_auth_provider.dart';
import '../../custum widgets/custom_loader.dart';
import '../doctor/mobile_doctor_dashboard.dart';
import '../main_shell.dart';

import '../patient/patient_dashboard.dart';

class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({super.key});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordOrOtpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordOrOtpController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor:
        isError ? Colors.red.shade600 : const Color(0xFF00B5AD),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final authProvider = context.read<MobileAuthProvider>();
    final mrNumber = _phoneController.text.trim(); // Reusing controller for MR Number
    final phone = _passwordOrOtpController.text.trim(); // Reusing for Phone Number

    if (mrNumber.isEmpty) {
      _showSnackBar('Please enter your MR number', isError: true);
      return;
    }

    if (phone.isEmpty) {
      _showSnackBar('Please enter your phone number', isError: true);
      return;
    }

    final result = await authProvider.loginPatient(mrNumber, phone);
    if (result['success'] == true) {
      _navigateToDashboard();
    } else {
      _showSnackBar(result['message'] ?? 'Login failed', isError: true);
    }
  }

  void _navigateToDashboard() {
    final user = context.read<MobileAuthProvider>().currentUser;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) {
        if (user?.role == 'patient') return const PatientDashboard();
        if (user?.role == 'doctor') return const MobileDoctorDashboard();
        return const MainShell();
      }),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;
    final hPad = screenW * 0.07;
    final headerH = screenH * 0.30;
    final logoSize = screenW * 0.18;
    final logoIconSize = screenW * 0.10;
    final titleFontSize = screenW * 0.062;
    final inputFontSize = screenW * 0.038;
    final btnFontSize = screenW * 0.042;

    final authProvider = context.watch<MobileAuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF00B5AD),
      body: Column(
        children: [
          // ── Teal Header ──────────────────────────────────────────────────
          SizedBox(
            height: headerH,
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Logo + app name centered
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.20),
                          ),
                          child: Center(
                            child: CustomPaint(
                              size: Size(logoIconSize, logoIconSize),
                              painter: _BandagePainter(),
                            ),
                          ),
                        ),
                        SizedBox(height: screenH * 0.012),
                        Text(
                          'HIMS',
                          style: TextStyle(
                            fontSize: screenW * 0.055,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── White Body ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: hPad, vertical: screenH * 0.035),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00B5AD),
                      ),
                    ),
                    SizedBox(height: screenH * 0.008),
                    Text(
                      'Patient Portal Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: inputFontSize * 0.95,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    SizedBox(height: screenH * 0.025),

                    // MR Number Field
                    _InputField(
                      controller: _phoneController,
                      hint: 'MR Number',
                      prefixIcon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.text,
                      fontSize: inputFontSize,
                      enabled: !authProvider.isLoading,
                    ),
                    SizedBox(height: screenH * 0.016),

                    // Phone Number Field
                    _InputField(
                      controller: _passwordOrOtpController,
                      hint: '3XXXXXXXXX',
                      prefixIcon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      fontSize: inputFontSize,
                      enabled: !authProvider.isLoading,
                      prefixText: '+92 ',
                    ),
                    SizedBox(height: screenH * 0.028),

                    // Sign In Button
                    SizedBox(
                      height: screenH * 0.062,
                      child: ElevatedButton(
                        onPressed:
                        authProvider.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B5AD),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          const Color(0xFF00B5AD).withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: authProvider.isLoading
                            ? const CustomLoader(size: 22, color: Colors.white)
                            : Text(
                          'Sign In Securely',
                          style: TextStyle(
                            fontSize: btnFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenH * 0.04),

                    // Security Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'SSL Secure Connection',
                          style: TextStyle(
                              fontSize: inputFontSize * 0.85,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: screenH * 0.02),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Input Field ───────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final double fontSize;
  final Widget? suffixIcon;
  final bool enabled;
  final String? prefixText;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.fontSize,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.enabled = true,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        TextStyle(color: Colors.grey.shade400, fontSize: fontSize * 0.95),
        prefixIcon: Icon(prefixIcon,
            color: Colors.grey.shade400, size: fontSize * 1.3),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        prefix: prefixText != null
            ? Text(prefixText!,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00B5AD)))
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled
            ? const Color(0xFFF5F5F5)
            : const Color(0xFFEEEEEE),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFF00B5AD), width: 1.5),
        ),
      ),
    );
  }
}

// ── Bandage Icon Painter (same as SignInScreen) ────────────────────────────────
class _BandagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = const Color(0xFF1ABC9C)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(45 * 3.14159265 / 180);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero,
            width: size.width * 0.32,
            height: size.height * 0.82),
        Radius.circular(size.width * 0.16),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero,
            width: size.width * 0.82,
            height: size.height * 0.32),
        Radius.circular(size.height * 0.16),
      ),
      paint,
    );
    canvas.restore();

    final r = size.width * 0.04;
    final o = size.width * 0.22;
    for (final pt in [
      Offset(cx - o, cy - o * 0.5),
      Offset(cx - o * 0.5, cy - o),
      Offset(cx + o, cy - o * 0.5),
      Offset(cx + o * 0.5, cy - o),
      Offset(cx - o, cy + o * 0.5),
      Offset(cx - o * 0.5, cy + o),
      Offset(cx + o, cy + o * 0.5),
      Offset(cx + o * 0.5, cy + o),
    ]) {
      canvas.drawCircle(pt, r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}