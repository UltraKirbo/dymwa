import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/slime_avatar.dart';

class SlimeMakerScreen extends StatefulWidget {
  const SlimeMakerScreen({super.key});

  @override
  State<SlimeMakerScreen> createState() => _SlimeMakerScreenState();
}

class _SlimeMakerScreenState extends State<SlimeMakerScreen> {
  String _color = 'blue';
  int _eyes = 0;
  int _mouth = 0;
  int _accessory = 0;
  bool _isLoading = true;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final config = data['slimeConfig'];
        if (config != null) {
          setState(() {
            _color = config['color'] ?? 'blue';
            _eyes = config['eyes'] ?? 0;
            _mouth = config['mouth'] ?? 0;
            _accessory = config['accessory'] ?? 0;
          });
        }
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'slimeConfig': {
          'color': _color,
          'eyes': _eyes,
          'mouth': _mouth,
          'accessory': _accessory,
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar Slime sauvegardé ! 🌟')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final slimeConfig = {
      'color': _color,
      'eyes': _eyes,
      'mouth': _mouth,
      'accessory': _accessory,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slime Maker'),
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: const Text('Terminer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          // Zône de prévisualisation
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Center(
              child: SlimeAvatar(config: slimeConfig, size: 200),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Couleur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildColorButton('red', Colors.red),
                    _buildColorButton('blue', Colors.blue),
                    _buildColorButton('green', Colors.green),
                    _buildColorButton('yellow', Colors.amber),
                    _buildColorButton('purple', Colors.purple),
                    _buildColorButton('pink', Colors.pink),
                    _buildColorButton('black', Colors.grey.shade800),
                  ],
                ),
                const SizedBox(height: 24),
                
                const Text('Yeux', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOptionButton('Normaux', _eyes == 0, () => setState(() => _eyes = 0)),
                    _buildOptionButton('Fâchés', _eyes == 1, () => setState(() => _eyes = 1)),
                    _buildOptionButton('Mignons', _eyes == 2, () => setState(() => _eyes = 2)),
                  ],
                ),
                const SizedBox(height: 24),
                
                const Text('Bouche', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOptionButton('Sourire', _mouth == 0, () => setState(() => _mouth = 0)),
                    _buildOptionButton('Triste', _mouth == 1, () => setState(() => _mouth = 1)),
                    _buildOptionButton('Surpris', _mouth == 2, () => setState(() => _mouth = 2)),
                  ],
                ),
                const SizedBox(height: 24),

                const Text('Accessoire', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildOptionButton('Aucun', _accessory == 0, () => setState(() => _accessory = 0)),
                    _buildOptionButton('Couronne', _accessory == 1, () => setState(() => _accessory = 1)),
                    _buildOptionButton('Casquette', _accessory == 2, () => setState(() => _accessory = 2)),
                    _buildOptionButton('Lunettes', _accessory == 3, () => setState(() => _accessory = 3)),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(String colorName, Color colorValue) {
    final isSelected = _color == colorName;
    return GestureDetector(
      onTap: () => setState(() => _color = colorName),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorValue,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
          boxShadow: isSelected ? [BoxShadow(color: colorValue.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)] : [],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
