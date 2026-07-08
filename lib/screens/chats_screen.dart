import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_detail_screen.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import '../services/moderation_service.dart';
import '../theme.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(25.0),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                dividerColor: Colors.transparent, // Supprime le trait du bas
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Discussions'),
                  Tab(text: 'Amis'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildChatsTab(),
                _buildFriendsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    final ChatService chatService = ChatService();
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot>(
      stream: chatService.getChats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Afficher le lien dans la console noire de l'ordinateur
          print('\n\n🔥 LIEN POUR L\'INDEX FIREBASE : \n${snapshot.error}\n\n');
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                'Erreur Firebase (Vous pouvez maintenant copier le lien ci-dessous) :\n\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // On filtre pour ne garder que les conversations avec au moins 1 message et non bloquées
        final chats = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lastMsg = data['lastMessage'] as String?;
          if (lastMsg == null || lastMsg.trim().isEmpty) return false;
          
          String peerId = "";
          for (String key in data.keys) {
            if (key.startsWith('user_') && key != 'user_$myUid') {
              peerId = key.substring(5);
            }
          }
          if (ModerationService().isBlocked(peerId)) return false;
          return true;
        }).toList();

        if (chats.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_outline, size: 80, color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Aucune discussion en cours.",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Vos échanges apparaîtront ici. Allez dans 'Amis' pour commencer à discuter !",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            final chatId = chats[index].id;
            
            // Trouver le nom et l'ID du destinataire
            String peerName = "Ami";
            String peerId = "";
            for (String key in chat.keys) {
              if (key.startsWith('user_') && key != 'user_$myUid') {
                peerName = chat[key];
                peerId = key.substring(5); // enlever 'user_'
              }
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(peerId).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
                    peerName = userData['name'];
                  }
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                    title: Text(peerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(chat['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            chatId: chatId,
                            peerName: peerName,
                            peerId: peerId,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FriendService().getFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.people_outline, size: 80, color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Vous n'avez pas encore d'amis.",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Utilisez le Radar sur La Place pour faire des rencontres et ajouter des amis !",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        final friends = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index].data() as Map<String, dynamic>;
            final peerId = friend['uid'];
            final peerName = friend['name'];

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                title: Text(peerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.chat_bubble, color: Theme.of(context).primaryColor),
                    onPressed: () async {
                      // Démarrer ou retrouver le chat
                      final chatId = await ChatService().createOrGetChat(peerId, peerName);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              chatId: chatId,
                              peerName: peerName,
                              peerId: peerId,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
