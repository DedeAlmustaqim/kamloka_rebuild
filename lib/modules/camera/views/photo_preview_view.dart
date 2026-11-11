import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class PhotoPreviewView extends StatelessWidget {
  const PhotoPreviewView({
    super.key,
    required this.filePath,
  });

  final String filePath;

  Future<void> _sharePhoto(BuildContext context) async {
    final file = File(filePath);
    final exists = await file.exists();
    if (!context.mounted) return;
    if (!exists) {
      _showMessage(context, 'Foto tidak ditemukan.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'Foto dari KAMLOKA',
        ),
      );
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Foto gagal dibagikan: $error');
      }
    }
  }

  Future<void> _deletePhoto(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, size: 30),
        title: const Text('Hapus foto?'),
        content: const Text(
          'Foto ini akan dihapus dari penyimpanan aplikasi. '
          'Jika sudah tersimpan di galeri, salinan galeri tidak ikut dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF292929),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus foto'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
      if (context.mounted) {
        Navigator.of(context).pop();
        _showMessage(context, 'Foto berhasil dihapus.');
      }
    } catch (error) {
      if (context.mounted) _showMessage(context, 'Foto gagal dihapus: $error');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
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
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xB3000000),
                  ],
                  stops: [0, 0.22, 0.68, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CircleAction(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onPressed: Get.back,
                  ),
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KAMLOKA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'PHOTO PREVIEW',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CircleAction(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Bagikan foto',
                    onPressed: () => _sharePhoto(context),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomAction(
                        icon: Icons.share_outlined,
                        label: 'Bagikan',
                        onPressed: () => _sharePhoto(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BottomAction(
                        icon: Icons.delete_outline_rounded,
                        label: 'Hapus',
                        destructive: true,
                        onPressed: () => _deletePhoto(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white30, width: 1),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: destructive ? Colors.white : Colors.black,
        backgroundColor: destructive
            ? Colors.black.withValues(alpha: 0.58)
            : Colors.white,
        side: BorderSide(
          color: destructive ? Colors.white54 : Colors.white,
        ),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
