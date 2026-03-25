// ══════════════════════════════════════════════════════════════
//  ФОРМА СОЗДАНИЯ / РЕДАКТИРОВАНИЯ СОБЫТИЯ
//  Используется для добавления новой задачи и редактирования
//  существующей. Открывается из EventsPage через _openDialog().
//
//  Функции:
//    • текстовое поле (до 2 строк)
//    • голосовой ввод (speech_to_text, локаль ru_RU)
//      → RussianDateParser автоматически извлекает дату из речи
//    • выбор цветной метки (LabelColors)
//    • включение напоминания + выбор даты/времени
//      - быстрые интервалы: 1ч / 4ч / 8ч / завтра
//      - кастомный интервал: дни + часы + минуты
//      - календарь + CupertinoDatePicker для времени
//    • выбор повторения (RecurrenceOption)
//
//  Возвращает Navigator.pop(context, true) если задача сохранена
// ══════════════════════════════════════════════════════════════
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../database.dart';
import '../notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/form_widgets.dart';
import '../date_parser.dart';

class EventFormPage extends StatefulWidget {
  final Event? event;
  const EventFormPage({super.key, this.event});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  late TextEditingController _contentCtrl;
  bool _reminderEnabled = false;
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  DateTime? _selectedDateTime;
  bool _showCustomInterval = false;
  final _daysCtrl = TextEditingController(text: '0');
  final _hoursCtrl = TextEditingController(text: '0');
  final _minutesCtrl = TextEditingController(text: '30');

