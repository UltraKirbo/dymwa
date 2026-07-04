import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Liste des thèmes et de leurs prix (Dym-Coins)
  static const Map<String, int> themePrices = {
    'default': 0,
    'ocean': 100,
    'sunset': 150,
    'cyberpunk': 300,
  };

  // Liste des bordures, leurs prix et couleurs
  static Map<String, int> borderPrices = {};
  static Map<String, List<Color>> borderColors = {};

  // Liste des titres et de leurs prix
  static Map<String, int> titlePrices = {};

  // Charger les données depuis le fichier JSON
  static Future<void> loadShopItems() async {
    try {
      final String response = await rootBundle.loadString('assets/data/shop_items.json');
      final data = await json.decode(response);
      
      final bordersData = data['borders'] as Map<String, dynamic>;
      borderPrices.clear();
      borderColors.clear();
      bordersData.forEach((key, value) {
        borderPrices[key] = value['price'] as int;
        List<dynamic> hexColors = value['colors'] ?? [];
        borderColors[key] = hexColors.map((hex) => _colorFromHex(hex.toString())).toList();
      });

      titlePrices = Map<String, int>.from(data['titles']);
    } catch (e) {
      print("Erreur de chargement des items de la boutique : $e");
      borderPrices = {'none': 0};
      borderColors = {'none': []};
      titlePrices = {'': 0};
    }
  }

  static Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  static LinearGradient? getBorderGradient(String borderId) {
    final colors = borderColors[borderId];
    if (colors == null || colors.isEmpty) return null;
    return LinearGradient(colors: colors);
  }

  // --- MONNAIE ET BOUTIQUE ---

  // Ajouter des Dym-Coins
  Future<void> addCoins(int amount) async {
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'coins': FieldValue.increment(amount),
    });
  }

  // Acheter un thème
  Future<bool> buyTheme(String themeId) async {
    if (uid.isEmpty) return false;
    int price = themePrices[themeId] ?? 9999;
    
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    
    int currentCoins = (doc.data() as Map<String, dynamic>)['coins'] ?? 0;
    
    if (currentCoins >= price) {
      await _firestore.collection('users').doc(uid).update({
        'coins': FieldValue.increment(-price),
        'unlockedThemes': FieldValue.arrayUnion([themeId]),
        'activeTheme': themeId, // On l'équipe directement
      });
      return true; // Achat réussi
    }
    return false; // Pas assez de pièces
  }

  // Équiper un thème déjà acheté
  Future<void> equipTheme(String themeId) async {
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'activeTheme': themeId,
    });
  }

  // Acheter une bordure
  Future<bool> buyBorder(String borderId) async {
    if (uid.isEmpty) return false;
    int price = borderPrices[borderId] ?? 9999;
    
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    
    int currentCoins = (doc.data() as Map<String, dynamic>)['coins'] ?? 0;
    
    if (currentCoins >= price) {
      await _firestore.collection('users').doc(uid).update({
        'coins': FieldValue.increment(-price),
        'unlockedBorders': FieldValue.arrayUnion([borderId]),
        'activeBorder': borderId,
      });
      return true;
    }
    return false;
  }

  // Équiper une bordure
  Future<void> equipBorder(String borderId) async {
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'activeBorder': borderId,
    });
  }

  // Acheter un titre
  Future<bool> buyTitle(String titleId) async {
    if (uid.isEmpty) return false;
    int price = titlePrices[titleId] ?? 9999;
    
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    
    int currentCoins = (doc.data() as Map<String, dynamic>)['coins'] ?? 0;
    
    if (currentCoins >= price) {
      await _firestore.collection('users').doc(uid).update({
        'coins': FieldValue.increment(-price),
        'unlockedTitles': FieldValue.arrayUnion([titleId]),
        'activeTitle': titleId,
      });
      return true;
    }
    return false;
  }

  // Équiper un titre
  Future<void> equipTitle(String titleId) async {
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'activeTitle': titleId,
    });
  }

  // --- QUÊTES ---

  // Initialisation des quêtes quotidiennes
  Future<void> checkDailyQuestsSetup() async {
    if (uid.isEmpty) return;
    
    DocumentReference userRef = _firestore.collection('users').doc(uid);
    DocumentSnapshot snapshot = await userRef.get();
    if (!snapshot.exists) return;
    
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    Map<String, dynamic> quests = data['questProgress'] ?? {};
    
    DateTime now = DateTime.now();
    String todayKey = "${now.year}-${now.month}-${now.day}";
    String lastDaily = quests['last_daily_date'] ?? "";
    List<dynamic> dailyList = quests['daily_quests_list'] ?? [];
    
    if (lastDaily != todayKey || dailyList.isEmpty) {
      // Nouveau jour, ou migration, remise à zéro
      quests['daily_image'] = 0;
      quests['daily_voice'] = 0;
      quests['daily_games'] = 0;
      quests['daily_messages'] = 0;
      quests['daily_target_messages'] = 0;
      quests['daily_friends'] = 0;
      
      quests['daily_image_claimed'] = false;
      quests['daily_voice_claimed'] = false;
      quests['daily_games_claimed'] = false;
      quests['daily_messages_claimed'] = false;
      quests['daily_target_claimed'] = false;
      quests['daily_friends_claimed'] = false;
      quests['daily_bonus_claimed'] = false;
      
      quests['last_daily_date'] = todayKey;
      
      // Liste des quêtes possibles
      List<String> pool = [
        'daily_send_image',
        'daily_send_voice',
        'daily_play_game',
        'daily_send_messages_5',
        'daily_add_friend'
      ];
      
      // Tirage de l'ami aléatoire si possible
      QuerySnapshot friendsSnap = await userRef.collection('friends').get();
      if (friendsSnap.docs.isNotEmpty) {
        pool.add('daily_target_friend'); // Ajoute la quête ciblée au pool
        final docs = friendsSnap.docs.toList()..shuffle();
        final selectedFriend = docs.first.data() as Map<String, dynamic>;
        quests['daily_target_uid'] = selectedFriend['uid'];
        quests['daily_target_name'] = selectedFriend['name'];
      } else {
        quests['daily_target_uid'] = '';
        quests['daily_target_name'] = '';
      }
      
      // Tirer 3 quêtes au hasard
      pool.shuffle();
      quests['daily_quests_list'] = pool.take(3).toList();
      
      await userRef.update({'questProgress': quests});
    }
  }

  // Incrémenter la quête ciblée
  Future<void> progressTargetedQuest(String targetUid) async {
    if (uid.isEmpty || targetUid.isEmpty) return;
    
    DocumentReference userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;
      
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> quests = data['questProgress'] ?? {};
      
      String dailyTarget = quests['daily_target_uid'] ?? '';
      if (dailyTarget == targetUid) {
        int count = (quests['daily_target_messages'] ?? 0) + 1;
        quests['daily_target_messages'] = count;
        transaction.update(userRef, {'questProgress': quests});
        _checkRewards('daily_target_messages', 0, count, quests);
      }
    });
  }

  // Incrémenter le compteur d'une action
  Future<void> progressQuest(String actionType) async {
    if (uid.isEmpty) return;
    
    DocumentReference userRef = _firestore.collection('users').doc(uid);
    
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;
      
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> quests = data['questProgress'] ?? {};
      
      // Incrémentation permanente
      int permanentCount = (quests[actionType] ?? 0) + 1;
      quests[actionType] = permanentCount;
      
      int dailyCount = 0;
      if (actionType == 'messages_sent') {
        dailyCount = (quests['daily_messages'] ?? 0) + 1;
        quests['daily_messages'] = dailyCount;
      } else if (actionType == 'games_played') {
        dailyCount = (quests['daily_games'] ?? 0) + 1;
        quests['daily_games'] = dailyCount;
      } else if (actionType == 'friends_added') {
        dailyCount = (quests['daily_friends'] ?? 0) + 1;
        quests['daily_friends'] = dailyCount;
      } else if (actionType == 'image_sent') {
        dailyCount = (quests['daily_image'] ?? 0) + 1;
        quests['daily_image'] = dailyCount;
      } else if (actionType == 'voice_messages_sent') {
        dailyCount = (quests['daily_voice'] ?? 0) + 1;
        quests['daily_voice'] = dailyCount;
      }
      
      transaction.update(userRef, {'questProgress': quests});
      
      // Validation asynchrone
      _checkRewards(actionType, permanentCount, dailyCount, quests);
    });
  }
  
  // Vérifie si un palier est atteint
  void _checkRewards(String action, int permCount, int dailyCount, Map<String, dynamic> quests) {
    bool madeChange = false;
    List<dynamic> dailyList = quests['daily_quests_list'] ?? [];
    
    // Quêtes Quotidiennes
    if (action == 'messages_sent' && dailyCount >= 5 && dailyList.contains('daily_send_messages_5')) {
      if (quests['daily_messages_claimed'] != true) {
        addCoins(20);
        quests['daily_messages_claimed'] = true;
        madeChange = true;
      }
    }
    if (action == 'image_sent' && dailyCount >= 1 && dailyList.contains('daily_send_image')) {
      if (quests['daily_image_claimed'] != true) {
        addCoins(10);
        quests['daily_image_claimed'] = true;
        madeChange = true;
      }
    }
    if (action == 'voice_messages_sent' && dailyCount >= 1 && dailyList.contains('daily_send_voice')) {
      if (quests['daily_voice_claimed'] != true) {
        addCoins(10);
        quests['daily_voice_claimed'] = true;
        madeChange = true;
      }
    }
    if (action == 'games_played' && dailyCount >= 1 && dailyList.contains('daily_play_game')) {
      if (quests['daily_games_claimed'] != true) {
        addCoins(15);
        quests['daily_games_claimed'] = true;
        madeChange = true;
      }
    }
    if (action == 'friends_added' && dailyCount >= 1 && dailyList.contains('daily_add_friend')) {
      if (quests['daily_friends_claimed'] != true) {
        addCoins(15);
        quests['daily_friends_claimed'] = true;
        madeChange = true;
      }
    }
    if (action == 'daily_target_messages' && dailyCount >= 1 && dailyList.contains('daily_target_friend')) {
      if (quests['daily_target_claimed'] != true) {
        addCoins(15);
        quests['daily_target_claimed'] = true;
        madeChange = true;
      }
    }
    
    // Bonus Grand Chelem
    int completedDailies = 0;
    for (String qId in dailyList) {
      if (qId == 'daily_send_image' && quests['daily_image_claimed'] == true) completedDailies++;
      if (qId == 'daily_send_voice' && quests['daily_voice_claimed'] == true) completedDailies++;
      if (qId == 'daily_play_game' && quests['daily_games_claimed'] == true) completedDailies++;
      if (qId == 'daily_send_messages_5' && quests['daily_messages_claimed'] == true) completedDailies++;
      if (qId == 'daily_add_friend' && quests['daily_friends_claimed'] == true) completedDailies++;
      if (qId == 'daily_target_friend' && quests['daily_target_claimed'] == true) completedDailies++;
    }

    if (completedDailies == 3 && quests['daily_bonus_claimed'] != true && dailyList.length == 3) {
      addCoins(50);
      quests['daily_bonus_claimed'] = true;
      madeChange = true;
    }
    
    // Sauvegarder les claims quotidiens si changement
    if (madeChange) {
       _firestore.collection('users').doc(uid).set({'questProgress': quests}, SetOptions(merge: true));
    }
    // Quêtes Permanentes
    if (action == 'messages_sent' && permCount == 100) {
      if (quests['messages_sent_claimed'] != true) {
        addCoins(500);
        _firestore.collection('users').doc(uid).set({'questProgress': {'messages_sent_claimed': true}}, SetOptions(merge: true));
      }
    }
    if (action == 'friends_added' && permCount == 10) {
      if (quests['friends_added_claimed'] != true) {
        addCoins(300);
        _firestore.collection('users').doc(uid).set({'questProgress': {'friends_added_claimed': true}}, SetOptions(merge: true));
      }
    }
    if (action == 'voice_messages_sent' && permCount == 5) {
      if (quests['voice_messages_sent_claimed'] != true) {
        addCoins(150);
        _firestore.collection('users').doc(uid).set({'questProgress': {'voice_messages_sent_claimed': true}}, SetOptions(merge: true));
      }
    }
    if (action == 'games_played' && permCount == 3) {
      if (quests['games_played_claimed'] != true) {
        addCoins(200);
        _firestore.collection('users').doc(uid).set({'questProgress': {'games_played_claimed': true}}, SetOptions(merge: true));
      }
    }
  }
}
