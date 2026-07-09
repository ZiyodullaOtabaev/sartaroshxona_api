import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/login_screen.dart';
import 'package:sartaroshxona/screens/role_selection_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AUTH GUARD — Fresha uslubidagi "browse-first" mantiq
///
/// Foydalanuvchi ilovani ro'yxatdan o'tmasdan ko'radi. Faqat biror amal
/// (band qilish, sevimli, to'lov) qilmoqchi bo'lganda ro'yxatdan o'tish so'raladi.
/// ═══════════════════════════════════════════════════════════════════════════
class AuthGuard {
  AuthGuard._();

  /// userId <= 0 => mehmon (guest)
  static bool isGuest(int userId) => userId <= 0;

  /// Amalni bajarishdan oldin chaqiriladi.
  /// Login bo'lsa true qaytaradi. Aks holda chiroyli oyna ko'rsatadi va false qaytaradi.
  static Future<bool> require(
    BuildContext context, {
    String title = "Davom etish uchun kiring",
    String message = "Bu amalni bajarish uchun hisobingizga kiring yoki ro'yxatdan o'ting.",
    IconData icon = Icons.lock_outline_rounded,
  }) async {
    final loggedIn = await ApiService().isLoggedIn();
    if (loggedIn) return true;
    if (!context.mounted) return false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthPromptSheet(title: title, message: message, icon: icon),
    );
    return false;
  }
}

/// Auth so'rovi oynasi (bottom sheet)
class _AuthPromptSheet extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _AuthPromptSheet({required this.title, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 28),
          // Icon
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
              boxShadow: [BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 28),
          // Register button (asosiy)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
              },
              child: const Text("Ro'yxatdan o'tish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          // Login button (ikkilamchi)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: const Text("Hisobim bor — Kirish", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Hozircha ko'rib turaman", style: TextStyle(color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// Mehmon uchun to'liq ekran o'rnini bosuvchi placeholder
/// (Navbatlar, Profil kabi login talab qiladigan tablar uchun)
class GuestPrompt extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const GuestPrompt({
    super.key,
    this.icon = Icons.account_circle_outlined,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withOpacity(0.1),
                  ),
                  child: Icon(icon, size: 48, color: colors.primary),
                ),
                const SizedBox(height: 24),
                Text(title, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen())),
                    child: const Text("Ro'yxatdan o'tish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text("Hisobim bor — Kirish", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
