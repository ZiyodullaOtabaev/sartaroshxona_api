import 'package:flutter/material.dart';
import 'package:sartaroshxona/screens/register_screen.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
                  boxShadow: [
                    BoxShadow(color: colors.primary.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.people_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                "Qaysi maqsadda foydalanasiz?",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, height: 1.25),
              ),
              const SizedBox(height: 6),
              Text("Rolni tanlab ro'yxatdan o'ting", style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              _RoleCard(
                colors: colors,
                title: "Mijozman",
                subtitle: "Sartarosh qidirish va navbat olish uchun",
                icon: Icons.person_rounded,
                role: "customer",
              ),
              const SizedBox(height: 12),
              _RoleCard(
                colors: colors,
                title: "Sartaroshman",
                subtitle: "Xizmat ko'rsatish va mijozlarni boshqarish",
                icon: Icons.content_cut_rounded,
                role: "barber",
              ),
              const SizedBox(height: 12),
              _RoleCard(
                colors: colors,
                title: "Sartaroshxona egasiman",
                subtitle: "Salon, xodimlar va daromad boshqaruvi (CRM)",
                icon: Icons.store_rounded,
                role: "owner",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final AppColors colors;
  final String title;
  final String subtitle;
  final IconData icon;
  final String role;

  const _RoleCard({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(selectedRole: role))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colors.primary.withOpacity(0.15), colors.primaryLight.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, color: colors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}
