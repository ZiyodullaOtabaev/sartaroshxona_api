import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';

class QrCardDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String qrData;
  final String? avatarUrl;

  const QrCardDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.qrData,
    this.avatarUrl,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String qrData,
  }) {
    showDialog(
      context: context,
      builder: (_) => QrCardDialog(
        title: title,
        subtitle: subtitle,
        qrData: qrData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_2_rounded, color: colors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "SARTAROSHXONA QR",
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // QR Code Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0D1117),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0D1117),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Helper text
            Text(
              "Mijozlar ushbu QR kodni skanerlab,\ntug'ridan-to'g'ri navbat olishlari mumkin",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Yopish"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
