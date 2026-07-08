import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'gamification_service.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // 1. Envoyer une demande d'ami
  Future<void> sendFriendRequest(String targetUid) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) return;

    // Récupérer mes infos pour la notification
    final myDoc = await _firestore.collection('users').doc(currentUid).get();
    final myName = myDoc.data()?['name'] ?? "Quelqu'un";

    // Ajouter la requête chez le destinataire
    await _firestore
        .collection('users')
        .doc(targetUid)
        .collection('friend_requests')
        .doc(currentUid)
        .set({
      'uid': currentUid,
      'name': myName,
      'timestamp': FieldValue.serverTimestamp(),
    });

  }

  // 2. Accepter une demande
  Future<void> acceptFriendRequest(String requesterUid) async {
    if (currentUid.isEmpty || requesterUid.isEmpty) return;

    // Récupérer les infos du requérant
    final requesterDoc = await _firestore.collection('users').doc(requesterUid).get();
    final requesterName = requesterDoc.data()?['name'] ?? "Ami";

    // Récupérer mes infos
    final myDoc = await _firestore.collection('users').doc(currentUid).get();
    final myName = myDoc.data()?['name'] ?? "Ami";

    // Ajouter à ma liste d'amis
    await _firestore.collection('users').doc(currentUid).collection('friends').doc(requesterUid).set({
      'uid': requesterUid,
      'name': requesterName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // M'ajouter à sa liste d'amis
    await _firestore.collection('users').doc(requesterUid).collection('friends').doc(currentUid).set({
      'uid': currentUid,
      'name': myName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Supprimer la demande
    await deleteFriendRequest(requesterUid);

    // Récompense de gamification
    GamificationService().progressQuest('friends_added');

  }

  // 3. Refuser ou annuler une demande
  Future<void> deleteFriendRequest(String requesterUid) async {
    await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('friend_requests')
        .doc(requesterUid)
        .delete();
  }

  // 4. Flux (Stream) des demandes d'amis en attente
  Stream<QuerySnapshot> getPendingRequests() {
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('friend_requests')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 5. Flux (Stream) de la liste d'amis
  Stream<QuerySnapshot> getFriends() {
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('friends')
        .orderBy('name')
        .snapshots();
  }

  // Vérifier le statut de l'amitié avec quelqu'un
  // 0 = Rien, 1 = Demande Envoyée, 2 = Demande Reçue, 3 = Amis
  Future<int> checkFriendStatus(String targetUid) async {
    if (currentUid.isEmpty || targetUid.isEmpty) return 0;

    // Vérifier si amis
    final friendDoc = await _firestore.collection('users').doc(currentUid).collection('friends').doc(targetUid).get();
    if (friendDoc.exists) return 3;

    // Vérifier si j'ai envoyé une demande (elle est chez lui)
    final sentRequest = await _firestore.collection('users').doc(targetUid).collection('friend_requests').doc(currentUid).get();
    if (sentRequest.exists) return 1;

    // Vérifier si j'ai reçu une demande (elle est chez moi)
    final receivedRequest = await _firestore.collection('users').doc(currentUid).collection('friend_requests').doc(targetUid).get();
    if (receivedRequest.exists) return 2;

    return 0;
  }
}
