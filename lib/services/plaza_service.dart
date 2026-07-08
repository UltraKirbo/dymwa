import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class PlazaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<String> _getLocationSilently() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return 'Lieu inconnu';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return 'Lieu inconnu';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String city = place.locality ?? place.subAdministrativeArea ?? '';
        String country = place.country ?? '';
        if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
        if (city.isNotEmpty) return city;
        if (country.isNotEmpty) return country;
      }
    } catch (e) {
      // Échec silencieux
    }
    return 'Lieu inconnu';
  }

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
      String locationName = await _getLocationSilently();

      // 1. L'ajouter à la place
      await plazaRef.set({
        'metAt': FieldValue.serverTimestamp(),
        'metLocation': locationName,
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
