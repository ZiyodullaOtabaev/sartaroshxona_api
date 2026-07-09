import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/screens/login_screen.dart';
import 'package:sartaroshxona/screens/favorites_screen.dart';
import 'package:sartaroshxona/screens/notifications_screen.dart';
import 'package:sartaroshxona/screens/payment_history_screen.dart';
import 'package:sartaroshxona/screens/change_password_screen.dart';
import 'package:sartaroshxona/screens/admin_verify_screen.dart';
import 'package:sartaroshxona/screens/loyalty_screen.dart';
import 'package:sartaroshxona/screens/referral_screen.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/utils/launcher.dart';
import 'package:sartaroshxona/widgets/glass.dart';

class UserProfileScreen extends StatefulWidget {
  final String userName;
  final int userId;
  const UserProfileScreen({super.key, required this.userName, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  File? _pickedImage;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final colors = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text("Profil rasmi", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _imageOption(colors, Icons.camera_alt_rounded, "Kamera", () => _getImage(ImageSource.camera))),
                  const SizedBox(width: 12),
                  Expanded(child: _imageOption(colors, Icons.photo_library_rounded, "Galereya", () => _getImage(ImageSource.gallery))),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageOption(AppColors colors, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  void _logout() {
    final colors = Theme.of(context).extension<AppColors>()!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Chiqish', style: TextStyle(color: colors.textPrimary)),
        content: Text('Tizimdan chiqmoqchimisiz?', style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Bekor', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.error),
            onPressed: () async {
              await ApiService().logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Profil', style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: colors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // ─── PROFIL KARTASI ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: colors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                          ),
                          child: _pickedImage != null
                              ? ClipOval(child: Image.file(_pickedImage!, fit: BoxFit.cover, width: 72, height: 72))
                              : Center(
                            child: Text(
                              widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'M',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]),
                            child: Icon(Icons.camera_alt_rounded, color: colors.primary, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Mijoz', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Text('Oddiy a\'zo', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── ASOSIY HARAKATLAR ───────────────────────────────────
            _section(colors, "Asosiy", [
              _tile(colors, icon: Icons.card_giftcard_rounded, iconColor: const Color(0xFF2ECC71), title: "Loyalty karta", subtitle: "10 navbat = 1 bepul", onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => LoyaltyScreen(userId: widget.userId)));
              }),
              _tile(colors, icon: Icons.people_alt_rounded, iconColor: const Color(0xFF6C5CE7), title: "Do'stlarni taklif qiling", subtitle: "Ikkalangizga chegirma", onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ReferralScreen(userId: widget.userId)));
              }),
              _tile(colors, icon: Icons.favorite_rounded, iconColor: Colors.redAccent, title: "Sevimli sartaroshlar", subtitle: "Tanlangan sartaroshlar", onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen(userId: widget.userId)));
              }),
              _tile(colors, icon: Icons.receipt_long_rounded, iconColor: colors.info, title: "To'lov tarixi", subtitle: "Barcha to'lovlar", onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentHistoryScreen(userId: widget.userId)));
              }),
              _tile(colors, icon: Icons.notifications_rounded, iconColor: colors.warning, title: "Bildirishnomalar", subtitle: "Xabarlar va yangiliklar", onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(userId: widget.userId)));
              }),
            ]),

            // ─── SOZLAMALAR ──────────────────────────────────────────
            _section(colors, "Sozlamalar", [
              _tile(
                colors,
                icon: themeProvider.isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                iconColor: themeProvider.isDark ? Colors.amber : Colors.indigo,
                title: "Tungi rejim",
                subtitle: themeProvider.isDark ? "Yoqilgan" : "O'chirilgan",
                trailing: Switch(value: themeProvider.isDark, onChanged: (_) => themeProvider.toggleTheme(), activeColor: colors.primary),
              ),
              _tile(colors, icon: Icons.lock_rounded, iconColor: colors.secondary, title: "Parolni o'zgartirish", subtitle: "Xavfsizlik", onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen(userId: widget.userId)));
              }),
              _tile(colors, icon: Icons.language_rounded, iconColor: colors.info, title: "Til", subtitle: "O'zbek"),
            ]),

            // ─── ILOVA HAQIDA ────────────────────────────────────────
            _section(colors, "Ilova haqida", [
              _tile(colors, icon: Icons.info_outline_rounded, iconColor: colors.textTertiary, title: "Ilova versiyasi", subtitle: "v1.0.0", onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminVerifyScreen()))),
              _tile(colors, icon: Icons.business_center_rounded, iconColor: colors.textTertiary, title: "Ishlab chiquvchi", subtitle: "Sartaroshxona Team"),
              _tile(colors, icon: Icons.headset_mic_rounded, iconColor: colors.success, title: "Qo'llab-quvvatlash", subtitle: "+998 90 000 00 00", onTap: () => Launcher.call(context, "+998900000000")),
              _tile(colors, icon: Icons.star_rounded, iconColor: colors.gold, title: "Ilovani baholash", subtitle: "Do'kondan baholash", onTap: () => Launcher.open(context, "https://play.google.com/store/apps/details?id=com.example.sartaroshxona")),
            ]),

            const SizedBox(height: 8),
            // ─── CHIQISH ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error.withOpacity(0.1),
                  foregroundColor: colors.error,
                  elevation: 0,
                  side: BorderSide(color: colors.error.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Tizimdan chiqish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text('Sartaroshxona v1.0.0', style: TextStyle(color: colors.textTertiary, fontSize: 12))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(AppColors colors, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(title, style: TextStyle(color: colors.textTertiary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        GlassContainer(
          borderRadius: 16,
          child: Column(
            children: List.generate(children.length, (i) {
              if (i < children.length - 1) {
                return Column(children: [children[i], Divider(height: 1, color: colors.border, indent: 54)]);
              }
              return children[i];
            }),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _tile(AppColors colors, {required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, VoidCallback? onLongPress, Color? iconColor}) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (iconColor ?? colors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor ?? colors.primary, size: 20),
      ),
      title: Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12)) : null,
      trailing: trailing ?? (onTap != null ? Icon(Icons.arrow_forward_ios_rounded, color: colors.textTertiary, size: 13) : null),
    );
  }
}
