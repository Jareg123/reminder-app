// ══════════════════════════════════════════════════════════════
//  ВИДЖЕТЫ ХЕДЕРА
//  Маленькие иконки-кнопки и переключатель темы в шапке экрана.
//
//  Содержит:
//    • HeaderIcon   — универсальная иконка-кнопка (поиск, видимость…)
//    • ThemeToggle  — кнопка переключения light/dark темы
//                     (сохраняет выбор в SharedPreferences)
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// ── Иконка-кнопка ─────────────────────────────────────────────
class HeaderIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const HeaderIcon({
    super.key,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active
              ? c.primary.withValues(alpha: 0.12)
              : c.chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? c.primary : c.textSecondary,
        ),
      ),
    );
  }
}

// ── Переключатель темы ────────────────────────────────────────
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppColorScheme.of(context);

    return GestureDetector(
      onTap: () {
        final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
        themeNotifier.value = newMode;
        SharedPreferences.getInstance().then((p) {
          p.setString('theme_mode', newMode == ThemeMode.dark ? 'dark' : 'light');
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c.chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween(begin: 0.75, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            size: 18,
            color: isDark ? const Color(0xFFFFD60A) : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
