import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});
  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  void _claimReward(List<dynamic> pieces) async {
    if (pieces.length >= 9) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'puzzlePieces': [],
        'coins': FieldValue.increment(1000)
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Puzzle terminé ! +1000 Dym-Coins')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Troc de Puzzle')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final List<dynamic> rawPieces = data['puzzlePieces'] ?? [];
          final Set<int> pieces = rawPieces.map((e) => e as int).toSet();
          
          bool isComplete = pieces.length >= 9;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Rencontrez des gens sur La Place pour obtenir de nouvelles pièces !', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).primaryColor, width: 4),
                  boxShadow: AppTheme.softShadow,
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    bool hasPiece = pieces.contains(index);
                    return Container(
                      decoration: BoxDecoration(
                        color: hasPiece ? Colors.greenAccent : Colors.grey.shade800,
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Center(
                        child: Icon(
                          hasPiece ? Icons.extension : Icons.lock_outline,
                          color: hasPiece ? Colors.black54 : Colors.white24,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              Text('${pieces.length} / 9 Pièces', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isComplete ? () => _claimReward(rawPieces) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isComplete ? Colors.amber : Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Réclamer la récompense (1000 Coins)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      )
    );
  }
}
