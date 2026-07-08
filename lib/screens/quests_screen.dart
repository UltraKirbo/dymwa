import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gamification_service.dart';
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
             var qData = GamificationService.dailyQuestsConfig[qId];
             if (qData == null) continue;
             
             String action = qData['action'];
             String key = qData['key'];
             int requiredCount = qData['required_count'];
             int progress = 0;
             
             if (action == 'messages_sent') progress = quests['daily_messages'] ?? 0;
             else if (action == 'image_sent') progress = quests['daily_image'] ?? 0;
             else if (action == 'voice_messages_sent') progress = quests['daily_voice'] ?? 0;
             else if (action == 'games_played') progress = quests['daily_games'] ?? 0;
             else if (action == 'friends_added') progress = quests['daily_friends'] ?? 0;
             else if (action == 'daily_target_messages') progress = quests['daily_target_messages'] ?? 0;
             
             bool isClaimed = quests[key] ?? false;
             bool isCompleted = progress >= requiredCount;
             
             if (isClaimed) completedDailies++;
             
             String title = qData['title'] ?? 'Quête';
             String subtitle = qData['subtitle'] ?? 'Objectif';
             if (qId == 'daily_target_friend') {
               String tName = quests['daily_target_name'] ?? '';
               if (tName.isNotEmpty) subtitle = "Envoyer un message à $tName";
             }
             
             dailyQuestWidgets.add(_buildQuestCard(
                context: context,
                title: title,
                subtitle: subtitle,
                progress: progress,
                maxProgress: requiredCount,
                reward: qData['reward'] ?? 0,
                isCompleted: isCompleted,
                isClaimed: isClaimed,
                icon: _getIconFromName(qData['icon'] ?? ''),
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
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
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
                    color: Colors.grey.withValues(alpha: 0.1),
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
                              ? Colors.amber.withValues(alpha: 0.2) 
                              : Colors.grey.withValues(alpha: 0.05),
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
                        // Les Quêtes Permanentes sont générées dynamiquement
                        ...GamificationService.permanentQuestsConfig.entries.map((entry) {
                           final qData = entry.value;
                           String action = qData['action'];
                           String key = qData['key'];
                           int requiredCount = qData['required_count'];
                           int progress = quests[action] ?? 0; // L'action correspond à la clé de progression permanente
                           bool isClaimed = quests[key] ?? false;
                           bool isCompleted = progress >= requiredCount;

                           return _buildQuestCard(
                             context: context,
                             title: qData['title'] ?? 'Quête',
                             subtitle: qData['subtitle'] ?? 'Objectif',
                             progress: progress,
                             maxProgress: requiredCount,
                             reward: qData['reward'] ?? 0,
                             isCompleted: isCompleted,
                             isClaimed: isClaimed,
                             icon: _getIconFromName(qData['icon'] ?? ''),
                           );
                        }).toList(),
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

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'chat_bubble_rounded': return Icons.chat_bubble_rounded;
      case 'camera_alt_rounded': return Icons.camera_alt_rounded;
      case 'mic_rounded': return Icons.mic_rounded;
      case 'gamepad_rounded': return Icons.gamepad_rounded;
      case 'person_add_alt_1_rounded': return Icons.person_add_alt_1_rounded;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'forum_rounded': return Icons.forum_rounded;
      case 'group_add_rounded': return Icons.group_add_rounded;
      default: return Icons.stars;
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
                    color: isCompleted ? primaryColor : primaryColor.withValues(alpha: 0.1),
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
                    color: primaryColor.withValues(alpha: 0.1),
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
                          color: Colors.grey.withValues(alpha: 0.15),
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
                            colors: [primaryColor.withValues(alpha: 0.7), primaryColor],
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
