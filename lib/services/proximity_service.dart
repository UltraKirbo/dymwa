import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'local_storage_service.dart';

class ProximityService {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  
  // Démarrer la diffusion
  Future<void> startAdvertising(String myUid, Function(String peerName)? onEncounter) async {
    try {
      bool a = await Nearby().startAdvertising(
        myUid,
        strategy,
        onConnectionInitiated: (id, info) async {
          // On accepte la connexion P2P
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) async {
              if (payload.type == PayloadType.BYTES) {
                final String jsonStr = String.fromCharCodes(payload.bytes!);
                await LocalStorageService.saveEncounter(jsonStr);
                
                // Extraire le nom pour la notification
                try {
                  final data = jsonDecode(jsonStr);
                  if (onEncounter != null && data['name'] != null) {
                    onEncounter(data['name']);
                  }
                } catch(e) {}
              }
            },
            onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
          );
        },
        onConnectionResult: (id, status) async {
          if (status == Status.CONNECTED) {
            // Connexion établie ! On lui envoie notre profil complet.
            final myProfileJson = await LocalStorageService.getMyProfilePayload();
            await Nearby().sendBytesPayload(id, Uint8List.fromList(myProfileJson.codeUnits));
          }
        },
        onDisconnected: (id) {},
      );
      print('Advertising started: $a');
    } catch (exception) {
      print('Erreur advertising: $exception');
    }
  }

  // Démarrer la découverte
  Future<void> startDiscovery(String myUid, Function(String peerName)? onEncounter) async {
    try {
      bool a = await Nearby().startDiscovery(
        "dymwa_app", // Identifiant de service fixe pour que tout le monde se trouve
        strategy,
        onEndpointFound: (id, name, serviceId) async {
          // Dès qu'on trouve quelqu'un, on demande une connexion P2P
          await Nearby().requestConnection(
            myUid,
            id,
            onConnectionInitiated: (id, info) async {
              await Nearby().acceptConnection(
                id,
                onPayLoadRecieved: (endpointId, payload) async {
                  if (payload.type == PayloadType.BYTES) {
                    final String jsonStr = String.fromCharCodes(payload.bytes!);
                    await LocalStorageService.saveEncounter(jsonStr);
                    
                    try {
                      final data = jsonDecode(jsonStr);
                      if (onEncounter != null && data['name'] != null) {
                        onEncounter(data['name']);
                      }
                    } catch(e) {}
                  }
                },
                onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
              );
            },
            onConnectionResult: (id, status) async {
              if (status == Status.CONNECTED) {
                final myProfileJson = await LocalStorageService.getMyProfilePayload();
                await Nearby().sendBytesPayload(id, Uint8List.fromList(myProfileJson.codeUnits));
              }
            },
            onDisconnected: (id) {},
          );
        },
        onEndpointLost: (id) {},
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

