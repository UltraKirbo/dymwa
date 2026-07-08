import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gamification_service.dart';
import '../services/ad_service.dart';
import '../theme.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final primaryColor = Theme.of(context).primaryColor;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Boutique', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Thèmes'),
              Tab(text: 'Bordures'),
              Tab(text: 'Titres'),
            ],
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final int coins = data['coins'] ?? 0;
            final String lastAdDate = data['last_ad_date'] ?? '';
            final String todayStr = DateTime.now().toIso8601String().substring(0, 10);
            final bool hasWatchedAdToday = lastAdDate == todayStr;

            return Column(
              children: [
                // --- HEADER SOLDE ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    border: Border(bottom: BorderSide(color: primaryColor.withValues(alpha: 0.1))),
                  ),
                  child: Column(
                    children: [
                      const Text('Solde Disponible', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monetization_on, color: primaryColor, size: 40),
                          const SizedBox(width: 12),
                          Text('$coins', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color, letterSpacing: -2)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // BOUTON PUBLICITÉ
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: ElevatedButton.icon(
                          onPressed: hasWatchedAdToday ? null : () {
                            AdService().showRewardedAd(() {
                              GamificationService().addCoins(50);
                              FirebaseFirestore.instance.collection('users').doc(uid).set({
                                'last_ad_date': todayStr
                              }, SetOptions(merge: true));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('+50 Dym-Coins ajoutés !'),
                                  backgroundColor: Colors.green,
                                ));
                              }
                            });
                          },
                          icon: Icon(hasWatchedAdToday ? Icons.check_circle : Icons.play_circle_filled, size: 24),
                          label: Text(
                            hasWatchedAdToday ? 'Revenez demain' : 'Regarder une pub (+50)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasWatchedAdToday ? Colors.grey : primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // --- TAB BAR VIEW ---
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildThemesGrid(data),
                      _buildBordersGrid(data),
                      _buildTitlesGrid(data),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildThemesGrid(Map<String, dynamic> data) {
    final List<dynamic> unlocked = data['unlockedThemes'] ?? ['default'];
    final String active = data['activeTheme'] ?? 'default';

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: GamificationService.themePrices.length,
      itemBuilder: (context, index) {
        final themeId = GamificationService.themePrices.keys.elementAt(index);
        final price = GamificationService.themePrices[themeId]!;
        return _buildCard(
          context: context, 
          itemId: themeId, 
          price: price, 
          isUnlocked: unlocked.contains(themeId), 
          isActive: active == themeId, 
          itemType: 'theme'
        );
      },
    );
  }

  Widget _buildBordersGrid(Map<String, dynamic> data) {
    final List<dynamic> unlocked = data['unlockedBorders'] ?? ['none'];
    final String active = data['activeBorder'] ?? 'none';

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: GamificationService.borderPrices.length,
      itemBuilder: (context, index) {
        final borderId = GamificationService.borderPrices.keys.elementAt(index);
        final price = GamificationService.borderPrices[borderId]!;
        return _buildCard(
          context: context, 
          itemId: borderId, 
          price: price, 
          isUnlocked: unlocked.contains(borderId), 
          isActive: active == borderId, 
          itemType: 'border'
        );
      },
    );
  }

  Widget _buildTitlesGrid(Map<String, dynamic> data) {
    final List<dynamic> unlocked = data['unlockedTitles'] ?? [''];
    final String active = data['activeTitle'] ?? '';
    
    // On filtre le titre vide ("") pour ne pas avoir de trou dans la grille
    final availableTitles = GamificationService.titlePrices.keys.where((t) => t.isNotEmpty).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: availableTitles.length,
      itemBuilder: (context, index) {
        final titleId = availableTitles[index];
        final price = GamificationService.titlePrices[titleId]!;
        return _buildCard(
          context: context, 
          itemId: titleId, 
          price: price, 
          isUnlocked: unlocked.contains(titleId), 
          isActive: active == titleId, 
          itemType: 'title'
        );
      },
    );
  }

  Widget _buildCard({required BuildContext context, required String itemId, required int price, required bool isUnlocked, required bool isActive, required String itemType}) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isActive ? primaryColor : Colors.transparent, width: 2),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PREVIEW
          Expanded(
            flex: 3,
            child: Container(
              decoration: itemType == 'theme' ? BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                gradient: _getThemeGradient(itemId),
              ) : null,
              child: itemType == 'theme' 
                ? (isActive ? const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8.0), child: CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.check, size: 16, color: Colors.green)))) : null)
                : itemType == 'border'
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: GamificationService.getBorderGradient(itemId),
                        ),
                        child: const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, color: Colors.white, size: 30),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(itemId, style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.orange, fontSize: 18), textAlign: TextAlign.center),
                    ),
            ),
          ),
          
          // INFOS
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        itemId.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      if (!isUnlocked)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$price', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(width: 4),
                            const Icon(Icons.monetization_on, color: Colors.grey, size: 14),
                          ],
                        ),
                    ],
                  ),
                  
                  // BOUTON
                  if (isActive)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('Actif', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
                    )
                  else if (isUnlocked)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          if (itemType == 'theme') GamificationService().equipTheme(itemId);
                          else if (itemType == 'border') GamificationService().equipBorder(itemId);
                          else GamificationService().equipTitle(itemId);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Équiper'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          bool success = false;
                          if (itemType == 'theme') success = await GamificationService().buyTheme(itemId);
                          else if (itemType == 'border') success = await GamificationService().buyBorder(itemId);
                          else success = await GamificationService().buyTitle(itemId);

                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Débloqué !'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dym-Coins insuffisants !'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('Acheter', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient? _getThemeGradient(String themeId) {
    switch (themeId) {
      case 'default': return const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF69F0AE)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'ocean': return const LinearGradient(colors: [Color(0xFF00B0FF), Color(0xFF40C4FF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'sunset': return const LinearGradient(colors: [Color(0xFFFF3D00), Color(0xFFFF9E80)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'cyberpunk': return const LinearGradient(colors: [Color(0xFFD500F9), Color(0xFFFF4081)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default: return const LinearGradient(colors: [Colors.grey, Colors.black38]);
    }
  }
}
