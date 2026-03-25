// ══════════════════════════════════════════════════════════════
//  ПАНЕЛЬ МУЛЬТИВЫБОРА
//  Заменяет FAB когда выбрана хотя бы одна задача.
//  Показывает счётчик и кнопки: Готово / Перенести / Удалить.
//
//  Вызов — в EventsPage вместо FloatingActionButton:
//    floatingActionButton: _isSelecting
//        ? MultiSelectBar(count: ..., onCancel: ..., ...)
//        : FloatingActionButton(...)
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MultiSelectBar extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onDone;
  final VoidCallback onReschedule;

  const MultiSelectBar({
    super.key,
    required this.count,
    required this.onCancel,
    required this.onDelete,
    required this.onDone,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Верхняя строка: отмена + счётчик
          Row(
            children: [
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Выбрано: $count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Нижняя строка: действия
          Row(
            children: [
              // Готово
              Expanded(
                child: GestureDetector(
                  onTap: onDone,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: c.done.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 15, color: c.done),
                        const SizedBox(width: 5),
                        Text('Готово',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.done)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Перенести
              Expanded(
                child: GestureDetector(
                  onTap: onReschedule,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: c.snooze.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: c.snooze),
                        const SizedBox(width: 5),
                        Text('Перенести',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.snooze)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Удалить
              Expanded(
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: c.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 15, color: c.danger),
                        const SizedBox(width: 5),
                        Text('Удалить',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.danger)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
