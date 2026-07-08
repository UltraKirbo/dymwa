import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../widgets/chat/chat_header.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/message_bubble.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String peerName;
  final String peerId;
  
  const ChatDetailScreen({super.key, required this.chatId, required this.peerName, required this.peerId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  
  UserProfile? _peerProfile;

  @override
  void initState() {
    super.initState();
    _loadPeerProfile();
  }

  Future<void> _loadPeerProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.peerId).get();
    if (doc.exists && mounted) {
      setState(() {
        _peerProfile = UserProfile.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatHeader(
        chatId: widget.chatId,
        peerId: widget.peerId,
        peerName: widget.peerName,
        peerProfile: _peerProfile,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!;
                
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe = msg.senderId == myUid;

                    return MessageBubble(
                      message: msg,
                      isMe: isMe,
                      chatId: widget.chatId,
                      peerName: widget.peerName,
                    );
                  },
                );
              },
            ),
          ),

          // Typing indicator
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final typing = data['typing'] ?? {};
              if (typing[widget.peerId] == true) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('chat.typing'.tr(args: [widget.peerName]), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Input Bar
          ChatInputBar(
            chatId: widget.chatId,
            peerId: widget.peerId,
          ),
        ],
      ),
    );
  }
}
