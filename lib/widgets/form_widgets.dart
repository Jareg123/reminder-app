// ══════════════════════════════════════════════════════════════
//  ВИДЖЕТЫ ФОРМЫ СОБЫТИЯ
//  Используются только внутри EventFormPage (pages/event_form_page.dart).
//
//  Содержит:
//    • CompactBtn    — кнопка "Дата и время" / "Интервал" в форме
//    • QuickButton   — быстрые интервалы (1ч / 4ч / 8ч / Завтра)
//    • IntervalField — поле ввода числа (дни / часы / минуты)
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// ── Компактная кнопка (дата / интервал) ──────────────────────
class CompactBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppColorScheme c;

  const CompactBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? c.primary.withValues(alpha: 0.1)
              : c.primarySurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active
                ? c.primary.withValues(alpha: 0.35)
                : c.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: c.primary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Кнопка быстрого интервала ─────────────────────────────────
class QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const QuickButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: c.primarySurface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.primary.withValues(alpha: 0.15)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                )),
          ),
        ),
      ),
    );
  }
}

// ── Поле ввода числа (дни / часы / минуты) ───────────────────
class IntervalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const IntervalField({super.key, required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              )),
          const SizedBox(height: 3),
          Container(
            decoration: BoxDecoration(
              color: c.primarySurface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: c.primary.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.primary,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              onTap: () => controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
