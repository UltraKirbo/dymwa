import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/rpg_utils.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  
  int _currentPage = 0;
  bool _isLoading = false;

  // Step 1: Credentials
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Step 2: Identity
  final _nameController = TextEditingController();
  final _greetingController = TextEditingController();
  String _country = 'fr';

  // Step 3: Affinités
  String _gender = 'Garçon';
  String _preference = 'Les deux';

  // Step 4: Hobbies
  List<String> _selectedHobbies = [];

  final Map<String, String> _availableCountries = {
    'fr': '🇫🇷 France', 'us': '🇺🇸 États-Unis', 'gb': '🇬🇧 Royaume-Uni', 'jp': '🇯🇵 Japon',
    'br': '🇧🇷 Brésil', 'ca': '🇨🇦 Canada', 'de': '🇩🇪 Allemagne', 'it': '🇮🇹 Italie',
    'es': '🇪🇸 Espagne', 'pt': '🇵🇹 Portugal', 'kr': '🇰🇷 Corée du Sud', 'cn': '🇨🇳 Chine',
    'in': '🇮🇳 Inde', 'au': '🇦🇺 Australie', 'be': '🇧🇪 Belgique', 'ch': '🇨🇭 Suisse',
    'ru': '🇷🇺 Russie', 'mx': '🇲🇽 Mexique', 'ar': '🇦🇷 Argentine', 'za': '🇿🇦 Afrique du Sud',
    'ma': '🇲🇦 Maroc', 'dz': '🇩🇿 Algérie', 'tn': '🇹🇳 Tunisie', 'eg': '🇪🇬 Égypte',
    'sn': '🇸🇳 Sénégal', 'ci': '🇨🇮 Côte d\'Ivoire', 'tr': '🇹🇷 Turquie', 'gr': '🇬🇷 Grèce',
    'se': '🇸🇪 Suède', 'no': '🇳🇴 Norvège', 'dk': '🇩🇰 Danemark', 'fi': '🇫🇮 Finlande',
    'nl': '🇳🇱 Pays-Bas', 'ie': '🇮🇪 Irlande', 'pl': '🇵🇱 Pologne', 'ua': '🇺🇦 Ukraine',
  };

  void _nextPage() {
    if (_currentPage == 0) {
      if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir l\'email et le mot de passe.')));
        return;
      }
    } else if (_currentPage == 1) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir un pseudo.')));
        return;
      }
    }
    
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _onHobbyToggle(String hobby) {
    setState(() {
      if (_selectedHobbies.contains(hobby)) {
        _selectedHobbies.remove(hobby);
      } else {
        if (_selectedHobbies.length < 5) {
          _selectedHobbies.add(hobby);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 passions')));
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedHobbies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir au moins une passion.')));
      return;
    }

    setState(() => _isLoading = true);

    String calculatedClass = RpgUtils.calculateClass(_selectedHobbies);

    try {
      await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
        _country,
        _selectedHobbies,
        calculatedClass,
        _greetingController.text.trim(),
        _gender,
        _preference,
      );
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Indicateur de progression
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Row(
                children: List.generate(4, (index) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    decoration: BoxDecoration(
                      color: index <= _currentPage ? colors.primary : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )),
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildStep1(colors),
                  _buildStep2(colors),
                  _buildStep3(colors),
                  _buildStep4(colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.radar_rounded, size: 100, color: colors.primary),
          const SizedBox(height: 24),
          const Text('Rejoignez l\'Aventure', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Créez votre compte pour rencontrer le monde entier.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _nextPage,
              child: const Text('Continuer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.badge, size: 80, color: colors.secondary),
          const SizedBox(height: 24),
          const Text('Votre Carte d\'Identité', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Comment doit-on vous appeler sur La Place ?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Pseudo',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _greetingController,
            decoration: InputDecoration(
              labelText: 'Phrase d\'accroche (Optionnel)',
              hintText: "Salut, moi c'est...",
              prefixIcon: const Icon(Icons.chat_bubble_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _country,
            decoration: InputDecoration(
              labelText: 'Votre Pays (Pour l\'Atlas)',
              prefixIcon: const Icon(Icons.public),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _availableCountries.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _country = val);
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              TextButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('Retour')),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextPage,
                child: const Text('Continuer'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStep3(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.favorite, size: 80, color: colors.error),
          const SizedBox(height: 24),
          const Text('Vos Affinités', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Qui souhaitez-vous croiser sur l\'application ?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: InputDecoration(
              labelText: 'Je suis...',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'Garçon', child: Text('Un Garçon')),
              DropdownMenuItem(value: 'Fille', child: Text('Une Fille')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _gender = val);
            },
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _preference,
            decoration: InputDecoration(
              labelText: 'Je souhaite rencontrer...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'Garçons', child: Text('Uniquement des Garçons')),
              DropdownMenuItem(value: 'Filles', child: Text('Uniquement des Filles')),
              DropdownMenuItem(value: 'Les deux', child: Text('Des Garçons et des Filles')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _preference = val);
            },
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              TextButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('Retour')),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextPage,
                child: const Text('Continuer'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStep4(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Icon(Icons.stars, size: 80, color: colors.tertiary),
          const SizedBox(height: 24),
          const Text('Vos Passions', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Sélectionnez vos centres d\'intérêt (jusqu\'à 5).', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: RpgUtils.availableHobbies.map((hobby) {
              final isSelected = _selectedHobbies.contains(hobby);
              return ChoiceChip(
                label: Text(hobby),
                selected: isSelected,
                onSelected: (_) => _onHobbyToggle(hobby),
                selectedColor: colors.primary.withValues(alpha: 0.3),
                checkmarkColor: colors.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              TextButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('Retour')),
              const Spacer(),
              ElevatedButton(
                onPressed: _selectedHobbies.isEmpty || _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Rejoindre l\'Aventure', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
