import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../services/gamification_service.dart';
import '../utils/rpg_utils.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _greetingController = TextEditingController(); // Phrase de salutation
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  String? _avatarBase64;
  String _activeBorder = 'none';
  String _activeTitle = '';
  String? _rpgClass;
  String _country = 'fr'; // Pays par défaut
  String _gender = 'Garçon';
  String _preference = 'Les deux';
  List<String> _selectedHobbies = [];
  
  final Map<String, String> _availableCountries = {
    'fr': '🇫🇷 France',
    'us': '🇺🇸 États-Unis',
    'gb': '🇬🇧 Royaume-Uni',
    'jp': '🇯🇵 Japon',
    'br': '🇧🇷 Brésil',
    'ca': '🇨🇦 Canada',
    'de': '🇩🇪 Allemagne',
    'it': '🇮🇹 Italie',
    'es': '🇪🇸 Espagne',
    'pt': '🇵🇹 Portugal',
    'kr': '🇰🇷 Corée du Sud',
    'cn': '🇨🇳 Chine',
    'in': '🇮🇳 Inde',
    'au': '🇦🇺 Australie',
    'be': '🇧🇪 Belgique',
    'ch': '🇨🇭 Suisse',
    'ru': '🇷🇺 Russie',
    'mx': '🇲🇽 Mexique',
    'ar': '🇦🇷 Argentine',
    'za': '🇿🇦 Afrique du Sud',
    'ma': '🇲🇦 Maroc',
    'dz': '🇩🇿 Algérie',
    'tn': '🇹🇳 Tunisie',
    'eg': '🇪🇬 Égypte',
    'sn': '🇸🇳 Sénégal',
    'ci': '🇨🇮 Côte d\'Ivoire',
    'tr': '🇹🇷 Turquie',
    'gr': '🇬🇷 Grèce',
    'se': '🇸🇪 Suède',
    'no': '🇳🇴 Norvège',
    'dk': '🇩🇰 Danemark',
    'fi': '🇫🇮 Finlande',
    'nl': '🇳🇱 Pays-Bas',
    'ie': '🇮🇪 Irlande',
    'pl': '🇵🇱 Pologne',
    'ua': '🇺🇦 Ukraine',
    'ro': '🇷🇴 Roumanie',
    'vn': '🇻🇳 Vietnam',
    'th': '🇹🇭 Thaïlande',
    'id': '🇮🇩 Indonésie',
    'my': '🇲🇾 Malaisie',
    'ph': '🇵🇭 Philippines',
    'nz': '🇳🇿 Nouvelle-Zélande',
    'co': '🇨🇴 Colombie',
    'cl': '🇨🇱 Chili',
    'pe': '🇵🇪 Pérou',
    've': '🇻🇪 Venezuela',
    'cu': '🇨🇺 Cuba',
    'jm': '🇯🇲 Jamaïque',
    'il': '🇮🇱 Israël',
    'sa': '🇸🇦 Arabie Saoudite',
    'ae': '🇦🇪 Émirats Arabes Unis',
    'qa': '🇶🇦 Qatar',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _greetingController.text = data['greeting'] ?? '';
        _avatarBase64 = data['avatarBase64'];
        _activeBorder = data['activeBorder'] ?? 'none';
        _activeTitle = data['activeTitle'] ?? '';
        _rpgClass = data['rpgClass'];
        _country = data['country'] ?? 'fr';
        _gender = data['gender'] ?? 'Garçon';
        _preference = data['preference'] ?? 'Les deux';
        if (data['hobbies'] != null) {
          _selectedHobbies = List<String>.from(data['hobbies']);
        }
      }
    }
    setState(() => _isLoading = false);
  }

  void _onHobbyToggle(String hobby, StateSetter setModalState) {
    setModalState(() {
      if (_selectedHobbies.contains(hobby)) {
        _selectedHobbies.remove(hobby);
      } else {
        if (_selectedHobbies.length < 5) {
          _selectedHobbies.add(hobby);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 hobbies')));
        }
      }
      if (_selectedHobbies.isNotEmpty) {
        _rpgClass = RpgUtils.calculateClass(_selectedHobbies);
      } else {
        _rpgClass = null;
      }
    });
  }

  void _showHobbiesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choisissez jusqu\'à 5 passe-temps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RpgUtils.availableHobbies.map((hobby) {
                      final isSelected = _selectedHobbies.contains(hobby);
                      return ChoiceChip(
                        label: Text(hobby),
                        selected: isSelected,
                        onSelected: (_) => _onHobbyToggle(hobby, setModalState),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _selectedHobbies.isNotEmpty ? () {
                      Navigator.pop(context);
                      _saveProfile();
                    } : null,
                    child: const Text('Valider'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }



  Future<void> _saveProfile() async {
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'greeting': _greetingController.text.trim(),
        if (_avatarBase64 != null) 'avatarBase64': _avatarBase64,
        if (_rpgClass != null) 'rpgClass': _rpgClass,
        'country': _country,
        'gender': _gender,
        'preference': _preference,
        if (_selectedHobbies.isNotEmpty) 'hobbies': _selectedHobbies,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour !')),
        );
      }
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 300);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _avatarBase64 = base64Encode(bytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  Container(
                    padding: _activeBorder != 'none' ? const EdgeInsets.all(6) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: GamificationService.getBorderGradient(_activeBorder),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade800,
                      child: _avatarBase64 != null
                          ? ClipOval(child: Image.memory(base64Decode(_avatarBase64!), width: 120, height: 120, fit: BoxFit.cover))
                          : const Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
          ),
          if (_activeTitle.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                _activeTitle,
                style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom d\'utilisateur',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _greetingController,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'Phrase de salutation (StreetPass)',
              hintText: 'Ex: J\'aime les chats !',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _country,
            decoration: const InputDecoration(
              labelText: 'Mon Pays (StreetPass)',
              border: OutlineInputBorder(),
            ),
            items: _availableCountries.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _country = val);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _gender,
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Je suis...', 
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _preference,
                  decoration: const InputDecoration(labelText: 'Je cherche...', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Garçons', child: Text('Garçons')),
                    DropdownMenuItem(value: 'Filles', child: Text('Filles')),
                    DropdownMenuItem(value: 'Les deux', child: Text('Les deux')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _preference = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.surface,
            leading: const Icon(Icons.shield, color: Colors.purpleAccent),
            title: Text(_selectedHobbies.isNotEmpty ? 'Mes Passions' : 'Définir mes passions'),
            subtitle: _selectedHobbies.isNotEmpty ? Text(_selectedHobbies.join(' - ')) : const Text('Choisis tes centres d\'intérêt !'),
            trailing: const Icon(Icons.edit),
            onTap: _showHobbiesDialog,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }
}
