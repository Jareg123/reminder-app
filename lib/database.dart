import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Event {
  final int? id;
  final String content;
  final String createdAt;
  final String? reminderAt;
  final int isActive;
  final int isDone;

  Event({
    this.id,
    required this.content,
    required this.createdAt,
    this.reminderAt,
    this.isActive = 1,
    this.isDone = 0,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      content: map['content'],
      createdAt: map['created_at'],
      reminderAt: map['reminder_at'],
      isActive: map['is_active'] ?? 1,
      isDone: map['is_done'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'created_at': createdAt,
      'reminder_at': reminderAt,
      'is_active': isActive,
      'is_done': isDone,
    };
  }

  Event copyWith({
    int? id,
    String? content,
    String? createdAt,
    String? reminderAt,
    int? isActive,
    int? isDone,
  }) {
    return Event(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      reminderAt: reminderAt ?? this.reminderAt,
      isActive: isActive ?? this.isActive,
      isDone: isDone ?? this.isDone,
    );
  }
}

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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT,
            created_at TEXT,
            reminder_at TEXT,
            is_active INTEGER,
            is_done INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final cols = await db.rawQuery("PRAGMA table_info(events)");
          final colNames = cols.map((c) => c['name'] as String).toList();
          if (!colNames.contains('is_done')) {
            await db.execute("ALTER TABLE events ADD COLUMN is_done INTEGER DEFAULT 0");
          }
        }
      },
    );
  }

  static Future<int> addEvent(String content, {String? reminderAt}) async {
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
    });
  }

  static Future<List<Event>> getAll() async {
    final db = await database;
    final maps = await db.query('events', orderBy: 'id DESC');
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

  static Future<void> updateEvent(int id, String content, {String? reminderAt}) async {
    final db = await database;
    await db.update(
      'events',
      {'content': content, 'reminder_at': reminderAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
