import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/user_model.dart';
import '../../services/moderation_service.dart';
import '../../screens/call_screen.dart';
import '../full_screen_image_viewer.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String chatId;
  final String peerId;
  final String peerName;
  final UserProfile? peerProfile;

  const ChatHeader({
    super.key,
    required this.chatId,
    required this.peerId,
    required this.peerName,
    this.peerProfile,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${'chat.report'.tr()} $peerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text("chat.report_spam".tr()),
              onTap: () {
                ModerationService().reportUser(peerId, peerName, "Spam");
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('chat.report_sent'.tr())));
              },
            ),
            ListTile(
              title: Text("chat.report_inappropriate".tr()),
              onTap: () {
                ModerationService().reportUser(peerId, peerName, "Inapproprié");
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('chat.report_sent'.tr())));
              },
            ),
            ListTile(
              title: Text("chat.report_harassment".tr()),
              onTap: () {
                ModerationService().reportUser(peerId, peerName, "Harcèlement");
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('chat.report_sent'.tr())));
              },
            ),
          ],
        ),
      )
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("chat.block_confirm_title".tr()),
        content: Text("chat.block_confirm_body".tr(args: [peerName])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("chat.cancel".tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ModerationService().blockUser(peerId, peerName);
              if (context.mounted) {
                Navigator.pop(context); // fermer dialog
                Navigator.pop(context); // quitter chat
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('chat.user_blocked'.tr())));
              }
            },
            child: Text("chat.block".tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  void _showUserProfile(BuildContext context) {
    if (peerProfile == null) return;
    
    final greeting = peerProfile!.greeting;
    final bio = peerProfile!.bio;
    final activeTitle = peerProfile!.activeTitle;
    final rpgClass = peerProfile!.rpgClass;
    
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
                  if (peerProfile!.avatarBase64 != null && peerProfile!.avatarBase64!.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(base64Image: peerProfile!.avatarBase64!, tag: 'profile_dialog_$peerId'),
                    ));
                  }
                },
                child: Container(
                  padding: peerProfile!.activeBorder != 'none' ? const EdgeInsets.all(4) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _getBorderGradient(peerProfile!.activeBorder),
                  ),
                  child: Hero(
                    tag: 'profile_dialog_$peerId',
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade800,
                      child: (peerProfile!.avatarBase64 != null && peerProfile!.avatarBase64!.isNotEmpty)
                          ? ClipOval(child: Image.memory(base64Decode(peerProfile!.avatarBase64!), width: 100, height: 100, fit: BoxFit.cover))
                          : const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(peerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
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

  LinearGradient? _getBorderGradient(String borderId) {
    switch (borderId) {
      case 'gold': return const LinearGradient(colors: [Colors.yellowAccent, Colors.amber, Colors.orangeAccent]);
      case 'fire': return const LinearGradient(colors: [Colors.red, Colors.deepOrange, Colors.yellow]);
      case 'neon': return const LinearGradient(colors: [Colors.cyanAccent, Colors.purpleAccent, Colors.pinkAccent]);
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: GestureDetector(
        onTap: () => _showUserProfile(context),
        child: Row(
          children: [
            Container(
              padding: (peerProfile?.activeBorder ?? 'none') != 'none' ? const EdgeInsets.all(2) : EdgeInsets.zero,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _getBorderGradient(peerProfile?.activeBorder ?? 'none'),
              ),
              child: Hero(
                tag: 'chat_header_$peerId',
                child: CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: 16,
                  child: (peerProfile?.avatarBase64 != null && peerProfile!.avatarBase64!.isNotEmpty)
                      ? ClipOval(child: Image.memory(base64Decode(peerProfile!.avatarBase64!), width: 32, height: 32, fit: BoxFit.cover))
                      : const Icon(Icons.person, color: Colors.white, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(peerName),
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
                  chatId: chatId,
                  peerName: peerName,
                  isCaller: true,
                ),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'report') _showReportDialog(context);
            if (value == 'block') _showBlockDialog(context);
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'report', child: Text('chat.report'.tr())),
            PopupMenuItem(value: 'block', child: Text('chat.block'.tr(), style: const TextStyle(color: Colors.red))),
          ],
        ),
      ],
    );
  }
}
