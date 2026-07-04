import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class PlazaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> registerEncounter(String peerUid) async {
    if (uid.isEmpty || peerUid == uid) return;

    final myDoc = await _firestore.collection('users').doc(uid).get();
    final peerDoc = await _firestore.collection('users').doc(peerUid).get();

    if (!myDoc.exists || !peerDoc.exists) return;

    final myData = myDoc.data()!;
    final peerData = peerDoc.data()!;

    final myGender = myData['gender'] ?? 'Garçon'; // Par défaut
    final myPreference = myData['preference'] ?? 'Les deux';
    final peerGender = peerData['gender'] ?? 'Garçon';
    final peerPreference = peerData['preference'] ?? 'Les deux';

    // Logique de filtre strict (gestion des pluriels)
    bool iWantThem = (myPreference == 'Les deux') || 
                     (myPreference == 'Garçons' && peerGender == 'Garçon') || 
                     (myPreference == 'Filles' && peerGender == 'Fille');
                     
    bool theyWantMe = (peerPreference == 'Les deux') || 
                      (peerPreference == 'Garçons' && myGender == 'Garçon') || 
                      (peerPreference == 'Filles' && myGender == 'Fille');

    if (!iWantThem || !theyWantMe) {
      // Incompatibilité, on ignore silencieusement la rencontre
      return;
    }

    final plazaRef = _firestore.collection('users').doc(uid).collection('plaza').doc(peerUid);
    final plazaDoc = await plazaRef.get();

    // Si on ne l'a jamais rencontré
    if (!plazaDoc.exists) {
      // 1. L'ajouter à la place
      await plazaRef.set({
        'metAt': FieldValue.serverTimestamp(),
        'uid': peerUid,
      });

      // 2. Débloquer le pays du joueur rencontré
      final peerCountry = peerData['country'];
      if (peerCountry != null) {
        List<dynamic> unlockedCountries = myData['unlockedCountries'] ?? [];
        if (!unlockedCountries.contains(peerCountry)) {
          await _firestore.collection('users').doc(uid).update({
            'unlockedCountries': FieldValue.arrayUnion([peerCountry]),
            'coins': FieldValue.increment(100),
          });
        }
      }
    }
  }

  Stream<QuerySnapshot> getPlazaUsers() {
    return _firestore.collection('users').doc(uid).collection('plaza')
        .orderBy('metAt', descending: true)
        .snapshots();
  }
}
