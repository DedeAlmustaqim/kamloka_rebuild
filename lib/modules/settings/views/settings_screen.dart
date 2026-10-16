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
        title: const Text('Pengaturan',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: ProTheme.brandGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 29),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KAMLOKA',
                          style: TextStyle(
                            color: ProTheme.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          )),
                      SizedBox(height: 4),
                      Text('Kamera Lokasi',
                          style: TextStyle(color: _muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('PREFERENSI'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
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
            const SizedBox(height: 28),
            const _SectionLabel('MODE DEVELOPER'),
            const SizedBox(height: 10),
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
                    access.isPro.value ? 'Mode PRO aktif' : 'Mode Gratis aktif',
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
          const SizedBox(height: 28),
          const _SectionLabel('TINGKATKAN PENGALAMAN'),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Get.to(
                () => const KamlokaProScreen(),
                transition: Transition.cupertino,
              ),
              child: Ink(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE69A), Color(0xFFFFF2C8)],
                  ),
                  border: Border.all(color: ProTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        color: ProTheme.primaryDark, size: 34),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KAMLOKA Pro',
                              style: TextStyle(
                                color: ProTheme.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              )),
                          SizedBox(height: 5),
                          Text(
                            'Dokumentasi perjalanan dan fitur premium dalam satu paket',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: ProTheme.secondaryText),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('LAINNYA'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.info_outline_rounded,
                  color: ProTheme.secondaryText),
              title: const Text('Tentang KAMLOKA',
                  style: TextStyle(
                      color: ProTheme.text, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Informasi aplikasi dan pengembang',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: ProTheme.secondaryText),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'KAMLOKA',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Kamera Lokasi',
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text('KAMLOKA • Kamera Lokasi',
                style: TextStyle(color: ProTheme.secondaryText, fontSize: 11)),
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
        color: SettingsScreen._muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
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
      title: Text(title,
          style: const TextStyle(color: ProTheme.text, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: SettingsScreen._muted, fontSize: 12)),
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
      final isActionResult = message.contains('Pembelian KAMLOKA Pro diterima') ||
          message.contains('berhasil dipulihkan') ||
          message.startsWith('Pembelian gagal:') ||
          message == 'Pembelian dibatalkan.' ||
          message.startsWith('Produk belum dapat dimuat:') ||
          message.startsWith('Produk Pro belum ditemukan.') ||
          message.startsWith('Gagal menghubungkan Google Play:');
      if (!isActionResult || !mounted) return;

      final isError = message.startsWith('Pembelian gagal:') ||
          message.startsWith('Produk belum dapat dimuat:') ||
          message.startsWith('Produk Pro belum ditemukan.') ||
          message.startsWith('Gagal menghubungkan Google Play:');
      final isSuccess = message.contains('diterima') ||
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE69A), Color(0xFFFFF6D9)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEAD28B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.photo_camera_back_outlined,
                        size: 29,
                        color: ProTheme.text,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Dokumentasi lapangan, lebih teratur.',
                      style: TextStyle(
                        color: ProTheme.text,
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Kelompokkan perjalanan, lokasi, dan foto menjadi laporan yang siap dibagikan.',
                      style: TextStyle(
                        color: ProTheme.text,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Obx(() {
                final pro = Get.find<ProAccessService>();
                final billing = Get.find<ProPurchaseService>();
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ProTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ProTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: pro.isPro.value
                              ? const Color(0xFFE3F4E8)
                              : const Color(0xFFF0F1EC),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          pro.isPro.value
                              ? Icons.verified_rounded
                              : Icons.info_outline_rounded,
                          color: pro.isPro.value ? ProTheme.green : ProTheme.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pro.isPro.value ? 'KAMLOKA Pro aktif' : 'Status akses',
                              style: const TextStyle(
                                color: ProTheme.text,
                                fontWeight: FontWeight.w800,
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
              const SizedBox(height: 14),
              Obx(() {
                final billing = Get.find<ProPurchaseService>();
                final product = billing.product.value;
                final canBuy = product != null &&
                    billing.storeAvailable.value &&
                    !billing.purchasePending.value;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ProTheme.surface,
                    borderRadius: BorderRadius.circular(22),
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
                              color: const Color(0xFFFFF2C8),
                              borderRadius: BorderRadius.circular(14),
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
                                    fontWeight: FontWeight.w800,
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
                      const SizedBox(height: 16),
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
                            : const Icon(Icons.lock_open_rounded),
                        label: Text(
                          product == null
                              ? 'Pembelian segera tersedia'
                              : 'Beli KAMLOKA Pro • ${product.price}',
                        ),
                      ),
                      const SizedBox(height: 4),
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
                          borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 26),
              const Text(
                'Fitur KAMLOKA Pro',
                style: TextStyle(
                  color: ProTheme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Buka akses dokumentasi perjalanan dan fitur premium dengan sekali pembayaran. Harga ditampilkan langsung dari Google Play.',
                style: TextStyle(color: ProTheme.secondaryText, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              _ProFeatureRow(
                title: 'Template watermark premium',
                feature: KamlokaFeature.premiumWatermarkTemplates,
              ),
              const SizedBox(height: 10),
              _ProFeatureRow(
                title: 'Kustomisasi watermark lanjutan',
                feature: KamlokaFeature.advancedWatermarkCustomization,
              ),
              const SizedBox(height: 26),
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
  const _ProFeatureRow({
    required this.title,
    required this.feature,
  });

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
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: ProTheme.border),
        ),
        child: Row(
          children: [
            Icon(
              available ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
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
