import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isListening = false;

  Future<void> init() async {
    // 1. Configurer les notifications locales
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      settings: initSettings,
    );

    // 2. Démarrer l'écouteur global pour les "Fausses notifications"
    startLocalMessageListener();
  }

  void startLocalMessageListener() {
    if (_isListening) return;
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (currentUid.isEmpty) return;

    _isListening = true;

    FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: currentUid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>;
          
          // Vérifie si le dernier message ne vient pas de nous
          if (data['lastSenderId'] != null && data['lastSenderId'] != currentUid) {
            String title = "Nouveau message";
            
            // Trouver le nom de l'expéditeur
            for (String key in data.keys) {
              if (key.startsWith('user_') && key != 'user_$currentUid') {
                title = data[key];
              }
            }

            _showLocalNotification(title, data['lastMessage'] ?? "Vous avez reçu un message");
          }
        }
      }
    });
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'dymwa_chats_channel',
      'Messages Chat',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotifications.show(
      id: DateTime.now().millisecond, // ID unique
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  // Ne sert plus dans cette option (A), mais conservé pour l'API si besoin
  Future<void> saveTokenToDatabase() async {}
}
