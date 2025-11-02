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

  /// 🔹 --- THIS FUNCTION IS NOW UPDATED --- 🔹
  /// Finds and returns a list of new image files from the Tello drone's directory
  /// based on a UTC timestamp.
  static Future<List<File>> importFromTello(
    DateTime lastImportTimestamp, // Now accepts the UTC timestamp
  ) async {
    debugPrint(
      "  [ImageHandler] Checking for files modified AFTER (UTC): ${lastImportTimestamp.toIso8601String()}",
    );

    try {
      final telloDir = Directory('/storage/emulated/0/Pictures/TelloPhoto');
      debugPrint("  [ImageHandler] Checking path: ${telloDir.path}");

      if (!await telloDir.exists()) {
        debugPrint("  [ImageHandler] ❌ ERROR: Directory does not exist!");
        return [];
      }

      final allFiles = telloDir.listSync().whereType<File>().toList();
      debugPrint(
        "  [ImageHandler] Found ${allFiles.length} total files in folder.",
      );

      if (allFiles.isEmpty) {
        return [];
      }

      // Get a sample file for debugging
      final firstFile = allFiles.first;
      final firstFileModTime = firstFile.lastModifiedSync();
      debugPrint(
        "  [ImageHandler] Sample file: ${firstFile.path} | Modified (Local): $firstFileModTime | Modified (UTC): ${firstFileModTime.toUtc()}",
      );

      // Filter the files
      final newFiles = allFiles.where((f) {
        // 🔹 FIX: Convert file time to UTC before comparing!
        final fileModTimeUtc = f.lastModifiedSync().toUtc();

        // 🔹 FIX: Compare UTC to UTC
        final isNew = fileModTimeUtc.isAfter(lastImportTimestamp);

        debugPrint(
          "  [ImageHandler]   - File: ${f.path.split('/').last} | Modified (UTC): ${fileModTimeUtc.toIso8601String()} | Is New? -> $isNew",
        );
        return isNew;
      }).toList();

      debugPrint("  [ImageHandler] Returning ${newFiles.length} new files.");
      return newFiles;
    } catch (e) {
      debugPrint("  [ImageHandler] ❌ ERROR reading Tello folder: $e");
      return [];
    }
  }

  /// 🔹 --- THIS FUNCTION IS NOW UPDATED --- 🔹
  /// Compresses a given image file and saves it to a temporary directory.
  /// Returns the new, compressed file.
  static Future<File?> compressImage(File sourceFile) async {
    try {
      final tempDir = await getApplicationDocumentsDirectory();

      // 1. Get the original filename WITHOUT the extension
      final String baseName = p.basenameWithoutExtension(sourceFile.path);

      // 2. Create a new target filename that *always* ends in .jpg
      final String targetFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${baseName}.jpg';

      // 3. Create the full target path
      final targetPath = p.join(
        tempDir.path,
        'SPOTATO',
        'Temp',
        targetFileName, // Use the new .jpg filename
      );

      // 4. Create the directory if it doesn't exist
      final targetDir = Directory(p.dirname(targetPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 1080,
        minHeight: 1080,
        // 5. 🔹 THE FIX: Explicitly tell the compressor to create a JPEG.
        // This will convert PNGs to JPEGs and satisfy the validator.
        format: CompressFormat.jpeg,
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
