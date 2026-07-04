import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocalStorageService {
  static const String _encountersKey = 'plaza_encounters';

  // Récupérer son propre profil complet pour l'envoyer par Bluetooth
  static Future<String> getMyProfilePayload() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "{}";

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return "{}";
    
    final data = doc.data()!;
    
    // On crée un dictionnaire léger avec juste ce qu'il faut pour la Place (StreetPass)
    Map<String, dynamic> payload = {
      'uid': uid,
      'name': data['name'] ?? 'Inconnu',
      'greeting': data['greeting'] ?? 'Salut !',
      'avatarBase64': data['avatarBase64'] ?? '',
      'rpgClass': data['rpgClass'] ?? 'Novice',
      'hobbies': data['hobbies'] ?? [],
      'country': data['country'] ?? 'fr',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    return jsonEncode(payload);
  }

  // Sauvegarder un profil reçu en Bluetooth
  static Future<void> saveEncounter(String payloadJson) async {
    try {
      final Map<String, dynamic> encounterData = jsonDecode(payloadJson);
      final String incomingUid = encounterData['uid'] ?? '';
      
      if (incomingUid.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      List<String> encountersList = prefs.getStringList(_encountersKey) ?? [];
      
      // Vérifier si on a déjà croisé cette personne aujourd'hui
      bool alreadyMet = encountersList.any((e) {
        final Map<String, dynamic> data = jsonDecode(e);
        return data['uid'] == incomingUid;
      });

      if (!alreadyMet) {
        encountersList.add(payloadJson);
        await prefs.setStringList(_encountersKey, encountersList);
        print('Rencontre sauvegardée en LOCAL : ${encounterData['name']}');
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde de la rencontre locale : $e');
    }
  }

  // Récupérer toutes les rencontres locales pour la Place
  static Future<List<Map<String, dynamic>>> getLocalEncounters() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> encountersList = prefs.getStringList(_encountersKey) ?? [];
    
    return encountersList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  // Vider les rencontres (ex: tous les 30 jours, ou manuellement)
  static Future<void> clearEncounters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_encountersKey);
  }
}
