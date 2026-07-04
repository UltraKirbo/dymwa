import 'package:flutter/material.dart';
import 'dart:math';

class SlimeAvatar extends StatefulWidget {
  final Map<String, dynamic>? config;
  final double size;

  const SlimeAvatar({super.key, this.config, this.size = 100});

  @override
  State<SlimeAvatar> createState() => _SlimeAvatarState();
}

class _SlimeAvatarState extends State<SlimeAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Permet de passer facilement au système d'images PNG plus tard si besoin
  // Pour l'instant, c'est du 100% code.
  @override
  Widget build(BuildContext context) {
    final colorString = widget.config?['color'] ?? 'blue';
    final eyesType = widget.config?['eyes'] ?? 0;
    final mouthType = widget.config?['mouth'] ?? 0;
    final accessoryType = widget.config?['accessory'] ?? 0;

    Color slimeColor = _getColor(colorString);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Effet de respiration (Squash & Stretch)
        double squash = 1.0 - (_controller.value * 0.08);
        double stretch = 1.0 + (_controller.value * 0.05);

        return Transform.scale(
          scaleX: stretch,
          scaleY: squash,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: SlimePainter(
                color: slimeColor,
                eyes: eyesType,
                mouth: mouthType,
                accessory: accessoryType,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getColor(String colorStr) {
    switch (colorStr) {
      case 'red': return Colors.red.shade400;
      case 'green': return Colors.green.shade400;
      case 'purple': return Colors.purple.shade400;
      case 'yellow': return Colors.amber.shade400;
      case 'pink': return Colors.pink.shade300;
      case 'black': return Colors.grey.shade800;
      case 'blue':
      default:
        return Colors.blue.shade400;
    }
  }
}

class SlimePainter extends CustomPainter {
  final Color color;
  final int eyes;
  final int mouth;
  final int accessory;

  SlimePainter({required this.color, required this.eyes, required this.mouth, required this.accessory});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- CORPS DU SLIME ---
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Un slime est comme une goutte d'eau écrasée
    Path bodyPath = Path();
    bodyPath.moveTo(w * 0.1, h * 0.9); // Bas gauche
    // Courbe vers le haut (tête)
    bodyPath.quadraticBezierTo(w * 0.1, h * 0.2, w * 0.5, h * 0.1); 
    bodyPath.quadraticBezierTo(w * 0.9, h * 0.2, w * 0.9, h * 0.9);
    // Base plate (légèrement incurvée)
    bodyPath.quadraticBezierTo(w * 0.5, h * 1.0, w * 0.1, h * 0.9);
    
    canvas.drawPath(bodyPath, bodyPaint);
    
    // Highlight (Reflet)
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    Path highlightPath = Path();
    highlightPath.moveTo(w * 0.25, h * 0.35);
    highlightPath.quadraticBezierTo(w * 0.35, h * 0.2, w * 0.5, h * 0.2);
    highlightPath.quadraticBezierTo(w * 0.4, h * 0.3, w * 0.3, h * 0.4);
    canvas.drawPath(highlightPath, highlightPaint);

    // --- YEUX ---
    final eyePaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final whiteEyePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

    double leftEyeX = w * 0.35;
    double rightEyeX = w * 0.65;
    double eyeY = h * 0.55;

    if (eyes == 0) {
      // Normaux
      canvas.drawCircle(Offset(leftEyeX, eyeY), w * 0.08, eyePaint);
      canvas.drawCircle(Offset(rightEyeX, eyeY), w * 0.08, eyePaint);
      canvas.drawCircle(Offset(leftEyeX + w * 0.02, eyeY - h * 0.02), w * 0.03, whiteEyePaint);
      canvas.drawCircle(Offset(rightEyeX + w * 0.02, eyeY - h * 0.02), w * 0.03, whiteEyePaint);
    } else if (eyes == 1) {
      // Fâchés
      canvas.drawCircle(Offset(leftEyeX, eyeY), w * 0.07, eyePaint);
      canvas.drawCircle(Offset(rightEyeX, eyeY), w * 0.07, eyePaint);
      // Sourcils
      final browPaint = Paint()..color = Colors.black..strokeWidth = 3..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(leftEyeX - w * 0.08, eyeY - h * 0.08), Offset(leftEyeX + w * 0.05, eyeY - h * 0.02), browPaint);
      canvas.drawLine(Offset(rightEyeX + w * 0.08, eyeY - h * 0.08), Offset(rightEyeX - w * 0.05, eyeY - h * 0.02), browPaint);
    } else if (eyes == 2) {
      // Mignons (étoiles ou grands yeux)
      canvas.drawCircle(Offset(leftEyeX, eyeY), w * 0.1, eyePaint);
      canvas.drawCircle(Offset(rightEyeX, eyeY), w * 0.1, eyePaint);
      canvas.drawCircle(Offset(leftEyeX + w * 0.03, eyeY - h * 0.03), w * 0.04, whiteEyePaint);
      canvas.drawCircle(Offset(rightEyeX + w * 0.03, eyeY - h * 0.03), w * 0.04, whiteEyePaint);
      canvas.drawCircle(Offset(leftEyeX - w * 0.02, eyeY + h * 0.02), w * 0.02, whiteEyePaint);
      canvas.drawCircle(Offset(rightEyeX - w * 0.02, eyeY + h * 0.02), w * 0.02, whiteEyePaint);
    }

    // --- BOUCHE ---
    final mouthPaint = Paint()..color = Colors.black..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    double mouthY = h * 0.7;

    if (mouth == 0) {
      // Sourire
      Path mPath = Path();
      mPath.moveTo(w * 0.45, mouthY);
      mPath.quadraticBezierTo(w * 0.5, mouthY + h * 0.05, w * 0.55, mouthY);
      canvas.drawPath(mPath, mouthPaint);
    } else if (mouth == 1) {
      // Triste
      Path mPath = Path();
      mPath.moveTo(w * 0.45, mouthY + h * 0.03);
      mPath.quadraticBezierTo(w * 0.5, mouthY, w * 0.55, mouthY + h * 0.03);
      canvas.drawPath(mPath, mouthPaint);
    } else if (mouth == 2) {
      // Surpris ("O")
      canvas.drawCircle(Offset(w * 0.5, mouthY), w * 0.04, mouthPaint..style = PaintingStyle.fill);
    }

    // --- ACCESSOIRE ---
    if (accessory == 1) {
      // Couronne
      final crownPaint = Paint()..color = Colors.yellowAccent.shade700..style = PaintingStyle.fill;
      Path cPath = Path();
      cPath.moveTo(w * 0.3, h * 0.2);
      cPath.lineTo(w * 0.3, h * 0.05);
      cPath.lineTo(w * 0.4, h * 0.15);
      cPath.lineTo(w * 0.5, h * 0.02);
      cPath.lineTo(w * 0.6, h * 0.15);
      cPath.lineTo(w * 0.7, h * 0.05);
      cPath.lineTo(w * 0.7, h * 0.2);
      cPath.close();
      canvas.drawPath(cPath, crownPaint);
    } else if (accessory == 2) {
      // Casquette
      final hatPaint = Paint()..color = Colors.red..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromLTWH(w * 0.3, h * 0.05, w * 0.4, h * 0.3), 3.14, 3.14, true, hatPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.3, h * 0.18, w * 0.6, h * 0.05), const Radius.circular(5)), hatPaint);
    } else if (accessory == 3) {
      // Lunettes de soleil
      final glassPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, eyeY - h * 0.05, w * 0.22, h * 0.12), const Radius.circular(5)), glassPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, eyeY - h * 0.05, w * 0.22, h * 0.12), const Radius.circular(5)), glassPaint);
      canvas.drawLine(Offset(w * 0.47, eyeY), Offset(w * 0.53, eyeY), Paint()..color = Colors.black..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(covariant SlimePainter oldDelegate) {
    return color != oldDelegate.color || eyes != oldDelegate.eyes || mouth != oldDelegate.mouth || accessory != oldDelegate.accessory;
  }
}
