import 'package:flutter/material.dart';

import '../theme/pro_theme.dart';

enum ProMessageType { info, success, error, warning }

Future<void> showProMessageDialog({
  required BuildContext context,
  required String title,
  required String message,
  ProMessageType type = ProMessageType.info,
  String buttonText = 'Mengerti',
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
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: ProTheme.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ProTheme.text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.2,
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
            const SizedBox(height: 22),
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
  );
}
