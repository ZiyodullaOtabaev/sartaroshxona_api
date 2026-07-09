import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tashqi havola/qo'ng'iroq ochish uchun yordamchilar.
class Launcher {
  /// Telefon raqamiga qo'ng'iroq (tel:) ochish.
  static Future<void> call(BuildContext context, String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _snack(context, "Telefon raqami mavjud emas");
      return;
    }
    // Faqat raqam, +, * va # belgilarini qoldiramiz
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+*#]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    await _launch(context, uri, "Qo'ng'iroqni ochib bo'lmadi");
  }

  /// Tashqi URL (brauzer/do'kon) ochish.
  static Future<void> open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    await _launch(context, uri, "Havolani ochib bo'lmadi");
  }

  static Future<void> _launch(BuildContext context, Uri uri, String errorMsg) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _snack(context, errorMsg);
    } catch (_) {
      if (context.mounted) _snack(context, errorMsg);
    }
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
