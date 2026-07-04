import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';

class CallScreen extends StatefulWidget {
  final String chatId;
  final String peerName;
  final bool isCaller;
  final String? roomId;

  const CallScreen({
    super.key,
    required this.chatId,
    required this.peerName,
    required this.isCaller,
    this.roomId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  final ChatService _chatService = ChatService();
  
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      if (widget.isCaller) {
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
        final ids = widget.chatId.split('_');
        final peerUid = ids.firstWhere((id) => id != myUid, orElse: () => "");

        String roomId = await _callService.createRoom(peerUid);
        await _chatService.sendMessage(widget.chatId, "📞 Appel vocal démarré. (ID: $roomId)");
        _startTimer();
      } else {
        if (widget.roomId != null) {
          await _callService.joinRoom(widget.roomId!);
          _startTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur d'appel: $e")));
        Navigator.pop(context);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });

        // Raccrocher si personne ne répond après 30 secondes
        if (widget.isCaller && !_callService.isConnected && _secondsElapsed >= 30) {
          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personne n'a répondu à l'appel.")));
          _endCall();
        }
      }
    });
  }

  void _endCall() async {
    await _callService.hangUp();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _callService.toggleMute(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _callService.toggleSpeaker(_isSpeakerOn);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _callService.hangUp(); // Sécurité au cas où on quitte la page autrement
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Mode sombre élégant
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Text(
              "Appel en cours...",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              widget.peerName,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _formatDuration(_secondsElapsed),
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 150 + (_pulseController.value * 30),
                      height: 150 + (_pulseController.value * 30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor.withOpacity(0.3 - (_pulseController.value * 0.2)),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 50, color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlBtn(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.white : Colors.white24,
                    iconColor: _isMuted ? Colors.black : Colors.white,
                    onTap: _toggleMute,
                  ),
                  _buildControlBtn(
                    icon: Icons.call_end,
                    color: Colors.red,
                    iconColor: Colors.white,
                    size: 70,
                    onTap: _endCall,
                  ),
                  _buildControlBtn(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    color: _isSpeakerOn ? Colors.white : Colors.white24,
                    iconColor: _isSpeakerOn ? Colors.black : Colors.white,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildControlBtn({required IconData icon, required Color color, required Color iconColor, double size = 60, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}
