import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  ephemeralImage,
  voice,
  gameConnect4,
  gameTicTacToe,
  unknown
}

class Message {
  final String id;
  final String senderId;
  final String? text;
  final String? imageBase64;
  final String? imageUrl;
  final String? audioBase64;
  final String? audioUrl;
  final MessageType type;
  final bool isEdited;
  final bool isDeleted;
  final String? replyToId;
  final String? replyToText;
  final DateTime? timestamp;
  final bool isOpened;
  final Map<String, String> reactions;

  // For games
  final List<int>? board;
  final String? player1;
  final String? player2;
  final String? currentTurn;
  final String? winner;

  Message({
    required this.id,
    required this.senderId,
    this.text,
    this.imageBase64,
    this.imageUrl,
    this.audioBase64,
    this.audioUrl,
    required this.type,
    this.isEdited = false,
    this.isDeleted = false,
    this.replyToId,
    this.replyToText,
    this.timestamp,
    this.isOpened = false,
    this.reactions = const {},
    this.board,
    this.player1,
    this.player2,
    this.currentTurn,
    this.winner,
  });

  factory Message.fromMap(String id, Map<String, dynamic> data) {
    MessageType parsedType = MessageType.unknown;
    final typeStr = data['type'] as String?;
    if (typeStr == 'text') parsedType = MessageType.text;
    else if (typeStr == 'image') parsedType = MessageType.image;
    else if (typeStr == 'ephemeral_image') parsedType = MessageType.ephemeralImage;
    else if (typeStr == 'voice') parsedType = MessageType.voice;
    else if (typeStr == 'game_connect4') parsedType = MessageType.gameConnect4;
    else if (typeStr == 'game_tictactoe') parsedType = MessageType.gameTicTacToe;

    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      text: data['text'],
      imageBase64: data['imageBase64'],
      imageUrl: data['imageUrl'],
      audioBase64: data['audioBase64'],
      audioUrl: data['audioUrl'],
      type: parsedType,
      isEdited: data['isEdited'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      replyToId: data['replyToId'],
      replyToText: data['replyToText'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      isOpened: data['isOpened'] ?? false,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      board: data['board'] != null ? List<int>.from(data['board']) : null,
      player1: data['player1'],
      player2: data['player2'],
      currentTurn: data['currentTurn'],
      winner: data['winner'],
    );
  }

  Map<String, dynamic> toMap() {
    String typeStr = 'unknown';
    switch (type) {
      case MessageType.text: typeStr = 'text'; break;
      case MessageType.image: typeStr = 'image'; break;
      case MessageType.ephemeralImage: typeStr = 'ephemeral_image'; break;
      case MessageType.voice: typeStr = 'voice'; break;
      case MessageType.gameConnect4: typeStr = 'game_connect4'; break;
      case MessageType.gameTicTacToe: typeStr = 'game_tictactoe'; break;
      default: break;
    }

    return {
      'senderId': senderId,
      if (text != null) 'text': text,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (audioBase64 != null) 'audioBase64': audioBase64,
      if (audioUrl != null) 'audioUrl': audioUrl,
      'type': typeStr,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (timestamp != null) 'timestamp': timestamp, // Usually handled by FieldValue.serverTimestamp() during creation
      'isOpened': isOpened,
      'reactions': reactions,
      if (board != null) 'board': board,
      if (player1 != null) 'player1': player1,
      if (player2 != null) 'player2': player2,
      if (currentTurn != null) 'currentTurn': currentTurn,
      if (winner != null) 'winner': winner,
    };
  }
}
