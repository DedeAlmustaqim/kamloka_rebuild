import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../pro/services/pro_access_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color _background = Color(0xFF101820);
  static const Color _surface = Color(0xFF1B2933);
  static const Color _muted = Color(0xFFACB8C1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: _background, size: 29),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KAMLOKA',
                          style: TextStyle(
                            color: Colors.white,
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
                Divider(height: 1, indent: 58, color: Color(0xFF34434D)),
                _InfoTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Penyimpanan',
                  subtitle: 'Foto disimpan ke album KAMLOKA',
                ),
              ],
            ),
          ),
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
                    colors: [Color(0xFF354654), Color(0xFF202F3A)],
                  ),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFFFFD479), size: 34),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KAMLOKA Pro',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              )),
                          SizedBox(height: 5),
                          Text(
                            'Kenali fitur premium yang sedang disiapkan',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white70),
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
                  color: Colors.white70),
              title: const Text('Tentang KAMLOKA',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Informasi aplikasi dan pengembang',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white54),
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
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
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
      leading: Icon(icon, color: Colors.white70),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: SettingsScreen._muted, fontSize: 12)),
    );
  }
}

class KamlokaProScreen extends StatelessWidget {
  const KamlokaProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsScreen._background,
      appBar: AppBar(
        backgroundColor: SettingsScreen._background,
        foregroundColor: Colors.white,
        title: const Text('KAMLOKA Pro'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.workspace_premium_rounded,
                  size: 76, color: Color(0xFFFFD479)),
              const SizedBox(height: 24),
              const Text(
                'Lebih banyak kemungkinan dengan KAMLOKA Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Obx(() {
                final pro = Get.find<ProAccessService>();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263640),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pro.isPro.value
                            ? Icons.verified_rounded
                            : Icons.lock_outline_rounded,
                        color: pro.isPro.value
                            ? const Color(0xFF8BE0B0)
                            : const Color(0xFFFFD479),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pro.isPro.value
                                  ? 'KAMLOKA Pro aktif'
                                  : 'Versi Gratis aktif',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              pro.isPro.value
                                  ? 'Akses premium tersedia.'
                                  : 'Pembelian dan aktivasi Pro belum tersedia.',
                              style: const TextStyle(
                                color: SettingsScreen._muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              const Text(
                'Fitur berikut disiapkan untuk tahap pengembangan selanjutnya. Belum ada fitur premium yang dijual atau dikunci pada versi ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SettingsScreen._muted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              _ProFeatureRow(
                title: 'Template watermark premium',
                feature: KamlokaFeature.premiumWatermarkTemplates,
              ),
              const SizedBox(height: 10),
              _ProFeatureRow(
                title: 'Kustomisasi watermark lanjutan',
                feature: KamlokaFeature.advancedWatermarkCustomization,
              ),
              const Spacer(),
              FilledButton(
                onPressed: Get.back,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: SettingsScreen._background,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Mengerti'),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: SettingsScreen._surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              available ? Icons.check_circle_outline : Icons.lock_outline,
              color: available ? const Color(0xFF8BE0B0) : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              available ? 'Aktif' : 'Segera hadir',
              style: TextStyle(
                color: available ? const Color(0xFF8BE0B0) : SettingsScreen._muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    });
  }
}
