import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/chat_service.dart';
import '../services/call_service.dart';
import '../services/moderation_service.dart';
import '../widgets/full_screen_image_viewer.dart';
import 'call_screen.dart';
import '../widgets/connect_four_widget.dart';
import '../widgets/audio_message_widget.dart';
import '../widgets/tic_tac_toe_widget.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String peerName;
  final String peerId;
  
  const ChatDetailScreen({super.key, required this.chatId, required this.peerName, required this.peerId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _msgController = TextEditingController();
  final ChatService _chatService = ChatService();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  
  // Nouveaux états
  Map<String, dynamic>? _peerData;
  String? _peerAvatarBase64;
  String _peerActiveBorder = 'none';
  Timer? _typingTimer;
  
  // États de l'interface Avancée
  String? _replyingToId;
  String? _replyingToText;
  String? _editingMessageId;

  // État de l'audio
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordFilePath;

  @override
  void initState() {
    super.initState();
    _loadPeerAvatar();
  }

  Future<void> _loadPeerAvatar() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.peerId).get();
    if (doc.exists && mounted) {
      setState(() {
        _peerData = doc.data();
        _peerAvatarBase64 = _peerData?['avatarBase64'];
        _peerActiveBorder = _peerData?['activeBorder'] ?? 'none';
      });
    }
  }

  void _onTyping() {
    _chatService.updateTyping(widget.chatId, true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.updateTyping(widget.chatId, false);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatService.updateTyping(widget.chatId, false);
    _audioRecorder.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text;
    if (text.trim().isNotEmpty) {
      if (_editingMessageId != null) {
        _chatService.editMessage(widget.chatId, _editingMessageId!, text);
        setState(() {
          _editingMessageId = null;
        });
      } else {
        _chatService.sendMessage(widget.chatId, text, replyToId: _replyingToId, replyToText: _replyingToText);
        setState(() {
          _replyingToId = null;
          _replyingToText = null;
        });
      }
      _msgController.clear();
    }
  }

  Future<void> _sendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 600);
    if (image != null) {
      if (!mounted) return;
      
      bool isEphemeral = false;
      final bool? confirmSend = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.black,
                insetPadding: EdgeInsets.zero,
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context, null),
                          ),
                          const Text("Aperçu", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 48), // Pour centrer le titre
                        ],
                      ),
                      Expanded(
                        child: InteractiveViewer(
                          child: Image.file(File(image.path), fit: BoxFit.contain),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.black54,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  isEphemeral = !isEphemeral;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isEphemeral ? Colors.purpleAccent.withOpacity(0.2) : Colors.transparent,
                                  border: Border.all(color: isEphemeral ? Colors.purpleAccent : Colors.grey),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(isEphemeral ? Icons.visibility_off : Icons.visibility, color: isEphemeral ? Colors.purpleAccent : Colors.grey, size: 20),
                                    const SizedBox(width: 8),
                                    Text("Vue unique", style: TextStyle(color: isEphemeral ? Colors.purpleAccent : Colors.grey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            FloatingActionButton(
                              backgroundColor: Theme.of(context).primaryColor,
                              onPressed: () => Navigator.pop(context, true),
                              child: const Icon(Icons.send, color: Colors.white),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }
          );
        }
      );

      if (confirmSend == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Envoi de l\'image en cours...')));
        try {
          await _chatService.sendImageMessage(widget.chatId, File(image.path), replyToId: _replyingToId, replyToText: _replyingToText, isEphemeral: isEphemeral);
          setState(() {
            _replyingToId = null;
            _replyingToText = null;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Échec de l'envoi.\n$e"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ));
          }
        }
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _recordFilePath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        // Enregistrement très léger pour base64 (64 kbps pour la clarté)
        await _audioRecorder.start(const RecordConfig(bitRate: 64000, encoder: AudioEncoder.aacLc), path: _recordFilePath!);
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Envoi du vocal en cours...')));
        try {
          await _chatService.sendVoiceMessage(widget.chatId, path, replyToId: _replyingToId, replyToText: _replyingToText);
          setState(() {
            _replyingToId = null;
            _replyingToText = null;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Échec de l'envoi vocal.\n$e"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ));
          }
        }
      }
    } catch (e) {
      print(e);
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.gamepad, color: Colors.white),
                  ),
                  title: const Text('Défier au Puissance 4'),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.peerId.isNotEmpty) {
                      _chatService.sendConnectFourChallenge(widget.chatId, widget.peerId);
                    }
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.7),
                    child: const Icon(Icons.grid_3x3, color: Colors.white),
                  ),
                  title: const Text('Défier au Morpion'),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.peerId.isNotEmpty) {
                      _chatService.sendTicTacToeChallenge(widget.chatId, widget.peerId);
                    }
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.5),
                    child: const Icon(Icons.image, color: Colors.white),
                  ),
                  title: const Text('Envoyer une image'),
                  onTap: () {
                    Navigator.pop(context);
                    _sendImage();
                  },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showMessageOptions(String msgId, Map<String, dynamic> msg, bool isMe) {
    if (msg['type'] == 'game_connect4') return; // Pas d'options sur un jeu en cours

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '😂', '😲', '😢', '👍', '🔥'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _chatService.reactToMessage(widget.chatId, msgId, emoji);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              if (msg['type'] == 'text')
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Répondre'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _replyingToId = msgId;
                      _replyingToText = msg['text'];
                      _editingMessageId = null; // Annule l'édition si en cours
                    });
                  },
                ),
              if (isMe && msg['type'] == 'text' && msg['isDeleted'] != true)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Modifier'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessageId = msgId;
                      _replyingToId = null;
                      _msgController.text = msg['text'];
                    });
                  },
                ),
              if (isMe && msg['isDeleted'] != true)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _chatService.deleteMessage(widget.chatId, msgId);
                  },
                ),
            ],
          ),
        );
      }
    );
  }

  void _showUserProfile() {
    if (_peerData == null) return;
    
    final greeting = _peerData!['greeting'] ?? 'Salut !';
    final bio = _peerData!['bio'] ?? '';
    final activeTitle = _peerData!['activeTitle'] ?? '';
    final rpgClass = _peerData!['rpgClass'] ?? '';
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (_peerAvatarBase64 != null && _peerAvatarBase64!.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(base64Image: _peerAvatarBase64!, tag: 'profile_dialog_${widget.peerId}'),
                    ));
                  }
                },
                child: Container(
                  padding: _peerActiveBorder != 'none' ? const EdgeInsets.all(4) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _getBorderGradient(_peerActiveBorder),
                  ),
                  child: Hero(
                    tag: 'profile_dialog_${widget.peerId}',
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade800,
                      child: _peerAvatarBase64 != null
                          ? ClipOval(child: Image.memory(base64Decode(_peerAvatarBase64!), width: 100, height: 100, fit: BoxFit.cover))
                          : const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.peerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (activeTitle.isNotEmpty)
                Text(activeTitle, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
              
              if (rpgClass.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield, color: Colors.purpleAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(rpgClass, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                    ],
                  ),
                ),
                
              const SizedBox(height: 16),
              
              if (greeting.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('"$greeting"', style: const TextStyle(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                ),
                
              if (bio.isNotEmpty)
                Text(bio, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Signaler ${widget.peerName}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Faux profil / Spam"),
              onTap: () {
                ModerationService().reportUser(widget.peerId, widget.peerName, "Spam");
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé.')));
              },
            ),
            ListTile(
              title: const Text("Contenu inapproprié"),
              onTap: () {
                ModerationService().reportUser(widget.peerId, widget.peerName, "Inapproprié");
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé.')));
              },
            ),
            ListTile(
              title: const Text("Harcèlement"),
              onTap: () {
                ModerationService().reportUser(widget.peerId, widget.peerName, "Harcèlement");
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé.')));
              },
            ),
          ],
        ),
      )
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Bloquer cet utilisateur ?"),
        content: Text("Vous ne pourrez plus échanger avec ${widget.peerName}."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ModerationService().blockUser(widget.peerId, widget.peerName);
              if (mounted) {
                Navigator.pop(context); // fermer dialog
                Navigator.pop(context); // quitter chat
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur bloqué.')));
              }
            },
            child: const Text("Bloquer", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showUserProfile,
          child: Row(
            children: [
              Container(
                padding: _peerActiveBorder != 'none' ? const EdgeInsets.all(2) : EdgeInsets.zero,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _getBorderGradient(_peerActiveBorder),
                ),
                child: Hero(
                  tag: 'chat_header_${widget.peerId}',
                  child: CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 16,
                    child: _peerAvatarBase64 != null
                        ? ClipOval(child: Image.memory(base64Decode(_peerAvatarBase64!), width: 32, height: 32, fit: BoxFit.cover))
                        : const Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(widget.peerName),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    chatId: widget.chatId,
                    peerName: widget.peerName,
                    isCaller: true,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'report') _showReportDialog();
              if (value == 'block') _showBlockDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'report', child: Text('Signaler')),
              const PopupMenuItem(value: 'block', child: Text('Bloquer', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!.docs;
                
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final docId = messages[index].id;
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final bool isMe = msg['senderId'] == myUid;
                    final bool isDeleted = msg['isDeleted'] == true;
                    final bool isEdited = msg['isEdited'] == true;

                    if (msg['type'] == 'game_connect4') {
                      return Align(
                        alignment: Alignment.center,
                        child: ConnectFourWidget(
                          chatId: widget.chatId,
                          messageId: docId,
                          gameData: msg,
                        ),
                      );
                    }
                    if (msg['type'] == 'game_tictactoe') {
                      return Align(
                        alignment: Alignment.center,
                        child: TicTacToeWidget(
                          chatId: widget.chatId,
                          messageId: docId,
                          gameData: msg,
                        ),
                      );
                    }

                    Widget messageContent;
                    if (isDeleted) {
                      messageContent = const Text("🚫 Ce message a été supprimé.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white70));
                    } else if (msg['type'] == 'ephemeral_image') {
                      final bool isOpened = msg['isOpened'] == true;
                      if (isMe) {
                        messageContent = const Text("👻 Image éphémère envoyée", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white70));
                      } else if (isOpened) {
                        messageContent = const Text("👻 Image expirée", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white70));
                      } else {
                        messageContent = ElevatedButton.icon(
                          onPressed: () async {
                            await _chatService.markEphemeralOpened(widget.chatId, docId);
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (_) {
                                  Timer(const Duration(seconds: 5), () {
                                    _chatService.deleteEphemeralMessage(widget.chatId, docId);
                                    if (Navigator.canPop(context)) Navigator.pop(context);
                                  });
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: Image.memory(base64Decode(msg['imageBase64']), fit: BoxFit.contain),
                                  );
                                }
                              );
                            }
                          },
                          icon: const Icon(Icons.remove_red_eye, color: Colors.white),
                          label: const Text("Appuyer pour voir (5s)", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                        );
                      }
                    } else if (msg['type'] == 'image') {
                      if (msg['imageBase64'] != null) {
                        messageContent = ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(base64Decode(msg['imageBase64']), width: 200, fit: BoxFit.cover),
                        );
                      } else {
                        messageContent = ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(msg['imageUrl'] ?? '', width: 200, fit: BoxFit.cover),
                        );
                      }
                    } else if (msg['type'] == 'voice') {
                      messageContent = AudioMessageWidget(
                        audioUrl: msg['audioUrl'], 
                        audioBase64: msg['audioBase64'], 
                        isMe: isMe
                      );
                    } else if (msg['text']?.startsWith("📞 Appel vocal démarré") == true) {
                      String text = msg['text'];
                      RegExp regExp = RegExp(r"\(ID: (.*)\)");
                      var match = regExp.firstMatch(text);
                      String roomId = match != null ? match.group(1) ?? '' : '';

                      messageContent = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("📞 Appel vocal", style: TextStyle(color: isMe ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.bold)),
                          if (!isMe && roomId.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CallScreen(
                                      chatId: widget.chatId,
                                      peerName: widget.peerName,
                                      isCaller: false,
                                      roomId: roomId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.call, color: Colors.white),
                              label: const Text("Rejoindre l'appel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ],
                        ],
                      );
                    } else {
                      messageContent = Text(
                        msg['text'] ?? '',
                        style: TextStyle(color: isMe ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color),
                      );
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showMessageOptions(docId, msg, isMe),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02), // Ombre ultra légère
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msg['replyToText'] != null)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 26),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    msg['replyToText'],
                                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: isMe ? Colors.white70 : Colors.black54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              messageContent,
                              if (isEdited && !isDeleted)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('(Modifié)', style: TextStyle(fontSize: 10, color: isMe ? Colors.white54 : Colors.grey)),
                                ),
                              if (msg['reactions'] != null && (msg['reactions'] as Map).isNotEmpty)
                                Align(
                                  alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
                                    child: Text((msg['reactions'] as Map).values.first, style: const TextStyle(fontSize: 14)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Indicateur de frappe
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final typing = data['typing'] ?? {};
              if (typing[widget.peerId] == true) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("${widget.peerName} est en train d'écrire...", style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Barre d'état (Réponse / Édition)
          if (_replyingToText != null || _editingMessageId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.withValues(alpha: 26),
              child: Row(
                children: [
                  Icon(_editingMessageId != null ? Icons.edit : Icons.reply, size: 20, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _editingMessageId != null ? "Modification du message..." : "Réponse à : $_replyingToText",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _replyingToText = null;
                        _replyingToId = null;
                        _editingMessageId = null;
                        _msgController.clear();
                      });
                    },
                  )
                ],
              ),
            ),

          // Zone de saisie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary), 
                    onPressed: _showAttachmentMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      onChanged: (_) => _onTyping(),
                      decoration: InputDecoration(
                        hintText: _isRecording ? 'Enregistrement vocal en cours...' : 'Écrire un message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      readOnly: _isRecording, // Bloque la saisie texte pendant le vocal
                    ),
                  ),
                  GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecording(),
                    child: IconButton(
                      icon: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary),
                      onPressed: () {}, // Handled by gesture detector
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient? _getBorderGradient(String borderId) {
    switch (borderId) {
      case 'gold': return const LinearGradient(colors: [Colors.yellowAccent, Colors.amber, Colors.orangeAccent]);
      case 'fire': return const LinearGradient(colors: [Colors.red, Colors.deepOrange, Colors.yellow]);
      case 'neon': return const LinearGradient(colors: [Colors.cyanAccent, Colors.purpleAccent, Colors.pinkAccent]);
      default: return null;
    }
  }
}
