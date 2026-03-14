import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'database.dart';
import 'notification_service.dart';

// ══════════════════════════════════════════════════════════════
//  Глобальный переключатель темы
// ══════════════════════════════════════════════════════════════
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// ══════════════════════════════════════════════════════════════
//  Адаптивная палитра — Light / Dark
// ══════════════════════════════════════════════════════════════
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
  });

  static const light = AppColorScheme._(
    primary: Color(0xFF10B981),        // изумрудный
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
  );

  static AppColorScheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

// ══════════════════════════════════════════════════════════════
//  Точка входа
// ══════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
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
          title: 'Напоминалка',
          debugShowCheckedModeBanner: false,
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

// ══════════════════════════════════════════════════════════════
//  Главный экран
// ══════════════════════════════════════════════════════════════
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<Event> _events = [];
  bool _hideDone = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await DB.getAll();
    setState(() => _events = events);
  }

  List<Event> get _visibleEvents {
    if (_hideDone) return _events.where((e) => e.isDone == 0).toList();
    return _events;
  }

  Future<void> _toggleDone(Event event) async {
    await DB.toggleDone(event.id!, event.isDone);
    await _loadEvents();
  }

  Future<void> _deleteEvent(Event event) async {
    final c = AppColorScheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ModernDialog(
        title: 'Удалить событие?',
        content: event.content,
        confirmText: 'Удалить',
        confirmColor: c.danger,
      ),
    );
    if (confirmed == true) {
      await NotificationService.cancelNotification(event.id!);
      await DB.deleteEvent(event.id!);
      await _loadEvents();
    }
  }

  Future<void> _openDialog({Event? event}) async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => EventFormPage(event: event),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    if (result == true) await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);
    final visible = _visibleEvents;
    final now = DateTime.now();
    final doneCount = _events.where((e) => e.isDone == 1).length;
    final totalCount = _events.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Хедер ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Напоминалка',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        totalCount == 0
                            ? 'Пока пусто'
                            : '$doneCount из $totalCount выполнено',
                        style: TextStyle(fontSize: 14, color: c.textSecondary),
                      ),
                      const Spacer(),
                      const _ThemeToggle(),
                      const SizedBox(width: 10),
                      _FilterChip(
                        label: 'Скрыть готовые',
                        selected: _hideDone,
                        onChanged: (v) => setState(() => _hideDone = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Прогресс-бар ───────────────────────────────
            if (totalCount > 0) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: doneCount / totalCount,
                    minHeight: 4,
                    backgroundColor: c.primary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ── Список ─────────────────────────────────────
            Expanded(
              child: visible.isEmpty
                  ? _EmptyState(
                      allDone: _hideDone && _events.any((e) => e.isDone == 1),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: visible.length,
                      itemBuilder: (ctx, i) {
                        final event = visible[i];
                        return _EventCard(
                          event: event,
                          now: now,
                          onToggle: () => _toggleDone(event),
                          onDelete: () => _deleteEvent(event),
                          onTap: () => _openDialog(event: event),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── FAB ────────────────────────────────────────────
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: c.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _openDialog(),
          backgroundColor: c.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Кнопка переключения темы
// ══════════════════════════════════════════════════════════════
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppColorScheme.of(context);

    return GestureDetector(
      onTap: () {
        themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.chipBg,
          borderRadius: BorderRadius.circular(12),
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
            size: 20,
            color: isDark ? const Color(0xFFFFD60A) : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Карточка события
// ══════════════════════════════════════════════════════════════
class _EventCard extends StatelessWidget {
  final Event event;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.now,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);
    final isDone = event.isDone == 1;
    DateTime? remindDt;
    bool overdue = false;

    if (event.reminderAt != null) {
      try {
        remindDt = DateFormat('yyyy-MM-dd HH:mm').parse(event.reminderAt!);
        overdue = !isDone && remindDt.isBefore(now);
      } catch (_) {}
    }

    Color bgColor;
    Color borderColor;
    if (overdue) {
      bgColor = c.overdueLight;
      borderColor = c.overdue.withValues(alpha: 0.25);
    } else if (isDone) {
      bgColor = c.doneLight;
      borderColor = c.done.withValues(alpha: 0.2);
    } else {
      bgColor = c.card;
      borderColor = c.border.withValues(alpha: 0.5);
    }

    return Dismissible(
      key: Key('event_${event.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => _ModernDialog(
                title: 'Удалить событие?',
                content: event.content,
                confirmText: 'Удалить',
                confirmColor: c.danger,
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: c.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (!isDone)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? c.done : Colors.transparent,
                    border: Border.all(
                      color: isDone ? c.done : c.border,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.content,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDone ? c.textSecondary : c.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildSubtitle(c, overdue),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.border, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(AppColorScheme c, bool overdue) {
    if (overdue) {
      return Row(
        children: [
          Icon(Icons.schedule, color: c.overdue, size: 13),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Просрочено · ${event.reminderAt}',
              style: TextStyle(color: c.overdue, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    if (event.reminderAt != null) {
      return Row(
        children: [
          Icon(Icons.notifications_none_rounded,
              color: c.primary.withValues(alpha: 0.6), size: 13),
          const SizedBox(width: 4),
          Text(
            event.reminderAt!,
            style: TextStyle(color: c.primary.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      );
    }
    return Text(
      event.createdAt,
      style: TextStyle(color: c.textSecondary, fontSize: 12),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Чип-фильтр
// ══════════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.primary.withValues(alpha: 0.12) : c.chipBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 15,
              color: selected ? c.primary : c.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? c.primary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Пустое состояние
// ══════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final bool allDone;
  const _EmptyState({this.allDone = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: c.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              allDone ? Icons.celebration_rounded : Icons.notifications_none_rounded,
              size: 36,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            allDone ? 'Всё выполнено!' : 'Пока нет событий',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            allDone
                ? 'Отличная работа, все дела сделаны'
                : 'Нажмите + чтобы создать первое',
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Модальный диалог
// ══════════════════════════════════════════════════════════════
class _ModernDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final Color confirmColor;

  const _ModernDialog({
    required this.title,
    required this.content,
    required this.confirmText,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: c.textPrimary)),
            const SizedBox(height: 12),
            Text('"$content"',
                style: TextStyle(color: c.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: c.border),
                      ),
                    ),
                    child: Text('Отмена',
                        style: TextStyle(
                            color: c.textSecondary, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(confirmText,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Экран создания / редактирования события
// ══════════════════════════════════════════════════════════════
class EventFormPage extends StatefulWidget {
  final Event? event;
  const EventFormPage({super.key, this.event});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  late TextEditingController _contentCtrl;
  bool _reminderEnabled = false;
  DateTime? _selectedDateTime;
  bool _showCustomInterval = false;
  final _daysCtrl = TextEditingController(text: '0');
  final _hoursCtrl = TextEditingController(text: '0');
  final _minutesCtrl = TextEditingController(text: '30');

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.event?.content ?? '');
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

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(
                  primary: c.primary, onPrimary: Colors.white, surface: c.card)
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
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(primary: c.primary, onPrimary: Colors.white)
              : ColorScheme.light(primary: c.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    final combined =
        DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    if (combined.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Это время уже прошло'),
          backgroundColor: c.overdue,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _save() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return;

    String? reminderAt;
    if (_reminderEnabled && _selectedDateTime != null) {
      reminderAt = DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime!);
    }

    int eventId;
    if (_isEdit) {
      await DB.updateEvent(widget.event!.id!, text, reminderAt: reminderAt);
      eventId = widget.event!.id!;
      await NotificationService.cancelNotification(eventId);
    } else {
      eventId = await DB.addEvent(text, reminderAt: reminderAt);
    }

    if (reminderAt != null && _selectedDateTime != null) {
      await NotificationService.scheduleNotification(
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
        ? DateFormat('dd.MM.yyyy  HH:mm').format(_selectedDateTime!)
        : null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактировать' : 'Новое событие'),
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, size: 20, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _save,
              style: TextButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                _isEdit ? 'Сохранить' : 'Добавить',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Поле ввода ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _contentCtrl,
                autofocus: true,
                maxLines: 3,
                style: TextStyle(fontSize: 16, color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Что нужно запомнить?',
                  labelStyle: TextStyle(color: c.textSecondary),
                  floatingLabelStyle: TextStyle(color: c.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: c.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(18),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Секция напоминания ─────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.primarySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.notifications_none_rounded,
                            color: c.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Напоминание',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: _reminderEnabled,
                        onChanged: (v) =>
                            setState(() => _reminderEnabled = v),
                      ),
                    ],
                  ),

                  if (_reminderEnabled) ...[
                    const SizedBox(height: 20),

                    // ── Быстрые интервалы ─────────────────
                    Text('Быстро',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                          letterSpacing: 0.5,
                        )),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _QuickButton(
                            label: '1 ч',
                            onTap: () =>
                                _setQuick(const Duration(hours: 1))),
                        const SizedBox(width: 8),
                        _QuickButton(
                            label: '4 ч',
                            onTap: () =>
                                _setQuick(const Duration(hours: 4))),
                        const SizedBox(width: 8),
                        _QuickButton(
                            label: '8 ч',
                            onTap: () =>
                                _setQuick(const Duration(hours: 8))),
                        const SizedBox(width: 8),
                        _QuickButton(
                            label: 'Завтра',
                            onTap: () =>
                                _setQuick(const Duration(days: 1))),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Своё время ─────────────────────────
                    GestureDetector(
                      onTap: () => setState(
                          () => _showCustomInterval = !_showCustomInterval),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _showCustomInterval
                              ? c.primary.withValues(alpha: 0.1)
                              : c.primarySurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _showCustomInterval
                                ? c.primary.withValues(alpha: 0.3)
                                : c.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showCustomInterval
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.tune_rounded,
                              color: c.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Своё время',
                              style: TextStyle(
                                color: c.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Раскрывающийся ввод ────────────────
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _IntervalField(
                                    controller: _daysCtrl, label: 'Дни'),
                                const SizedBox(width: 10),
                                _IntervalField(
                                    controller: _hoursCtrl, label: 'Часы'),
                                const SizedBox(width: 10),
                                _IntervalField(
                                    controller: _minutesCtrl, label: 'Мин'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _applyCustomInterval,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Установить',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _showCustomInterval
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),

                    const SizedBox(height: 18),
                    Divider(color: c.divider, height: 1),
                    const SizedBox(height: 18),

                    // ── Точное время ──────────────────────
                    Text('Точное время',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                          letterSpacing: 0.5,
                        )),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickDate,
                            icon: Icon(Icons.calendar_month_rounded,
                                size: 18, color: c.primary),
                            label: Text('Выбрать',
                                style: TextStyle(color: c.primary)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primarySurface,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        if (_selectedDateTime != null) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () =>
                                setState(() => _selectedDateTime = null),
                            icon: Icon(Icons.close_rounded,
                                color: c.danger, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  c.danger.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Выбранное время ───────────────────
                    if (fmt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: c.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: c.primary, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              fmt,
                              style: TextStyle(
                                color: c.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text('Время не выбрано',
                          style: TextStyle(
                              color: c.textSecondary.withValues(alpha: 0.6),
                              fontSize: 13)),
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

// ══════════════════════════════════════════════════════════════
//  Кнопка быстрого интервала
// ══════════════════════════════════════════════════════════════
class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: c.primarySurface,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: c.primary.withValues(alpha: 0.15)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: c.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Поле ввода интервала (дни / часы / минуты)
// ══════════════════════════════════════════════════════════════
class _IntervalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _IntervalField({required this.controller, required this.label});

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
                color: c.textSecondary,
              )),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: c.primarySurface,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: c.primary.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.primary,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
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
