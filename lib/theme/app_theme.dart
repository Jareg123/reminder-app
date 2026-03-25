// ══════════════════════════════════════════════════════════════
//  ТЕМА ПРИЛОЖЕНИЯ
//  Всё что связано с цветами, темой и константами UI.
//
//  Содержит:
//    • themeNotifier     — глобальный переключатель light/dark
//    • LabelColors       — набор цветных меток для задач
//    • RecurrenceOption  — варианты повторения (нет / час / день / неделя)
//    • AppColorScheme    — адаптивная палитра (light + dark), используется
//                          через AppColorScheme.of(context) везде в UI
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

// Глобальный переключатель темы — слушается в MyApp (main.dart)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// ── Цветные метки задач ───────────────────────────────────────
class LabelColors {
  static const List<String?> all = [
    null,       // без метки
    'FF6B6B',   // красный
    'FFB347',   // оранжевый
    'FFD93D',   // жёлтый
    '6BCB77',   // зелёный
    '4D96FF',   // синий
    'A66CFF',   // фиолетовый
  ];

  static Color toColor(String hex) => Color(int.parse('FF$hex', radix: 16));
}

// ── Варианты повторений ───────────────────────────────────────
class RecurrenceOption {
  final String? value; // минуты как строка или null
  final String label;
  final IconData icon;

  const RecurrenceOption(this.value, this.label, this.icon);

  static const List<RecurrenceOption> all = [
    RecurrenceOption(null, 'Нет', Icons.close_rounded),
    RecurrenceOption('60', 'Час', Icons.refresh_rounded),
    RecurrenceOption('1440', 'День', Icons.today_rounded),
    RecurrenceOption('10080', 'Неделя', Icons.date_range_rounded),
  ];
}

// ── Адаптивная палитра — Light / Dark ────────────────────────
// Использование: final c = AppColorScheme.of(context);
class AppColorScheme {
  final Color primary;
  final Color primarySurface;
  final Color bg;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color overdue;
  final Color overdueLight;
  final Color done;
  final Color doneLight;
  final Color danger;
  final Color border;
  final Color divider;
  final Color chipBg;
  final Color snooze;
  final Color snoozeLight;

  const AppColorScheme._({
    required this.primary,
    required this.primarySurface,
    required this.bg,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.overdue,
    required this.overdueLight,
    required this.done,
    required this.doneLight,
    required this.danger,
    required this.border,
    required this.divider,
    required this.chipBg,
    required this.snooze,
    required this.snoozeLight,
  });

  static const light = AppColorScheme._(
    primary: Color(0xFF10B981),
    primarySurface: Color(0xFFECFDF5),
    bg: Color(0xFFF6F7F9),
    card: Colors.white,
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF8E8E93),
    overdue: Color(0xFFFF6B35),
    overdueLight: Color(0xFFFFF3ED),
    done: Color(0xFF34C759),
    doneLight: Color(0xFFF0FFF4),
    danger: Color(0xFFFF3B30),
    border: Color(0xFFE5E5EA),
    divider: Color(0xFFF2F2F7),
    chipBg: Color(0xFFEFEFF4),
    snooze: Color(0xFFF59E0B),
    snoozeLight: Color(0xFFFFFBEB),
  );

  static const dark = AppColorScheme._(
    primary: Color(0xFF34D399),
    primarySurface: Color(0xFF132A21),
    bg: Color(0xFF111113),
    card: Color(0xFF1C1C1E),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF8E8E93),
    overdue: Color(0xFFFF8F5C),
    overdueLight: Color(0xFF2A1E14),
    done: Color(0xFF30D158),
    doneLight: Color(0xFF162A1A),
    danger: Color(0xFFFF453A),
    border: Color(0xFF2C2C2E),
    divider: Color(0xFF2C2C2E),
    chipBg: Color(0xFF2C2C2E),
    snooze: Color(0xFFFBBF24),
    snoozeLight: Color(0xFF2A2410),
  );

  static AppColorScheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
