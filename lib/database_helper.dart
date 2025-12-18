import 'dart:io';

import 'package:flutter/material.dart'; // Added for debugPrint
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'config.dart';

class DatabaseHelper {
  static const _databaseName = "spotato.db";
  static const _databaseVersion = 1;

  static const tableAnalyses = 'analyses';

  static const columnId = 'id';
  static const columnImagePath = 'imagePath';
  static const columnLabel = 'label';
  static const columnConfidence = 'confidence';
  static const columnDuration = 'analysisDuration';
  static const columnCaptureTime = 'captureTime';
  static const columnAlbumName = 'albumName';
  static const columnRowTag = 'rowTag'; // New column for the row tag

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableAnalyses (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnImagePath TEXT NOT NULL UNIQUE,
        $columnLabel TEXT,
        $columnConfidence REAL NOT NULL,
        $columnDuration INTEGER,
        $columnCaptureTime TEXT NOT NULL,
        $columnAlbumName TEXT NOT NULL,
        $columnRowTag TEXT 
      )
      ''');
  }

  Future<int> insertAnalysis(DetectionResult result, String albumName) async {
    Database db = await instance.database;
    final map = {
      columnImagePath: result.file.path,
      columnLabel: result.label,
      columnConfidence: result.confidence,
      columnDuration: result.analysisDuration?.inMilliseconds,
      columnCaptureTime: result.captureTime?.toIso8601String(),
      columnAlbumName: albumName,
      columnRowTag: result.rowTag,
    };
    return await db.insert(
      tableAnalyses,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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

  // 🔹 --- THIS FUNCTION IS NOW FIXED --- 🔹
  // 🔹 --- FILTERING IMPLEMENTED HERE --- 🔹
  /// Retrieves albums with optional filtering.
  /// [startDate] and [endDate] filter by the album's latest image time.
  /// [filterType] can be 'All', 'Has Disease', or 'Healthy'.
  Future<List<Map<String, dynamic>>> getAllAlbums({
    DateTime? startDate,
    DateTime? endDate,
    String filterType = 'All', // 'All', 'Has Disease', 'Healthy'
  }) async {
    Database db = await instance.database;

    // 1. Build the WHERE clause (Date Range & Exclude Current Scan)
    String whereClause = "$columnAlbumName != 'Current Scan'";
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += " AND $columnCaptureTime >= ?";
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      // Add one day to include the end date fully (up to midnight)
      final effectiveEndDate = endDate.add(const Duration(days: 1));
      whereClause += " AND $columnCaptureTime < ?";
      whereArgs.add(effectiveEndDate.toIso8601String());
    }

    // 2. Build the HAVING clause (Disease Filter)
    String havingClause = "";
    if (filterType == 'Has Disease') {
      // Must have at least one image with 'Blight'
      havingClause = "HAVING SUM(CASE WHEN $columnLabel LIKE '%Blight%' THEN 1 ELSE 0 END) > 0";
    } else if (filterType == 'Healthy') {
      // Must have ZERO images with 'Blight'
      havingClause = "HAVING SUM(CASE WHEN $columnLabel LIKE '%Blight%' THEN 1 ELSE 0 END) = 0";
    }

    // 3. Construct the Query
    // We group by AlbumName and RowTag to aggregate stats
    final sql = '''
      SELECT
        $columnAlbumName,
        $columnRowTag, 
        MAX($columnCaptureTime) as latestImageTime,
        COUNT($columnId) as imageCount,
        SUM(CASE WHEN $columnLabel LIKE '%Blight%' THEN 1 ELSE 0 END) as diseaseCount
      FROM $tableAnalyses
      WHERE $whereClause
      GROUP BY $columnAlbumName, $columnRowTag
      $havingClause
      ORDER BY latestImageTime DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, whereArgs);

    // 🔹 DEBUGGING
    debugPrint("--- [DatabaseHelper] getAllAlbums(Filter: $filterType) ---");
    debugPrint("Found ${maps.length} albums.");
    
    return maps;
  }

  Future<List<DetectionResult>> getRecentAnalyses({int limit = 4}) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableAnalyses,
      where: "$columnAlbumName != ?",
      whereArgs: ['Current Scan'],
      orderBy: '$columnCaptureTime DESC',
      limit: limit,
    );
    return _mapToList(maps);
  }

  Future<int> updateAlbumAndTag(
    String oldName,
    String newName,
    String rowTag,
  ) async {
    Database db = await instance.database;
    return await db.update(
      tableAnalyses,
      {
        columnAlbumName: newName,
        columnRowTag: rowTag, // Set the row tag for all images in this scan
      },
      where: '$columnAlbumName = ?',
      whereArgs: [oldName],
    );
  }

  Future<int> deleteAlbum(String albumName) async {
    Database db = await instance.database;
    return await db.delete(
      tableAnalyses,
      where: '$columnAlbumName = ?',
      whereArgs: [albumName],
    );
  }

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
        rowTag: maps[i][columnRowTag], // Read the saved tag
      );
    });
  }
}
