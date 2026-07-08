import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../providers/chat_state_provider.dart';
import '../connect_four_widget.dart';
import '../tic_tac_toe_widget.dart';
import '../audio_message_widget.dart';
import '../../screens/call_screen.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;
  final bool isMe;
  final String chatId;
  final String peerName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatId,
    required this.peerName,
  });

  void _showMessageOptions(BuildContext context, WidgetRef ref) {
    if (message.type == MessageType.gameConnect4 || message.type == MessageType.gameTicTacToe) return;

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
                        ChatService().reactToMessage(chatId, message.id, emoji);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              if (message.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: Text('chat.reply'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(chatStateProvider.notifier).setReplying(message.id, message.text ?? '');
                  },
                ),
              if (isMe && message.type == MessageType.text && !message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text('chat.edit'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(chatStateProvider.notifier).setEditing(message.id, message.text ?? '');
                  },
                ),
              if (isMe && !message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('chat.delete'.tr(), style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    ChatService().deleteMessage(chatId, message.id);
                  },
                ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.type == MessageType.gameConnect4) {
      return Align(
        alignment: Alignment.center,
        child: ConnectFourWidget(
          chatId: chatId,
          messageId: message.id,
          gameData: message.toMap(),
        ),
      );
    }
    if (message.type == MessageType.gameTicTacToe) {
      return Align(
        alignment: Alignment.center,
        child: TicTacToeWidget(
          chatId: chatId,
          messageId: message.id,
          gameData: message.toMap(),
        ),
      );
    }

    Widget messageContent = _buildContent(context);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context, ref),
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
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.replyToText != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message.replyToText!,
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: isMe ? Colors.white70 : Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              messageContent,
              if (message.isEdited && !message.isDeleted)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('chat.edited_label'.tr(), style: TextStyle(fontSize: 10, color: isMe ? Colors.white54 : Colors.grey)),
                ),
              if (message.reactions.isNotEmpty)
                Align(
                  alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                    child: Text(message.reactions.values.first, style: const TextStyle(fontSize: 14)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.isDeleted) {
      return Text("chat.deleted_message".tr(), style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70));
    }

    if (message.type == MessageType.ephemeralImage) {
      if (isMe) {
        return Text("chat.ephemeral_sent".tr(), style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70));
      } else if (message.isOpened) {
        return Text("chat.ephemeral_expired".tr(), style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70));
      } else {
        return ElevatedButton.icon(
          onPressed: () async {
            await ChatService().markEphemeralOpened(chatId, message.id);
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (_) {
                  Timer(const Duration(seconds: 5), () {
                    ChatService().deleteEphemeralMessage(chatId, message.id);
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  });
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    child: Image.memory(base64Decode(message.imageBase64!), fit: BoxFit.contain),
                  );
                }
              );
            }
          },
          icon: const Icon(Icons.remove_red_eye, color: Colors.white),
          label: Text("chat.tap_to_view".tr(), style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
        );
      }
    }

    if (message.type == MessageType.image) {
      if (message.imageBase64 != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(base64Decode(message.imageBase64!), width: 200, fit: BoxFit.cover),
        );
      } else if (message.imageUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(message.imageUrl!, width: 200, fit: BoxFit.cover),
        );
      }
    }

    if (message.type == MessageType.voice) {
      return AudioMessageWidget(
        audioUrl: message.audioUrl, 
        audioBase64: message.audioBase64, 
        isMe: isMe
      );
    }

    if (message.text?.startsWith("📞 Appel vocal démarré") == true || message.text?.startsWith("📞 Voice call started") == true) {
      String text = message.text!;
      RegExp regExp = RegExp(r"\(ID: (.*)\)");
      var match = regExp.firstMatch(text);
      String roomId = match != null ? match.group(1) ?? '' : '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("chat.voice_call".tr(), style: TextStyle(color: isMe ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.bold)),
          if (!isMe && roomId.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      chatId: chatId,
                      peerName: peerName,
                      isCaller: false,
                      roomId: roomId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.call, color: Colors.white),
              label: Text("chat.join_call".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ],
      );
    }

    return Text(
      message.text ?? '',
      style: TextStyle(color: isMe ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color),
    );
  }
}
