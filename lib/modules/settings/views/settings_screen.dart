import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
                  icon: Icons.watermark_outlined,
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
              const Text(
                'Fitur premium sedang direncanakan. Detail fitur, harga, dan skema pembayaran akan ditentukan sebelum diluncurkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SettingsScreen._muted,
                  fontSize: 14,
                  height: 1.6,
                ),
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
