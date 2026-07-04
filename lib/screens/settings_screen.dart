import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _bgStreetPassEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bgStreetPassEnabled = prefs.getBool('background_streetpass_enabled') ?? false;
      _isLoading = false;
    });
  }

  void _toggleBackgroundService(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_streetpass_enabled', val);
    setState(() => _bgStreetPassEnabled = val);

    final service = FlutterBackgroundService();
    if (val) {
      service.startService();
    } else {
      service.invoke('stopService');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('GÉNÉRAL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.surface,
            title: const Text('Mode StreetPass en continu', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Scanne le Bluetooth en arrière-plan (consomme plus de batterie).', style: TextStyle(fontSize: 12)),
            secondary: const Icon(Icons.radar, color: Colors.greenAccent),
            value: _bgStreetPassEnabled,
            onChanged: _toggleBackgroundService,
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('APPARENCE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('Système (Défaut)'),
                      value: ThemeMode.system,
                      groupValue: themeProvider.themeMode,
                      onChanged: (val) { if (val != null) themeProvider.setThemeMode(val); },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Clair'),
                      value: ThemeMode.light,
                      groupValue: themeProvider.themeMode,
                      onChanged: (val) { if (val != null) themeProvider.setThemeMode(val); },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Sombre'),
                      value: ThemeMode.dark,
                      groupValue: themeProvider.themeMode,
                      onChanged: (val) { if (val != null) themeProvider.setThemeMode(val); },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('COMPTE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.surface,
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Se déconnecter', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
}
