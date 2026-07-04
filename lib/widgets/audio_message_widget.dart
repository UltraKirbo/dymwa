import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioMessageWidget extends StatefulWidget {
  final String? audioUrl;
  final String? audioBase64;
  final bool isMe;

  const AudioMessageWidget({super.key, this.audioUrl, this.audioBase64, required this.isMe});

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    // Setup listeners
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
          _isLoaded = true;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });

    // Précharger l'audio (optionnel, mais permet d'avoir la durée)
    try {
      if (widget.audioBase64 != null) {
        await _audioPlayer.setSourceBytes(base64Decode(widget.audioBase64!));
      } else if (widget.audioUrl != null) {
        await _audioPlayer.setSourceUrl(widget.audioUrl!);
      }
    } catch (e) {
      print("Erreur de chargement de l'audio : $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color;
    final iconColor = widget.isMe ? Colors.white : Theme.of(context).primaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: iconColor,
            size: 36,
          ),
          onPressed: () async {
            if (_isPlaying) {
              await _audioPlayer.pause();
            } else {
              if (widget.audioBase64 != null) {
                await _audioPlayer.play(BytesSource(base64Decode(widget.audioBase64!)));
              } else if (widget.audioUrl != null) {
                await _audioPlayer.play(UrlSource(widget.audioUrl!));
              }
            }
          },
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120, // Largeur fixe pour la barre
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  activeTrackColor: widget.isMe ? Colors.white : Theme.of(context).primaryColor,
                  inactiveTrackColor: widget.isMe ? Colors.white38 : Colors.grey[300],
                  thumbColor: iconColor,
                ),
                child: Slider(
                  min: 0,
                  max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                  value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
                  onChanged: (value) async {
                    final position = Duration(milliseconds: value.toInt());
                    await _audioPlayer.seek(position);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                _isLoaded ? _formatDuration(_position) + ' / ' + _formatDuration(_duration) : "--:--",
                style: TextStyle(color: textColor, fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
