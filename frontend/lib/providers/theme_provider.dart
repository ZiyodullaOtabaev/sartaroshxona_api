import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sartaroshxona/utils/app_constants.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(AppConstants.themeKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.themeKey, _isDark);
  }

  ThemeData get themeData => _isDark ? darkTheme : lightTheme;

  static ThemeData get darkTheme => _buildTheme(Brightness.dark, AppColors.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light, AppColors.light);

  /// Premium, izchil theme — har ikkala rejim uchun bitta builder.
  static ThemeData _buildTheme(Brightness brightness, AppColors c) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      primaryColor: c.primary,
      splashColor: c.primary.withOpacity(0.08),
      highlightColor: c.primary.withOpacity(0.04),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: Colors.white,
        secondary: c.secondary,
        onSecondary: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
        error: c.error,
        onError: Colors.white,
      ),

      // ─── Typography ───
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        titleLarge: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: c.textPrimary, height: 1.4),
        bodyMedium: TextStyle(color: c.textSecondary, height: 1.4),
        labelLarge: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
      ),

      // ─── AppBar ───
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),

      // ─── Elevated Button ───
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.2),
        ),
      ),

      // ─── Outlined Button ───
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // ─── Text Button ───
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ─── Card ───
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Input ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.6), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.error, width: 1.5)),
        errorStyle: TextStyle(color: c.error, fontSize: 11),
      ),

      // ─── SnackBar ───
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceVariant,
        contentTextStyle: TextStyle(color: c.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(16),
      ),

      // ─── BottomSheet ───
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),

      // ─── Dialog ───
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ─── Divider ───
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),

      // ─── Switch ───
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary.withOpacity(0.4) : null),
      ),

      // ─── Progress Indicator ───
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),

      // ─── Chip ───
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        labelStyle: TextStyle(color: c.textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: c.border),
      ),

      extensions: [c],
    );
  }
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  final Color gold;

  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.gold,
  });

  static const dark = AppColors(
    primary: Color(0xFF2ECC71),
    primaryLight: Color(0xFF4ADE80),
    secondary: Color(0xFF4ECDC4),
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    surfaceVariant: Color(0xFF1C2128),
    border: Color(0xFF21262D),
    textPrimary: Color(0xFFF0F6FC),
    textSecondary: Color(0xFF8B949E),
    textTertiary: Color(0xFF484F58),
    success: Color(0xFF3FB950),
    error: Color(0xFFFF6B6B),
    warning: Color(0xFFD29922),
    info: Color(0xFF58A6FF),
    gold: Color(0xFFFFD700),
  );

  static const light = AppColors(
    primary: Color(0xFF2ECC71),
    primaryLight: Color(0xFF4ADE80),
    secondary: Color(0xFF4ECDC4),
    background: Color(0xFFF6F8FA),
    surface: Colors.white,
    surfaceVariant: Color(0xFFF3F4F6),
    border: Color(0xFFE1E4E8),
    textPrimary: Color(0xFF1F2328),
    textSecondary: Color(0xFF656D76),
    textTertiary: Color(0xFF8C959F),
    success: Color(0xFF1A7F37),
    error: Color(0xFFFF6B6B),
    warning: Color(0xFF9A6700),
    info: Color(0xFF0969DA),
    gold: Color(0xFFFFD700),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? error,
    Color? warning,
    Color? info,
    Color? gold,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      gold: gold ?? this.gold,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
    );
  }
}
