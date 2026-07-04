import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shop_screen.dart';
import '../theme.dart';

class QuestsScreen extends StatelessWidget {
  final bool showAppBar;
  const QuestsScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final primaryColor = Theme.of(context).primaryColor;

    Widget body = DefaultTabController(
      length: 2,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final quests = data['questProgress'] as Map<String, dynamic>? ?? {};
          final int coins = data['coins'] ?? 0;

          int messagesSent = quests['messages_sent'] ?? 0;
          
          int friendsAdded = quests['friends_added'] ?? 0;
          bool friendsAddedClaimed = quests['friends_added_claimed'] ?? false;
          
          int voiceMessagesSent = quests['voice_messages_sent'] ?? 0;
          bool voiceMessagesSentClaimed = quests['voice_messages_sent_claimed'] ?? false;
          
          int gamesPlayed = quests['games_played'] ?? 0;
          bool gamesPlayedClaimed = quests['games_played_claimed'] ?? false;
          
          bool dailyBonusClaimed = quests['daily_bonus_claimed'] ?? false;
          
          List<dynamic> dailyList = quests['daily_quests_list'] ?? [];
          int completedDailies = 0;
          List<Widget> dailyQuestWidgets = [];
          
          for (String qId in dailyList) {
             var qData = _getQuestData(qId, quests);
             if (qData.isEmpty) continue;
             
             if (qData['isClaimed'] == true) {
               completedDailies++;
             }
             
             dailyQuestWidgets.add(_buildQuestCard(
                context: context,
                title: qData['title'],
                subtitle: qData['subtitle'],
                progress: qData['progress'],
                maxProgress: qData['maxProgress'],
                reward: qData['reward'],
                isCompleted: qData['isCompleted'],
                isClaimed: qData['isClaimed'],
                icon: qData['icon'],
             ));
          }
          
          return Column(
            children: [
              // --- HEADER: Solde et Boutique ---
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Solde actuel',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.white, size: 36),
                            const SizedBox(width: 8),
                            Text(
                              '$coins', 
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
                      },
                      icon: const Icon(Icons.storefront, color: Colors.black87),
                      label: const Text('Boutique', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    )
                  ],
                ),
              ),

