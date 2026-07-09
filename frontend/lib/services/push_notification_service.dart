import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sartaroshxona/services/api_service.dart';

/// Background message handler — top-level funksiya bo'lishi shart
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[Push] Background: ${message.notification?.title}');
}

/// Push Notification xizmati — Firebase Cloud Messaging
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Firebase va push notification'ni ishga tushirish
  Future<void> initialize() async {
    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Ruxsat so'rash
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Ruxsat berilmadi');
      return;
    }

    // Local notification kanali (Android)
    await _setupLocalNotifications();

    // FCM token olish
    _fcmToken = await _messaging.getToken();
    debugPrint('[Push] FCM Token: $_fcmToken');

    // Token yangilanganda
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _registerTokenOnServer(newToken);
    });

    // Foreground xabarlar
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Ilova notification'dan ochilganda
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Ilova yopiq bo'lganda notification'dan ochilgan bo'lsa
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  /// FCM tokenni backend'ga yuborish
  Future<void> registerToken(int userId) async {
    if (_fcmToken == null) return;
    await _registerTokenOnServer(_fcmToken!, userId: userId);
  }

  Future<void> _registerTokenOnServer(String token, {int? userId}) async {
    if (userId == null) {
      final savedId = await ApiService().getSavedUserId();
      if (savedId == null) return;
      userId = savedId;
    }
    try {
      await ApiService().registerDevice(
        userId: userId,
        fcmToken: token,
        deviceType: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      debugPrint('[Push] Token register xatolik: $e');
    }
  }

  /// Unregister (logout da)
  Future<void> unregisterToken(int userId) async {
    if (_fcmToken == null) return;
    try {
      await ApiService().unregisterDevice(
        userId: userId,
        fcmToken: _fcmToken!,
      );
    } catch (e) {
      debugPrint('[Push] Token unregister xatolik: $e');
    }
  }

  // ─── LOCAL NOTIFICATIONS SETUP ──────────────────────────────────────────

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[Push] Local notification tapped: ${details.payload}');
      },
    );

    // Android notification channel
    const channel = AndroidNotificationChannel(
      'sartaroshxona_main',
      'Sartaroshxona',
      description: 'Navbat va bildirishnomalar',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ─── MESSAGE HANDLERS ─────────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    debugPrint('[Push] Foreground: ${notification.title}');

    // Local notification ko'rsatish (ilova ochiq bo'lganda ham)
    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sartaroshxona_main',
          'Sartaroshxona',
          channelDescription: 'Navbat va bildirishnomalar',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['type'],
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[Push] Tapped: ${message.data}');
    // TODO: message.data['type'] bo'yicha tegishli sahifaga navigate qilish
  }
}
