import 'dart:async';
import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'chats_screen.dart';
import 'plaza_screen.dart';
import 'feed_screen.dart';
import 'quests_screen.dart';
import 'shop_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friend_service.dart';
import '../services/gamification_service.dart' as import_gamification;
import 'call_screen.dart' as import_call_screen;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    // Initialise les quêtes quotidiennes (tirage au sort)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      import_gamification.GamificationService().checkDailyQuestsSetup();
    });
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('calleeId', isEqualTo: currentUid)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final roomId = change.doc.id;
          final callerId = data['callerId'];
          if (callerId != null) {
            _showIncomingCallDialog(roomId, callerId);
          }
        }
      }
    });
  }

  Future<void> _showIncomingCallDialog(String roomId, String callerId) async {
    // Éviter d'afficher plusieurs fois pour le même appel en récupérant d'abord les infos
    final doc = await FirebaseFirestore.instance.collection('users').doc(callerId).get();
    if (!doc.exists) return;
    
    final callerName = doc.data()?['name'] ?? "Quelqu'un";
    
    // Déterminer le chatId
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    List<String> ids = [currentUid, callerId];
    ids.sort();
    final chatId = ids.join("_");

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("📞 Appel entrant", style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
          content: Text("$callerName vous appelle !", style: const TextStyle(color: Colors.white70, fontSize: 18), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            GestureDetector(
              onTap: () {
                FirebaseFirestore.instance.collection('calls').doc(roomId).delete();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                child: const Icon(Icons.call_end, color: Colors.white, size: 36),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => import_call_screen.CallScreen(
                      chatId: chatId,
                      peerName: callerName,
                      isCaller: false,
                      roomId: roomId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                child: const Icon(Icons.call, color: Colors.white, size: 36),
              ),
            ),
          ],
        );
      }
    );
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true, // Pour que le contenu passe sous la barre flottante
      appBar: AppBar(
        title: const Text('dymwa', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: -0.5)),
        centerTitle: false, // Plus moderne à gauche
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FriendService().getPendingRequests(),
            builder: (context, snapshot) {
              int requestCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      _showFriendRequests(context);
                    },
                  ),
                  if (requestCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$requestCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.storefront, color: Colors.amber),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          )
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats', 0, theme),
                _buildNavItem(Icons.storefront_outlined, Icons.storefront, 'La Place', 1, theme),
                _buildNavItem(Icons.public_outlined, Icons.public, 'Le Fil', 2, theme),
                _buildNavItem(Icons.emoji_events_outlined, Icons.emoji_events, 'Quêtes', 3, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index, ThemeData theme) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey(isSelected),
                  color: isSelected ? theme.primaryColor : Colors.grey.shade600,
                  size: 26,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    Widget currentScreen;
    if (_currentIndex == 0) {
      currentScreen = const ChatsScreen(key: ValueKey('chats'));
    } else if (_currentIndex == 1) {
      currentScreen = const PlazaScreen(key: ValueKey('plaza'));
    } else if (_currentIndex == 2) {
      currentScreen = const FeedScreen(key: ValueKey('feed'));
    } else {
      currentScreen = const QuestsScreen(key: ValueKey('quests'), showAppBar: false);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05), // Léger glissement vers le haut
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: currentScreen,
    );
  }

  void _showFriendRequests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FriendService().getPendingRequests(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final requests = snapshot.data!.docs;
            
            if (requests.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text("Aucune demande d'ami en attente.", style: TextStyle(color: Colors.grey))),
              );
            }
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Demandes d'amis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(req['name'] ?? 'Inconnu'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () {
                                FriendService().acceptFriendRequest(req['uid']);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () {
                                FriendService().deleteFriendRequest(req['uid']);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      }
    );
  }
}
