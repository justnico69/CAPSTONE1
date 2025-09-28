import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'detection_result.dart';

class HistoryStorage {
  static const String _fileName = 'detection_history.json';

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  Future<void> addResult(DetectionResult result) async {
    try {
      final List<DetectionResult> history = await getHistory();
      history.insert(0, result); // Add new result at the beginning

      final File file = File(await _getFilePath());
      final List<Map<String, dynamic>> jsonList = history
          .map((e) => e.toJson())
          .toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print("Error saving history: $e");
    }
  }

  Future<List<DetectionResult>> getHistory() async {
    try {
      final File file = File(await _getFilePath());
      if (!await file.exists()) {
        return []; // Return an empty list if file doesn't exist
      }

      final String contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList
          .map((json) => DetectionResult.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Error loading history: $e");
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      final File file = File(await _getFilePath());
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print("Error clearing history: $e");
    }
  }
}
