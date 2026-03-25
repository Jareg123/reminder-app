// ══════════════════════════════════════════════════════════════
//  ТОЧКА ВХОДА + КОРНЕВОЙ ВИДЖЕТ
//
//  main()  — инициализация уведомлений, загрузка темы,
//            перепланирование всех уведомлений после перезапуска
//
//  MyApp   — MaterialApp с поддержкой light/dark темы.
//            Тема хранится в themeNotifier (theme/app_theme.dart),
//            слушается здесь через ValueListenableBuilder.
//
//  Структура приложения:
//    main.dart               ← ты здесь
//    theme/app_theme.dart    ← цвета, метки, повторения
//    pages/events_page.dart  ← главный экран (список задач)
//    pages/event_form_page.dart ← форма создания/редактирования
//    widgets/                ← все переиспользуемые виджеты
//    database.dart           ← SQLite: Event, DB
//    notification_service.dart ← планирование уведомлений
//    date_parser.dart        ← разбор дат из русского текста
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'notification_service.dart';
import 'theme/app_theme.dart';
import 'pages/events_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  // Загружаем сохранённую тему
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('theme_mode') ?? 'light';
  themeNotifier.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;

  // Перепланируем все уведомления при старте.
  // Android сбрасывает AlarmManager после перезагрузки устройства
  // или убийства процесса battery optimizer'ом.
  try {
    final events = await DB.getAll();
    await NotificationService.rescheduleAll(events);
  } catch (_) {}

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        final isDark = mode == ThemeMode.dark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ));

        return MaterialApp(
          title: 'Reminder & Notify',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: mode,
          theme: _buildTheme(AppColorScheme.light, Brightness.light),
          darkTheme: _buildTheme(AppColorScheme.dark, Brightness.dark),
          home: const EventsPage(),
        );
      },
    );
  }

  ThemeData _buildTheme(AppColorScheme c, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      dialogBackgroundColor: c.card,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        primary: c.primary,
        surface: c.bg,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? Colors.white
            : Colors.grey.shade500),
        trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? c.primary
            : c.border),
      ),
    );
  }
}
