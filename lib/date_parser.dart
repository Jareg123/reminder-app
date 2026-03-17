/// Парсер русских дат из текста.
/// Принимает строку вроде "завтра в 10 к стоматологу"
/// и возвращает ParsedInput с DateTime? и очищенным текстом.

class ParsedInput {
  final String text;       // "к стоматологу"
  final DateTime? dateTime; // завтра 10:00

  ParsedInput({required this.text, this.dateTime});
}

class RussianDateParser {
  static ParsedInput parse(String input) {
    final now = DateTime.now();
    String text = input.trim();
    DateTime? result;

    // ── Нормализация ──
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // ── "через X минут/часов/дней" ──
    final throughPattern = RegExp(
      r'через\s+(\d+|пол(?:часа)?)\s*(минут[аы]?|мин|часо[ва]?|час|дн[яей]|день)',
      caseSensitive: false,
    );
    final throughMatch = throughPattern.firstMatch(text);
    if (throughMatch != null) {
      final rawAmount = throughMatch.group(1)!.toLowerCase();
      final unit = throughMatch.group(2)!.toLowerCase();
      int amount;
      if (rawAmount.startsWith('пол')) {
        amount = 30;
        result = now.add(const Duration(minutes: 30));
        text = text.replaceFirst(throughMatch.group(0)!, '').trim();
        return ParsedInput(text: _cleanText(text), dateTime: result);
      } else {
        amount = int.tryParse(rawAmount) ?? 1;
      }

      if (unit.startsWith('мин')) {
        result = now.add(Duration(minutes: amount));
      } else if (unit.startsWith('час')) {
        result = now.add(Duration(hours: amount));
      } else if (unit.startsWith('дн') || unit == 'день') {
        result = now.add(Duration(days: amount));
      }
      text = text.replaceFirst(throughMatch.group(0)!, '').trim();
      return ParsedInput(text: _cleanText(text), dateTime: result);
    }

    // ── "через полчаса" (без числа) ──
    final halfHourPattern = RegExp(r'через\s+полчаса', caseSensitive: false);
    final halfHourMatch = halfHourPattern.firstMatch(text);
    if (halfHourMatch != null) {
      result = now.add(const Duration(minutes: 30));
      text = text.replaceFirst(halfHourMatch.group(0)!, '').trim();
      return ParsedInput(text: _cleanText(text), dateTime: result);
    }

    // ── День: "сегодня", "завтра", "послезавтра" ──
    DateTime? dayBase;
    String remaining = text;

    final todayPattern = RegExp(r'сегодня', caseSensitive: false);
    final tomorrowPattern = RegExp(r'завтра', caseSensitive: false);
    final dayAfterPattern = RegExp(r'послезавтра', caseSensitive: false);

    if (dayAfterPattern.hasMatch(remaining)) {
      dayBase = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
      remaining = remaining.replaceFirst(dayAfterPattern, '').trim();
    } else if (tomorrowPattern.hasMatch(remaining)) {
      dayBase = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      remaining = remaining.replaceFirst(tomorrowPattern, '').trim();
    } else if (todayPattern.hasMatch(remaining)) {
      dayBase = DateTime(now.year, now.month, now.day);
      remaining = remaining.replaceFirst(todayPattern, '').trim();
    }

    // ── День недели ──
    if (dayBase == null) {
      final weekdays = {
        'понедельник': DateTime.monday,
        'вторник': DateTime.tuesday,
        'среду': DateTime.wednesday,
        'среда': DateTime.wednesday,
        'четверг': DateTime.thursday,
        'пятницу': DateTime.friday,
        'пятница': DateTime.friday,
        'субботу': DateTime.saturday,
        'суббота': DateTime.saturday,
        'воскресенье': DateTime.sunday,
      };
      for (final entry in weekdays.entries) {
        final pattern = RegExp(
          r'(?:в\s+)?(?:следующ(?:ий|ую|ее)\s+)?' + entry.key,
          caseSensitive: false,
        );
        final match = pattern.firstMatch(remaining);
        if (match != null) {
          var daysAhead = entry.value - now.weekday;
          if (daysAhead <= 0) daysAhead += 7;
          if (match.group(0)!.contains(RegExp(r'следующ', caseSensitive: false))) {
            if (daysAhead < 7) daysAhead += 7;
          }
          dayBase = DateTime(now.year, now.month, now.day).add(Duration(days: daysAhead));
          remaining = remaining.replaceFirst(match.group(0)!, '').trim();
          break;
        }
      }
    }

    // ── Конкретная дата: "25 марта", "3 апреля" ──
    if (dayBase == null) {
      final months = {
        'январ': 1, 'феврал': 2, 'март': 3, 'мар': 3,
        'апрел': 4, 'ма[яй]': 5, 'июн': 6,
        'июл': 7, 'август': 8, 'авг': 8, 'сентябр': 9, 'сен': 9,
        'октябр': 10, 'окт': 10, 'ноябр': 11, 'нояб': 11,
        'декабр': 12, 'дек': 12,
      };
      for (final entry in months.entries) {
        final pattern = RegExp(
          r'(\d{1,2})\s+' + entry.key + r'\w*',
          caseSensitive: false,
        );
        final match = pattern.firstMatch(remaining);
        if (match != null) {
          final day = int.tryParse(match.group(1)!) ?? 1;
          var year = now.year;
          final candidate = DateTime(year, entry.value, day);
          if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
            year++;
          }
          dayBase = DateTime(year, entry.value, day);
          remaining = remaining.replaceFirst(match.group(0)!, '').trim();
          break;
        }
      }
    }

