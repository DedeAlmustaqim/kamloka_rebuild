import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// KAMLOKA's single source of truth for feature access.
///
/// The developer override is available only in debug builds. Store-backed
/// entitlements can replace this temporary mechanism when billing is ready.
enum KamlokaFeature {
  cameraCapture,
  locationWatermark,
  fieldDocumentation,
  premiumWatermarkTemplates,
  advancedWatermarkCustomization,
}

class ProAccessService extends GetxService {
  /// Current entitlement state. New installs and release builds default to Free.
  final RxBool isPro = false.obs;

  /// Temporary development-only switch; release builds cannot change access
  /// through this method. Purchase integration must validate store entitlement.
  void setDeveloperProOverride(bool enabled) {
    if (!kDebugMode) return;
    isPro.value = enabled;
  }

  bool hasAccess(KamlokaFeature feature) {
    switch (feature) {
      case KamlokaFeature.cameraCapture:
      case KamlokaFeature.locationWatermark:
        return true;
      case KamlokaFeature.fieldDocumentation:
      case KamlokaFeature.premiumWatermarkTemplates:
      case KamlokaFeature.advancedWatermarkCustomization:
        return isPro.value;
    }
  }
}
