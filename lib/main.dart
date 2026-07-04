import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/background_scanner.dart';
import 'services/gamification_service.dart';
import 'services/step_service.dart';
import 'services/ad_service.dart';
import 'services/moderation_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  try {
    await FirebaseMessaging.instance.requestPermission();
  } catch (e) {
    print('FCM Permission Error: $e');
  }

  await GamificationService.loadShopItems();
  await GamificationService.loadQuests();
  await NotificationService().init();
  await initializeBackgroundService();
  await StepService().init(); // Initialiser le pédomètre
  await AdService().init(); // Initialiser AdMob
  await ModerationService().init(); // Initialiser la modération
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const DymwaApp(),
    ),
  );
}

class DymwaApp extends StatelessWidget {
  const DymwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'dymwa',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.getThemeData(context, isDark: false),
          darkTheme: themeProvider.getThemeData(context, isDark: true),
          themeMode: themeProvider.themeMode, // S'adapte selon le choix de l'utilisateur
          home: const SplashScreen(),
        );
      },
    );
  }
}