    // ── Время: "в 10", "в 10:30", "10 утра", "15 часов" ──
    // ЗАЩИТА: голые цифры ("1 2 3 4 5") больше не считаются временем
    int? hour;
    int minute = 0;

    final timePattern = RegExp(
      r'в?\s*(\d{1,2})(?::(\d{2}))?\s*(?:часо[ва]?)?\s*(утра|дня|вечера|ночи)?',
      caseSensitive: false,
    );
    final timeMatch = timePattern.firstMatch(remaining);

    if (timeMatch != null) {
      final fullMatch = timeMatch.group(0)!;
      final hasPreposition = fullMatch.toLowerCase().contains('в');
      final hasPeriod = timeMatch.group(3) != null;
      final hasHourWord = fullMatch.toLowerCase().contains('час');
      final hasColon = fullMatch.contains(':');

      final isValidTime = hasPreposition || hasPeriod || hasHourWord || hasColon;

      if (isValidTime) {
        hour = int.tryParse(timeMatch.group(1)!) ?? 0;
        minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        final period = timeMatch.group(3)?.toLowerCase();

        if (period != null) {
          if (period == 'утра' && hour == 12) hour = 0;
          if ((period == 'дня' || period == 'вечера') && hour! < 12) hour = hour! + 12;
          if (period == 'ночи' && hour! < 12 && hour != 0) hour = hour! + 0;
        } else if (hour! < 8 && dayBase != null) {
          hour = hour! + 12;
        }

        remaining = remaining.replaceFirst(fullMatch, '').trim();
      }
      // иначе — просто цифры в тексте, оставляем как есть
    }

    // ── Словесное время: "утром", "днём" и т.д. ──
    if (hour == null) {
      final wordTimes = {
        r'утром': 9,
        r'днём|днем': 13,
        r'в\s*обед': 13,
        r'вечером': 19,
        r'ночью': 23,
        r'в\s*полдень': 12,
        r'в\s*полночь': 0,
      };
      for (final entry in wordTimes.entries) {
        final pattern = RegExp(entry.key, caseSensitive: false);
        final match = pattern.firstMatch(remaining);
        if (match != null) {
          hour = entry.value;
          remaining = remaining.replaceFirst(match.group(0)!, '').trim();
          break;
        }
      }
    }

    // ── Собираем результат ──
    if (dayBase != null || hour != null) {
      final base = dayBase ?? DateTime(now.year, now.month, now.day);
      final h = hour ?? 9;
      result = DateTime(base.year, base.month, base.day, h, minute);

      if (dayBase == null && result.isBefore(now)) {
        result = result.add(const Duration(days: 1));
      }
    }

    return ParsedInput(text: _cleanText(remaining), dateTime: result);
  }

  /// Убираем мусор + первая буква заглавная (только если начинается с буквы)
  static String _cleanText(String text) {
    text = text
        .replaceAll(RegExp(r'^[,.\s]+'), '')
        .replaceAll(RegExp(r'[,.\s]+$'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Убрать висящие предлоги
    text = text.replaceAll(RegExp(r'^(в|на|к|до|по)\s+', caseSensitive: false), '');

    // Первая буква заглавная ТОЛЬКО если начинается с буквы
    if (text.isNotEmpty && RegExp(r'^[a-zа-яё]', caseSensitive: false).hasMatch(text)) {
      text = text[0].toUpperCase() + text.substring(1);
    }

    return text;
  }
}