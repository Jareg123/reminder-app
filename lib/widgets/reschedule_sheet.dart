// ══════════════════════════════════════════════════════════════
//  BOTTOM SHEET — ПЕРЕНОС ГРУППЫ ЗАДАЧ (мультивыбор)
//  Открывается из панели мультивыбора (MultiSelectBar).
//  Возвращает Duration — на сколько сдвинуть время задач.
//
//  Варианты: +1ч / +4ч / +1 сутки / +1 неделя / своё время
//
//  Содержит вспомогательный виджет RescheduleField —
//  поле ввода числа (дни/часы/минуты).
//
//  Вызов:
//    final result = await showModalBottomSheet<Duration?>(
//      context: context,
//      builder: (ctx) => RescheduleSheet(),
//    );
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class RescheduleSheet extends StatefulWidget {
  const RescheduleSheet({super.key});

  @override
  State<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<RescheduleSheet> {
  final _daysCtrl    = TextEditingController(text: '0');
  final _hoursCtrl   = TextEditingController(text: '0');
  final _minutesCtrl = TextEditingController(text: '0');
  bool _showCustom = false;

  @override
  void dispose() {
    _daysCtrl.dispose();
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _apply(Duration dur) => Navigator.pop(context, dur);

  void _applyCustom() {
    final d = int.tryParse(_daysCtrl.text) ?? 0;
    final h = int.tryParse(_hoursCtrl.text) ?? 0;
    final m = int.tryParse(_minutesCtrl.text) ?? 0;
    if (d == 0 && h == 0 && m == 0) return;
    _apply(Duration(days: d, hours: h, minutes: m));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    Widget quickBtn(String label, IconData icon, Duration dur) {
      return ListTile(
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.snooze.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: c.snooze, size: 18),
        ),
        title: Text(label,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w500)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _apply(dur),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            Text('Перенести задачи',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
            const SizedBox(height: 4),
            Text('Время сдвинется от исходного',
                style: TextStyle(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 8),
            quickBtn('+1 час',     Icons.hourglass_top_rounded,    const Duration(hours: 1)),
            quickBtn('+4 часа',    Icons.hourglass_bottom_rounded,  const Duration(hours: 4)),
            quickBtn('+1 сутки',   Icons.today_rounded,             const Duration(days: 1)),
            quickBtn('+1 неделя',  Icons.date_range_rounded,        const Duration(days: 7)),
            // Произвольное время
            ListTile(
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _showCustom
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.tune_rounded,
                  color: c.primary, size: 18),
              ),
              title: Text('Выбрать время...',
                  style: TextStyle(
                      color: c.primary, fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () => setState(() => _showCustom = !_showCustom),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        RescheduleField(ctrl: _daysCtrl,    label: 'Дни'),
                        const SizedBox(width: 8),
                        RescheduleField(ctrl: _hoursCtrl,   label: 'Часы'),
                        const SizedBox(width: 8),
                        RescheduleField(ctrl: _minutesCtrl, label: 'Мин'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _applyCustom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: const Text('Применить',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _showCustom
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Поле ввода числа (дни / часы / минуты) ───────────────────
// Используется внутри RescheduleSheet
class RescheduleField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const RescheduleField({super.key, required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: c.primarySurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.primary.withValues(alpha: 0.2)),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.primary),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              onTap: () => ctrl.selection = TextSelection(
                  baseOffset: 0, extentOffset: ctrl.text.length),
            ),
          ),
        ],
      ),
    );
  }
}
