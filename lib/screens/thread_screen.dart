import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/daily_question_service.dart';

class ThreadScreen extends StatefulWidget {
  final DocumentSnapshot answerDoc;

  const ThreadScreen({super.key, required this.answerDoc});

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final DailyQuestionService _questionService = DailyQuestionService();
  final TextEditingController _replyController = TextEditingController();
  bool _isSubmitting = false;

  void _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    await _questionService.postReply(widget.answerDoc.id, text);
    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _replyController.clear();
      });
      // Défilement automatique vers le bas ou cacher le clavier
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.answerDoc.data() as Map<String, dynamic>;
    final isMe = data['uid'] == _questionService.currentUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Réponses"),
      ),
      body: Column(
        children: [
          // Carte Parent (Le Tweet original)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        data['name'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? "Moi" : data['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          data['question'],
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  data['text'],
                  style: const TextStyle(fontSize: 20, height: 1.4),
                ),
              ],
            ),
          ),
          
          // Liste des réponses
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _questionService.getReplies(widget.answerDoc.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final replies = snapshot.data?.docs ?? [];

                if (replies.isEmpty) {
                  return const Center(
                    child: Text(
                      "Soyez le premier à réagir !",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: replies.length,
                  itemBuilder: (context, index) {
                    final replyData = replies[index].data() as Map<String, dynamic>;
                    final bool replyIsMe = replyData['uid'] == _questionService.currentUid;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey.shade300,
                            child: Text(
                              replyData['name'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  replyIsMe ? "Moi" : replyData['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  replyData['text'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Zone de texte pour répondre
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: "Écrire une réponse...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.1),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSubmitting
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                          onPressed: _submitReply,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
