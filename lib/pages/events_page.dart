// ══════════════════════════════════════════════════════════════
//  ГЛАВНЫЙ ЭКРАН — СПИСОК СОБЫТИЙ
//  Отвечает за:
//    • загрузку и отображение списка задач из БД
//    • поиск по задачам (строка появляется/скрывается анимацией)
//    • переключатель "скрыть выполненные"
//    • прогресс-бар (выполнено X из Y)
//    • мультивыбор задач (долгий тап → MultiSelectBar)
//    • откладывание (SnoozeSheet) и перенос (RescheduleSheet)
//    • обновление home widget при каждом изменении списка
//    • запрос исключения из battery optimization (Android)
//
//  Переход на форму создания/редактирования: _openDialog()
// ══════════════════════════════════════════════════════════════
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database.dart';
import '../notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import '../widgets/snooze_sheet.dart';
import '../widgets/reschedule_sheet.dart';
import '../widgets/modern_dialog.dart';
import '../widgets/multi_select_bar.dart';
import '../widgets/header_widgets.dart';
import '../widgets/empty_state.dart';
import 'event_form_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> with WidgetsBindingObserver {
  List<Event> _events = [];
  bool _hideDone = false;
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  int _streak = 0;
  bool _wasAllDone = false;
  late ConfettiController _confettiController;

  // ── Мультивыбор ──────────────────────────────────────
  final Set<int> _selected = {};
  bool get _isSelecting => _selected.isNotEmpty;

  void _toggleSelect(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _cancelSelection() => setState(() => _selected.clear());

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ModernDialog(
        title: 'Удалить ${_selected.length} событий?',
        content: 'Это действие нельзя отменить',
        confirmText: 'Удалить',
        confirmColor: AppColorScheme.of(context).danger,
      ),
    ) ?? false;
    if (!confirmed) return;
    for (final id in _selected) {
      await NotificationService.safeCancel(id);
      await DB.deleteEvent(id);
    }
    _selected.clear();
    await _loadEvents();
  }

  Future<void> _markSelectedDone() async {
    for (final id in _selected) {
      final event = _events.firstWhere((e) => e.id == id);
      if (event.isDone == 0) {
        await DB.toggleDone(id, 0);
        await DB.recordTaskCompleted();
      }
    }
    _selected.clear();
    await _loadStreak();
    await _loadEvents();
  }

  Future<void> _rescheduleSelected() async {
    final c = AppColorScheme.of(context);

    final result = await showModalBottomSheet<Duration?>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const RescheduleSheet(),
    );
    if (result == null) return;

    final now = DateTime.now();
    for (final id in _selected) {
      final event = _events.firstWhere((e) => e.id == id);
      if (event.reminderAt == null) continue;
      try {
        final old = DateFormat('yyyy-MM-dd HH:mm').parse(event.reminderAt!);
        var next = old.add(result);
        if (next.isBefore(now)) next = now.add(result);
        final newStr = DateFormat('yyyy-MM-dd HH:mm').format(next);
        await DB.updateReminderAt(id, newStr);
        await NotificationService.safeCancel(id);
        await NotificationService.safeSchedule(
          id: id,
          title: 'Напоминание',
          body: event.content,
          scheduledTime: next,
        );
      } catch (_) {}
    }
    _selected.clear();
    await _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Перенесено: ${_events.length} задач'),
          backgroundColor: c.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEvents();
    _loadHideDone();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadStreak();
    _checkWeeklySummary();
    NotificationService.onTaskUpdated = _loadEvents;
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestBatteryOptimizationExemption();
      });
    }
  }

  /// Пишет ближайшие задачи в home widget
  Future<void> _updateWidget() => NotificationService.refreshHomeWidget();

  Future<void> _loadEvents() async {
    final events = await DB.getAll();

    events.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone.compareTo(b.isDone);

      final ta = a.reminderAt;
      final tb = b.reminderAt;
      if (ta == null && tb == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });

    setState(() => _events = events);
    final nowAllDone = events.isNotEmpty && events.every((e) => e.isDone == 1);
    if (nowAllDone && !_wasAllDone) {
      _confettiController.play();
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.heavyImpact();
    }
    _wasAllDone = nowAllDone;
    _updateWidget();
  }

  Future<void> _loadHideDone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _hideDone = prefs.getBool('hide_done') ?? false);
  }

  // Обновляем список при возврате в приложение
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadEvents();
    }
  }

  // Просим исключить из battery optimization — без этого Android
  // может убить процесс и уведомления перестанут приходить
  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    NotificationService.onTaskUpdated = null;
    _confettiController.dispose();
    super.dispose();
  }

  List<Event> get _visibleEvents {
    var list = _events.toList();
    if (_hideDone) list = list.where((e) => e.isDone == 0).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) => e.content.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _toggleDone(Event event) async {
    HapticFeedback.mediumImpact();
    if (event.isDone == 0) await DB.recordTaskCompleted();
    await DB.toggleDone(event.id!, event.isDone);

    // Повторяющееся событие → перепланировать после отметки выполненным
    if (event.isDone == 0 && event.recurrence != null && event.reminderAt != null) {
      final minutes = int.tryParse(event.recurrence!);
      if (minutes != null) {
        final oldTime = DateFormat('yyyy-MM-dd HH:mm').parse(event.reminderAt!);
        var next = oldTime.add(Duration(minutes: minutes));
        while (next.isBefore(DateTime.now())) {
          next = next.add(Duration(minutes: minutes));
        }
        final nextStr = DateFormat('yyyy-MM-dd HH:mm').format(next);
        await DB.updateReminderAt(event.id!, nextStr);
        await DB.toggleDone(event.id!, 1);
        await NotificationService.safeCancel(event.id!);
        await NotificationService.safeSchedule(
          id: event.id!,
          title: 'Напоминание',
          body: event.content,
          scheduledTime: next,
        );
      }
    }
    if (event.recurrence == null && event.isDone == 0) {
      await NotificationService.safeCancel(event.id!);
    }
    await _loadStreak();
    await _loadEvents();
  }

  Future<void> _snoozeEvent(Event event) async {
    final c = AppColorScheme.of(context);
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const SnoozeSheet(),
    );
    if (choice == null) return;

    DateTime baseTime = DateTime.now();
    if (event.reminderAt != null) {
      try {
        baseTime = DateFormat('yyyy-MM-dd HH:mm').parse(event.reminderAt!);
      } catch (_) {}
    }

    final newTime = baseTime.add(choice);
    final newStr = DateFormat('yyyy-MM-dd HH:mm').format(newTime);

    await DB.updateReminderAt(event.id!, newStr);
    await NotificationService.safeCancel(event.id!);
    await NotificationService.safeSchedule(
      id: event.id!,
      title: 'Напоминание',
      body: event.content,
      scheduledTime: newTime,
    );

    await _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Отложено до ${DateFormat('HH:mm').format(newTime)}'),
          backgroundColor: c.snooze,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _deleteEvent(Event event) async {
    await NotificationService.safeCancel(event.id!);
    await DB.deleteEvent(event.id!);
    await _loadEvents();
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

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _searchQuery = '';
      } else {
        Future.delayed(
          const Duration(milliseconds: 100),
              () => _searchFocus.requestFocus(),
        );
      }
    });
  }

  Future<void> _loadStreak() async {
    final streak = await DB.getStreak();
    if (mounted) setState(() => _streak = streak);
  }

  Future<void> _checkWeeklySummary() async {
    if (DateTime.now().weekday != DateTime.monday) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final lastSummary = prefs.getString('last_weekly_summary') ?? '';
    if (lastSummary == todayStr) return;
    final count = await DB.getWeeklyCompletedCount();
    if (count > 0) {
      await prefs.setString('last_weekly_summary', todayStr);
      await NotificationService.showInstant(
        id: 9999,
        title: 'Итоги недели 🔥',
        body: 'За прошлую неделю ты выполнил $count ${_taskWord(count)}. Отличная работа!',
      );
    }
  }

  String _streakWord(int n) {
    if (n % 100 >= 11 && n % 100 <= 14) return 'дней';
    switch (n % 10) {
      case 1: return 'день';
      case 2: case 3: case 4: return 'дня';
      default: return 'дней';
    }
  }

  String _taskWord(int n) {
    if (n % 100 >= 11 && n % 100 <= 14) return 'задач';
    switch (n % 10) {
      case 1: return 'задачу';
      case 2: case 3: case 4: return 'задачи';
      default: return 'задач';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorScheme.of(context);
    final visible = _visibleEvents;
    final now = DateTime.now();
    final doneCount = _events.where((e) => e.isDone == 1).length;
    final totalCount = _events.length;

    return Stack(
      children: [
        Scaffold(
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
                  Row(
                    children: [
                      Text(
                        'Reminder & Notify',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      HeaderIcon(
                        icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                        active: _searchOpen,
                        onTap: _toggleSearch,
                      ),
                      const SizedBox(width: 4),
                      const ThemeToggle(),
                      const SizedBox(width: 4),
                      HeaderIcon(
                        icon: _hideDone
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        active: _hideDone,
                        onTap: () async {
                          setState(() => _hideDone = !_hideDone);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('hide_done', _hideDone);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        totalCount == 0
                            ? 'Пока пусто'
                            : '$doneCount из $totalCount выполнено',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                      if (_streak > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 3),
                              Text(
                                '$_streak ${_streakWord(_streak)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF6B35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Строка поиска ──────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border.withValues(alpha: 0.5)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: c.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Найти событие…',
                      hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              crossFadeState: _searchOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),

            // ── Прогресс-бар ───────────────────────────────
            if (totalCount > 0) ...[
              const SizedBox(height: 12),
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
            const SizedBox(height: 12),

            // ── Список ─────────────────────────────────────
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                allDone: _hideDone && _events.any((e) => e.isDone == 1),
                isSearch: _searchQuery.isNotEmpty,
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: visible.length,
                itemBuilder: (ctx, i) {
                  final event = visible[i];
                  final isSelected = _selected.contains(event.id);
                  return EventCard(
                    event: event,
                    now: now,
                    onToggle: () => _isSelecting
                        ? _toggleSelect(event.id!)
                        : _toggleDone(event),
                    onDelete: () => _deleteEvent(event),
                    onSnooze: () => _snoozeEvent(event),
                    onTap: () => _isSelecting
                        ? _toggleSelect(event.id!)
                        : _openDialog(event: event),
                    onLongPress: () => _toggleSelect(event.id!),
                    isSelected: isSelected,
                    isSelecting: _isSelecting,
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ── FAB / панель мультивыбора ──────────────────────
      floatingActionButtonLocation: _isSelecting
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: _isSelecting
          ? MultiSelectBar(
              count: _selected.length,
              onCancel: _cancelSelection,
              onDelete: _deleteSelected,
              onDone: _markSelectedDone,
              onReschedule: _rescheduleSelected,
            )
          : Container(
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
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.07,
            numberOfParticles: 25,
            gravity: 0.15,
            colors: const [
              Color(0xFF10B981),
              Color(0xFFFFD93D),
              Color(0xFFFF6B6B),
              Color(0xFF4D96FF),
              Color(0xFFA66CFF),
              Color(0xFFFFB347),
            ],
          ),
        ),
      ],
    );
  }
}
