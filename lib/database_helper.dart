//database_helper.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'config.dart';

/// A singleton class to manage the application's SQLite database.
///
/// This class handles database initialization, schema creation (onCreate),
/// and provides methods for CRUD (Create, Read, Update, Delete) operations
/// on the analysis data.
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
  static const columnRowTag = 'rowTag';

  /// Private constructor for the singleton pattern.
  DatabaseHelper._privateConstructor();
  /// The single, static instance of [DatabaseHelper] for the entire application.
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  /// Retrieves the database instance, initializing it if not already present.
  ///
  /// If the database is already initialized, it returns the cached instance.
  /// Otherwise, it calls [_initDatabase] to open it.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database by finding the app's documents directory
  /// and opening (or creating) the database file at that path.
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  /// Called when the database is created for the first time.
  ///
  /// This method defines the schema for the [tableAnalyses].
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableAnalyses (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnImagePath TEXT NOT NULL UNIQUE,
        $columnLabel TEXT,
        $columnConfidence REAL NOT NOT NULL,
        $columnDuration INTEGER,
        $columnCaptureTime TEXT NOT NULL,
        $columnAlbumName TEXT NOT NULL,
        $columnRowTag TEXT 
      )
      ''');
  }

  /// Inserts a new [DetectionResult] into the database under a specific [albumName].
  ///
  /// Returns the ID of the newly inserted row.
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

  /// Retrieves all [DetectionResult]s associated with a specific [albumName],
  /// ordered by capture time (newest first).
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

  /// Retrieves a summary of all albums, excluding 'Current Scan'.
  ///
  /// Groups results by album name and row tag, and includes the
  /// latest image timestamp ('latestImageTime') and total image count ('imageCount')
  /// for each album.
  Future<List<Map<String, dynamic>>> getAllAlbums() async {
    Database db = await instance.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        $columnAlbumName,
        $columnRowTag, 
        MAX($columnCaptureTime) as latestImageTime,
        COUNT($columnId) as imageCount
      FROM $tableAnalyses
      WHERE $columnAlbumName != 'Current Scan'
      GROUP BY $columnAlbumName, $columnRowTag
      ORDER BY latestImageTime DESC
      ''');

    // 🔹 DEBUGGING: See what the database is returning
    debugPrint("--- [DatabaseHelper] getAllAlbums() ---");
    debugPrint("Found ${maps.length} albums.");
    for (var album in maps) {
      debugPrint(
        "  - Album: ${album[columnAlbumName]}, Row: ${album[columnRowTag]}",
      );
    }
    // ------------------------------------------------

    return maps;
  }

  /// Fetches a [limit]ed number of the most recent analyses,
  /// excluding any from the 'Current Scan' album.
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

  /// Updates the album name and row tag for all entries matching the [oldName].
  ///
  /// This is used for renaming an album or saving a 'Current Scan'.
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
        columnRowTag: rowTag,
      },
      where: '$columnAlbumName = ?',
      whereArgs: [oldName],
    );
  }

  /// Deletes all analysis entries associated with a specific [albumName].
  Future<int> deleteAlbum(String albumName) async {
    Database db = await instance.database;
    return await db.delete(
      tableAnalyses,
      where: '$columnAlbumName = ?',
      whereArgs: [albumName],
    );
  }

  /// A private helper utility to convert a list of database [maps]
  /// into a list of [DetectionResult] objects.
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
        rowTag: maps[i][columnRowTag],
      );
    });
  }
}