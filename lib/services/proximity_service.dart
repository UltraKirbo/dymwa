import 'package:nearby_connections/nearby_connections.dart';

class ProximityUser {
  final String endpointId;
  final String uid; // L'UID Firebase récupéré
  final String name; // Nom Firebase récupéré

  ProximityUser({required this.endpointId, required this.uid, required this.name});
}

class ProximityService {
  final Strategy strategy = Strategy.P2P_CLUSTER; // Stratégie pour les réseaux maillés (petits groupes de proximité)
  
  // Démarrer la diffusion (Advertising) pour que les autres nous trouvent
  Future<void> startAdvertising(String myUid) async {
    try {
      bool a = await Nearby().startAdvertising(
        myUid, // On diffuse notre UID Firebase comme nom pour que les autres puissent récupérer notre profil
        strategy,
        onConnectionInitiated: (id, info) {
          // Connexion initiée (ignoré pour l'instant car on veut juste se voir, pas forcément s'envoyer des gros fichiers direct)
        },
        onConnectionResult: (id, status) {},
        onDisconnected: (id) {},
      );
      print('Advertising started: $a');
    } catch (exception) {
      print('Erreur advertising: $exception');
    }
  }

  // Démarrer la découverte (Discovery) pour trouver les autres
  Future<void> startDiscovery(
      Function(String endpointId, String uid) onEndpointFound,
      Function(String endpointId) onEndpointLost) async {
    try {
      bool a = await Nearby().startDiscovery(
        "dymwa_app", // Service ID
        strategy,
        onEndpointFound: (id, name, serviceId) {
          // name contient l'UID de l'autre personne !
          onEndpointFound(id ?? "", name ?? "");
        },
        onEndpointLost: (id) {
          onEndpointLost(id ?? "");
        },
      );
      print('Discovery started: $a');
    } catch (e) {
      print('Erreur discovery: $e');
    }
  }

  void stopAll() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
  }
}
