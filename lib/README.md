# Напоминалка

Минималистичное Android-приложение для управления напоминаниями. Изумрудный дизайн, тёмная тема, локальные уведомления.

## Возможности

- Создание событий с напоминаниями
- Быстрые интервалы (1ч / 4ч / 8ч / завтра) и произвольный ввод (дни, часы, минуты)
- Точное время через DatePicker + TimePicker
- Цветные метки для категоризации
- Повторяющиеся напоминания (час / день / неделя)
- Свайп вправо → отложить, свайп влево → удалить
- Поиск по событиям
- Тёмная и светлая тема с переключателем
- Тактильная обратная связь (haptic feedback)
- Зелёные акцентные уведомления

## Стек

- Flutter 3.x + Dart
- sqflite — локальная база данных
- flutter_local_notifications — уведомления
- timezone — планирование по часовым поясам

## Сборка

```bash
flutter pub get
flutter run            # debug
flutter build apk      # release APK
flutter build appbundle # для Google Play
```

## Иконка

```bash
# 1. Положи icon.png (1024x1024) в assets/
# 2. Добавь в pubspec.yaml:
#    flutter_launcher_icons:
#      android: true
#      image_path: "assets/icon.png"
# 3. Запусти:
dart run flutter_launcher_icons
```

## Лицензия

MIT License — см. [LICENSE](LICENSE)
