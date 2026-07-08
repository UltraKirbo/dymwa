class UserProfile {
  final String id;
  final String name;
  final String? avatarBase64;
  final String activeBorder;
  final String greeting;
  final String bio;
  final String activeTitle;
  final String rpgClass;

  UserProfile({
    required this.id,
    required this.name,
    this.avatarBase64,
    this.activeBorder = 'none',
    this.greeting = '',
    this.bio = '',
    this.activeTitle = '',
    this.rpgClass = '',
  });

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      name: data['name'] ?? 'Utilisateur',
      avatarBase64: data['avatarBase64'],
      activeBorder: data['activeBorder'] ?? 'none',
      greeting: data['greeting'] ?? 'Salut !',
      bio: data['bio'] ?? '',
      activeTitle: data['activeTitle'] ?? '',
      rpgClass: data['rpgClass'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (avatarBase64 != null) 'avatarBase64': avatarBase64,
      'activeBorder': activeBorder,
      'greeting': greeting,
      'bio': bio,
      'activeTitle': activeTitle,
      'rpgClass': rpgClass,
    };
  }
}
