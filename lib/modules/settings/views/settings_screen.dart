import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../pro/services/pro_access_service.dart';
import '../../pro/services/pro_purchase_service.dart';
import '../../pro/views/pro_trips_screen.dart';
import '../../pro/theme/pro_theme.dart';
import '../../pro/widgets/pro_message_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color _background = ProTheme.background;
  static const Color _surface = ProTheme.surface;
  static const Color _muted = ProTheme.secondaryText;

  @override
  Widget build(BuildContext context) {
    return ProTheme.apply(
      Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: ProTheme.text,
          elevation: 0,
          title: const Text(
            'Pengaturan',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/kamloka_typo.png',
                    width: 132,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Atur preferensi aplikasi',
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const _SectionLabel('Preferensi'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ProTheme.border),
              ),
              child: const Column(
                children: [
                  _InfoTile(
                    icon: Icons.layers_outlined,
                    title: 'Watermark foto',
                    subtitle: 'Otomatis ditambahkan saat foto diproses',
                  ),
                  Divider(height: 1, indent: 58, color: ProTheme.border),
                  _InfoTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Penyimpanan',
                    subtitle: 'Foto disimpan ke album KAMLOKA',
                  ),
                ],
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              const _SectionLabel('Developer'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ProTheme.border),
                ),
                child: Obx(() {
                  final access = Get.find<ProAccessService>();
                  return SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    secondary: Icon(
                      access.isPro.value
                          ? Icons.workspace_premium_rounded
                          : Icons.developer_mode_rounded,
                      color: access.isPro.value
                          ? ProTheme.primaryDark
                          : ProTheme.secondaryText,
                    ),
                    title: Text(
                      access.isPro.value
                          ? 'Mode PRO aktif'
                          : 'Mode Gratis aktif',
                      style: const TextStyle(
                        color: ProTheme.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Sementara untuk pengujian fitur. Hanya tampil pada debug build.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    value: access.isPro.value,
                    activeThumbColor: ProTheme.primaryDark,
                    onChanged: access.setDeveloperProOverride,
                  );
                }),
              ),
            ],
            const SizedBox(height: 24),
            const _SectionLabel('Tentang KAMLOKA Pro'),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Get.to(
                  () => const KamlokaProScreen(),
                  transition: Transition.cupertino,
                ),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ProTheme.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: ProTheme.primaryDark,
                        size: 28,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KAMLOKA Pro',
                              style: TextStyle(
                                color: ProTheme.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Dokumentasi perjalanan dan fitur tambahan',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: ProTheme.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Center(
              child: Text(
                'KAMLOKA • Kamera Lokasi',
                style: TextStyle(color: ProTheme.secondaryText, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: ProTheme.text,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Icon(icon, color: ProTheme.secondaryText),
      title: Text(
        title,
        style: const TextStyle(
          color: ProTheme.text,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: SettingsScreen._muted, fontSize: 12),
      ),
    );
  }
}

class KamlokaProScreen extends StatefulWidget {
  const KamlokaProScreen({super.key});

  @override
  State<KamlokaProScreen> createState() => _KamlokaProScreenState();
}

class _KamlokaProScreenState extends State<KamlokaProScreen> {
  Worker? _purchaseStatusWorker;

