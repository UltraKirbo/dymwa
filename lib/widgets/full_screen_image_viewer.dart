import 'package:flutter/material.dart';
import 'dart:convert';

class FullScreenImageViewer extends StatelessWidget {
  final String base64Image;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    required this.base64Image,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Hero(
            tag: tag,
            child: Image.memory(
              base64Decode(base64Image),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
