import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AlbumManager {
  /// Returns the SPOTATO/New Detections directory
  static Future<Directory> getBaseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/SPOTATO/New Detections');
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  /// Saves all image files to a timestamped folder
  static Future<String> saveScanImages(List<File> images) async {
    if (images.isEmpty) return '';

    final base = await getBaseDir();
    final now = DateTime.now();
    final folderName =
        '${now.month}-${now.day}-${now.year}_${now.hour}-${now.minute}';
    final scanDir = Directory('${base.path}/$folderName');
    await scanDir.create(recursive: true);

    for (var img in images) {
      final fileName = img.uri.pathSegments.last;
      await img.copy('${scanDir.path}/$fileName');
    }

    return folderName;
  }

  /// Clears all files inside Current Scan
  static Future<void> clearCurrentScan() async {
    try {
      final base = await getBaseDir();
      final currentScan = Directory('${base.path}/Current Scan');
      if (await currentScan.exists()) {
        for (var file in currentScan.listSync()) {
          if (file is File) await file.delete();
        }
        print('🗑 Cleared Current Scan folder.');
      }
    } catch (e) {
      print('❌ Failed to clear scan data: $e');
    }
  }
}
