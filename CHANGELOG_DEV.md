# Dev Changelog

## [2026-03-25] Геймификация v1

### Изменения:
- pubspec.yaml: добавлен пакет confetti ^0.7.0
- database.dart: версия БД 4→5, таблица daily_stats, методы recordTaskCompleted / getStreak / getWeeklyCompletedCount
- events_page.dart: стрик-бейдж в хедере, конфетти при 100%, еженедельная сводка

### Откат:
- Удалить confetti из pubspec.yaml, запустить flutter pub get
- В database.dart: вернуть version: 4, убрать daily_stats из onCreate/onUpgrade, удалить 3 новых метода
- В events_page.dart: удалить импорты confetti/dart:math, _streak/_confettiController/_wasAllDone, метод _loadStreak/_checkWeeklySummary/_streakWord, вернуть оригинальный _toggleDone/_markSelectedDone/_loadEvents/build

## [2026-03-25] Кнопки действий в уведомлении

### Изменения:
- database.dart: добавлены методы getById() и markDoneById()
- notification_service.dart: top-level onNotificationBackground(), static handleAction(), static onTaskUpdated callback, actions в AndroidNotificationDetails
- events_page.dart: подписка на NotificationService.onTaskUpdated в initState/dispose

### Откат:
- notification_service.dart: удалить onNotificationBackground, handleAction, onTaskUpdated, убрать actions из AndroidNotificationDetails, вернуть оригинальный initialize() без фонового обработчика
- database.dart: удалить getById() и markDoneById()
- events_page.dart: удалить строки с NotificationService.onTaskUpdated
