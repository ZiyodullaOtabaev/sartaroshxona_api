import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sartaroshxona/models/barber.dart';
import 'package:sartaroshxona/utils/app_constants.dart';
import 'package:sartaroshxona/services/offline_cache_service.dart';

/// API xizmati — backend bilan aloqa
/// JWT token bilan ishlaydi, auto-retry va xatolik boshqaruvi bilan
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = AppConstants.baseUrl;
  static const Duration _timeout = Duration(seconds: AppConstants.requestTimeoutSeconds);

  String? _token;

  // ─── IN-MEMORY CACHE ──────────────────────────────────────────────────────
  // Tez-tez o'qiladigan ma'lumotlarni (barberlar, salonlar) qisqa muddatga
  // keshlash — navigatsiya tez bo'lishi va tarmoq so'rovlarini kamaytirish uchun.
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(seconds: 60);

  T? _getCached<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.savedAt) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  void _setCache(String key, dynamic value) {
    _cache[key] = _CacheEntry(value, DateTime.now());
  }

  /// Keshni tozalash (logout yoki ma'lumot o'zgarganda)
  void clearCache() => _cache.clear();

  // ─── TOKEN MANAGEMENT ─────────────────────────────────────────────────────

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userRoleKey);
    await prefs.remove(AppConstants.userNameKey);
  }

  Future<void> saveUserData({required int userId, required String role, required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.userIdKey, userId);
    await prefs.setString(AppConstants.userRoleKey, role);
    await prefs.setString(AppConstants.userNameKey, name);
  }

  Future<int?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.userIdKey);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.userRoleKey);
  }

  // ─── HTTP HELPERS ─────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<http.Response?> _get(String endpoint) async {
    try {
      final headers = await _headers();
      return await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ).timeout(_timeout);
    } catch (e) {
      _logError('GET $endpoint', e);
      return null;
    }
  }

  Future<http.Response?> _post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _headers();
      return await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
    } catch (e) {
      _logError('POST $endpoint', e);
      return null;
    }
  }

  Future<http.Response?> _put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _headers();
      return await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
    } catch (e) {
      _logError('PUT $endpoint', e);
      return null;
    }
  }

  Future<http.Response?> _delete(String endpoint) async {
    try {
      final headers = await _headers();
      return await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ).timeout(_timeout);
    } catch (e) {
      _logError('DELETE $endpoint', e);
      return null;
    }
  }

  void _logError(String operation, dynamic error) {
    print("[ApiService] $operation ERROR: $error");
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> registerUser(
      String name,
      String email,
      String password,
      String role, {
        String? experience,
        String? phone,
        String? specialization,
        String? bio,
        double? lat,
        double? lng,
      }) async {
    final body = {
      "full_name": name,
      "email": email,
      "password": password,
      "role": role,
      "phone": phone ?? "",
      "experience": experience ?? "",
      "specialization": specialization ?? "",
      "bio": bio ?? "",
      "lat": lat ?? AppConstants.defaultLat,
      "lng": lng ?? AppConstants.defaultLng,
    };

    final response = await _post('/register', body: body);
    if (response == null) return null;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        await setToken(data['token']);
      }
      return data;
    }

    if (response.statusCode == 409) {
      return {"error": "Bu email allaqachon ro'yxatdan o'tgan"};
    }
    return {"error": "Ro'yxatdan o'tishda xatolik"};
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final response = await _post('/login', body: {
      "email": email,
      "password": password,
    });

    // Tarmoq xatosi (server topilmadi / timeout / IP noto'g'ri)
    if (response == null) {
      return {"error": "network"};
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        await setToken(data['token']);
      }
      final user = data['user'];
      if (user != null) {
        await saveUserData(
          userId: user['id'] ?? 0,
          role: user['role'] ?? 'customer',
          name: user['full_name'] ?? '',
        );
      }
      return data;
    }

    // 401/403 — haqiqatan parol/email noto'g'ri
    if (response.statusCode == 401 || response.statusCode == 403) {
      return {"error": "auth"};
    }

    // Boshqa server xatosi (500 va h.k.)
    return {"error": "server"};
  }

  Future<void> logout() async {
    await clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BARBERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Barber>> fetchBarbers(double lat, double lng, {double radiusKm = 2.0}) async {
    final cacheKey = OfflineCacheService.barbersKey(lat, lng);
    final response = await _get('/nearby_barbers?user_lat=$lat&user_lng=$lng&radius_km=$radiusKm');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final barbers = data.map((j) => Barber.fromJson(j)).toList();
      // Cache'ga saqlash
      OfflineCacheService().saveToCache(cacheKey, data);
      return barbers;
    }
    // Offline fallback
    final cached = await OfflineCacheService().getFromCache(cacheKey);
    if (cached != null && cached is List) {
      return cached.map((j) => Barber.fromJson(Map<String, dynamic>.from(j))).toList();
    }
    return await fetchAllBarbers(lat, lng);
  }

  Future<List<Barber>> fetchAllBarbers(double lat, double lng) async {
    final cacheKey = 'all_barbers_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
    final cached = _getCached<List<Barber>>(cacheKey);
    if (cached != null) return cached;

    final response = await _get('/all_barbers?user_lat=$lat&user_lng=$lng');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final barbers = data.map((j) => Barber.fromJson(j)).toList();
      _setCache(cacheKey, barbers);
      return barbers;
    }
    return [];
  }

  Future<List<Barber>> searchBarbers(String query) async {
    final response = await _get('/search_barbers?query=${Uri.encodeComponent(query)}');
    if (response != null && response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => Barber.fromJson(j)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> getBarberDetail(int barberId) async {
    final response = await _get('/barber/$barberId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<bool> updateOnlineStatus(int barberId, bool isOnline) async {
    final response = await _put('/update_online_status/$barberId?is_online=$isOnline');
    return response != null && response.statusCode == 200;
  }

  Future<bool> updateProfile(int barberId, Map<String, dynamic> data) async {
    final response = await _put('/update_profile/$barberId', body: data);
    return response != null && response.statusCode == 200;
  }

  Future<bool> updateWorkingDays(int barberId, List<int> days) async {
    try {
      final headers = await _headers();
      final response = await http.put(
        Uri.parse('$baseUrl/update_working_days/$barberId'),
        headers: headers,
        body: jsonEncode(days),
      ).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      _logError('updateWorkingDays', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SLOTS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getAvailableSlots(int barberId, String date) async {
    final response = await _get('/available_slots/$barberId?date=$date');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<bool> blockSlot({
    required int barberId,
    required String date,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    final response = await _post('/block_slot', body: {
      "barber_id": barberId,
      "blocked_date": date,
      "start_time": startTime,
      "end_time": endTime,
      "reason": reason ?? "",
    });
    return response != null && response.statusCode == 200;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SERVICES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getBarberServices(int barberId) async {
    final response = await _get('/get_services/$barberId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<bool> addService(int barberId, String name, double price,
      {int duration = 30, String description = ""}) async {
    final response = await _post(
      '/add_service?barber_id=$barberId&name=${Uri.encodeComponent(name)}'
          '&price=$price&duration=$duration&description=${Uri.encodeComponent(description)}',
    );
    return response != null && response.statusCode == 200;
  }

  Future<bool> deleteService(int serviceId) async {
    final response = await _delete('/delete_service/$serviceId');
    return response != null && response.statusCode == 200;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APPOINTMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> bookAppointment({
    required int customerId,
    required int barberId,
    int? serviceId,
    required String appointmentTime,
    required String serviceName,
    double price = 0,
    String? notes,
  }) async {
    final response = await _post('/book_appointment', body: {
      "customer_id": customerId,
      "barber_id": barberId,
      "service_id": serviceId,
      "appointment_time": appointmentTime,
      "service_name": serviceName,
      "price": price,
      "notes": notes ?? "",
    });

    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    if (response != null && response.statusCode == 409) {
      return {"error": "Bu vaqt band! Boshqa vaqt tanlang."};
    }
    return null;
  }

  Future<List<dynamic>> getCustomerAppointments(int customerId) async {
    final cacheKey = OfflineCacheService.appointmentsKey(customerId);
    final response = await _get('/customer_appointments/$customerId');
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      OfflineCacheService().saveToCache(cacheKey, data);
      return data;
    }
    // Offline fallback
    final cached = await OfflineCacheService().getFromCache(cacheKey);
    if (cached != null && cached is List) return cached;
    return [];
  }

  Future<List<dynamic>> getBarberAppointments(int barberId) async {
    final response = await _get('/barber_appointments/$barberId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<bool> updateStatus(int appId, String status) async {
    final response = await _put('/update_appointment_status/$appId?status=$status');
    return response != null && response.statusCode == 200;
  }

  Future<bool> cancelAppointment(int appId, int customerId) async {
    final response = await _put('/cancel_appointment/$appId?customer_id=$customerId');
    return response != null && response.statusCode == 200;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REVIEWS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> addReview({
    required int appointmentId,
    required int customerId,
    required int barberId,
    required int rating,
    String? comment,
  }) async {
    final response = await _post('/add_review', body: {
      "appointment_id": appointmentId,
      "customer_id": customerId,
      "barber_id": barberId,
      "rating": rating,
      "comment": comment ?? "",
    });
    return response != null && response.statusCode == 200;
  }

  Future<List<dynamic>> getBarberReviews(int barberId) async {
    final response = await _get('/barber_reviews/$barberId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> createPayment({
    required int appointmentId,
    required double amount,
    required String method,
  }) async {
    final response = await _post('/create_payment', body: {
      "appointment_id": appointmentId,
      "amount": amount,
      "method": method,
    });
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<List<dynamic>> getPaymentHistory(int customerId) async {
    final cacheKey = OfflineCacheService.paymentsKey(customerId);
    final response = await _get('/payment_history/$customerId');
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      OfflineCacheService().saveToCache(cacheKey, data);
      return data;
    }
    // Offline fallback
    final cached = await OfflineCacheService().getFromCache(cacheKey);
    if (cached != null && cached is List) return cached;
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONLAYN TO'LOV (Payme / Click)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Tanlangan tizim (payme/click) uchun checkout URL oladi.
  /// Natija: {checkout_url, order_id, amount, gateway} yoki null.
  Future<Map<String, dynamic>?> createCheckout(int appointmentId, String gateway) async {
    final response = await _post('/payment/checkout', body: {
      'appointment_id': appointmentId,
      'gateway': gateway,
    });
    if (response != null && response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    return null;
  }

  /// To'lov holatini tekshiradi (polling uchun). true = to'langan.
  Future<bool> isPaymentPaid(int appointmentId) async {
    final response = await _get('/payment/status/$appointmentId');
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['paid'] == true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ILOVA ICHIDA KARTA TO'LOVI (Payme Subscribe — Humo/Uzcard)
  // ═══════════════════════════════════════════════════════════════════════════
  // Oqim: createCard -> sendCardCode -> verifyCard -> payWithCard
  // Natija har doim {success: bool, error?: String, ...data}

  Future<Map<String, dynamic>> createCard(String number, String expire) =>
      _cardCall('/card/create', {'number': number, 'expire': expire});

  Future<Map<String, dynamic>> sendCardCode(String token) =>
      _cardCall('/card/send_code', {'token': token});

  Future<Map<String, dynamic>> verifyCard(String token, String code) =>
      _cardCall('/card/verify', {'token': token, 'code': code});

  Future<Map<String, dynamic>> payWithCard(int appointmentId, String token) =>
      _cardCall('/card/pay', {'appointment_id': appointmentId, 'token': token});

  Future<Map<String, dynamic>> _cardCall(String endpoint, Map<String, dynamic> body) async {
    final response = await _post(endpoint, body: body);
    if (response == null) {
      return {'success': false, 'error': "Server bilan aloqa yo'q"};
    }
    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(jsonDecode(response.body));
      return {'success': true, ...data};
    }
    try {
      final detail = jsonDecode(response.body)['detail'];
      return {'success': false, 'error': detail?.toString() ?? "Xatolik yuz berdi"};
    } catch (_) {
      return {'success': false, 'error': "Xatolik yuz berdi"};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATISTICS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getBarberStats(int barberId) async {
    final response = await _get('/barber_stats/$barberId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return _emptyStats;
  }

  static const Map<String, dynamic> _emptyStats = {
    "today_count": 0,
    "total_completed": 0,
    "revenue": 0,
    "monthly_revenue": 0,
    "pending_count": 0,
    "avg_rating": 5.0,
    "total_reviews": 0,
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getNotifications(int userId) async {
    final response = await _get('/notifications/$userId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {"notifications": [], "unread_count": 0};
  }

  Future<bool> markNotificationsRead(int userId) async {
    final response = await _put('/mark_notifications_read/$userId');
    return response != null && response.statusCode == 200;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FAVORITES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> toggleFavorite(int customerId, int barberId) async {
    final response = await _post('/toggle_favorite?customer_id=$customerId&barber_id=$barberId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<List<dynamic>> getFavorites(int customerId) async {
    final cacheKey = OfflineCacheService.favoritesKey(customerId);
    final response = await _get('/favorites/$customerId');
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      OfflineCacheService().saveToCache(cacheKey, data);
      return data;
    }
    // Offline fallback
    final cached = await OfflineCacheService().getFromCache(cacheKey);
    if (cached != null && cached is List) return cached;
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEALTH CHECK
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> checkHealth() async {
    final response = await _get('/health');
    return response != null && response.statusCode == 200;
  }

  /// Server'ni "uyg'otish" — cold start bo'lsa kutadi, natijani qaytaradi
  /// Splash screen'da chaqiriladi — foydalanuvchi animatsiya ko'rganida server uyg'onadi
  Future<bool> warmUp() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {"Accept": "application/json"},
      ).timeout(const Duration(seconds: 45));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sartaroshning tasdiqlash holati (pending/approved/rejected)
  Future<String?> getBarberStatus(int barberId) async {
    final response = await _get('/barber_status/$barberId');
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['verification_status']?.toString();
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRM: SALON (Owner) ENDPOINTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Owner: Salon yaratish
  Future<Map<String, dynamic>?> createSalon({
    required String name,
    String? description,
    String? address,
    String? district,
    String? phone,
    double? lat,
    double? lng,
  }) async {
    final response = await _post('/create_salon', body: {
      "name": name,
      "description": description ?? "",
      "address": address ?? "",
      "district": district ?? "Toshkent",
      "phone": phone ?? "",
      "lat": lat,
      "lng": lng,
    });
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Owner: O'z salonini olish
  Future<Map<String, dynamic>?> getMySalon() async {
    final response = await _get('/my_salon');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Owner: Salonni yangilash
  Future<bool> updateSalon(Map<String, dynamic> data) async {
    final response = await _put('/update_salon', body: data);
    return response != null && response.statusCode == 200;
  }

  /// Owner: Dashboard (umumiy + har bir sartarosh daromadi)
  Future<Map<String, dynamic>?> getOwnerDashboard() async {
    final response = await _get('/owner_dashboard');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Owner: Kunlik daromad hisoboti (grafik uchun)
  Future<Map<String, dynamic>?> getRevenueReport({int days = 7}) async {
    final response = await _get('/owner_revenue_report?days=$days');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Owner: Xodimlar ro'yxati
  Future<Map<String, dynamic>?> getSalonStaff() async {
    final response = await _get('/salon_staff');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Owner: Sartaroshni taklif qilish
  Future<Map<String, dynamic>?> inviteBarber({int? barberId, String? barberEmail, String? message}) async {
    final body = <String, dynamic>{};
    if (barberId != null) body["barber_id"] = barberId;
    if (barberEmail != null) body["barber_email"] = barberEmail;
    body["message"] = message ?? "";
    final response = await _post('/invite_barber', body: body);
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    if (response != null) {
      try {
        return jsonDecode(response.body);
      } catch (_) {}
    }
    return null;
  }

  /// Owner: Sartaroshni salondan chiqarish
  Future<bool> removeBarberFromSalon(int barberId) async {
    final response = await _delete('/remove_barber/$barberId');
    return response != null && response.statusCode == 200;
  }

  /// Barber: Salonga qo'shilish so'rovi
  Future<Map<String, dynamic>?> joinSalonRequest(int salonId, {String? message}) async {
    final response = await _post('/join_request', body: {
      "salon_id": salonId,
      "message": message ?? "",
    });
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Owner/Barber: Mening taklif/so'rovlarim
  Future<List<dynamic>> getMyInvitations() async {
    final response = await _get('/my_invitations');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  /// Owner/Barber: Taklif/so'rovga javob (qabul/rad)
  Future<Map<String, dynamic>?> respondInvitation(int invitationId, bool accept) async {
    final response = await _put('/respond_invitation/$invitationId', body: {
      "accept": accept,
    });
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Public: Salonlar ro'yxati
  Future<List<dynamic>> getSalons({int page = 1, int limit = 20}) async {
    final response = await _get('/salons?page=$page&limit=$limit');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  /// Public: Salon tafsilotlari
  Future<Map<String, dynamic>?> getSalonDetail(int salonId) async {
    final response = await _get('/salon/$salonId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Owner register (salon_name, also_barber bilan)
  Future<Map<String, dynamic>?> registerOwner({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String salonName,
    String? salonAddress,
    bool alsoBarber = false,
    double? lat,
    double? lng,
  }) async {
    final body = {
      "full_name": name,
      "email": email,
      "password": password,
      "role": "owner",
      "phone": phone,
      "salon_name": salonName,
      "salon_address": salonAddress ?? "",
      "also_barber": alsoBarber,
      "lat": lat ?? AppConstants.defaultLat,
      "lng": lng ?? AppConstants.defaultLng,
    };

    final response = await _post('/register', body: body);
    if (response == null) return null;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        await setToken(data['token']);
      }
      return data;
    }

    if (response.statusCode == 409) {
      return {"error": "Bu email allaqachon ro'yxatdan o'tgan"};
    }
    return {"error": "Ro'yxatdan o'tishda xatolik"};
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAROL O'ZGARTIRISH
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parolni o'zgartirish. Natija: {'success': bool, 'error': String?}
  Future<Map<String, dynamic>> changePassword(int userId, String oldPassword, String newPassword) async {
    final response = await _post('/change_password', body: {
      'user_id': userId,
      'old_password': oldPassword,
      'new_password': newPassword,
    });
    if (response == null) return {'success': false, 'error': "Server bilan aloqa yo'q"};
    if (response.statusCode == 200) return {'success': true};
    if (response.statusCode == 401) return {'success': false, 'error': "Joriy parol noto'g'ri"};
    if (response.statusCode == 400 || response.statusCode == 404) {
      try {
        return {'success': false, 'error': jsonDecode(response.body)['detail']?.toString() ?? 'Xatolik'};
      } catch (_) {}
    }
    return {'success': false, 'error': "Serverda xatolik. Keyinroq urinib ko'ring."};
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AVATAR YUKLASH
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sartarosh avatarini yuklash (multipart). Muvaffaqiyatli bo'lsa avatar_url qaytaradi.
  Future<String?> uploadAvatar(int barberId, String imagePath) async {
    try {
      final token = await getToken();
      final uri = Uri.parse('$baseUrl/upload_avatar/$barberId');
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        clearCache();
        return data['avatar_url'] as String?;
      }
      _logError('uploadAvatar', 'status ${response.statusCode}');
      return null;
    } catch (e) {
      _logError('uploadAvatar', e);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT / XABARLAR
  // ═══════════════════════════════════════════════════════════════════════════

  /// Xabar yuborish. Muvaffaqiyatli bo'lsa yaratilgan xabar map'ini qaytaradi.
  Future<Map<String, dynamic>?> sendMessage(int senderId, int receiverId, String body) async {
    final response = await _post('/send_message', body: {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'body': body,
    });
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'] != null ? Map<String, dynamic>.from(data['message']) : null;
    }
    return null;
  }

  /// Ikki foydalanuvchi o'rtasidagi yozishmalar.
  Future<List<Map<String, dynamic>>> getMessages(int userId, int otherId) async {
    final response = await _get('/messages/$userId/$otherId');
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['messages'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// Foydalanuvchining barcha suhbatlari.
  Future<List<Map<String, dynamic>>> getConversations(int userId) async {
    final response = await _get('/conversations/$userId');
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['conversations'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN — SARTAROSHLARNI TASDIQLASH
  // ═══════════════════════════════════════════════════════════════════════════

  /// Tasdiqlanmagan sartaroshlar ro'yxati. null = xato (noto'g'ri kalit yoki server).
  Future<List<Map<String, dynamic>>?> adminPendingBarbers(String adminKey) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/pending_barbers'),
        headers: {'Accept': 'application/json', 'X-Admin-Key': adminKey},
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return null;
    } catch (e) {
      _logError('adminPendingBarbers', e);
      return null;
    }
  }

  /// Sartaroshni tasdiqlash (approve=true) yoki rad etish (approve=false).
  Future<bool> adminVerifyBarber(int barberId, bool approve, String adminKey) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/verify_barber/$barberId?approve=$approve'),
        headers: {'Accept': 'application/json', 'X-Admin-Key': adminKey},
      ).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      _logError('adminVerifyBarber', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUSH NOTIFICATION — DEVICE REGISTER
  // ═══════════════════════════════════════════════════════════════════════════

  /// FCM tokenni backend'ga yuborish
  Future<bool> registerDevice({required int userId, required String fcmToken, String deviceType = 'android'}) async {
    final response = await _post('/device/register', body: {
      'user_id': userId,
      'fcm_token': fcmToken,
      'device_type': deviceType,
    });
    return response != null && response.statusCode == 200;
  }

  /// FCM tokenni deactivate qilish (logout da)
  Future<bool> unregisterDevice({required int userId, required String fcmToken}) async {
    final response = await _post('/device/unregister?user_id=$userId&fcm_token=${Uri.encodeComponent(fcmToken)}');
    return response != null && response.statusCode == 200;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMAIL VERIFICATION & PASSWORD RESET
  // ═══════════════════════════════════════════════════════════════════════════

  /// Email OTP tasdiqlash
  Future<Map<String, dynamic>?> verifyEmail(String email, String code) async {
    final response = await _post('/verify_email', body: {'email': email, 'code': code});
    if (response == null) return {'error': "Server bilan aloqa yo'q"};
    if (response.statusCode == 200) return jsonDecode(response.body);
    try { return {'error': jsonDecode(response.body)['detail']}; } catch (_) {}
    return {'error': 'Xatolik yuz berdi'};
  }

  /// Yangi tasdiqlash kodi yuborish
  Future<bool> resendVerification(String email) async {
    final response = await _post('/resend_verification?email=${Uri.encodeComponent(email)}');
    return response != null && response.statusCode == 200;
  }

  /// Parolni unutdim — kod yuborish
  Future<void> forgotPassword(String email) async {
    await _post('/forgot_password', body: {'email': email});
  }

  /// Parolni tiklash (kod + yangi parol)
  Future<Map<String, dynamic>?> resetPassword(String email, String code, String newPassword) async {
    final response = await _post('/reset_password', body: {
      'email': email, 'code': code, 'new_password': newPassword,
    });
    if (response == null) return {'error': "Server bilan aloqa yo'q"};
    if (response.statusCode == 200) return jsonDecode(response.body);
    try { return {'error': jsonDecode(response.body)['detail']}; } catch (_) {}
    return {'error': 'Xatolik yuz berdi'};
  }

  /// Token yangilash
  Future<String?> refreshToken() async {
    final token = await getToken();
    if (token == null) return null;
    final response = await _post('/refresh_token', body: {'token': token});
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newToken = data['token'] as String?;
      if (newToken != null) await setToken(newToken);
      return newToken;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOYALTY TIZIMI
  // ═══════════════════════════════════════════════════════════════════════════

  /// Loyalty holati (stamplar soni, rewardlar)
  Future<Map<String, dynamic>?> getLoyaltyStatus(int customerId) async {
    final response = await _get('/loyalty/status/$customerId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Bepul navbat kodini ishlatish
  Future<Map<String, dynamic>?> redeemLoyaltyReward({required int customerId, required String rewardCode, required int appointmentId}) async {
    final response = await _post('/loyalty/redeem', body: {
      'customer_id': customerId,
      'reward_code': rewardCode,
      'appointment_id': appointmentId,
    });
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REFERRAL TIZIMI
  // ═══════════════════════════════════════════════════════════════════════════

  /// Referral kodini olish
  Future<Map<String, dynamic>?> getMyReferralCode(int userId) async {
    final response = await _get('/referral/my_code/$userId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Referral statistika
  Future<Map<String, dynamic>?> getReferralStats(int userId) async {
    final response = await _get('/referral/stats/$userId');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}



/// Kesh yozuvi — qiymat + saqlangan vaqt
class _CacheEntry {
  final dynamic value;
  final DateTime savedAt;
  _CacheEntry(this.value, this.savedAt);
}