  String? _selectedLabelColor;
  String? _selectedRecurrence;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.event?.content ?? '');
    _selectedLabelColor = widget.event?.labelColor;
    _selectedRecurrence = widget.event?.recurrence;

    if (widget.event?.reminderAt != null) {
      try {
        _selectedDateTime =
            DateFormat('yyyy-MM-dd HH:mm').parse(widget.event!.reminderAt!);
        _reminderEnabled = true;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _daysCtrl.dispose();
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _applyCustomInterval() {
    final days = int.tryParse(_daysCtrl.text) ?? 0;
    final hours = int.tryParse(_hoursCtrl.text) ?? 0;
    final minutes = int.tryParse(_minutesCtrl.text) ?? 0;
    if (days == 0 && hours == 0 && minutes == 0) return;
    final delta = Duration(days: days, hours: hours, minutes: minutes);
    setState(() {
      _selectedDateTime = DateTime.now().add(delta);
      _showCustomInterval = false;
    });
  }

  Future<void> _pickDate() async {
    final c = AppColorScheme.of(context);
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Дата (календарь) ──────────────────────────────
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ru'),
      initialDate: _selectedDateTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(
              primary: c.primary,
              onPrimary: Colors.white,
              surface: c.card)
              : ColorScheme.light(
              primary: c.primary,
              onPrimary: Colors.white,
              surface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    if (!mounted) return;
    TimeOfDay? time;
    final initialTime = _selectedDateTime ?? now;
    await showDialog(
      context: context,
      builder: (ctx) {
        final dc = AppColorScheme.of(ctx);
        DateTime tempTime = DateTime(2000, 1, 1, initialTime.hour, initialTime.minute);
        return Dialog(
          backgroundColor: dc.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text('Выберите время',
                    style: TextStyle(
                      fontSize: 14,
                      color: dc.textSecondary,
                    )),
              ),
              SizedBox(
                height: 320,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(2000, 1, 1, initialTime.hour, initialTime.minute),
                  onDateTimeChanged: (dt) {
                    tempTime = dt;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Отмена',
                          style: TextStyle(color: dc.primary)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        time = TimeOfDay(
                          hour: tempTime.hour,
                          minute: tempTime.minute,
                        );
                        Navigator.pop(ctx);
                      },
                      child: Text('OK',
                          style: TextStyle(color: dc.primary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (time == null) return;

    final combined = DateTime(
        picked.year, picked.month, picked.day, time!.hour, time!.minute);
    if (combined.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Это время уже прошло — выберите другое'),
          backgroundColor: c.overdue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    setState(() => _selectedDateTime = combined);
  }

  Future<void> _setQuick(Duration delta) async {
    setState(() => _selectedDateTime = DateTime.now().add(delta));
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (e) => setState(() => _isListening = false),
    );
    if (!available) return;

    setState(() => _isListening = true);

    await _speech.listen(
      localeId: 'ru_RU',
      partialResults: true,
      listenFor: const Duration(seconds: 35),
      cancelOnError: true,
      onResult: (result) {
        setState(() {
          String displayText = result.recognizedWords;

          if (result.finalResult) {
            final parsed = RussianDateParser.parse(result.recognizedWords);

            displayText = parsed.text;

            if (parsed.dateTime != null) {
              _selectedDateTime = parsed.dateTime;
              _reminderEnabled = true;
            }
            _isListening = false;
          }

          _contentCtrl.text = displayText;
          _contentCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _contentCtrl.text.length),
          );
        });
      },
    );
  }

  Future<void> _save() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return;

    String? reminderAt;
    if (_reminderEnabled && _selectedDateTime != null) {
      reminderAt = DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime!);
    }

    int eventId;
    if (_isEdit) {
      await DB.updateEvent(
        widget.event!.id!,
        text,
        reminderAt: reminderAt,
        recurrence: _selectedRecurrence,
        labelColor: _selectedLabelColor,
      );
      eventId = widget.event!.id!;
      await NotificationService.safeCancel(eventId);
    } else {
      eventId = await DB.addEvent(
        text,
        reminderAt: reminderAt,
        recurrence: _selectedRecurrence,
        labelColor: _selectedLabelColor,
      );
    }

    await NotificationService.safeCancel(eventId);
    if (reminderAt != null && _selectedDateTime != null) {
      await NotificationService.safeSchedule(
        id: eventId,
        title: 'Напоминание',
        body: text,
        scheduledTime: _selectedDateTime!,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);
    final fmt = _selectedDateTime != null
        ? DateFormat('dd MMM  HH:mm').format(_selectedDateTime!)
        : null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        toolbarHeight: 52,
        title: Text(
          _isEdit ? 'Редактировать' : 'Новое событие',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              onPressed: _save,
              style: TextButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _isEdit ? 'Сохранить' : 'Добавить',
                style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Поле ввода + кнопка микрофона ─────────────
            IntrinsicHeight(
             child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border.withValues(alpha: 0.5)),
                    ),
                    child: TextField(
                      controller: _contentCtrl,
                      autofocus: true,
                      maxLines: 2,
                      style: TextStyle(fontSize: 15, color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Что нужно запомнить?',
                        hintStyle: TextStyle(
                            color: c.textSecondary.withValues(alpha: 0.5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? c.danger.withValues(alpha: 0.12)
                          : c.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isListening
                            ? c.danger.withValues(alpha: 0.4)
                            : c.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? c.danger : c.primary,
                      size: 22,
                    ),
                  ),
                ),
              ],
             ),
            ),
            const SizedBox(height: 10),

            // ── Метка (цветные кружки) ─────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.palette_rounded,
                      color: c.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text('Метка',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary,
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: LabelColors.all.map((hex) {
                        final isSelected = _selectedLabelColor == hex;
                        final isNone = hex == null;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedLabelColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: isSelected ? 26 : 22,
                            height: isSelected ? 26 : 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isNone
                                  ? c.chipBg
                                  : LabelColors.toColor(hex),
                              border: isSelected
                                  ? Border.all(
                                  color: c.textPrimary, width: 2)
                                  : Border.all(
                                  color:
                                  c.border.withValues(alpha: 0.4),
                                  width: 0.5),
                            ),
                            child: isNone
                                ? Icon(Icons.block_rounded,
                                size: 12, color: c.textSecondary)
                                : isSelected
                                ? const Icon(Icons.check_rounded,
                                size: 12, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Напоминание ────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок + переключатель
                  Row(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: c.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Напоминание',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            )),
                      ),
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: _reminderEnabled,
                          onChanged: (v) =>
                              setState(() => _reminderEnabled = v),
                        ),
                      ),
                    ],
                  ),

                  if (_reminderEnabled) ...[
                    const SizedBox(height: 12),
                    Divider(color: c.divider, height: 1),
                    const SizedBox(height: 12),

                    // ── Быстрые интервалы ─────────────────
                    Row(
                      children: [
                        QuickButton(
                            label: '1 ч',
                            onTap: () =>
                                _setQuick(const Duration(hours: 1))),
                        const SizedBox(width: 6),
                        QuickButton(
                            label: '4 ч',
                            onTap: () =>
                                _setQuick(const Duration(hours: 4))),
                        const SizedBox(width: 6),
                        QuickButton(
                            label: '8 ч',
                            onTap: () =>
                                _setQuick(const Duration(hours: 8))),
                        const SizedBox(width: 6),
                        QuickButton(
                            label: 'Завтра',
                            onTap: () =>
                                _setQuick(const Duration(days: 1))),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // ── Дата/время + Интервал в одну строку ──
                    Row(
                      children: [
                        Expanded(
                          child: CompactBtn(
                            icon: Icons.calendar_month_rounded,
                            label: fmt ?? 'Дата и время',
                            active: fmt != null,
                            onTap: _pickDate,
                            c: c,
                          ),
                        ),
                        const SizedBox(width: 6),
                        CompactBtn(
                          icon: _showCustomInterval
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.tune_rounded,
                          label: 'Интервал',
                          active: _showCustomInterval,
                          onTap: () => setState(() =>
                          _showCustomInterval = !_showCustomInterval),
                          c: c,
                        ),
                        if (_selectedDateTime != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(
                                    () => _selectedDateTime = null),
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color:
                                c.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: c.danger, size: 16),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // ── Своё время (раскрывается) ─────────
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IntervalField(
                                    controller: _daysCtrl,
                                    label: 'Дни'),
                                const SizedBox(width: 8),
                                IntervalField(
                                    controller: _hoursCtrl,
                                    label: 'Часы'),
                                const SizedBox(width: 8),
                                IntervalField(
                                    controller: _minutesCtrl,
                                    label: 'Мин'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _applyCustomInterval,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Установить',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _showCustomInterval
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 220),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
