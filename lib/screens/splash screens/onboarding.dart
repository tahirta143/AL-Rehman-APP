import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../auth/login.dart';

// ── App Primary Color ─────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF00B5AD);

const Color _kBg = Color(0xFFF4F8F8);
const Color _kNavy = Color(0xFF1A2E2D);
const Color _kSub = Color(0xFF6B8A89);

// ── Data Model ────────────────────────────────────────────────────────────────
class OnboardingData {
  final String title;
  final String subtitle;
  final String imagePath;

  const OnboardingData({
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}

const List<OnboardingData> onboardingPages = [
  OnboardingData(
    title: 'Waseela\nDiabesity',
    subtitle: 'Providing world-class diabesity care with advanced technology and expert doctors.',
    imagePath: 'assets/images/doctor2.png',
  ),
  OnboardingData(
    title: 'Advanced Diabetes\nDiagnostics',
    subtitle: 'From blood glucose monitoring to specialized care, we offer comprehensive health solutions.',
    imagePath: 'assets/images/onboard2.png',
  ),
  OnboardingData(
    title: 'Your Health,\nOur Priority',
    subtitle: 'Schedule your check-up instantly and experience personalised patient care.',
    imagePath: 'assets/images/dotor.png',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const SignInScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Top teal header with image ────────────────────────────────
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                // Teal background with curved bottom
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),

                // Subtle circle decoration top-right
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  right: 30,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),

                // Content: logo + image
                SafeArea(
                  child: Column(
                    children: [
                      // Hospital badge
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.asset("assets/images/eye4.png")
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Al-Rehman Eye Hospital',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const Spacer(),
                            // Skip
                            GestureDetector(
                              onTap: _navigateToLogin,
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Large image
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          itemCount: onboardingPages.length,
                          itemBuilder: (_, index) {
                            return FadeInUp(
                              duration: const Duration(milliseconds: 600),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                                child: Image.asset(
                                  onboardingPages[index].imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.remove_red_eye_rounded,
                                    size: 120,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom white content card ─────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              color: _kBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page indicators
                  Row(
                    children: List.generate(
                      onboardingPages.length,
                      (i) => _Dot(isActive: i == _currentPage),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      onboardingPages[_currentPage].title,
                      key: ValueKey<int>(_currentPage),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      onboardingPages[_currentPage].subtitle,
                      key: ValueKey<String>(onboardingPages[_currentPage].subtitle),
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kSub,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _currentPage == onboardingPages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot Indicator ─────────────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final bool isActive;

  const _Dot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(right: 6),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? _kPrimary : const Color(0xFFBFD8D6),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
