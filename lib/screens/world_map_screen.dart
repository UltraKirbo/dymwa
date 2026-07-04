import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atlas des Rencontres'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Simuler une rencontre',
            onPressed: () async {
              // Simuler une rencontre pour débloquer un pays au hasard
              final available = ['fr', 'us', 'gb', 'jp', 'br', 'ca', 'de', 'it', 'es', 'pt', 'kr', 'cn', 'in', 'au', 'ru', 'za', 'br'];
              final code = (available.toList()..shuffle()).first;
              
              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                'unlockedCountries': FieldValue.arrayUnion([code]),
                'coins': FieldValue.increment(100),
              });
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rencontre simulée ! Pays débloqué : $code')));
              }
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final List<dynamic> unlockedCountriesRaw = data['unlockedCountries'] ?? [];
          final Set<String> unlockedCountries = unlockedCountriesRaw.map((e) => e.toString().toLowerCase()).toSet();

          // Préparer les couleurs pour la carte
          Map<String, Color> mapColors = {};
          
          Color getColorForCountry(String code) {
            const Map<String, String> continentMap = {
              // Europe
              'fr': 'EU', 'gb': 'EU', 'de': 'EU', 'it': 'EU', 'es': 'EU', 'pt': 'EU', 'be': 'EU', 'ch': 'EU',
              'ru': 'EU', 'tr': 'EU', 'gr': 'EU', 'se': 'EU', 'no': 'EU', 'dk': 'EU', 'fi': 'EU', 'nl': 'EU',
              'ie': 'EU', 'pl': 'EU', 'ua': 'EU', 'ro': 'EU',
              // Asia
              'jp': 'AS', 'kr': 'AS', 'cn': 'AS', 'in': 'AS', 'vn': 'AS', 'th': 'AS', 'id': 'AS', 'my': 'AS',
              'ph': 'AS', 'il': 'AS', 'sa': 'AS', 'ae': 'AS', 'qa': 'AS',
              // North America
              'us': 'NA', 'ca': 'NA', 'mx': 'NA', 'cu': 'NA', 'jm': 'NA',
              // South America
              'br': 'SA', 'ar': 'SA', 'co': 'SA', 'cl': 'SA', 'pe': 'SA', 've': 'SA',
              // Africa
              'za': 'AF', 'ma': 'AF', 'dz': 'AF', 'tn': 'AF', 'eg': 'AF', 'sn': 'AF', 'ci': 'AF',
              // Oceania
              'au': 'OC', 'nz': 'OC',
            };

            final continent = continentMap[code] ?? 'UNKNOWN';

            switch (continent) {
              case 'EU': return Colors.blue; 
              case 'AS': return Colors.red; 
              case 'NA': return Colors.orange; 
              case 'SA': return Colors.green; 
              case 'AF': return Colors.amber; 
              case 'OC': return Colors.purple; 
              default: return Colors.teal; 
            }
          }

          for (String code in unlockedCountries) {
            mapColors[code] = getColorForCountry(code);
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  border: Border(bottom: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.2))),
                ),
                child: Column(
                  children: [
                    const Text('Pays Découverts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('${unlockedCountries.length} / 195', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: isDark ? const Color(0xFF121212) : const Color(0xFFE8F1F5), // Fond uni, doux et discret
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 1.0, // On ne peut pas dézoomer plus que la taille de l'écran
                      maxScale: 4.0,
                      boundaryMargin: EdgeInsets.zero, // Pas de marge en dehors de la carte
                      constrained: true, // La carte s'adapte à l'écran par défaut
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SimpleMap(
                        instructions: SMapWorld.instructions,
                        defaultColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        colors: mapColors,
                        callback: (id, name, tapDetails) {
                          if (unlockedCountries.contains(id.toString().toLowerCase())) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vous avez rencontré quelqu\'un de ce pays : $name !'), backgroundColor: Colors.green));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pays non débloqué ($name).'), backgroundColor: Colors.orange));
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ],
          );
        },
      )
    );
  }
}
