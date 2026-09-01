import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../remainder/reminder_model.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'reminders.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE reminders(
            id INTEGER PRIMARY KEY,
            title TEXT,
            body TEXT,
            scheduledTime TEXT,
            repeatFrequency TEXT,
            isActive INTEGER,
            priority TEXT,
            lastCompleted TEXT,
            customInterval INTEGER,
            customUnit TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE reminders ADD COLUMN completedAt TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE reminders ADD COLUMN lastCompleted TEXT');
        }
      },
    );
  }

  Future<void> insertReminder(Reminder reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      _toMap(reminder),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateReminder(Reminder reminder) async {
    final db = await database;
    await db.update(
      'reminders',
      _toMap(reminder),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<void> deleteReminder(int id) async {
    final db = await database;
    await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reminders');
    return List.generate(maps.length, (i) {
      return _fromMap(maps[i]);
    });
  }

  Future<Reminder?> getReminderById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('reminders');
  }

  Map<String, dynamic> _toMap(Reminder r) {
    return {
      'id': r.id,
      'title': r.title,
      'body': r.body,
      'scheduledTime': r.scheduledTime.toIso8601String(),
      'repeatFrequency': r.repeatFrequency.name,
      'isActive': r.isActive ? 1 : 0,
      'priority': r.priority.name,
      'lastCompleted': r.lastCompleted?.toIso8601String(),
      'customInterval': r.customInterval,
      'customUnit': r.customUnit,
    };
  }

  Reminder _fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      scheduledTime: DateTime.parse(map['scheduledTime']),
      repeatFrequency: RepeatFrequency.values.firstWhere(
        (e) => e.name == map['repeatFrequency'],
        orElse: () => RepeatFrequency.none,
      ),
      isActive: map['isActive'] == 1,
      priority: ReminderPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => ReminderPriority.medium,
      ),
      lastCompleted: map['lastCompleted'] != null ? DateTime.parse(map['lastCompleted']) : null,
      customInterval: map['customInterval'],
      customUnit: map['customUnit'],
    );
  }
}
