import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PhotoPreviewView extends StatelessWidget {
  const PhotoPreviewView({
    super.key,
    required this.filePath,
  });

  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F3),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.file(
                File(filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      'Foto tidak dapat ditampilkan.',
                      style: TextStyle(color: Color(0xFF68716B)), 
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close, color: Color(0xFF202522)), 
                    tooltip: 'Tutup',
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 22),
                child: Text(
                  'FOTO',
                  style: TextStyle(
                    color: Color(0xFF202522),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
