import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'gamification_service.dart';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // Créer une nouvelle Story avec une image
  Future<void> createStory(File imageFile) async {
    try {
      // 1. Upload de l'image sur Firebase Storage
      final String fileName = 'story_${DateTime.now().millisecondsSinceEpoch}_$currentUid.jpg';
      final Reference ref = _storage.ref().child('stories').child(fileName);
      
      await ref.putFile(imageFile);
      
      // 2. Récupérer le lien public de l'image
      final String downloadUrl = await ref.getDownloadURL();

      // 3. Sauvegarder la Story dans la base de données Firestore
      await _firestore.collection('stories').add({
        'authorId': currentUid,
        'imageUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Gamification
      GamificationService().progressQuest('stories_posted');
    } catch (e) {
      throw "Erreur lors de l'envoi de la Story : $e";
    }
  }

  // Récupérer les 20 dernières Stories
  Stream<QuerySnapshot> getRecentStories() {
    return _firestore
        .collection('stories')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }
}
