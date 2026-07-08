import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/chat_state_provider.dart';
import '../../services/chat_service.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final String chatId;
  final String peerId;

  const ChatInputBar({super.key, required this.chatId, required this.peerId});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _msgController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _typingTimer;
  String? _recordFilePath;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatService.updateTyping(widget.chatId, false);
    _audioRecorder.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _onTyping() {
    _chatService.updateTyping(widget.chatId, true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.updateTyping(widget.chatId, false);
    });
  }

  void _sendMessage() {
    final text = _msgController.text;
    final chatState = ref.read(chatStateProvider);
    
    if (text.trim().isNotEmpty) {
      if (chatState.editingMessageId != null) {
        _chatService.editMessage(widget.chatId, chatState.editingMessageId!, text);
        ref.read(chatStateProvider.notifier).clearReplyAndEdit();
      } else {
        _chatService.sendMessage(widget.chatId, text, replyToId: chatState.replyingToId, replyToText: chatState.replyingToText);
        ref.read(chatStateProvider.notifier).clearReplyAndEdit();
      }
      _msgController.clear();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _recordFilePath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(bitRate: 64000, encoder: AudioEncoder.aacLc), path: _recordFilePath!);
        ref.read(chatStateProvider.notifier).setRecording(true);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      ref.read(chatStateProvider.notifier).setRecording(false);
      
      if (path != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Envoi du vocal en cours...')));
        try {
          final chatState = ref.read(chatStateProvider);
          await _chatService.sendVoiceMessage(widget.chatId, path, replyToId: chatState.replyingToId, replyToText: chatState.replyingToText);
          ref.read(chatStateProvider.notifier).clearReplyAndEdit();
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
      debugPrint(e.toString());
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
                  title: Text('chat.challenge_connect4'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.peerId.isNotEmpty) {
                      _chatService.sendConnectFourChallenge(widget.chatId, widget.peerId);
                    }
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.7),
                    child: const Icon(Icons.grid_3x3, color: Colors.white),
                  ),
                  title: Text('chat.challenge_tictactoe'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.peerId.isNotEmpty) {
                      _chatService.sendTicTacToeChallenge(widget.chatId, widget.peerId);
                    }
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    child: const Icon(Icons.image, color: Colors.white),
                  ),
                  title: Text('chat.send_image'.tr()),
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
                          Text('chat.preview'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 48), 
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
                                  color: isEphemeral ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.transparent,
                                  border: Border.all(color: isEphemeral ? Colors.purpleAccent : Colors.grey),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(isEphemeral ? Icons.visibility_off : Icons.visibility, color: isEphemeral ? Colors.purpleAccent : Colors.grey, size: 20),
                                    const SizedBox(width: 8),
                                    Text('chat.view_once'.tr(), style: TextStyle(color: isEphemeral ? Colors.purpleAccent : Colors.grey, fontWeight: FontWeight.bold)),
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
          final chatState = ref.read(chatStateProvider);
          await _chatService.sendImageMessage(widget.chatId, File(image.path), replyToId: chatState.replyingToId, replyToText: chatState.replyingToText, isEphemeral: isEphemeral);
          ref.read(chatStateProvider.notifier).clearReplyAndEdit();
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    
    ref.listen<ChatState>(chatStateProvider, (previous, next) {
      if (next.editingMessageId != null && next.editingMessageId != previous?.editingMessageId) {
        _msgController.text = next.editingMessageText ?? '';
      }
    });

    return Column(
      children: [
        if (chatState.replyingToText != null || chatState.editingMessageId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(chatState.editingMessageId != null ? Icons.edit : Icons.reply, size: 20, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chatState.editingMessageId != null ? "chat.editing".tr() : "chat.reply_to".tr(args: [chatState.replyingToText!]),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    ref.read(chatStateProvider.notifier).clearReplyAndEdit();
                    _msgController.clear();
                  },
                )
              ],
            ),
          ),
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
                      hintText: chatState.isRecording ? 'chat.recording'.tr() : 'chat.type_message'.tr(),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    readOnly: chatState.isRecording,
                  ),
                ),
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: IconButton(
                    icon: Icon(chatState.isRecording ? Icons.mic : Icons.mic_none, color: chatState.isRecording ? Colors.red : Theme.of(context).colorScheme.primary),
                    onPressed: () {},
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
    );
  }
}
