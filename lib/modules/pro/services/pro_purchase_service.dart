import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'pro_access_service.dart';

/// Google Play billing bridge for KAMLOKA Pro.
///
/// Google Play one-time purchase for lifetime KAMLOKA Pro access.
class ProPurchaseService extends GetxService {
  static const String proProductId = 'kamloka_pro';

  final InAppPurchase _billing = InAppPurchase.instance;
  final RxBool storeAvailable = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool purchasePending = false.obs;
  final Rxn<ProductDetails> product = Rxn<ProductDetails>();
  final RxString statusMessage =
      'ID produk Google Play akan diisi setelah upload aplikasi.'.obs;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool get isProductConfigured => proProductId.trim().isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    _purchaseSubscription = _billing.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        statusMessage.value = 'Pembaruan pembelian gagal: $error';
        purchasePending.value = false;
      },
    );
    initialize();
  }

  Future<void> initialize() async {
    isLoading.value = true;
    try {
      storeAvailable.value = await _billing.isAvailable();
      if (!storeAvailable.value) {
        statusMessage.value = 'Google Play Billing belum tersedia di perangkat ini.';
        return;
      }
      if (!isProductConfigured) {
        statusMessage.value =
            'Integrasi billing siap. ID produk menunggu produk dibuat di Play Console.';
        return;
      }

      final response = await _billing.queryProductDetails({proProductId});
      if (response.error != null) {
        statusMessage.value =
            'Produk belum dapat dimuat: ${response.error!.message}';
        return;
      }
      if (response.notFoundIDs.contains(proProductId) ||
          response.productDetails.isEmpty) {
        statusMessage.value =
            'Produk Pro belum ditemukan. Periksa ID produk dan konfigurasi Play Console.';
        return;
      }

      product.value = response.productDetails.firstWhere(
        (item) => item.id == proProductId,
      );
      statusMessage.value = 'Produk KAMLOKA Pro tersedia.';
      // Re-query owned non-consumable purchases so Pro access is restored
      // after an app restart or reinstall. The purchase stream handles results.
      try {
        await _billing.restorePurchases();
      } catch (error) {
        if (kDebugMode) {
          debugPrint('KAMLOKA automatic purchase restore error: $error');
        }
      }
    } catch (error) {
      statusMessage.value = 'Gagal menghubungkan Google Play: $error';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> buyPro() async {
    final details = product.value;
    if (!storeAvailable.value || details == null || purchasePending.value) {
      statusMessage.value = isProductConfigured
          ? 'Produk belum siap dibeli. Coba muat ulang produk.'
          : 'Pembelian akan diaktifkan setelah ID produk tersedia dari Play Console.';
      return;
    }

    try {
      purchasePending.value = true;
      statusMessage.value = 'Menunggu konfirmasi Google Play…';
      final started = await _billing.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) {
        purchasePending.value = false;
        statusMessage.value = 'Google Play tidak memulai proses pembelian.';
      }
    } catch (error) {
      purchasePending.value = false;
      statusMessage.value = 'Pembelian gagal dimulai: $error';
    }
  }

  Future<void> restorePurchases() async {
    if (!storeAvailable.value) {
      statusMessage.value = 'Google Play Billing belum tersedia.';
      return;
    }
    if (!isProductConfigured) {
      statusMessage.value =
          'Pemulihan pembelian dapat diuji setelah ID produk tersedia.';
      return;
    }

    try {
      isLoading.value = true;
      await _billing.restorePurchases();
      statusMessage.value = 'Memeriksa pembelian sebelumnya melalui Google Play…';
    } catch (error) {
      statusMessage.value = 'Pemulihan pembelian gagal: $error';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (isProductConfigured && purchase.productID != proProductId) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasePending.value = true;
          statusMessage.value = 'Pembelian sedang diproses Google Play…';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // This client currently grants access from Google Play purchase
          // updates. Add trusted server-side purchase-token verification before
          // treating this as tamper-resistant entitlement enforcement.
          if (isProductConfigured && purchase.productID == proProductId) {
            Get.find<ProAccessService>().isPro.value = true;
            statusMessage.value = purchase.status == PurchaseStatus.restored
                ? 'Pembelian KAMLOKA Pro berhasil dipulihkan.'
                : 'Pembelian KAMLOKA Pro diterima.';
          }
          purchasePending.value = false;
          break;
        case PurchaseStatus.error:
          purchasePending.value = false;
          statusMessage.value =
              'Pembelian gagal: ${purchase.error?.message ?? 'Kesalahan tidak diketahui'}';
          break;
        case PurchaseStatus.canceled:
          purchasePending.value = false;
          statusMessage.value = 'Pembelian dibatalkan.';
          break;
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await _billing.completePurchase(purchase);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('KAMLOKA completePurchase error: $error');
          }
        }
      }
    }
  }

  @override
  void onClose() {
    _purchaseSubscription?.cancel();
    super.onClose();
  }
}
