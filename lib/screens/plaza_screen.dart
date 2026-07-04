import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/proximity_service.dart';
import '../services/local_storage_service.dart';
import '../services/gamification_service.dart';
import '../services/chat_service.dart';
import '../services/moderation_service.dart';
import 'chat_detail_screen.dart';
import 'world_map_screen.dart';
import 'puzzle_screen.dart';
import '../theme.dart';
import '../services/gamification_service.dart';
import '../widgets/full_screen_image_viewer.dart';
import 'dart:convert';
import 'dart:math';

class PlazaScreen extends StatefulWidget {
  const PlazaScreen({super.key});

  @override
  State<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends State<PlazaScreen> {
  final ProximityService _proximityService = ProximityService();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  
  bool isScanning = false;
  bool _isTestMode = false;
  List<Map<String, dynamic>> _localEncounters = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLocalEncounters();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadLocalEncounters();
    });
  }

  Future<void> _loadLocalEncounters() async {
    final encounters = await LocalStorageService.getLocalEncounters();
    final filteredEncounters = encounters.where((e) {
      final uid = e['uid'];
      return uid != null && !ModerationService().isBlocked(uid);
    }).toList();

    if (mounted) {
      setState(() {
        _localEncounters = filteredEncounters;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _proximityService.stopAll();
    super.dispose();
  }

  Future<void> _initPermissionsAndScan() async {
    if (_isTestMode) return;
    setState(() => isScanning = true);
    
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    bool hasPermissions = statuses.values.every((status) => status.isGranted);

    if (hasPermissions) {
      void onEncounterSaved(String peerName) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nouvelle rencontre avec $peerName ! 🌟')));
          _loadLocalEncounters();
        }
      }

      await _proximityService.startAdvertising(myUid, onEncounterSaved);
      await _proximityService.startDiscovery(myUid, onEncounterSaved);
      GamificationService().progressQuest('radar_used');
    }
    
    // Auto-stop scan after 10s for UI
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => isScanning = false);
    });
  }

  Future<void> _fetchGlobalUsersForTest() async {
    if (!_isTestMode) return;
    setState(() => isScanning = true);
    try {
      // Pour le mode test, on simule l'arrivée de données P2P
      final mockData1 = jsonEncode({
        'uid': 'mock_garcon', 'name': 'Lucas (Test)', 'gender': 'Garçon', 'country': 'es', 'greeting': 'Hola !', 'rpgClass': 'Guerrier',
      });
      final mockData2 = jsonEncode({
        'uid': 'mock_fille', 'name': 'Emma (Test)', 'gender': 'Fille', 'country': 'it', 'greeting': 'Ciao !', 'rpgClass': 'Mage',
      });
      
      await LocalStorageService.saveEncounter(mockData1);
      await LocalStorageService.saveEncounter(mockData2);
      await _loadLocalEncounters();
      
      setState(() => isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rencontres simulées en mode Hors-Ligne ! 🌟')));
      }
      GamificationService().progressQuest('radar_used');
    } catch (e) {
      setState(() => isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('La Place'),
        actions: [
          Row(
            children: [
              const Icon(Icons.science, size: 20),
              Switch(
                value: _isTestMode,
                onChanged: (val) {
                  setState(() {
                    _isTestMode = val;
                    isScanning = false;
                  });
                  if (val) {
                    _proximityService.stopAll();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode Test: Simulation Globale')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode Bluetooth Actif')));
                  }
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          // Banner Atlas
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorldMapScreen())),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.indigo]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: const Row(
                children: [
                  Icon(Icons.public, color: Colors.white, size: 40),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🌍 Mon Atlas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Découvre le monde et gagne des Dym-Coins !', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          
          // Banner Puzzle (Restaurée)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PuzzleScreen())),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.deepPurple]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: const Row(
                children: [
                  Icon(Icons.extension, color: Colors.white, size: 40),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Troc de Puzzle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Complète le puzzle pour gagner des Dym-Coins !', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: _localEncounters.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 32.0, right: 32.0, bottom: 60.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar, size: 60, color: Theme.of(context).primaryColor.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            "La Place est vide.",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Mettez votre téléphone dans votre poche, activez le radar et allez vous balader pour faire des rencontres !",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : InteractiveViewer(
                    constrained: false,
                    boundaryMargin: EdgeInsets.zero,
                    minScale: 0.3,
                    maxScale: 2.0,
                    child: Container(
                      width: 1500,
                      height: 1500,
                      color: Theme.of(context).colorScheme.surface,
                      child: GridPaper(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        divisions: 2,
                        subdivisions: 4,
                        child: Stack(
                          children: _localEncounters.map((userData) {
                            String peerUid = userData['uid'] ?? 'unknown';
                            Random rand = Random(peerUid.hashCode);
                            double left = rand.nextDouble() * 1300 + 50;
                            double top = rand.nextDouble() * 1300 + 50;
                            
                            return Positioned(
                              left: left,
                              top: top,
                              child: _buildPlazaAvatar(userData),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90), // Pour éviter la barre de navigation
        child: FloatingActionButton.extended(
          onPressed: isScanning ? null : (_isTestMode ? _fetchGlobalUsersForTest : _initPermissionsAndScan),
          icon: isScanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.radar),
          label: Text(isScanning ? 'Recherche...' : 'Scanner'),
        ),
      ),
    );
  }

  Widget _buildPlazaAvatar(Map<String, dynamic> userData) {
    final String peerUid = userData['uid'] ?? '';
    final name = userData['name'] ?? 'Inconnu';
    final rpgClass = userData['rpgClass'] ?? 'Novice 🔰';
    final greeting = userData['greeting'] ?? 'Salut !';
    final avatarBase64 = userData['avatarBase64'];
    final activeBorder = userData['activeBorder'] ?? 'none';
    final activeTitle = userData['activeTitle'] ?? '';

    return GestureDetector(
      onTap: () => _showUserDialog(peerUid, name, greeting, avatarBase64, activeBorder, activeTitle),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
            constraints: const BoxConstraints(maxWidth: 120),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('"$greeting"', style: const TextStyle(color: Colors.white, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
          Container(
            padding: activeBorder != 'none' ? const EdgeInsets.all(3) : EdgeInsets.zero,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: GamificationService.getBorderGradient(activeBorder),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey.shade800,
              child: avatarBase64 != null && avatarBase64.isNotEmpty
                  ? ClipOval(child: Image.memory(base64Decode(avatarBase64), width: 60, height: 60, fit: BoxFit.cover))
                  : const Icon(Icons.person, size: 30, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(8)),
            child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showUserDialog(String peerUid, String name, String greeting, String? avatarBase64, String activeBorder, String activeTitle) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'report') _showReportDialog(peerUid, name);
                    if (value == 'block') _showBlockDialog(peerUid, name);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'report', child: Text('Signaler')),
                    const PopupMenuItem(value: 'block', child: Text('Bloquer', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (avatarBase64 != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(base64Image: avatarBase64, tag: 'plaza_avatar_$peerUid'),
                    ));
                  }
                },
                child: Container(
                  padding: activeBorder != 'none' ? const EdgeInsets.all(4) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: GamificationService.getBorderGradient(activeBorder),
                  ),
                  child: Hero(
                    tag: 'plaza_avatar_$peerUid',
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade800,
                      child: avatarBase64 != null
                          ? ClipOval(child: Image.memory(base64Decode(avatarBase64), width: 100, height: 100, fit: BoxFit.cover))
                          : const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (activeTitle.isNotEmpty)
                Text(activeTitle, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('"$greeting"', style: const TextStyle(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context); // Close dialog
                  final chatId = await ChatService().createOrGetChat(peerUid, name);
                  if (mounted) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(chatId: chatId, peerId: peerUid, peerName: name)
                    ));
                  }
                },
                icon: const Icon(Icons.chat),
                label: const Text('Discuter'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(String peerUid, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Signaler $name"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Faux profil / Spam"),
              onTap: () {
                ModerationService().reportUser(peerUid, name, "Spam");
                Navigator.pop(context);
                Navigator.pop(context); // Fermer le profil
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé.')));
              },
            ),
            ListTile(
              title: const Text("Contenu inapproprié"),
              onTap: () {
                ModerationService().reportUser(peerUid, name, "Inapproprié");
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé.')));
              },
            ),
            ListTile(
              title: const Text("Harcèlement"),
              onTap: () {
                ModerationService().reportUser(peerUid, name, "Harcèlement");
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé.')));
              },
            ),
          ],
        ),
      )
    );
  }

  void _showBlockDialog(String peerUid, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Bloquer cet utilisateur ?"),
        content: Text("Vous ne croiserez plus jamais $name sur La Place, et il ne pourra plus vous contacter."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ModerationService().blockUser(peerUid, name);
              if (mounted) {
                Navigator.pop(context); // fermer dialog blocage
                Navigator.pop(context); // fermer dialog profil
                _loadLocalEncounters(); // rafraichir la place
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur bloqué.')));
              }
            },
            child: const Text("Bloquer", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }
}
