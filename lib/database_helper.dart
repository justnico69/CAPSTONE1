import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'config.dart'; // We'll need this for the DetectionResult class

// --- The Database Helper Class ---
// Manages all database operations: creating the DB, tables, and CRUD operations.

class DatabaseHelper {
  // --- Database constants ---
  static const _databaseName = "spotato.db";
  static const _databaseVersion = 1;

  // --- Table and column names ---
  static const tableAnalyses = 'analyses';
  static const columnId = 'id';
  static const columnImagePath = 'imagePath';
  static const columnLabel = 'label';
  static const columnConfidence = 'confidence';
  static const columnDuration = 'analysisDuration'; // in milliseconds
  static const columnCaptureTime = 'captureTime'; // ISO 8601 String
  static const columnAlbumName = 'albumName';

  // --- Singleton instance ---
  // This pattern ensures we only ever have one instance of this class.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // --- Database connection ---
  // This holds the single, app-wide database connection.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database by finding the correct path and creating the tables.
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  /// Creates the database tables when the app is first installed.
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableAnalyses (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnImagePath TEXT NOT NULL UNIQUE,
        $columnLabel TEXT,
        $columnConfidence REAL NOT NULL,
        $columnDuration INTEGER,
        $columnCaptureTime TEXT NOT NULL,
        $columnAlbumName TEXT NOT NULL
      )
    ''');
  }

  // --- CRUD (Create, Read, Update, Delete) Operations ---

  /// 1. CREATE: Inserts a new analysis record into the database.
  Future<int> insertAnalysis(DetectionResult result, String albumName) async {
    Database db = await instance.database;
    final map = {
      columnImagePath: result.file.path,
      columnLabel: result.label,
      columnConfidence: result.confidence,
      columnDuration: result.analysisDuration?.inMilliseconds,
      columnCaptureTime: result.captureTime?.toIso8601String(),
      columnAlbumName: albumName,
    };
    return await db.insert(
      tableAnalyses,
      map,
      // Replace any existing entry for the same image path.
      // This is useful if the user re-analyzes an image.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 2. READ: Fetches all analyses for a specific album.
  /// Used in: `album_detail_page.dart`
  Future<List<DetectionResult>> getAnalysesForAlbum(String albumName) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableAnalyses,
      where: '$columnAlbumName = ?',
      whereArgs: [albumName],
      orderBy: '$columnCaptureTime DESC',
    );

    return _mapToList(maps);
  }

  /// 3. READ: Fetches a list of unique album names.
  /// Used in: `album_page.dart`
  Future<List<Map<String, dynamic>>> getAllAlbums() async {
    Database db = await instance.database;
    // We get the album name and the timestamp of the newest photo in that album.
    // This lets us sort the albums by most recently saved.
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        $columnAlbumName, 
        MAX($columnCaptureTime) as latestImageTime,
        COUNT($columnId) as imageCount 
      FROM $tableAnalyses 
      WHERE $columnAlbumName != 'Current Scan'
      GROUP BY $columnAlbumName 
      ORDER BY latestImageTime DESC
    ''');
    return maps;
  }

  /// 4. READ: Fetches the 4 most recent analyses from saved albums.
  /// Used in: `home_page.dart`
  Future<List<DetectionResult>> getRecentAnalyses({int limit = 4}) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableAnalyses,
      where: "$columnAlbumName != ?",
      whereArgs: ['Current Scan'], // Don't show unsaved scans on the homepage
      orderBy: '$columnCaptureTime DESC',
      limit: limit,
    );
    return _mapToList(maps);
  }

  /// 5. UPDATE: Changes the album name for a set of analyses.
  /// Used for saving the "Current Scan" to a permanent album.
  /// Used in: `row_detail.dart`
  Future<int> updateAlbumName(String oldName, String newName) async {
    Database db = await instance.database;
    return await db.update(
      tableAnalyses,
      {columnAlbumName: newName},
      where: '$columnAlbumName = ?',
      whereArgs: [oldName],
    );
  }

  /// 6. DELETE: Deletes all analyses associated with an album name.
  /// Used for: `_clearCurrentScan` and `_deleteSelected` in the album page.
  Future<int> deleteAlbum(String albumName) async {
    Database db = await instance.database;
    return await db.delete(
      tableAnalyses,
      where: '$columnAlbumName = ?',
      whereArgs: [albumName],
    );
  }

  /// Helper function to convert a list of database maps into a list of DetectionResult objects.
  List<DetectionResult> _mapToList(List<Map<String, dynamic>> maps) {
    return List.generate(maps.length, (i) {
      return DetectionResult(
        file: File(maps[i][columnImagePath]),
        label: maps[i][columnLabel],
        confidence: maps[i][columnConfidence] ?? 0.0,
        analysisDuration: maps[i][columnDuration] != null
            ? Duration(milliseconds: maps[i][columnDuration])
            : null,
        captureTime: DateTime.parse(maps[i][columnCaptureTime]),
      );
    });
  }
}
