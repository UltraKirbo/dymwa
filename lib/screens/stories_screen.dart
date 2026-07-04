import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/story_service.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  final StoryService _storyService = StoryService();
  bool _isUploading = false;

  Future<void> _pickAndUploadStory() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        await _storyService.createStory(File(image.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story publiée avec succès !')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isUploading)
          const LinearProgressIndicator(),
        
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: StreamBuilder<QuerySnapshot>(
            stream: _storyService.getRecentStories(),
            builder: (context, snapshot) {
              final stories = snapshot.data?.docs ?? [];
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: stories.length + 1, // +1 pour le bouton "Ma Story"
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Bouton pour ajouter une story
                    return GestureDetector(
                      onTap: _pickAndUploadStory,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: Colors.grey[300],
                                  child: const Icon(Icons.add, color: Colors.black, size: 30),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Ma Story', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  }

                  // Affichage des stories
                  final storyData = stories[index - 1].data() as Map<String, dynamic>;
                  final imageUrl = storyData['imageUrl'] as String?;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                            backgroundColor: Colors.grey,
                            child: imageUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Ami', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(),
        const Expanded(
          child: Center(
            child: Text(
              'Appuyez sur "Ma Story" pour partager\nune photo avec vos proches.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}
