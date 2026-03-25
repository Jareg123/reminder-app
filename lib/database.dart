import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Event {
  final int? id;
  final String content;
  final String createdAt;
  final String? reminderAt;
  final int isActive;
  final int isDone;
  final String? recurrence; // повторение в минутах: '60', '1440', '10080'
  final String? labelColor;  // hex цвет метки: 'FF6B6B', '4ECDC4' и т.д.

  Event({
    this.id,
    required this.content,
    required this.createdAt,
    this.reminderAt,
    this.isActive = 1,
    this.isDone = 0,
    this.recurrence,
    this.labelColor,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      content: map['content'],
      createdAt: map['created_at'],
      reminderAt: map['reminder_at'],
      isActive: map['is_active'] ?? 1,
      isDone: map['is_done'] ?? 0,
      recurrence: map['recurrence'],
      labelColor: map['label_color'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'created_at': createdAt,
      'reminder_at': reminderAt,
      'is_active': isActive,
      'is_done': isDone,
      'recurrence': recurrence,
      'label_color': labelColor,
    };
  }

  Event copyWith({
    int? id,
    String? content,
    String? createdAt,
    String? reminderAt,
    int? isActive,
    int? isDone,
    Object? recurrence = _sentinel,
    Object? labelColor = _sentinel,
  }) {
    return Event(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      reminderAt: reminderAt ?? this.reminderAt,
      isActive: isActive ?? this.isActive,
      isDone: isDone ?? this.isDone,
      recurrence: recurrence == _sentinel ? this.recurrence : recurrence as String?,
      labelColor: labelColor == _sentinel ? this.labelColor : labelColor as String?,
    );
  }
}

const Object _sentinel = Object();

class DB {
  static Database? _database;

  static Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'events.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT,
            created_at TEXT,
            reminder_at TEXT,
            is_active INTEGER,
            is_done INTEGER DEFAULT 0,
            recurrence TEXT,
            label_color TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE daily_stats (
            date TEXT PRIMARY KEY,
            completed_tasks INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        final cols = await db.rawQuery("PRAGMA table_info(events)");
        final colNames = cols.map((c) => c['name'] as String).toList();

        if (oldVersion < 2) {
          if (!colNames.contains('is_done')) {
            await db.execute("ALTER TABLE events ADD COLUMN is_done INTEGER DEFAULT 0");
          }
        }
        if (oldVersion < 3) {
          if (!colNames.contains('recurrence')) {
            await db.execute("ALTER TABLE events ADD COLUMN recurrence TEXT");
          }
        }
        if (oldVersion < 4) {
          if (!colNames.contains('label_color')) {
            await db.execute("ALTER TABLE events ADD COLUMN label_color TEXT");
          }
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS daily_stats (
              date TEXT PRIMARY KEY,
              completed_tasks INTEGER DEFAULT 0
            )
          ''');
        }
      },
    );
  }

  static Future<int> addEvent(
    String content, {
    String? reminderAt,
    String? recurrence,
    String? labelColor,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return db.insert('events', {
      'content': content,
      'created_at': createdAt,
      'reminder_at': reminderAt,
      'is_active': 1,
      'is_done': 0,
      'recurrence': recurrence,
      'label_color': labelColor,
    });
  }

  static Future<List<Event>> getAll() async {
    final db = await database;
    final maps = await db.query(
      'events',
      orderBy: "CASE WHEN reminder_at IS NULL THEN 1 ELSE 0 END, reminder_at ASC, id DESC",
    );
    return maps.map((m) => Event.fromMap(m)).toList();
  }

  static Future<void> deleteEvent(int id) async {
    final db = await database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> toggleDone(int id, int currentState) async {
    final db = await database;
    final newState = currentState == 0 ? 1 : 0;
    await db.update('events', {'is_done': newState}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateEvent(
    int id,
    String content, {
    String? reminderAt,
    Object? recurrence = _sentinel,
    Object? labelColor = _sentinel,
  }) async {
    final db = await database;
    final data = <String, dynamic>{
      'content': content,
      'reminder_at': reminderAt,
    };
    if (recurrence != _sentinel) {
      data['recurrence'] = recurrence as String?;
    }
    if (labelColor != _sentinel) {
      data['label_color'] = labelColor as String?;
    }
    await db.update('events', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<Event?> getById(int id) async {
    final db = await database;
    final maps = await db.query('events', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Event.fromMap(maps.first);
  }

  static Future<void> markDoneById(int id) async {
    final db = await database;
    await db.update('events', {'is_done': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Обновляет только reminder_at — для авто-перепланирования и откладывания
  static Future<void> updateReminderAt(int id, String reminderAt) async {
    final db = await database;
    await db.update(
      'events',
      {'reminder_at': reminderAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> recordTaskCompleted() async {
    final db = await database;
    final today = _todayStr();
    await db.rawInsert(
      'INSERT OR IGNORE INTO daily_stats (date, completed_tasks) VALUES (?, 0)',
      [today],
    );
    await db.rawUpdate(
      'UPDATE daily_stats SET completed_tasks = completed_tasks + 1 WHERE date = ?',
      [today],
    );
  }

  static Future<int> getStreak() async {
    final db = await database;
    final rows = await db.query('daily_stats', orderBy: 'date DESC');
    final Map<String, int> byDate = {};
    for (final row in rows) {
      byDate[row['date'] as String] = row['completed_tasks'] as int;
    }
    int streak = 0;
    var checkDate = DateTime.now();
    final today = _todayStr();
    if ((byDate[today] ?? 0) == 0) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    while (true) {
      final d = checkDate;
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if ((byDate[dateStr] ?? 0) > 0) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static Future<int> getWeeklyCompletedCount() async {
    final db = await database;
    final now = DateTime.now();
    final dates = List.generate(7, (i) {
      final d = now.subtract(Duration(days: i + 1));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
    final placeholders = List.filled(7, '?').join(',');
    final result = await db.rawQuery(
      'SELECT SUM(completed_tasks) as total FROM daily_stats WHERE date IN ($placeholders)',
      dates,
    );
    return (result.first['total'] as int?) ?? 0;
  }
}
