// ══════════════════════════════════════════════════════════════
//  BOTTOM SHEET — ОТЛОЖИТЬ ЗАДАЧУ
//  Показывается при свайпе карточки вправо.
//  Возвращает Duration — на сколько отложить.
//
//  Варианты: 30 мин / 1 час / 4 часа / до завтра
//
//  Вызов:
//    final choice = await showModalBottomSheet<Duration>(
//      context: context,
//      builder: (ctx) => SnoozeSheet(),
//    );
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SnoozeSheet extends StatelessWidget {
  const SnoozeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    Widget option(String label, IconData icon, Duration dur) {
      return ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.snooze.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c.snooze, size: 20),
        ),
        title: Text(label, style: TextStyle(
            color: c.textPrimary, fontWeight: FontWeight.w500)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => Navigator.pop(context, dur),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Отложить',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                )),
            const SizedBox(height: 8),
            option('На 30 минут', Icons.snooze_rounded, const Duration(minutes: 30)),
            option('На 1 час', Icons.schedule_rounded, const Duration(hours: 1)),
            option('На 4 часа', Icons.access_time_rounded, const Duration(hours: 4)),
            option('До завтра', Icons.wb_sunny_rounded, const Duration(days: 1)),
          ],
        ),
      ),
    );
  }
}
