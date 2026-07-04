import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'proximity_service.dart';
import 'plaza_service.dart';
import 'notification_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'streetpass_background_channel', 
    'StreetPass Scanner', 
    description: 'Scanne les environs en continu', 
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'streetpass_background_channel',
      initialNotificationTitle: 'Dymwa',
      initialNotificationContent: 'Recherche de joueurs...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase in isolate
  await Firebase.initializeApp();
  
  // Démarrer l'écoute des messages pour les fausses notifications push
  await NotificationService().init();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // If user logs out or disables background, we should stop
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  ProximityService proximity = ProximityService();
  
  // We periodically restart scanning to ensure the OS doesn't kill the BLE scanning.
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('background_streetpass_enabled') ?? false;

    if (!isEnabled) {
      proximity.stopAll();
      service.stopSelf();
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      service.stopSelf();
      return;
    }

    flutterLocalNotificationsPlugin.show(
      id: 888,
      title: 'Dymwa StreetPass',
      body: 'Scan en cours en arrière-plan...',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'streetpass_background_channel',
          'StreetPass Scanner',
          icon: 'ic_bg_service_small', // Assurez-vous d'avoir une icône, sinon ça plantera sur certains appareils (on utilise celle par défaut pour l'instant)
          ongoing: true,
        ),
      ),
    );

    proximity.stopAll();
    await proximity.startAdvertising(uid);
    await proximity.startDiscovery((endpointId, peerUid) async {
      await PlazaService().registerEncounter(peerUid);
      // Notification Push Locale
      flutterLocalNotificationsPlugin.show(
        id: peerUid.hashCode,
        title: 'Rencontre StreetPass ! 🌟',
        body: 'Vous avez croisé quelqu\'un ! Regardez votre Place.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('streetpass_alerts', 'Rencontres', importance: Importance.high),
        ),
      );
    }, (id) {});
  });
}
