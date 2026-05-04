import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hims_app/core/providers/permission_provider.dart';
import 'package:hims_app/core/services/auth_storage_service.dart';
import '../../providers/mobile_auth_provider.dart';
import 'package:animate_do/animate_do.dart';
import '../main_shell.dart';
import '../patient/patient_dashboard.dart';
import '../doctor/mobile_doctor_dashboard.dart';
import 'onboarding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _circleAnimation;

  final String _companyName = 'WASEELA DIABESITY';
  final String _logoAsset = 'assets/images/Waseelalogo.png';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _circleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.7, curve: Curves.elasticOut)));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));
    _controller.forward();

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Wait for splash animation to be visible
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    try {
      final storage = AuthStorageService();
      final token = await storage.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      final role = await storage.getRole().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        final mobileProvider = context.read<MobileAuthProvider>();

        if (role == 'patient') {
          // Timeout auto-login — don't hang if server is unreachable
          await mobileProvider.tryAutoLogin().timeout(
            const Duration(seconds: 6),
            onTimeout: () {},
          );
          if (!mounted) return;
          _goTo(const PatientDashboard());

        } else if (role == 'doctor') {
          await mobileProvider.tryAutoLogin().timeout(
            const Duration(seconds: 6),
            onTimeout: () {},
          );
          if (!mounted) return;
          _goTo(const MobileDoctorDashboard());

        } else {
          final permProvider = context.read<PermissionProvider>();

          // Load cached permissions first (fast, local)
          await permProvider.loadFromStorage().timeout(
            const Duration(seconds: 3),
            onTimeout: () {},
          );

          // Sync from server with timeout — if it fails, cached perms are used
          try {
            await permProvider.syncFromServer().timeout(
              const Duration(seconds: 6),
            );
          } catch (_) {
            // Server unreachable — continue with cached permissions
          }

          if (!mounted) return;
          _goTo(const MainShell());
        }
      } else {
        _goTo(const OnboardingScreen());
      }
    } catch (e) {
      debugPrint('Splash Auth Error: $e');
      if (!mounted) return;
      _goTo(const OnboardingScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00B5AD),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo: Clean Elastic Pop ──
                FadeInDown(
                  duration: const Duration(milliseconds: 1200),
                  from: 50,
                  child: ZoomIn(
                    duration: const Duration(milliseconds: 1000),
                    child: Image.asset(
                      _logoAsset,
                      height: 160,
                      width: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.emergency_outlined,
                              size: 100, color: Colors.white),
                    ),
                  ),
                ),
                // const SizedBox(height: 30),
                //
                // // ── Company Name: Character-by-Character Staggered Reveal ──
                Wrap(
                  alignment: WrapAlignment.center,
                  children: _companyName
                      .split('')
                      .asMap()
                      .entries
                      .map((entry) {
                    return FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: Duration(milliseconds: 600 + (entry.key * 50)),
                      from: 20,
                      child: Text(
                        entry.value == ' ' ? '\u00A0' : entry.value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: Colors.black12,
                              offset: Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // const SizedBox(height: 20),
                //
                // // ── Tagline: Smooth Sequential Entrance ──
                // FadeIn(
                //   duration: const Duration(seconds: 1),
                //   delay: const Duration(milliseconds: 1800),
                //   child: Text(
                //     "Vision Beyond Borders",
                //     style: TextStyle(
                //       color: Colors.white.withOpacity(0.8),
                //       fontSize: 13,
                //       fontWeight: FontWeight.w500,
                //       letterSpacing: 4.0,
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}