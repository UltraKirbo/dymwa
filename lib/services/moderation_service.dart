import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationService {
  static final ModerationService _instance = ModerationService._internal();
  factory ModerationService() => _instance;
  ModerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _blockedUsersCache = {};
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blocked_users')
          .get();
          
      _blockedUsersCache.clear();
      for (var doc in snapshot.docs) {
        _blockedUsersCache.add(doc.id);
      }
      _isInitialized = true;
    } catch (e) {
      print("Erreur initialisation ModerationService: $e");
    }
  }

  bool isBlocked(String uid) {
    return _blockedUsersCache.contains(uid);
  }

  Future<void> blockUser(String targetUid, String targetName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || targetUid.isEmpty) return;

    // 1. Ajouter à la liste locale
    _blockedUsersCache.add(targetUid);

    // 2. Enregistrer dans Firestore
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('blocked_users')
        .doc(targetUid)
        .set({
      'uid': targetUid,
      'name': targetName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 3. Supprimer l'amitié (dans les deux sens)
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .doc(targetUid)
        .delete();
        
    await _firestore
        .collection('users')
        .doc(targetUid)
        .collection('friends')
        .doc(user.uid)
        .delete();
  }

  Future<void> reportUser(String targetUid, String targetName, String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || targetUid.isEmpty) return;

    await _firestore.collection('reports').add({
      'reporterUid': user.uid,
      'reportedUid': targetUid,
      'reportedName': targetName,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending'
    });
  }
}
