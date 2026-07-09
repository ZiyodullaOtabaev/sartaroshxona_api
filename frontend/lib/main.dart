import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/screens/splash_screen.dart';
import 'package:sartaroshxona/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase ishga tushirish
  await Firebase.initializeApp();

  // Push Notification ishga tushirish
  await PushNotificationService().initialize();

  // Status bar uslubi
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Faqat portret rejim
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const SartaroshxonaApp(),
    ),
  );
}

class SartaroshxonaApp extends StatelessWidget {
  const SartaroshxonaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sartaroshxona',
      theme: themeProvider.themeData,
      home: const SplashScreen(),
    );
  }
}