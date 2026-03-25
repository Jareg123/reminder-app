// ══════════════════════════════════════════════════════════════
//  ПУСТОЕ СОСТОЯНИЕ
//  Показывается когда список задач пуст.
//  Три режима:
//    • isSearch=true     → "Ничего не найдено"
//    • allDone=true      → "Всё выполнено!"
//    • по умолчанию      → "Пока нет событий"
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final bool allDone;
  final bool isSearch;
  const EmptyState({super.key, this.allDone = false, this.isSearch = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    IconData icon;
    String title;
    String subtitle;

    if (isSearch) {
      icon = Icons.search_off_rounded;
      title = 'Ничего не найдено';
      subtitle = 'Попробуйте изменить запрос';
    } else if (allDone) {
      icon = Icons.celebration_rounded;
      title = 'Всё выполнено!';
      subtitle = 'Отличная работа, все дела сделаны';
    } else {
      icon = Icons.notifications_none_rounded;
      title = 'Пока нет событий';
      subtitle = 'Нажмите + чтобы создать первое';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: c.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: c.primary),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: c.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(fontSize: 14, color: c.textSecondary)),
        ],
      ),
    );
  }
}