              // --- ONGLETS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(25.0),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade600,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(text: 'Quotidiennes'),
                      Tab(text: 'Permanentes'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- CONTENU DES ONGLETS ---
              Expanded(
                child: TabBarView(
                  children: [
                    // Onglet Quotidiennes
                    ListView(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                      children: [
                        // Bonus Grand Chelem
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: dailyBonusClaimed 
                              ? Colors.amber.withOpacity(0.2) 
                              : Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: dailyBonusClaimed ? Colors.amber : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.stars, color: dailyBonusClaimed ? Colors.amber : Colors.grey),
                                      const SizedBox(width: 8),
                                      const Text('Bonus Grand Chelem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  Text(
                                    '$completedDailies/3', 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: completedDailies == 3 ? Colors.amber : Colors.grey
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text('Complétez les 3 quêtes quotidiennes pour remporter 50 Dym-Coins supplémentaires !', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        
                        ...dailyQuestWidgets,
                      ],
                    ),
                    // Onglet Permanentes
                    ListView(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                      children: [
                        _buildQuestCard(
                          context: context,
                          title: 'L\'art de la conversation',
                          subtitle: 'Envoyer 100 messages au total',
                          progress: messagesSent,
                          maxProgress: 100,
                          reward: 500,
                          isCompleted: messagesSent >= 100,
                          isClaimed: messagesSent >= 100,
                          icon: Icons.forum_rounded,
                        ),
                        _buildQuestCard(
                          context: context,
                          title: 'Réseau Élargi',
                          subtitle: 'Ajouter 10 amis au total',
                          progress: friendsAdded,
                          maxProgress: 10,
                          reward: 300,
                          isCompleted: friendsAdded >= 10,
                          isClaimed: friendsAddedClaimed,
                          icon: Icons.group_add_rounded,
                        ),
                        _buildQuestCard(
                          context: context,
                          title: 'La Voix d\'Or',
                          subtitle: 'Envoyer 5 messages vocaux',
                          progress: voiceMessagesSent,
                          maxProgress: 5,
                          reward: 150,
                          isCompleted: voiceMessagesSent >= 5,
                          isClaimed: voiceMessagesSentClaimed,
                          icon: Icons.mic_rounded,
                        ),
                        _buildQuestCard(
                          context: context,
                          title: 'Grand Maître',
                          subtitle: 'Terminer 3 parties de Puissance 4',
                          progress: gamesPlayed,
                          maxProgress: 3,
                          reward: 200,
                          isCompleted: gamesPlayed >= 3,
                          isClaimed: gamesPlayedClaimed,
                          icon: Icons.gamepad_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (showAppBar) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quêtes', style: TextStyle(fontWeight: FontWeight.bold))),
        body: body,
      );
    }
    return body;
  }

  Map<String, dynamic> _getQuestData(String questId, Map<String, dynamic> quests) {
    switch (questId) {
      case 'daily_send_image':
        int prog = quests['daily_image'] ?? 0;
        return {
          'title': 'Le Photographe',
          'subtitle': 'Envoyer 1 photo',
          'progress': prog,
          'maxProgress': 1,
          'reward': 10,
          'isCompleted': prog >= 1,
          'isClaimed': quests['daily_image_claimed'] ?? false,
          'icon': Icons.camera_alt_rounded,
        };
      case 'daily_send_voice':
        int prog = quests['daily_voice'] ?? 0;
        return {
          'title': 'La Voix d\'Or',
          'subtitle': 'Envoyer 1 message vocal',
          'progress': prog,
          'maxProgress': 1,
          'reward': 10,
          'isCompleted': prog >= 1,
          'isClaimed': quests['daily_voice_claimed'] ?? false,
          'icon': Icons.mic_rounded,
        };
      case 'daily_play_game':
        int prog = quests['daily_games'] ?? 0;
        return {
          'title': 'Le Stratège',
          'subtitle': 'Terminer 1 partie de Puissance 4',
          'progress': prog,
          'maxProgress': 1,
          'reward': 15,
          'isCompleted': prog >= 1,
          'isClaimed': quests['daily_games_claimed'] ?? false,
          'icon': Icons.gamepad_rounded,
        };
      case 'daily_send_messages_5':
        int prog = quests['daily_messages'] ?? 0;
        return {
          'title': 'Le Bavard',
          'subtitle': 'Envoyer 5 messages au total',
          'progress': prog,
          'maxProgress': 5,
          'reward': 20,
          'isCompleted': prog >= 5,
          'isClaimed': quests['daily_messages_claimed'] ?? false,
          'icon': Icons.chat_bubble_rounded,
        };
      case 'daily_add_friend':
        int prog = quests['daily_friends'] ?? 0;
        return {
          'title': 'Le Radar',
          'subtitle': 'Ajouter 1 nouvel ami',
          'progress': prog,
          'maxProgress': 1,
          'reward': 15,
          'isCompleted': prog >= 1,
          'isClaimed': quests['daily_friends_claimed'] ?? false,
          'icon': Icons.person_add_alt_1_rounded,
        };
      case 'daily_target_friend':
        int prog = quests['daily_target_messages'] ?? 0;
        String tName = quests['daily_target_name'] ?? '';
        return {
          'title': 'Prendre des nouvelles',
          'subtitle': 'Envoyer un message à $tName',
          'progress': prog,
          'maxProgress': 1,
          'reward': 15,
          'isCompleted': prog >= 1,
          'isClaimed': quests['daily_target_claimed'] ?? false,
          'icon': Icons.volunteer_activism,
        };
      default:
        return {};
    }
  }

  Widget _buildQuestCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int progress,
    required int maxProgress,
    required int reward,
    required bool isCompleted,
    required bool isClaimed,
    required IconData icon,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final double percentage = progress / maxProgress;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCompleted ? primaryColor : primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: isCompleted ? Colors.white : primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+$reward', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 4),
                      Icon(Icons.monetization_on, color: primaryColor, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        height: 12,
                        width: percentage > 1 ? double.infinity : (MediaQuery.of(context).size.width - 72) * percentage, // 72 = margins
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor.withOpacity(0.7), primaryColor],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '$progress / $maxProgress',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
            if (isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Icon(isClaimed ? Icons.check_circle : Icons.stars, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isClaimed ? 'Récompense réclamée' : 'Quête terminée !', 
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
