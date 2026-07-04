class RpgUtils {
  static final List<String> availableHobbies = [
    "Sport", "Lecture", "Jeux Vidéo", "Voyage", 
    "Animaux", "Bénévolat", "Musique", "Bricolage", "Photographie"
  ];

  static String calculateClass(List<String> hobbies) {
    int guerrier = 0; int mage = 0; int explorateur = 0; int soigneur = 0;

    for (var hobby in hobbies) {
      if (hobby == "Sport" || hobby == "Bricolage") guerrier++;
      if (hobby == "Lecture" || hobby == "Jeux Vidéo" || hobby == "Musique") mage++;
      if (hobby == "Voyage" || hobby == "Photographie") explorateur++;
      if (hobby == "Animaux" || hobby == "Bénévolat") soigneur++;
    }

    if (guerrier >= mage && guerrier >= explorateur && guerrier >= soigneur) return "Guerrier ⚔️";
    if (soigneur >= guerrier && soigneur >= mage && soigneur >= explorateur) return "Soigneur 💖";
    if (mage >= guerrier && mage >= explorateur && mage >= soigneur) return "Mage 🔮";
    return "Explorateur 🗺️";
  }
}
