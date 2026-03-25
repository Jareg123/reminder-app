# Reminder & Notify — CLAUDE.md

## Стек
- Flutter (Dart), таргет Android
- SQLite через sqflite
- flutter_local_notifications + flutter_timezone для уведомлений
- speech_to_text для голосового ввода (локаль ru_RU)
- home_widget для виджета на рабочем столе
- shared_preferences для настроек (тема, hide_done)

## Структура lib/
```
main.dart                  — точка входа + MyApp (~100 строк)
database.dart              — Event, DB (SQLite)
notification_service.dart  — планирование уведомлений
date_parser.dart           — парсинг дат из русского текста

theme/app_theme.dart       — цвета, AppColorScheme, LabelColors, RecurrenceOption
pages/events_page.dart     — главный экран (список задач)
pages/event_form_page.dart — форма создания/редактирования
widgets/event_card.dart    — карточка задачи
widgets/snooze_sheet.dart  — bottom sheet "Отложить"
widgets/reschedule_sheet.dart — bottom sheet "Перенести" + RescheduleField
widgets/modern_dialog.dart — диалог подтверждения
widgets/multi_select_bar.dart — панель мультивыбора
widgets/header_widgets.dart   — HeaderIcon, ThemeToggle
widgets/empty_state.dart      — заглушка пустого списка
widgets/form_widgets.dart     — CompactBtn, QuickButton, IntervalField
```
Полная документация структуры: `structure.txt`

## Цвета и тема
- Основной цвет: emerald (#10B981 light / #34D399 dark)
- Тема переключается через `themeNotifier` (ValueNotifier в app_theme.dart)
- Использовать `AppColorScheme.of(context)` для всех цветов — не хардкодить

## Конвенции
- Комментарии в коде на русском — окей
- Приватные виджеты внутри файла страницы — с `_` префиксом
- Виджеты в отдельных файлах — публичные (без `_`)
- Компактный UI, без лишних отступов

## Android
- Package: com.gladkov.reminder_app (проверь в AndroidManifest)
- Home widget: com.example.reminder_app.HomeWidgetProvider
- ProGuard: android/app/proguard-rules.pro
- Версия SDK: minSdk 21, targetSdk 34 (проверь build.gradle.kts)
- Battery optimization exemption запрашивается при старте (EventsPage.initState)

## Важное
- Уведомления сбрасываются Android при перезагрузке → rescheduleAll() в main()
- Повторяющиеся задачи перепланируются при отметке "выполнено" (_toggleDone)
- DB версия 4 — при добавлении колонок делать миграцию в onUpgrade
- Голосовой ввод → RussianDateParser автоматически извлекает дату из фразы
