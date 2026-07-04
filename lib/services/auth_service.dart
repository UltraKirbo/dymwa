import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Écouter les changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  User? get currentUser => _auth.currentUser;

  // Inscription avec création de profil dans Firestore
  Future<void> signUpWithEmail(String email, String password, String name, String country, List<String> hobbies, String rpgClass, String greeting, String gender, String preference) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'name': name,
          'country': country,
          'hobbies': hobbies,
          'rpgClass': rpgClass,
          'gender': gender,
          'preference': preference,
          'greeting': greeting.isNotEmpty ? greeting : "Salut ! J'utilise dymwa.",
          'bio': "Nouvel explorateur !",
          'photoUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
          // Gamification
          'coins': 100, // Bonus de bienvenue !
          'activeTheme': 'default',
          'unlockedThemes': ['default'],
        });
        
        // Sauvegarder le token pour les notifications
        await NotificationService().saveTokenToDatabase();
      }
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Erreur lors de l'inscription";
    }
  }

  // Connexion
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await NotificationService().saveTokenToDatabase();
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Erreur lors de la connexion";
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
