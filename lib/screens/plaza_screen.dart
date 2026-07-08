import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../widgets/slime_avatar.dart';
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
        'slimeConfig': {'color': 'red', 'eyes': 1, 'mouth': 5, 'accessory': 5},
      });
      final mockData2 = jsonEncode({
        'uid': 'mock_fille', 'name': 'Emma (Test)', 'gender': 'Fille', 'country': 'it', 'greeting': 'Ciao !', 'rpgClass': 'Mage',
        'slimeConfig': {'color': 'cyan', 'eyes': 2, 'mouth': 3, 'accessory': 4},
      });
      final mockData3 = jsonEncode({
        'uid': 'mock_ninja', 'name': 'Yuki (Test)', 'gender': 'Garçon', 'country': 'jp', 'greeting': 'Konichiwa !', 'rpgClass': 'Voleur',
        'slimeConfig': {'color': 'black', 'eyes': 0, 'mouth': 0, 'accessory': 6},
      });
      final mockData4 = jsonEncode({
        'uid': 'mock_king', 'name': 'Arthur (Test)', 'gender': 'Garçon', 'country': 'gb', 'greeting': 'Hello mate!', 'rpgClass': 'Paladin',
        'slimeConfig': {'color': 'yellow', 'eyes': 4, 'mouth': 4, 'accessory': 1},
      });
      
      await LocalStorageService.saveEncounter(mockData1);
      await LocalStorageService.saveEncounter(mockData2);
      await LocalStorageService.saveEncounter(mockData3);
      await LocalStorageService.saveEncounter(mockData4);
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
                          Icon(Icons.radar, size: 60, color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
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
                    trackpadScrollCausesScale: true,
                    child: Container(
                      width: 1500,
                      height: 1500,
                      child: CustomPaint(
                        painter: PlazaMapPainter(),
                        child: Stack(
                          children: _localEncounters.map((userData) {
                            String peerUid = userData['uid'] ?? 'unknown';
                            return WanderingSlime(
                              key: ValueKey(peerUid),
                              userData: userData,
                              onTap: () => _showUserDialog(peerUid, userData),
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

  String _getFlag(String countryCode) {
    if (countryCode.length != 2) return "🌍";
    int flagOffset = 0x1F1E6;
    int asciiOffset = 0x41;
    String country = countryCode.toUpperCase();
    int firstChar = country.codeUnitAt(0) - asciiOffset + flagOffset;
    int secondChar = country.codeUnitAt(1) - asciiOffset + flagOffset;
    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }

  void _showUserDialog(String peerUid, Map<String, dynamic> userData) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    String metLocation = 'Lieu inconnu';
    String metAtString = 'Inconnue';

    if (myUid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(myUid).collection('plaza').doc(peerUid).get();
        if (doc.exists) {
          metLocation = doc.data()?['metLocation'] ?? 'Lieu inconnu';
          final ts = doc.data()?['metAt'];
          if (ts != null) {
            DateTime dt = ts.toDate();
            metAtString = "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}";
          }
        }
      } catch (e) {}
    }

    if (!mounted) return;

    final name = userData['name'] ?? 'Inconnu';
    final greeting = userData['greeting'] ?? 'Salut !';
    final activeTitle = userData['activeTitle'] ?? '';
    final country = userData['country'] ?? 'fr';
    final rpgClass = userData['rpgClass'] ?? 'Novice';
    final config = userData['slimeConfig'] ?? {};

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
              SlimeAvatar(config: config, size: 120),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_getFlag(country), style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              if (activeTitle.isNotEmpty)
                Text(activeTitle, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
              Text(rpgClass, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('"$greeting"', style: const TextStyle(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(metAtString, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(metLocation, style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis)),
                ],
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

class PlazaMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Herbe de base
    final grassPaint = Paint()..color = Colors.lightGreen.shade400;
    canvas.drawRect(Offset.zero & size, grassPaint);

    // 2. Rivière
    final riverPaint = Paint()..color = Colors.blue.shade300..style = PaintingStyle.stroke..strokeWidth = 100..strokeCap = StrokeCap.round;
    Path riverPath = Path();
    riverPath.moveTo(0, size.height * 0.2);
    riverPath.quadraticBezierTo(size.width * 0.5, size.height * 0.4, size.width * 0.3, size.height * 0.8);
    riverPath.quadraticBezierTo(size.width * 0.2, size.height * 1.1, size.width * 0.8, size.height);
    canvas.drawPath(riverPath, riverPaint);

    // 3. Taches d'herbe foncée
    final darkGrass = Paint()..color = Colors.lightGreen.shade600..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.2), 150, darkGrass);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.5), 200, darkGrass);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.9), 120, darkGrass);
    
    // 4. Chemins en terre
    final pathPaint = Paint()..color = Colors.brown.shade300.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 40..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.2), Offset(size.width * 0.5, size.height * 0.5), pathPaint);
    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.5), Offset(size.width * 0.8, size.height * 0.5), pathPaint);
    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.5), Offset(size.width * 0.5, size.height * 0.9), pathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WanderingSlime extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onTap;
  const WanderingSlime({super.key, required this.userData, required this.onTap});

  @override
  State<WanderingSlime> createState() => _WanderingSlimeState();
}

class _WanderingSlimeState extends State<WanderingSlime> with SingleTickerProviderStateMixin {
  late AnimationController _moveController;
  late Animation<Offset> _positionAnimation;
  
  Offset _currentPos = const Offset(750, 750);
  Offset _targetPos = const Offset(750, 750);
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    // Initialize random start position (avoiding absolute edges)
    _currentPos = Offset(_rand.nextDouble() * 1300 + 100, _rand.nextDouble() * 1300 + 100);
    _targetPos = _currentPos;

    _moveController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _moveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(Duration(milliseconds: 1000 + _rand.nextInt(3000)), () {
          if (mounted) _pickNewDestination();
        });
      }
    });
    
    // Démarrage décalé
    Future.delayed(Duration(milliseconds: _rand.nextInt(2000)), () {
      if (mounted) _pickNewDestination();
    });
  }

  void _pickNewDestination() {
    _currentPos = _targetPos;
    // Déplacement aléatoire dans un rayon de 300 à 600 px
    double dx = (_rand.nextDouble() - 0.5) * 800;
    double dy = (_rand.nextDouble() - 0.5) * 800;
    
    double newX = (_currentPos.dx + dx).clamp(100, 1400);
    double newY = (_currentPos.dy + dy).clamp(100, 1400);
    _targetPos = Offset(newX, newY);
    
    double distance = (_targetPos - _currentPos).distance;
    if (distance < 50) return; // Ignore if too close
    
    int durationMs = (distance * 15).toInt().clamp(2000, 10000); // Vitesse : 15ms par pixel
    
    _moveController.duration = Duration(milliseconds: durationMs);
    _positionAnimation = Tween<Offset>(begin: _currentPos, end: _targetPos).animate(CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));
    
    _moveController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userData['name'] ?? 'Inconnu';
    final config = widget.userData['slimeConfig'] ?? {};
    final greeting = widget.userData['greeting'] ?? '';

    return AnimatedBuilder(
      animation: _moveController,
      builder: (context, child) {
        final pos = _moveController.isAnimating ? _positionAnimation.value : _currentPos;
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (greeting.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                    child: Text(greeting, style: const TextStyle(color: Colors.black, fontSize: 10, fontStyle: FontStyle.italic)),
                  ),
                SlimeAvatar(config: config, size: 80),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

