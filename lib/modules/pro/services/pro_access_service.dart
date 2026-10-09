import 'package:get/get.dart';

/// KAMLOKA's single source of truth for feature access.
///
/// Purchase/restore integration is intentionally not implemented yet.
/// Until a trusted entitlement source is added, the app must remain Free.
enum KamlokaFeature {
  cameraCapture,
  locationWatermark,
  premiumWatermarkTemplates,
  advancedWatermarkCustomization,
}

class ProAccessService extends GetxService {
  /// Defaults to Free. Do not set this from UI or user-controlled preferences.
  /// Future billing integration should update this only after validating
  /// an entitlement from the store/backend.
  final RxBool isPro = false.obs;

  bool hasAccess(KamlokaFeature feature) {
    switch (feature) {
      case KamlokaFeature.cameraCapture:
      case KamlokaFeature.locationWatermark:
        return true;
      case KamlokaFeature.premiumWatermarkTemplates:
      case KamlokaFeature.advancedWatermarkCustomization:
        return isPro.value;
    }
  }
}
