import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class ThemeProvider with ChangeNotifier {
  String _activeTheme = 'default';
  ThemeMode _themeMode = ThemeMode.system;
  
  String get activeTheme => _activeTheme;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    int modeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[modeIndex];
    notifyListeners();
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  // Charge le thème depuis Firestore
  Future<void> _loadTheme() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // On écoute les changements pour que si l'utilisateur achète un thème sur un autre appareil, 
      // ça change instantanément
      FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          if (data.containsKey('activeTheme')) {
            _activeTheme = data['activeTheme'];
            notifyListeners();
          }
        }
      });
    }
  }

  // Obtenir le ThemeData selon le mode système
  ThemeData getThemeData(BuildContext context, {bool isDark = false}) {
    return AppTheme.getTheme(_activeTheme, isDark);
  }

  // Appelé manuellement si besoin de forcer un rafraîchissement local
  void setActiveTheme(String themeId) {
    _activeTheme = themeId;
    notifyListeners();
  }
}
