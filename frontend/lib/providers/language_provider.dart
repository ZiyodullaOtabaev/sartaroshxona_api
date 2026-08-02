import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  uzLotin('uz', 'O\'zbekcha (Lotin)', '🇺🇿'),
  uzKirill('uz_cyrl', 'Ўзбекча (Кирилл)', '🇺🇿'),
  ru('ru', 'Русский', '🇷🇺'),
  en('en', 'English', '🇬🇧');

  final String code;
  final String name;
  final String flag;
  const AppLanguage(this.code, this.name, this.flag);
}

class LanguageProvider extends ChangeNotifier {
  static const String _key = 'selected_language';
  AppLanguage _currentLanguage = AppLanguage.uzLotin;

  AppLanguage get currentLanguage => _currentLanguage;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_key);
    if (savedCode != null) {
      _currentLanguage = AppLanguage.values.firstWhere(
        (l) => l.code == savedCode,
        orElse: () => AppLanguage.uzLotin,
      );
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.code);
  }
}
