import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatState {
  final bool isRecording;
  final String? replyingToId;
  final String? replyingToText;
  final String? editingMessageId;
  final String? editingMessageText;

  ChatState({
    this.isRecording = false,
    this.replyingToId,
    this.replyingToText,
    this.editingMessageId,
    this.editingMessageText,
  });

  ChatState copyWith({
    bool? isRecording,
    String? replyingToId,
    String? replyingToText,
    String? editingMessageId,
    String? editingMessageText,
    bool clearReply = false,
    bool clearEdit = false,
  }) {
    return ChatState(
      isRecording: isRecording ?? this.isRecording,
      replyingToId: clearReply ? null : (replyingToId ?? this.replyingToId),
      replyingToText: clearReply ? null : (replyingToText ?? this.replyingToText),
      editingMessageId: clearEdit ? null : (editingMessageId ?? this.editingMessageId),
      editingMessageText: clearEdit ? null : (editingMessageText ?? this.editingMessageText),
    );
  }
}

class ChatStateNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => ChatState();

  void setRecording(bool isRecording) {
    state = state.copyWith(isRecording: isRecording);
  }

  void setReplying(String id, String text) {
    state = state.copyWith(
      replyingToId: id,
      replyingToText: text,
      clearEdit: true, // Cannot reply and edit at the same time
    );
  }

  void setEditing(String id, String text) {
    state = state.copyWith(
      editingMessageId: id,
      editingMessageText: text,
      clearReply: true, // Cannot edit and reply at the same time
    );
  }

  void clearReplyAndEdit() {
    state = state.copyWith(clearReply: true, clearEdit: true);
  }
}

final chatStateProvider = NotifierProvider<ChatStateNotifier, ChatState>(() {
  return ChatStateNotifier();
});
