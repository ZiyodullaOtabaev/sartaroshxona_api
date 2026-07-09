/// Ilova konfiguratsiyasi
/// Production'da bu qiymatlarni environment variables orqali o'zgartiring
class AppConstants {
  AppConstants._();

  // ─── API CONFIG ───────────────────────────────────────────────────────────
  /// Backend server manzili
  ///
  /// 2 xil rejim:
  ///   1) PRODUCTION (tavsiya etiladi) — Render'dagi doimiy URL.
  ///      Har qanday tarmoqda (mobil internet, istalgan Wi-Fi) ishlaydi.
  ///      Render dashboard'dagi haqiqiy URL bilan solishtirib tekshiring.
  ///   2) LOCAL TEST — kompyuteringiz Wi-Fi IP'si (telefon+PC bir Wi-Fi'da).
  ///      Masalan: 'http://192.168.1.100:8000'  (ipconfig bilan toping)
  ///
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
  /// bilan vaqtincha local'ga o'tkazsa bo'ladi.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sartaroshxona-api-ly5e.onrender.com', // ← Render URL
  );

  /// API so'rovlar uchun timeout (sekundlarda)
  /// Render bepul tarif "cold start" qilishi mumkin — shuning uchun 30s.
  static const int requestTimeoutSeconds = 30;

  // ─── APP INFO ─────────────────────────────────────────────────────────────
  static const String appName = 'Sartaroshxona';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  // ─── MAP CONFIG ───────────────────────────────────────────────────────────
  /// Default joylashuv (Toshkent markazi)
  static const double defaultLat = 41.3111;
  static const double defaultLng = 69.2797;

  /// Default qidiruv radiusi (km)
  static const double defaultSearchRadiusKm = 2.0;

  // ─── PAGINATION ───────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // ─── VALIDATION ───────────────────────────────────────────────────────────
  static const int minPasswordLength = 8;
  static const int maxNameLength = 100;
  static const int maxBioLength = 500;

  // ─── STORAGE KEYS ─────────────────────────────────────────────────────────
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String userNameKey = 'user_name';
  static const String themeKey = 'app_theme';

  // ─── CONTACT INFO ─────────────────────────────────────────────────────────
  static const String supportPhone = '+998 90 000 00 00';
  static const String supportEmail = 'support@sartaroshxona.uz';
  static const String developerName = 'Sartaroshxona Team';
}
