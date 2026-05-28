import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../features/incorrect_note/models/incorrect_note.dart';

class DatabaseHelper {
  static const _databaseName = "everlaw_edu.db";
  static const _databaseVersion = 1;
  static const tableIncorrectNote = 'client_incorrect_note';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableIncorrectNote (
        id TEXT PRIMARY KEY,
        quizId TEXT NOT NULL,
        question TEXT NOT NULL,
        options TEXT NOT NULL,
        answerIndex INTEGER NOT NULL,
        selectedIndex INTEGER NOT NULL,
        explanation TEXT NOT NULL,
        lawReference TEXT NOT NULL,
        incorrectAt TEXT NOT NULL,
        isArchived INTEGER NOT NULL,
        syncStatus TEXT NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 스키마 변경 시 대응 로직을 여기에 작성합니다.
  }

  // --- CRUD Operations for client_incorrect_note ---

  Future<int> insertNote(IncorrectNote note) async {
    Database db = await instance.database;
    return await db.insert(
      tableIncorrectNote, 
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<IncorrectNote>> getAllNotes() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableIncorrectNote);
    return List.generate(maps.length, (i) {
      return IncorrectNote.fromMap(maps[i]);
    });
  }

  Future<int> updateNote(IncorrectNote note) async {
    Database db = await instance.database;
    return await db.update(
      tableIncorrectNote,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(String id) async {
    Database db = await instance.database;
    return await db.delete(
      tableIncorrectNote,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllNotes() async {
    Database db = await instance.database;
    await db.delete(tableIncorrectNote);
  }

  // pendingDelete 상태인 ID 목록 조회
  Future<List<String>> getPendingDeleteIds() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableIncorrectNote,
      columns: ['id'],
      where: 'syncStatus = ?',
      whereArgs: [SyncStatus.pendingDelete.name],
    );
    return List.generate(maps.length, (i) => maps[i]['id'] as String);
  }

  // pendingAdd 상태인 항목들 조회
  Future<List<IncorrectNote>> getPendingAddNotes() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableIncorrectNote,
      where: 'syncStatus = ?',
      whereArgs: [SyncStatus.pendingAdd.name],
    );
    return List.generate(maps.length, (i) => IncorrectNote.fromMap(maps[i]));
  }
}
