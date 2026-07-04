import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'gamification_service.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // Récupérer la liste des conversations de l'utilisateur
  Stream<QuerySnapshot> getChats() {
    return _firestore
        .collection('chats')
        .where('users', arrayContains: currentUid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // Créer ou récupérer une conversation avec un utilisateur
  Future<String> createOrGetChat(String peerUid, String peerName) async {
    // ID prédictible pour éviter les doublons (trié par ordre alphabétique)
    List<String> ids = [currentUid, peerUid];
    ids.sort();
    String chatId = ids.join("_");

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    
    if (!chatDoc.exists) {
      // Get my actual name to avoid the "Moi" bug for the recipient
      String myName = "Utilisateur";
      final myDoc = await _firestore.collection('users').doc(currentUid).get();
      if (myDoc.exists) {
        myName = myDoc.data()?['name'] ?? "Utilisateur";
      }

      await _firestore.collection('chats').doc(chatId).set({
        'users': ids,
        'user_$currentUid': myName,
        'user_$peerUid': peerName,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  // Récupérer les messages d'une conversation
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Envoyer un message texte
  Future<void> sendMessage(String chatId, String text, {String? replyToId, String? replyToText}) async {
    if (text.trim().isEmpty) return;

    final messageData = {
      'senderId': currentUid,
      'text': text,
      'type': 'text',
      'isEdited': false,
      'isDeleted': false,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Mettre à jour le dernier message de la conversation
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUid,
    });
    GamificationService().progressQuest('messages_sent');
    
    // Déclencheur pour la quête ciblée aléatoire
    List<String> uids = chatId.split('_');
    String targetUid = uids.firstWhere((id) => id != currentUid, orElse: () => '');
    if (targetUid.isNotEmpty) {
      GamificationService().progressTargetedQuest(targetUid);
    }
  }

  // --- TYPING ---
  Future<void> updateTyping(String chatId, bool isTyping) async {
    await _firestore.collection('chats').doc(chatId).set({
      'typing': {currentUid: isTyping}
    }, SetOptions(merge: true));
  }

  // --- EDITION / SUPPRESSION ---
  
  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': 'Ce message a été supprimé',
      'isDeleted': true,
      'type': 'text', // S'il s'agissait d'une image ou audio, on le masque
    });
  }

  // --- REACTIONS ---
  Future<void> reactToMessage(String chatId, String messageId, String emoji) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'reactions': {currentUid: emoji}
    }, SetOptions(merge: true));
  }

  // --- MEDIA ---

  Future<void> sendImageMessage(String chatId, File imageFile, {String? replyToId, String? replyToText, bool isEphemeral = false}) async {
    try {
      final bytes = imageFile.readAsBytesSync();
      final base64String = base64Encode(bytes);

      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'senderId': currentUid,
        'imageBase64': base64String,
        'type': isEphemeral ? 'ephemeral_image' : 'image',
        'isOpened': false,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': "📸 Image",
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': currentUid,
      });

      GamificationService().progressQuest('messages_sent');
      GamificationService().progressQuest('image_sent');
      
      List<String> uids = chatId.split('_');
      String targetUid = uids.firstWhere((id) => id != currentUid, orElse: () => '');
      if (targetUid.isNotEmpty) {
        GamificationService().progressTargetedQuest(targetUid);
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Marquer lu et supprimer l'éphémère
  Future<void> markEphemeralOpened(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({'isOpened': true});
  }

  Future<void> deleteEphemeralMessage(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
  }

  Future<void> sendVoiceMessage(String chatId, String audioPath, {String? replyToId, String? replyToText}) async {
    final file = File(audioPath);
    if (!file.existsSync()) return;

    try {
      final bytes = file.readAsBytesSync();
      final base64String = base64Encode(bytes);

      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'senderId': currentUid,
        'audioBase64': base64String,
        'type': 'voice',
        'replyToId': replyToId,
        'replyToText': replyToText,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': "🎙️ Vocal",
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': currentUid,
      });

      GamificationService().progressQuest('messages_sent');
      GamificationService().progressQuest('voice_messages_sent');
      
      List<String> uids = chatId.split('_');
      String targetUid = uids.firstWhere((id) => id != currentUid, orElse: () => '');
      if (targetUid.isNotEmpty) {
        GamificationService().progressTargetedQuest(targetUid);
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- PUISSANCE 4 ---
  
  // Lancer un défi Puissance 4
  Future<void> sendConnectFourChallenge(String chatId, String peerUid) async {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    // Un plateau vide fait 7x6 = 42 cases (0 = vide, 1 = moi, 2 = lui)
    List<int> emptyBoard = List.filled(42, 0);

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUid,
      'receiverId': peerUid,
      'type': 'game_connect4',
      'text': '🎮 Défi Puissance 4 lancé !',
      'timestamp': FieldValue.serverTimestamp(),
      'board': emptyBoard,
      'player1': currentUid, // Le joueur 1 est celui qui lance le défi (jetons rouges/1)
      'player2': peerUid, // Le joueur 2 (jetons jaunes/2)
      'currentTurn': peerUid, // Le défié commence
      'winner': '', // Vide si pas fini, 'draw' si égalité, ou l'UID du gagnant
    });
    
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': "🎮 Défi Puissance 4",
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUid,
    });
  }

  // Jouer un coup (mettre à jour le plateau)
  Future<void> playConnectFourMove(String chatId, String messageId, List<int> newBoard, String nextTurnUid, String winnerUid) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'board': newBoard,
      'currentTurn': nextTurnUid,
      'winner': winnerUid,
    });

    if (winnerUid.isNotEmpty) {
      // Donne la récompense à celui qui a posé le jeton final
      GamificationService().progressQuest('games_played');
    }
  }

  // --- MORPION ---
  
  Future<void> sendTicTacToeChallenge(String chatId, String peerUid) async {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    List<int> emptyBoard = List.filled(9, 0);

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUid,
      'receiverId': peerUid,
      'type': 'game_tictactoe',
      'text': '🎮 Défi Morpion lancé !',
      'timestamp': FieldValue.serverTimestamp(),
      'board': emptyBoard,
      'player1': currentUid,
      'player2': peerUid,
      'currentTurn': peerUid,
      'winner': '',
    });
    
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': "🎮 Défi Morpion",
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUid,
    });
  }

  Future<void> playTicTacToeMove(String chatId, String messageId, List<int> newBoard, String nextTurnUid, String winnerUid) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'board': newBoard,
      'currentTurn': nextTurnUid,
      'winner': winnerUid,
    });

    if (winnerUid.isNotEmpty) {
      GamificationService().progressQuest('games_played');
    }
  }
}
