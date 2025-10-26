import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A helper class to manage image fetching and compression.
class ImageHandler {
  static final _picker = ImagePicker();

  /// Picks an image from the user's gallery.
  static Future<File?> pickFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint("Image picking error: $e");
    }
    return null;
  }

  /// 🔹 UPDATED: This function now only finds files modified *after* the
  /// [lastImportTime] to avoid importing duplicates from previous sessions.
  static Future<List<File>> importFromTello(DateTime lastImportTime) async {
    try {
      final telloDir = Directory('/storage/emulated/0/Pictures/TelloPhoto/');

      if (!await telloDir.exists()) {
        debugPrint("--- DEBUG ---");
        debugPrint("❌ Directory does not exist: ${telloDir.path}");
        debugPrint("---------------");
        return [];
      }

      debugPrint("--- DEBUG ---");
      debugPrint("✅ Directory exists. Listing all files...");

      // Ensure we only get files, not directories or other links
      final allFiles = telloDir.listSync().whereType<File>().toList();
      if (allFiles.isEmpty) {
        debugPrint("⚠️ Directory is empty. No files found.");
        debugPrint("---------------");
        return [];
      }

      debugPrint("Filtering for new files created after: $lastImportTime");

      final newFiles = allFiles.where((f) {
        final mod = f.lastModifiedSync();

        // 🔹 THIS IS THE NEW LOGIC 🔹
        // It's only "new" if its modification time is *after* the last import.
        final isNew = mod.isAfter(lastImportTime);

        debugPrint(
          "  - Checking ${p.basename(f.path)} (Modified: $mod). Is new? $isNew",
        );

        return isNew;
      }).toList();

      debugPrint("${newFiles.length} new file(s) found.");
      debugPrint("---------------");
      return newFiles;
    } catch (e) {
      debugPrint("--- DEBUG ---");
      debugPrint("❌ CRITICAL ERROR reading Tello folder: $e");
      if (e is FileSystemException && e.message.contains('Permission denied')) {
        debugPrint(
          "👉 This is a PERMISSION PROBLEM. Did you grant storage access?",
        );
      }
      debugPrint("---------------");
      return [];
    }
  }

  /// Compresses a given image file and saves it to a temporary directory.
  /// Returns the new, compressed file.
  static Future<File?> compressImage(File sourceFile) async {
    try {
      final tempDir = await getApplicationDocumentsDirectory();

      // Get the source filename WITHOUT its extension (e.g., "1761475959045")
      final sourceFileName = p.basenameWithoutExtension(sourceFile.path);
      // Create a new target filename that ALWAYS ends in .jpg
      final targetFileName =
          '${DateTime.now().millisecondsSinceEpoch}_$sourceFileName.jpg';

      // Create a unique target path to avoid file name collisions.
      final targetPath = p.join(
        tempDir.path,
        'SPOTATO',
        'Temp',
        targetFileName, // Use the new .jpg filename
      );

      // Ensures the target directory exists before trying to write to it.
      await Directory(p.dirname(targetPath)).create(recursive: true);

      final result = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        targetPath, // This path now correctly ends in .jpg
        quality: 85, // Good balance of quality and size
        minWidth: 1080, // Resize larger images
        minHeight: 1080,
      );

      if (result != null) {
        final originalSize = await sourceFile.length();
        final compressedSize = await result.length();
        debugPrint(
          '✅ Image compressed: ${(originalSize / 1024).toStringAsFixed(1)}KB -> ${(compressedSize / 1024).toStringAsFixed(1)}KB',
        );
        return File(result.path);
      }
    } catch (e) {
      debugPrint("❌ Image compression error: $e");
    }
    return null;
  }
}
