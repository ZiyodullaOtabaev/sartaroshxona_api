import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Offline cache xizmati — internet yo'q bo'lganda eski ma'lumotlarni ko'rsatish
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._();

  static const String _prefix = 'cache_';

  // ─── CONNECTIVITY ─────────────────────────────────────────────────────────

  /// Hozir internet bormi?
  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Internet holatini stream sifatida kuzatish
  Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none),
    );
  }

  // ─── CACHE OPERATIONS ─────────────────────────────────────────────────────

  /// Ma'lumotni cache'ga saqlash
  Future<void> saveToCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('$_prefix$key', jsonEncode(cacheData));
    } catch (e) {
      debugPrint('[Cache] Save xatolik ($key): $e');
    }
  }

  /// Cache'dan ma'lumot olish (maxAge — necha soat amal qiladi)
  Future<dynamic> getFromCache(String key, {int maxAgeHours = 24}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;

      final cacheData = jsonDecode(raw);
      final timestamp = cacheData['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      final maxAge = maxAgeHours * 3600 * 1000;

      if (age > maxAge) {
        // Muddati o'tgan — o'chirish
        await prefs.remove('$_prefix$key');
        return null;
      }

      return cacheData['data'];
    } catch (e) {
      debugPrint('[Cache] Get xatolik ($key): $e');
      return null;
    }
  }

  /// Cache'dan o'chirish
  Future<void> removeFromCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  /// Barcha cache'ni tozalash
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // ─── KALIT NOMLARI ────────────────────────────────────────────────────────

  /// Barberlar ro'yxati cache kaliti
  static String barbersKey(double lat, double lng) =>
      'barbers_${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}';

  /// Mijoz navbatlari
  static String appointmentsKey(int customerId) => 'appointments_$customerId';

  /// To'lov tarixi
  static String paymentsKey(int customerId) => 'payments_$customerId';

  /// Bildirishnomalar
  static String notificationsKey(int userId) => 'notifications_$userId';

  /// Sevimlilar
  static String favoritesKey(int customerId) => 'favorites_$customerId';

  /// Loyalty holati
  static String loyaltyKey(int customerId) => 'loyalty_$customerId';
}