  @override
  void initState() {
    super.initState();
    final billing = Get.find<ProPurchaseService>();
    _purchaseStatusWorker = ever<String>(billing.statusMessage, (message) {
      final isActionResult =
          message.contains('Pembelian KAMLOKA Pro diterima') ||
          message.contains('berhasil dipulihkan') ||
          message.startsWith('Pembelian gagal:') ||
          message == 'Pembelian dibatalkan.' ||
          message.startsWith('Produk belum dapat dimuat:') ||
          message.startsWith('Produk Pro belum ditemukan.') ||
          message.startsWith('Gagal menghubungkan Google Play:');
      if (!isActionResult || !mounted) return;

      final isError =
          message.startsWith('Pembelian gagal:') ||
          message.startsWith('Produk belum dapat dimuat:') ||
          message.startsWith('Produk Pro belum ditemukan.') ||
          message.startsWith('Gagal menghubungkan Google Play:');
      final isSuccess =
          message.contains('diterima') ||
          message.contains('berhasil dipulihkan');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showProMessageDialog(
          context: context,
          title: isSuccess
              ? 'KAMLOKA Pro aktif'
              : isError
              ? 'Belum berhasil'
              : 'Informasi pembelian',
          message: message,
          type: isSuccess
              ? ProMessageType.success
              : isError
              ? ProMessageType.error
              : ProMessageType.info,
        );
      });
    });
  }

  @override
  void dispose() {
    _purchaseStatusWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProTheme.apply(
      Scaffold(
        appBar: AppBar(title: const Text('KAMLOKA Pro')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Semua dokumentasi,\nlebih teratur.',
                      style: TextStyle(
                        color: ProTheme.text,
                        fontSize: 24,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Simpan perjalanan, lokasi, dan foto dalam satu catatan yang mudah dibagikan.',
                      style: TextStyle(
                        color: ProTheme.secondaryText,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Obx(() {
                final pro = Get.find<ProAccessService>();
                final billing = Get.find<ProPurchaseService>();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: ProTheme.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: ProTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: pro.isPro.value
                              ? const Color(0xFFE3F4E8)
                              : const Color(0xFFF0F1EC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          pro.isPro.value
                              ? Icons.verified_rounded
                              : Icons.info_outline_rounded,
                          color: pro.isPro.value
                              ? ProTheme.green
                              : ProTheme.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pro.isPro.value
                                  ? 'KAMLOKA Pro aktif'
                                  : 'Status akses',
                              style: const TextStyle(
                                color: ProTheme.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pro.isPro.value
                                  ? 'Akses premium tersedia di perangkat ini.'
                                  : billing.statusMessage.value,
                              style: const TextStyle(
                                color: ProTheme.secondaryText,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (kDebugMode) ...[
                const SizedBox(height: 14),
                Obx(() {
                  final access = Get.find<ProAccessService>();
                  return Container(
                    decoration: BoxDecoration(
                      color: ProTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ProTheme.border),
                    ),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      secondary: Icon(
                        access.isPro.value
                            ? Icons.workspace_premium_rounded
                            : Icons.developer_mode_rounded,
                        color: access.isPro.value
                            ? ProTheme.primaryDark
                            : ProTheme.secondaryText,
                      ),
                      title: Text(
                        access.isPro.value
                            ? 'Uji fitur PRO: Aktif'
                            : 'Uji fitur PRO: Nonaktif',
                        style: const TextStyle(
                          color: ProTheme.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Sakelar sementara untuk pengujian developer. Tidak tersedia pada build rilis.',
                        style: TextStyle(
                          color: ProTheme.secondaryText,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      value: access.isPro.value,
                      activeThumbColor: ProTheme.primaryDark,
                      onChanged: access.setDeveloperProOverride,
                    ),
                  );
                }),
              ],
              const SizedBox(height: 14),
              Obx(() {
                final billing = Get.find<ProPurchaseService>();
                final access = Get.find<ProAccessService>();
                final product = billing.product.value;
                final canBuy =
                    product != null &&
                    billing.storeAvailable.value &&
                    !billing.purchasePending.value &&
                    !access.isPro.value;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ProTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ProTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4D6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: ProTheme.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Akses Pro',
                                  style: TextStyle(
                                    color: ProTheme.text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Sekali bayar • Akses PRO permanen',
                                  style: TextStyle(
                                    color: ProTheme.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (billing.isLoading.value)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: canBuy ? billing.buyPro : null,
                        icon: billing.purchasePending.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          access.isPro.value
                              ? 'KAMLOKA Pro sudah aktif'
                              : product == null
                              ? (billing.isLoading.value
                                    ? 'Memuat produk Google Play…'
                                    : 'Produk belum tersedia')
                              : 'Beli KAMLOKA Pro • ${product.price}',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: billing.isLoading.value
                            ? null
                            : billing.restorePurchases,
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('Pulihkan pembelian'),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ProTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: ProTheme.secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                billing.statusMessage.value,
                                style: const TextStyle(
                                  color: ProTheme.secondaryText,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: billing.isLoading.value
                            ? null
                            : billing.initialize,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Periksa produk'),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              // const Text(
              //   'Fitur KAMLOKA Pro',
              //   style: TextStyle(
              //     color: ProTheme.text,
              //     fontSize: 17,
              //     fontWeight: FontWeight.w700,
              //   ),
              // ),
              // const SizedBox(height: 6),
              // const Text(
              //   'Fitur untuk membantu merapikan dokumentasi perjalanan. Harga ditampilkan langsung dari Google Play.',
              //   style: TextStyle(
              //     color: ProTheme.secondaryText,
              //     fontSize: 13,
              //     height: 1.45,
              //   ),
              // ),
              // const SizedBox(height: 12),
              // _ProFeatureRow(
              //   title: 'Template watermark premium',
              //   feature: KamlokaFeature.premiumWatermarkTemplates,
              // ),
              // const SizedBox(height: 10),
              // _ProFeatureRow(
              //   title: 'Kustomisasi watermark lanjutan',
              //   feature: KamlokaFeature.advancedWatermarkCustomization,
              // ),
              // const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => Get.to(
                  () => const ProTripsScreen(),
                  transition: Transition.cupertino,
                ),
                icon: const Icon(Icons.route_outlined),
                label: const Text('Buka dokumentasi perjalanan'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: Get.back,
                child: const Text('Kembali ke pengaturan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  const _ProFeatureRow({required this.title, required this.feature});

  final String title;
  final KamlokaFeature feature;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final available = Get.find<ProAccessService>().hasAccess(feature);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: ProTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ProTheme.border),
        ),
        child: Row(
          children: [
            Icon(
              available
                  ? Icons.check_circle_outline_rounded
                  : Icons.schedule_rounded,
              color: available ? ProTheme.green : ProTheme.secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: ProTheme.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              available ? 'Aktif' : 'Direncanakan',
              style: TextStyle(
                color: available ? ProTheme.green : ProTheme.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    });
  }
}
