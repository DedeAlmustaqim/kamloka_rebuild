import 'package:flutter/material.dart';

import '../theme/pro_theme.dart';

enum ProMessageType { info, success, error, warning }

Future<void> showProMessageDialog({
  required BuildContext context,
  required String title,
  required String message,
  ProMessageType type = ProMessageType.info,
  String buttonText = 'Mengerti',
  bool barrierDismissible = true,
}) {
  final (IconData icon, Color color, Color background) = switch (type) {
    ProMessageType.success => (
        Icons.check_circle_rounded,
        ProTheme.green,
        const Color(0xFFE6F4EA),
      ),
    ProMessageType.error => (
        Icons.error_rounded,
        ProTheme.danger,
        const Color(0xFFFCE8E6),
      ),
    ProMessageType.warning => (
        Icons.warning_amber_rounded,
        const Color(0xFF8A6500),
        const Color(0xFFFFF3CD),
      ),
    ProMessageType.info => (
        Icons.info_rounded,
        ProTheme.brandGreen,
        const Color(0xFFE7F2EC),
      ),
  };

  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => Dialog(
      backgroundColor: ProTheme.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: ProTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 19),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ProTheme.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ProTheme.secondaryText,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> showProConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Lanjutkan',
  String cancelText = 'Batal',
  ProMessageType type = ProMessageType.warning,
}) async {
  final (IconData icon, Color color, Color background) = switch (type) {
    ProMessageType.success => (
        Icons.check_circle_rounded,
        ProTheme.green,
        const Color(0xFFE6F4EA),
      ),
    ProMessageType.error => (
        Icons.error_rounded,
        ProTheme.danger,
        const Color(0xFFFCE8E6),
      ),
    ProMessageType.warning => (
        Icons.warning_amber_rounded,
        const Color(0xFF8A6500),
        const Color(0xFFFFF3CD),
      ),
    ProMessageType.info => (
        Icons.info_rounded,
        ProTheme.brandGreen,
        const Color(0xFFE7F2EC),
      ),
  };

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: ProTheme.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: ProTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 31),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ProTheme.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ProTheme.secondaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(cancelText),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: type == ProMessageType.error ||
                              type == ProMessageType.warning
                          ? FilledButton.styleFrom(
                              backgroundColor: ProTheme.danger,
                            )
                          : null,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return result ?? false;
}
