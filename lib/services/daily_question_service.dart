import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyQuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // 30 questions pré-définies
  final List<String> _questions = [
    "Quel est ton plus grand rêve, même s'il paraît impossible ?",
    "Si tu pouvais avoir un super-pouvoir pendant 24h, que choisirais-tu ?",
    "Quel est le dernier film ou la dernière série qui t'a vraiment marqué ?",
    "Si tu devais manger un seul plat pour le reste de ta vie ?",
    "Quelle est ta musique 'plaisir coupable' absolue ?",
    "Quel est ton meilleur souvenir de vacances ?",
    "Quelle est la pire honte de ta vie ?",
    "Si tu gagnais à l'EuroMillions demain, quelle est la première chose que tu achèterais ?",
    "Quel est ton talent inutile caché ?",
    "Si tu pouvais dîner avec n'importe qui (vivant ou mort), qui serait-ce ?",
    "Quel est l'endroit le plus incroyable que tu aies visité ?",
    "Si tu devais vivre dans un univers fictif, ce serait lequel ?",
    "Quel est ton jeu vidéo d'enfance préféré ?",
    "Quel métier voulais-tu faire quand tu étais petit(e) ?",
    "Quel est le pire cadeau que tu aies jamais reçu ?",
    "Quel est le meilleur conseil qu'on t'ait jamais donné ?",
    "Si tu pouvais retourner dans le passé, à quelle époque irais-tu ?",
    "Quelle est la chose la plus folle que tu aies faite ?",
    "Si tu devais changer de prénom, que choisirais-tu ?",
    "Quelle est ta plus grande phobie ?",
    "Quel est ton mot préféré dans la langue française ?",
    "Si tu devais te réincarner en animal, lequel serais-tu ?",
    "Quel est le dernier mensonge que tu as dit ?",
    "Si ta maison prenait feu, quel objet sauverais-tu en premier ?",
    "Quelle est ta pire habitude ?",
    "Si tu pouvais parler couramment n'importe quelle langue, laquelle choisirais-tu ?",
    "Quel est le meilleur repas que tu aies jamais mangé ?",
    "Si tu étais un personnage historique, qui serais-tu ?",
    "Quelle est la chanson qui te met instantanément de bonne humeur ?",
    "Quel est ton plus grand accomplissement jusqu'à présent ?"
  ];

  String get todayKey {
    DateTime now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String getQuestionOfTheDay() {
    int daysSinceEpoch = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(0)).inDays;
    int index = daysSinceEpoch % _questions.length;
    return _questions[index];
  }

  // --- REPONSES (ANSWERS) ---

  Future<bool> hasAnsweredToday() async {
    if (currentUid.isEmpty) return false;
    final docId = "${todayKey}_$currentUid";
    final doc = await _firestore.collection('daily_answers').doc(docId).get();
    return doc.exists;
  }
  
  Stream<bool> hasAnsweredTodayStream() {
    if (currentUid.isEmpty) return Stream.value(false);
    final docId = "${todayKey}_$currentUid";
    return _firestore.collection('daily_answers').doc(docId).snapshots().map((doc) => doc.exists);
  }

  Future<void> postAnswer(String text) async {
    if (currentUid.isEmpty || text.trim().isEmpty) return;
    
    final docId = "${todayKey}_$currentUid";
    final userDoc = await _firestore.collection('users').doc(currentUid).get();
    final name = userDoc.data()?['name'] ?? 'Moi';
    
    await _firestore.collection('daily_answers').doc(docId).set({
      'uid': currentUid,
      'name': name,
      'dateKey': todayKey,
      'question': getQuestionOfTheDay(),
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'replyCount': 0,
    });
  }

  // Renvoie un stream filtré côté client pour éviter d'imposer un index composite complexe sur Firebase
  Stream<List<DocumentSnapshot>> getFriendsAnswers(List<String> friendUids) {
    List<String> uids = List.from(friendUids);
    if (!uids.contains(currentUid)) {
      uids.add(currentUid); // Inclure sa propre réponse
    }
    
    return _firestore
        .collection('daily_answers')
        .where('dateKey', isEqualTo: todayKey)
        .snapshots()
        .map((snapshot) {
           var docs = snapshot.docs.where((doc) {
             final data = doc.data();
             return uids.contains(data['uid']);
           }).toList();
           
           docs.sort((a, b) {
             final tA = a.data()['timestamp'] as Timestamp?;
             final tB = b.data()['timestamp'] as Timestamp?;
             if (tA == null || tB == null) return 0;
             return tB.compareTo(tA); // Tri décroissant (plus récent au plus ancien)
           });
           
           return docs;
        });
  }

  // --- REPLIES (THREADS) ---

  Future<void> postReply(String answerDocId, String text) async {
    if (currentUid.isEmpty || text.trim().isEmpty) return;
    
    final userDoc = await _firestore.collection('users').doc(currentUid).get();
    final name = userDoc.data()?['name'] ?? 'Moi';
    
    final answerRef = _firestore.collection('daily_answers').doc(answerDocId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(answerRef);
      if (!snapshot.exists) return;
      
      final replyRef = answerRef.collection('replies').doc();
      transaction.set(replyRef, {
        'uid': currentUid,
        'name': name,
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      int currentCount = (snapshot.data() as Map<String, dynamic>)['replyCount'] ?? 0;
      transaction.update(answerRef, {'replyCount': currentCount + 1});
    });
  }

  // Les replies sont triées par ordre chronologique naturel car c'est un seul champ
  Stream<QuerySnapshot> getReplies(String answerDocId) {
    return _firestore
        .collection('daily_answers')
        .doc(answerDocId)
        .collection('replies')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
