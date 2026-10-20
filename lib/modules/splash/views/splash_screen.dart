import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../camera/bindings/camera_binding.dart';
import '../../camera/views/camera_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minimumSplashDuration = Duration(milliseconds: 1400);
  static const _updateCheckTimeout = Duration(seconds: 4);
  static const _updateManifestUrl =
      'https://raw.githubusercontent.com/DedeAlmustaqim/'
      'kamloka-privacy-policy/main/update.json';
  static const _appInfoChannel = MethodChannel('kamloka/app_info');

  @override
  void initState() {
    super.initState();
    unawaited(_continueStartup());
  }

  Future<void> _continueStartup() async {
    await Future<void>.delayed(_minimumSplashDuration);
    if (!mounted) return;

    await _checkForUpdate();
    if (!mounted) return;

    Get.offAll(
      () => const CameraView(),
      binding: CameraBinding(),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 250),
    );
  }

  Future<void> _checkForUpdate() async {
    try {
      final response = await http
          .get(
            Uri.parse(_updateManifestUrl),
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(_updateCheckTimeout);

      if (response.statusCode != 200) return;

      final manifest = jsonDecode(response.body);
      if (manifest is! Map<String, dynamic>) return;

      final latestVersion = manifest['latestVersion'];
      final releaseNotes = manifest['releaseNotes'];
      final playStoreUrl = manifest['playStoreUrl'];

      if (latestVersion is! String ||
          playStoreUrl is! String ||
          playStoreUrl.isEmpty) {
        return;
      }

      final currentVersion =
          await _appInfoChannel.invokeMethod<String>('getVersionName')
              .timeout(_updateCheckTimeout);
      if (!mounted || currentVersion == null) return;
      if (_compareVersions(latestVersion, currentVersion) <= 0) return;

      final shouldUpdate = await _showUpdateDialog(
        latestVersion: latestVersion,
        releaseNotes: releaseNotes is String ? releaseNotes : null,
      );

      if (shouldUpdate == true) {
        await _appInfoChannel.invokeMethod<bool>(
          'openUrl',
          {'url': playStoreUrl},
        );
      }
    } on TimeoutException {
      debugPrint('[KAMLOKA UPDATE] Pemeriksaan versi melewati batas waktu.');
    } on PlatformException catch (error) {
      debugPrint('[KAMLOKA UPDATE] Kesalahan platform: ${error.message}');
    } catch (error, stackTrace) {
      // Update checking is best-effort. Never block camera startup on failure.
      debugPrint('[KAMLOKA UPDATE] Gagal memeriksa versi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  int _compareVersions(String first, String second) {
    final firstParts = first.split('.').map((part) => int.tryParse(part) ?? 0);
    final secondParts =
        second.split('.').map((part) => int.tryParse(part) ?? 0);
    final left = firstParts.toList();
    final right = secondParts.toList();
    final length = left.length > right.length ? left.length : right.length;

    for (var index = 0; index < length; index++) {
      final a = index < left.length ? left[index] : 0;
      final b = index < right.length ? right[index] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  Future<bool?> _showUpdateDialog({
    required String latestVersion,
    String? releaseNotes,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        elevation: 12,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Color(0xFF167D75),
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Pembaruan KAMLOKA tersedia',
                style: TextStyle(
                  color: Color(0xFF18232C),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versi $latestVersion sudah tersedia di Google Play.',
                style: const TextStyle(
                  color: Color(0xFF52606D),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (releaseNotes != null && releaseNotes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  releaseNotes,
                  style: const TextStyle(
                    color: Color(0xFF52606D),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF167D75),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(
                    'Perbarui Sekarang',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Nanti saja',
                    style: TextStyle(
                      color: Color(0xFF52606D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        systemNavigationBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Image.asset(
            'assets/images/kamloka_typo.png',
            width: 232,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text(
              'KAMLOKA',
              style: TextStyle(
                color: Color(0xFF18232C),
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
