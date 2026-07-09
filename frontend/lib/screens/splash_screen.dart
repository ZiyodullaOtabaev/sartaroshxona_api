import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sartaroshxona/screens/main_screen.dart';
import 'package:sartaroshxona/screens/barber_dashboard.dart';
import 'package:sartaroshxona/screens/owner_dashboard_screen.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/services/push_notification_service.dart';
import 'package:sartaroshxona/utils/app_constants.dart';
import 'package:sartaroshxona/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();

    // Server'ni uyg'otish (cold start bo'lsa animatsiya vaqtida uyg'onadi)
    final warmUpFuture = ApiService().warmUp();

    await Future.delayed(const Duration(milliseconds: 1800));

    // Server uyg'onganini kutish (agar hali uyg'onmagan bo'lsa)
    await warmUpFuture;

    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
      if (!onboardingDone) {
        _navigateTo(const OnboardingScreen());
        return;
      }

      final token = prefs.getString(AppConstants.tokenKey);
      final userId = prefs.getInt(AppConstants.userIdKey);
      final role = prefs.getString(AppConstants.userRoleKey);
      final name = prefs.getString(AppConstants.userNameKey) ?? 'Foydalanuvchi';

      if (token != null && token.isNotEmpty && userId != null) {
        // Auto-login — push tokenni ham register qilish
        PushNotificationService().registerToken(userId);

        if (role == 'barber') {
          _navigateTo(BarberDashboard(barberName: name, barberId: userId, userId: userId));
        } else if (role == 'owner') {
          _navigateTo(OwnerDashboardScreen(ownerName: name, userId: userId));
        } else {
          _navigateTo(MainScreen(userName: name, userId: userId));
        }
        return;
      }
    } catch (e) {
      debugPrint('Auto-login xatolik: $e');
    }

    // Fresha uslubi: login bo'lmasa ham ilovani MEHMON sifatida ko'rsatamiz.
    // Ro'yxatdan o'tish faqat biror amal qilinganda so'raladi.
    _navigateTo(const MainScreen(userName: "Mehmon", userId: 0));
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => page,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // Animated background circles
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 300 * _pulseAnim.value,
                height: 300 * _pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2ECC71).withOpacity(0.03),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 250 * _pulseAnim.value,
                height: 250 * _pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4ECDC4).withOpacity(0.03),
                ),
              ),
            ),
          ),

          // Grid lines
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with pulse
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: child,
                      ),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2ECC71), Color(0xFF4ECDC4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2ECC71).withOpacity(0.4),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.content_cut_rounded, size: 56, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Text
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        const Text(
                          "Sartaroshxona",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Eng yaxshi barberlar siz uchun",
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textOpacity,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: const Color(0xFF2ECC71).withOpacity(0.6),
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),

          // Version
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text("v1.0.0", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2ECC71).withOpacity(0.03)
      ..strokeWidth = 0.5;

    const step = 50.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
