// ══════════════════════════════════════════════════════════════
//  МОДАЛЬНЫЙ ДИАЛОГ
//  Универсальный диалог подтверждения действия.
//
//  Использование:
//    await showDialog<bool>(
//      context: context,
//      builder: (ctx) => ModernDialog(
//        title: 'Удалить?',
//        content: event.content,
//        confirmText: 'Удалить',
//        confirmColor: c.danger,
//      ),
//    );
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ModernDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final Color confirmColor;

  const ModernDialog({
    super.key,
    required this.title,
    required this.content,
    required this.confirmText,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
            const SizedBox(height: 12),
            Text('"$content"',
                style: TextStyle(color: c.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: c.border),
                      ),
                    ),
                    child: Text('Отмена',
                        style: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(confirmText,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
