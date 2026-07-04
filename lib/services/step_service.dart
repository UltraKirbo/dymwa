import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class StepService {
  static final StepService _instance = StepService._internal();
  factory StepService() => _instance;
  StepService._internal();

  StreamSubscription<StepCount>? _stepCountStream;
  int _todaySteps = 0;
  
  // Expose le nombre de pas d'aujourd'hui pour l'UI
  Stream<int> get todayStepsStream => _todayStepsController.stream;
  final _todayStepsController = StreamController<int>.broadcast();

  Future<void> init() async {
    // Demander la permission
    if (await Permission.activityRecognition.request().isGranted) {
      _startListening();
    }
  }

  void _startListening() {
    _stepCountStream = Pedometer.stepCountStream.listen((StepCount event) {
      _handleStepCount(event.steps);
    }, onError: (error) {
      print('Erreur Pédomètre: $error');
    });
  }

  Future<void> _handleStepCount(int totalStepsSinceReboot) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    
    // 1. Gérer les pas du jour (pour l'affichage)
    final savedDate = prefs.getString('step_baseline_date');
    int baseline = prefs.getInt('step_baseline_value') ?? -1;

    if (savedDate != todayStr || baseline == -1) {
      // Nouveau jour ou premier lancement : on fixe la baseline
      baseline = totalStepsSinceReboot;
      await prefs.setString('step_baseline_date', todayStr);
      await prefs.setInt('step_baseline_value', baseline);
    }

    _todaySteps = totalStepsSinceReboot - baseline;
    if (_todaySteps < 0) {
      // Le téléphone a redémarré (les pas retombent à 0)
      baseline = 0;
      await prefs.setInt('step_baseline_value', baseline);
      _todaySteps = totalStepsSinceReboot;
    }
    
    _todayStepsController.add(_todaySteps);

    // 2. Convertir les pas en Dym-Coins (1 pièce / 100 pas)
    int lastProcessed = prefs.getInt('last_processed_steps') ?? -1;
    
    if (lastProcessed == -1 || totalStepsSinceReboot < lastProcessed) {
      // Premier lancement ou reboot du téléphone
      lastProcessed = totalStepsSinceReboot;
      await prefs.setInt('last_processed_steps', lastProcessed);
      return;
    }

    int stepsDiff = totalStepsSinceReboot - lastProcessed;
    int coinsEarned = stepsDiff ~/ 100; // Division entière

    if (coinsEarned > 0) {
      // On a gagné des pièces !
      await _addCoins(coinsEarned);
      // On met à jour le dernier palier traité
      lastProcessed += (coinsEarned * 100);
      await prefs.setInt('last_processed_steps', lastProcessed);
    }
  }

  Future<void> _addCoins(int amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Pour l'instant on garde le solde sur Firebase comme demandé (ou on peut le passer full local plus tard)
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'coins': FieldValue.increment(amount),
      });
      print('Bravo ! Tu as gagné $amount Dym-Coins grâce à tes pas !');
    } catch (e) {
      print('Erreur lors de l\'ajout des pièces : $e');
    }
  }

  void dispose() {
    _stepCountStream?.cancel();
    _todayStepsController.close();
  }
}
