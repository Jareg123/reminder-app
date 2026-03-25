// ══════════════════════════════════════════════════════════════
//  КАРТОЧКА СОБЫТИЯ
//  Одна строка в списке задач. Поддерживает:
//    • свайп влево → удаление (с подтверждением ModernDialog)
//    • свайп вправо → отложить (SnoozeSheet)
//    • тап → открыть форму редактирования
//    • долгий тап → войти в режим мультивыбора
//    • в режиме мультивыбора — анимированный чекбокс выбора
//
//  Зависит от: ModernDialog, AppColorScheme, LabelColors, Event
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database.dart';
import '../theme/app_theme.dart';
import 'modern_dialog.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onSnooze;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool isSelecting;

  const EventCard({
    super.key,
    required this.event,
    required this.now,
    required this.onToggle,
    required this.onDelete,
    required this.onSnooze,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    required this.isSelecting,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);
    final isDone = event.isDone == 1;
    DateTime? remindDt;
    bool overdue = false;

    if (event.reminderAt != null) {
      try {
        remindDt = DateFormat('yyyy-MM-dd HH:mm').parse(event.reminderAt!);
        overdue = !isDone && remindDt.isBefore(now);
      } catch (_) {}
    }

    Color bgColor;
    Color borderColor;
    if (overdue) {
      bgColor = c.overdueLight;
      borderColor = c.overdue.withValues(alpha: 0.25);
    } else if (isDone) {
      bgColor = c.doneLight;
      borderColor = c.done.withValues(alpha: 0.2);
    } else {
      bgColor = c.card;
      borderColor = c.border.withValues(alpha: 0.5);
    }

    final hasLabel = event.labelColor != null;
    final labelColor = hasLabel ? LabelColors.toColor(event.labelColor!) : null;

    const radius = BorderRadius.all(Radius.circular(16));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: radius,
        child: Dismissible(
          key: Key('event_${event.id}'),
          direction: isSelecting
              ? DismissDirection.none
              : DismissDirection.horizontal,
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.endToStart) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => ModernDialog(
                  title: 'Удалить событие?',
                  content: event.content,
                  confirmText: 'Удалить',
                  confirmColor: c.danger,
                ),
              ) ??
                  false;
              if (confirmed) {
                onDelete();
              }
              return false;
            } else {
              onSnooze();
              return false;
            }
          },
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: c.danger,
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            color: c.snooze,
            child: const Icon(Icons.snooze_rounded, color: Colors.white, size: 24),
          ),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              color: isSelected
                  ? AppColorScheme.of(context).primary.withValues(alpha: 0.08)
                  : bgColor,
              child: Row(
                children: [
                  // ── Цветная полоска метки ────────────────
                  if (hasLabel)
                    Container(
                      width: 4,
                      height: 60,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: labelColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        hasLabel ? 10 : 16, 14, 12, 14,
                      ),
                      child: Row(
                        children: [
                          // Чекбокс
                          GestureDetector(
                            onTap: onToggle,
                            child: isSelecting
                                ? AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColorScheme.of(context).primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColorScheme.of(context).primary
                                            : AppColorScheme.of(context).border,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded,
                                            size: 16, color: Colors.white)
                                        : null,
                                  )
                                : AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDone ? c.done : Colors.transparent,
                                      border: Border.all(
                                        color: isDone ? c.done : c.border,
                                        width: 2,
                                      ),
                                    ),
                                    child: isDone
                                        ? const Icon(Icons.check_rounded,
                                            size: 16, color: Colors.white)
                                        : null,
                                  ),
                          ),
                          const SizedBox(width: 12),

                          // Контент
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.content,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDone ? c.textSecondary : c.textPrimary,
                                    decoration:
                                    isDone ? TextDecoration.lineThrough : null,
                                    decorationColor: c.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildSubtitle(c, overdue),
                              ],
                            ),
                          ),

                          // Иконка повторения
                          if (event.recurrence != null) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.repeat_rounded,
                                color: c.primary.withValues(alpha: 0.5), size: 16),
                          ],

                          Icon(Icons.chevron_right_rounded,
                              color: c.border, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(AppColorScheme c, bool overdue) {
    if (overdue) {
      return Row(
        children: [
          Icon(Icons.schedule, color: c.overdue, size: 13),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Просрочено · ${event.reminderAt}',
              style: TextStyle(color: c.overdue, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    if (event.reminderAt != null) {
      return Row(
        children: [
          Icon(Icons.notifications_none_rounded,
              color: c.primary.withValues(alpha: 0.6), size: 13),
          const SizedBox(width: 4),
          Text(
            event.reminderAt!,
            style: TextStyle(
                color: c.primary.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      );
    }
    return Text(
      event.createdAt,
      style: TextStyle(color: c.textSecondary, fontSize: 12),
    );
  }
}
