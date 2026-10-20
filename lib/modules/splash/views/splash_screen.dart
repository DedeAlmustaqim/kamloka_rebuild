import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:new_version_plus/new_version_plus.dart';

import '../../camera/bindings/camera_binding.dart';
import '../../camera/views/camera_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minimumSplashDuration = Duration(milliseconds: 1400);
  static const _versionCheckTimeout = Duration(seconds: 4);

  final NewVersionPlus _newVersion = NewVersionPlus(
    androidId: 'com.digitalnative.kamloka',
    androidPlayStoreCountry: 'id',
  );

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
      final status = await _newVersion
          .getVersionStatus()
          .timeout(_versionCheckTimeout);

      if (!mounted || status == null || !status.canUpdate) return;

      await _newVersion.showUpdateDialog(
        context: context,
        versionStatus: status,
        dialogTitle: 'Pembaruan KAMLOKA tersedia',
        dialogText:
            'Versi ${status.storeVersion} sudah tersedia di Google Play. '
            'Perbarui KAMLOKA untuk mendapatkan perbaikan dan peningkatan terbaru.',
        updateButtonText: 'Perbarui Sekarang',
        dismissButtonText: 'Nanti saja',
        allowDismissal: true,
        launchModeVersion: LaunchModeVersion.external,
      );
    } on TimeoutException {
      debugPrint('[KAMLOKA UPDATE] Pemeriksaan versi melewati batas waktu.');
    } catch (error, stackTrace) {
      // Version checking is best-effort: network/store errors must never block
      // users from opening the camera.
      debugPrint('[KAMLOKA UPDATE] Gagal memeriksa versi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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
