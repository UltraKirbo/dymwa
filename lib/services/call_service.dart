import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  bool isConnected = false;

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  // 1. Initialiser le stream audio (Microphone)
  Future<void> openUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false, // Appel vocal uniquement comme demandé
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  // 2. Créer une offre d'appel (Créer la Room)
  Future<String> createRoom(String peerUid) async {
    await openUserMedia();
    peerConnection = await createPeerConnection(configuration);
    
    // Ajouter nos pistes audio locales à la connexion
    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    // Récupérer le flux audio distant
    peerConnection?.onAddStream = (MediaStream stream) {
      remoteStream = stream;
    };

    // Préparer la Room dans Firestore
    DocumentReference roomRef = _firestore.collection('calls').doc();
    roomId = roomRef.id;

    // Collecter les ICE Candidates (les "chemins" réseaux)
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      roomRef.collection('callerCandidates').add(candidate.toMap());
    };

    // Créer et envoyer l'Offre (SDP)
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    await roomRef.set({
      'offer': offer.toMap(),
      'callerId': currentUid,
      'calleeId': peerUid,
      'status': 'calling',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Écouter si quelqu'un répond (Answer)
    roomRef.snapshots().listen((snapshot) async {
      final data = snapshot.data() as Map<String, dynamic>?;
      var remoteDesc = await peerConnection?.getRemoteDescription();
      if (data != null && data['answer'] != null && remoteDesc == null) {
        var answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
        await peerConnection?.setRemoteDescription(answer);
        isConnected = true;
      }
    });

    // Écouter les chemins réseaux de l'autre personne
    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          peerConnection!.addCandidate(
            RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
          );
        }
      }
    });

    return roomId!;
  }

  // 3. Répondre à un appel
  Future<void> joinRoom(String roomId) async {
    await openUserMedia();
    peerConnection = await createPeerConnection(configuration);
    
    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    peerConnection?.onAddStream = (MediaStream stream) {
      remoteStream = stream;
    };

    DocumentReference roomRef = _firestore.collection('calls').doc(roomId);

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      roomRef.collection('calleeCandidates').add(candidate.toMap());
    };

    // Récupérer l'offre
    DocumentSnapshot roomSnapshot = await roomRef.get();
    var data = roomSnapshot.data() as Map<String, dynamic>;
    var offer = data['offer'];
    await peerConnection?.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    // Créer et envoyer la réponse (Answer)
    var answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    await roomRef.update({'answer': answer.toMap(), 'status': 'connected'});
    isConnected = true;

    // Écouter les chemins réseaux de l'appelant
    roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          peerConnection!.addCandidate(
            RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
          );
        }
      }
    });
  }

  // Raccrocher
  Future<void> hangUp() async {
    localStream?.getTracks().forEach((track) => track.stop());
    remoteStream?.getTracks().forEach((track) => track.stop());
    peerConnection?.close();
    
    if (roomId != null) {
      await _firestore.collection('calls').doc(roomId).delete();
    }
    isConnected = false;
  }

  void toggleMute(bool isMuted) {
    if (localStream != null) {
      localStream!.getAudioTracks().forEach((track) {
        track.enabled = !isMuted;
      });
    }
  }

  void toggleSpeaker(bool isSpeakerOn) {
    // Dans flutter_webrtc, activer le haut parleur se fait via Helper
    // Comme Helper n'est pas toujours exposé selon les versions, on utilise le chemin de base
    // si disponible. En général Helper.setSpeakerphoneOn(isSpeakerOn)
    try {
      Helper.setSpeakerphoneOn(isSpeakerOn);
    } catch (e) {
      print("Speakerphone non supporté sur cette plateforme: $e");
    }
  }
}
