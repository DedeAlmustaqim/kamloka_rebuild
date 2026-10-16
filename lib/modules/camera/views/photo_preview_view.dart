import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../gallery/services/gallery_service.dart';

class PhotoPreviewView extends StatelessWidget {
  const PhotoPreviewView({
    super.key,
    required this.filePath,
  });

  final String filePath;

  Future<void> _sharePhoto(BuildContext context) async {
    final file = File(filePath);
    if (!await file.exists()) {
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
        icon: const Icon(Icons.delete_outline_rounded, size: 32),
        title: const Text('Hapus foto?'),
        content: const Text('Foto ini akan dihapus dari penyimpanan aplikasi. Jika sudah tersimpan di galeri, salinan galeri tidak ikut dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
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
      backgroundColor: Colors.black,
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CircleAction(
                    icon: Icons.close_rounded,
                    tooltip: 'Tutup',
                    onPressed: Get.back,
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Text(
                        'FOTO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  _CircleAction(
                    icon: Icons.share_outlined,
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
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomAction(
                        icon: Icons.ios_share_rounded,
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
      color: Colors.black54,
      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
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
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: destructive ? Colors.red.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.16),
        foregroundColor: destructive ? Colors.red.shade100 : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      ),
      icon: Icon(icon, size: 19),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
