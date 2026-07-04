import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/proximity_service.dart';
import '../services/plaza_service.dart';
import '../services/gamification_service.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'world_map_screen.dart';
import 'puzzle_screen.dart';
import '../theme.dart';
import '../services/gamification_service.dart';
import 'dart:convert';
import 'dart:math';

class PlazaScreen extends StatefulWidget {
  const PlazaScreen({super.key});

  @override
  State<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends State<PlazaScreen> {
  final ProximityService _proximityService = ProximityService();
  final PlazaService _plazaService = PlazaService();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  
  bool isScanning = false;
  bool _isTestMode = false;

  @override
  void dispose() {
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
      await _proximityService.startAdvertising(myUid);
      
      await _proximityService.startDiscovery(
        (endpointId, peerUid) async {
          await _plazaService.registerEncounter(peerUid);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nouvelle rencontre StreetPass ! 🌟')));
          }
        },
        (endpointId) {
          GamificationService().progressQuest('radar_used');
        },
      );
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
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      for (var doc in snapshot.docs) {
        if (doc.id != myUid) {
          await _plazaService.registerEncounter(doc.id);
        }
      }
      setState(() => isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nouvelles rencontres simulées ! 🌟')));
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _plazaService.getPlazaUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("La Place est vide.\nScannez les environs pour croiser du monde !", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
                }
                
                return InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(500),
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
                        children: docs.map((doc) {
                          String peerUid = doc['uid'];
                          Random rand = Random(peerUid.hashCode);
                          double left = rand.nextDouble() * 1300 + 50;
                          double top = rand.nextDouble() * 1300 + 50;
                          
                          return Positioned(
                            left: left,
                            top: top,
                            child: _buildPlazaAvatar(peerUid),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
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

  Widget _buildPlazaAvatar(String peerUid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(peerUid).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox(width: 40, height: 40, child: CircularProgressIndicator());
        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
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
                  child: avatarBase64 != null
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
              Container(
                padding: activeBorder != 'none' ? const EdgeInsets.all(4) : EdgeInsets.zero,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: GamificationService.getBorderGradient(activeBorder),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade800,
                  child: avatarBase64 != null
                      ? ClipOval(child: Image.memory(base64Decode(avatarBase64), width: 100, height: 100, fit: BoxFit.cover))
                      : const Icon(Icons.person, size: 50, color: Colors.white),
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
}
