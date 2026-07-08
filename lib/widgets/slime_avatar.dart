import 'package:flutter/material.dart';
import 'dart:math';

class SlimeAvatar extends StatefulWidget {
  final Map<String, dynamic>? config;
  final double size;

  const SlimeAvatar({super.key, this.config, this.size = 100});

  @override
  State<SlimeAvatar> createState() => _SlimeAvatarState();
}

class _SlimeAvatarState extends State<SlimeAvatar> with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _actionController;
  int _actionType = 0;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  void _triggerAction() {
    if (!_actionController.isAnimating) {
      setState(() {
        _actionType = Random().nextInt(4); // 4 animations différentes
      });
      _actionController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorString = widget.config?['color'] ?? 'blue';
    final eyesType = widget.config?['eyes'] ?? 0;
    final mouthType = widget.config?['mouth'] ?? 0;
    final accessoryType = widget.config?['accessory'] ?? 0;

    Color slimeColor = _getColor(colorString);

    return GestureDetector(
      onTap: _triggerAction,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breatheController, _actionController]),
        builder: (context, child) {
          // Effet de respiration
          double squash = 1.0 - (_breatheController.value * 0.08);
          double stretch = 1.0 + (_breatheController.value * 0.05);
          
          double dx = 0;
          double dy = 0;
          double rotation = 0;

          // Animations au toucher
          if (_actionController.isAnimating) {
            double actionVal = _actionController.value;
            double bellCurve = sin(actionVal * pi); // 0 -> 1 -> 0

            switch (_actionType) {
              case 0: // Saut classique
                dy = -(bellCurve * 40.0);
                squash = 1.0 + (bellCurve * 0.2);
                stretch = 1.0 - (bellCurve * 0.1);
                break;
              case 1: // Tonneau (Spin)
                rotation = actionVal * 2 * pi; // Fait un tour complet
                dy = -(bellCurve * 20.0); // Saute un peu en tournant
                break;
              case 2: // Frétillement (Wobble)
                double wobble = sin(actionVal * pi * 6); // Oscille 6 fois
                dx = wobble * 12.0;
                squash = 1.0 - (wobble.abs() * 0.1); // S'écrase légèrement à chaque secousse
                stretch = 1.0 + (wobble.abs() * 0.1);
                break;
              case 3: // Écrasement (Flan)
                squash = 1.0 - (bellCurve * 0.5); // S'aplatit violemment
                stretch = 1.0 + (bellCurve * 0.6); // S'élargit beaucoup
                dy = bellCurve * 15.0; // S'abaisse vers le sol
                break;
            }
          }

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
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
            ),
            ),
          );
        },
      ),
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
      case 'cyan': return Colors.cyan.shade400;
      case 'orange': return Colors.orange.shade400;
      case 'brown': return Colors.brown.shade400;
      case 'white': return Colors.grey.shade300;
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

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    Path path = Path();
    double width = size;
    double height = size;
    path.moveTo(center.dx, center.dy - height * 0.1);
    path.cubicTo(center.dx - width * 0.5, center.dy - height * 0.6, center.dx - width, center.dy, center.dx, center.dy + height * 0.4);
    path.cubicTo(center.dx + width, center.dy, center.dx + width * 0.5, center.dy - height * 0.6, center.dx, center.dy - height * 0.1);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- CORPS DU SLIME ---
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Un slime bien rond (Jelly)
    Path bodyPath = Path();
    bodyPath.moveTo(w * 0.15, h * 0.88); // Bas gauche
    // Courbe gauche (très bombée)
    bodyPath.cubicTo(
      w * -0.05, h * 0.8,  // Point de contrôle 1 (pousse vers la gauche en bas)
      w * 0.1, h * 0.15,   // Point de contrôle 2 (arrondi en haut à gauche)
      w * 0.5, h * 0.15,   // Sommet (milieu haut)
    );
    // Courbe droite (très bombée)
    bodyPath.cubicTo(
      w * 0.9, h * 0.15,   // Point de contrôle 1 (arrondi en haut à droite)
      w * 1.05, h * 0.8,   // Point de contrôle 2 (pousse vers la droite en bas)
      w * 0.85, h * 0.88,  // Bas droite
    );
    // Base plate (légèrement incurvée)
    bodyPath.quadraticBezierTo(w * 0.5, h * 0.98, w * 0.15, h * 0.88);
    
    canvas.drawPath(bodyPath, bodyPaint);
    
    // Highlight (Reflet plus incurvé pour s'adapter au volume)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    Path highlightPath = Path();
    highlightPath.moveTo(w * 0.2, h * 0.4);
    highlightPath.quadraticBezierTo(w * 0.25, h * 0.25, w * 0.45, h * 0.25);
    highlightPath.quadraticBezierTo(w * 0.35, h * 0.35, w * 0.25, h * 0.45);
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
    } else if (eyes == 3) {
      // Endormi
      final sleepPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
      Path leftPath = Path()..moveTo(leftEyeX - w * 0.05, eyeY)..quadraticBezierTo(leftEyeX, eyeY + h * 0.02, leftEyeX + w * 0.05, eyeY);
      Path rightPath = Path()..moveTo(rightEyeX - w * 0.05, eyeY)..quadraticBezierTo(rightEyeX, eyeY + h * 0.02, rightEyeX + w * 0.05, eyeY);
      canvas.drawPath(leftPath, sleepPaint);
      canvas.drawPath(rightPath, sleepPaint);
    } else if (eyes == 4) {
      // Coeurs
      final heartPaint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
      _drawHeart(canvas, Offset(leftEyeX, eyeY), w * 0.1, heartPaint);
      _drawHeart(canvas, Offset(rightEyeX, eyeY), w * 0.1, heartPaint);
    } else if (eyes == 5) {
      // K.O. (X)
      final crossPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(leftEyeX - w * 0.04, eyeY - h * 0.02), Offset(leftEyeX + w * 0.04, eyeY + h * 0.02), crossPaint);
      canvas.drawLine(Offset(leftEyeX + w * 0.04, eyeY - h * 0.02), Offset(leftEyeX - w * 0.04, eyeY + h * 0.02), crossPaint);
      canvas.drawLine(Offset(rightEyeX - w * 0.04, eyeY - h * 0.02), Offset(rightEyeX + w * 0.04, eyeY + h * 0.02), crossPaint);
      canvas.drawLine(Offset(rightEyeX + w * 0.04, eyeY - h * 0.02), Offset(rightEyeX - w * 0.04, eyeY + h * 0.02), crossPaint);
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
    } else if (mouth == 3) {
      // Chat (:3)
      Path mPath = Path();
      mPath.moveTo(w * 0.45, mouthY);
      mPath.quadraticBezierTo(w * 0.475, mouthY + h * 0.03, w * 0.5, mouthY);
      mPath.quadraticBezierTo(w * 0.525, mouthY + h * 0.03, w * 0.55, mouthY);
      canvas.drawPath(mPath, mouthPaint);
    } else if (mouth == 4) {
      // Langue
      Path mPath = Path();
      mPath.moveTo(w * 0.45, mouthY);
      mPath.quadraticBezierTo(w * 0.5, mouthY + h * 0.03, w * 0.55, mouthY);
      canvas.drawPath(mPath, mouthPaint);
      
      final tonguePaint = Paint()..color = Colors.pinkAccent..style = PaintingStyle.fill;
      Path tPath = Path();
      tPath.moveTo(w * 0.48, mouthY + h * 0.015);
      tPath.lineTo(w * 0.48, mouthY + h * 0.05);
      tPath.quadraticBezierTo(w * 0.5, mouthY + h * 0.07, w * 0.52, mouthY + h * 0.05);
      tPath.lineTo(w * 0.52, mouthY + h * 0.015);
      canvas.drawPath(tPath, tonguePaint);
    } else if (mouth == 5) {
      // Vampire
      Path mPath = Path();
      mPath.moveTo(w * 0.45, mouthY);
      mPath.quadraticBezierTo(w * 0.5, mouthY + h * 0.02, w * 0.55, mouthY);
      canvas.drawPath(mPath, mouthPaint);
      
      final fangPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
      Path f1 = Path()..moveTo(w * 0.46, mouthY + h * 0.005)..lineTo(w * 0.48, mouthY + h * 0.005)..lineTo(w * 0.47, mouthY + h * 0.03)..close();
      Path f2 = Path()..moveTo(w * 0.52, mouthY + h * 0.005)..lineTo(w * 0.54, mouthY + h * 0.005)..lineTo(w * 0.53, mouthY + h * 0.03)..close();
      canvas.drawPath(f1, fangPaint);
      canvas.drawPath(f2, fangPaint);
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
    } else if (accessory == 4) {
      // Auréole (Halo)
      final haloPaint = Paint()..color = Colors.yellowAccent..style = PaintingStyle.stroke..strokeWidth = 4;
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.02), width: w * 0.35, height: h * 0.08), haloPaint);
    } else if (accessory == 5) {
      // Cornes (Horns)
      final hornPaint = Paint()..color = Colors.red.shade900..style = PaintingStyle.fill;
      Path h1 = Path()..moveTo(w * 0.25, h * 0.2)..quadraticBezierTo(w * 0.2, h * 0.05, w * 0.15, h * 0.02)..quadraticBezierTo(w * 0.25, h * 0.1, w * 0.35, h * 0.15)..close();
      Path h2 = Path()..moveTo(w * 0.75, h * 0.2)..quadraticBezierTo(w * 0.8, h * 0.05, w * 0.85, h * 0.02)..quadraticBezierTo(w * 0.75, h * 0.1, w * 0.65, h * 0.15)..close();
      canvas.drawPath(h1, hornPaint);
      canvas.drawPath(h2, hornPaint);
    } else if (accessory == 6) {
      // Casque (Headphones)
      final bandPaint = Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 5;
      final padPaint = Paint()..color = Colors.blueAccent..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.5), 3.14, 3.14, false, bandPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.02, h * 0.4, w * 0.15, h * 0.25), const Radius.circular(8)), padPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.83, h * 0.4, w * 0.15, h * 0.25), const Radius.circular(8)), padPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SlimePainter oldDelegate) {
    return color != oldDelegate.color || eyes != oldDelegate.eyes || mouth != oldDelegate.mouth || accessory != oldDelegate.accessory;
  }
}
