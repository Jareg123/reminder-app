import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minimal Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EventsPage(),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить событие?'),
        content: Text('"${event.content}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
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
      MaterialPageRoute(builder: (_) => EventFormPage(event: event)),
    );
    if (result == true) await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEvents;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ваши события', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Row(
            children: [
              const Text('Скрыть готовые', style: TextStyle(fontSize: 13)),
              Switch(
                value: _hideDone,
                onChanged: (v) => setState(() => _hideDone = v),
                activeColor: Colors.blue,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDialog(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: visible.isEmpty
          ? Center(
              child: Text(
                _hideDone && _events.any((e) => e.isDone == 1)
                    ? 'Все дела выполнены 🎉'
                    : 'Нет событий. Нажми + чтобы добавить.',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: visible.length,
              itemBuilder: (ctx, i) {
                final event = visible[i];
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
                  bgColor = const Color(0xFFFFF3E0);
                  borderColor = const Color(0xFFFFCC80);
                } else if (isDone) {
                  bgColor = Colors.green.shade50;
                  borderColor = Colors.green.shade200;
                } else {
                  bgColor = Colors.white;
                  borderColor = Colors.blueGrey.shade100;
                }

                Widget subtitle;
                if (overdue) {
                  subtitle = Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 15),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Просрочено: ${event.reminderAt}',
                          style: const TextStyle(color: Colors.orange, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                } else if (event.reminderAt != null) {
                  subtitle = Text(
                    '⏰ ${event.reminderAt}',
                    style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
                  );
                } else {
                  subtitle = Text(
                    event.createdAt,
                    style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 12),
                  );
                }

                return Dismissible(
                  key: Key('event_${event.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить событие?'),
                            content: Text('"${event.content}"'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Отмена')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) async {
                    await NotificationService.cancelNotification(event.id!);
                    await DB.deleteEvent(event.id!);
                    await _loadEvents();
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListTile(
                      leading: Checkbox(
                        value: isDone,
                        onChanged: (_) => _toggleDone(event),
                        activeColor: Colors.green,
                      ),
                      title: Text(
                        event.content,
                        style: TextStyle(
                          color: isDone ? Colors.blueGrey.shade400 : Colors.black87,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: subtitle,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteEvent(event),
                      ),
                      onTap: () => _openDialog(event: event),
                    ),
                  ),
                );
              },
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
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;

    // После даты сразу предлагаем время
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
    );
    if (time == null) return;

    final combined = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    if (combined.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Это время уже прошло, выберите другое'),
          backgroundColor: Colors.orange,
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
      // Отменяем старое уведомление перед установкой нового
      await NotificationService.cancelNotification(eventId);
    } else {
      eventId = await DB.addEvent(text, reminderAt: reminderAt);
    }

    // Планируем уведомление если время выбрано
    if (reminderAt != null && _selectedDateTime != null) {
      await NotificationService.scheduleNotification(
        id: eventId,
        title: '⏰ Напоминание',
        body: text,
        scheduledTime: _selectedDateTime!,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = _selectedDateTime != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(_selectedDateTime!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактировать' : 'Новое событие'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              _isEdit ? 'Сохранить' : 'Добавить',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
            TextField(
              controller: _contentCtrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Что нужно запомнить?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Переключатель напоминания ───────────────────
            Row(
              children: [
                const Text('Установить напоминание', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Switch(
                  value: _reminderEnabled,
                  onChanged: (v) => setState(() => _reminderEnabled = v),
                  activeColor: Colors.blue,
                ),
              ],
            ),

            if (_reminderEnabled) ...[
              const SizedBox(height: 16),

              // ── Быстрые интервалы ───────────────────────
              const Text('Быстрые интервалы', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                      onPressed: () => _setQuick(const Duration(hours: 1)),
                      child: const Text('1 ч')),
                  OutlinedButton(
                      onPressed: () => _setQuick(const Duration(hours: 4)),
                      child: const Text('4 ч')),
                  OutlinedButton(
                      onPressed: () => _setQuick(const Duration(hours: 8)),
                      child: const Text('8 ч')),
                  OutlinedButton(
                      onPressed: () => _setQuick(const Duration(days: 1)),
                      child: const Text('Завтра')),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // ── Точное время ────────────────────────────
              const Text('Точное время', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Дата и время'),
                  ),
                  const SizedBox(width: 12),
                  if (_selectedDateTime != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedDateTime = null),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Убрать', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Выбранное время ─────────────────────────
              if (fmt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Выбрано: $fmt',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              else
                Text('Выбрано: —', style: TextStyle(color: Colors.blueGrey.shade400)),
            ],
          ],
        ),
      ),
    );
  }
}
