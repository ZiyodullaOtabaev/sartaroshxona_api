import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sartaroshxona/screens/main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.schedule_rounded,
      title: "Kutmang — bo'sh vaqtni ko'ring",
      description: "Sartaroshning real-time band/bo'sh slotlari. Telegram'da \"bo'shmisiz?\" deb kutish o'rniga — hoziroq ko'ring.",
      color: const Color(0xFF2ECC71),
    ),
    _OnboardingData(
      icon: Icons.location_on_rounded,
      title: "Eng yaqinini toping",
      description: "GPS bo'yicha 2 km radiusda barcha sartaroshlar. Xaritada ko'ring, masofani solishtiring.",
      color: const Color(0xFF3498DB),
    ),
    _OnboardingData(
      icon: Icons.star_rounded,
      title: "Ishonchli tanlang",
      description: "Haqiqiy mijozlar baholari va sharhlar. Reyting, tajriba — Telegram'da buni bilolmaysiz.",
      color: const Color(0xFFF39C12),
    ),
    _OnboardingData(
      icon: Icons.payment_rounded,
      title: "Xavfsiz onlayn to'lov",
      description: "Payme, Click yoki karta orqali oldindan to'lang. Naqd pul olib yurish shart emas.",
      color: const Color(0xFF9B59B6),
    ),
    _OnboardingData(
      icon: Icons.card_giftcard_rounded,
      title: "Sodiqlik mukofotlari",
      description: "10 ta navbat = 1 bepul! Do'stingizni taklif qiling — ikkalangizga 10,000 so'm chegirma.",
      color: const Color(0xFFE74C3C),
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    // Fresha uslubi: onboarding'dan keyin to'g'ridan-to'g'ri mehmon sifatida ilovaga kiramiz
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen(userName: "Mehmon", userId: 0)),
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
      backgroundColor: const Color(0xFF0F1419),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    "O'tkazib yuborish",
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (_, index) => _buildPage(_pages[index]),
              ),
            ),

            // Indicators + Button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? _pages[_currentPage].color : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1 ? "Keyingi" : "Boshlash",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glow
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.color.withOpacity(0.15),
              boxShadow: [
                BoxShadow(color: data.color.withOpacity(0.3), blurRadius: 40, spreadRadius: 5),
              ],
            ),
            child: Icon(data.icon, size: 56, color: data.color),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.3),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
