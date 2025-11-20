//image_handler.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A static helper class to manage all image fetching (gallery, Tello)
/// and processing (compression, format conversion).
class ImageHandler {
  /// A single instance of ImagePicker for the app.
  static final _picker = ImagePicker();

  /// Opens the device's gallery for the user to select a single image.
  /// Returns a [File] object or `null` if the user cancels.
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

  /// Scans the Tello drone's photo directory on the Android file system.
  ///
  /// This function compares the `lastModifiedSync` timestamp of each file (converted to UTC)
  /// against the [lastImportTimestamp] (also in UTC) to find only new photos.
  ///
  /// [lastImportTimestamp] The UTC timestamp of the last successful import.
  /// Returns a list of new [File] objects.
  static Future<List<File>> importFromTello(
    DateTime lastImportTimestamp,
  ) async {
    debugPrint(
      "  [ImageHandler] Checking for files modified AFTER (UTC): ${lastImportTimestamp.toIso8601String()}",
    );

    try {
      /// The hardcoded file path for Tello photos on Android devices.
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

      final firstFile = allFiles.first;
      final firstFileModTime = firstFile.lastModifiedSync();
      debugPrint(
        "  [ImageHandler] Sample file: ${firstFile.path} | Modified (Local): $firstFileModTime | Modified (UTC): ${firstFileModTime.toUtc()}",
      );

      // Filter the files by their modification time.
      final newFiles = allFiles.where((f) {
        // Convert file's last modified time to UTC for a reliable comparison.
        final fileModTimeUtc = f.lastModifiedSync().toUtc();

        // Check if the file's time is *after* the last import time.
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

  /// Compresses the given [sourceFile] to a max 1080p width/height and 85% quality.
  ///
  /// This function also converts any image format (like PNGs from the Tello drone)
  /// into [CompressFormat.jpeg] to ensure consistency and save space.
  /// Returns the new, compressed [File] stored in the app's temp directory.
  static Future<File?> compressImage(File sourceFile) async {
    try {
      final tempDir = await getApplicationDocumentsDirectory();

      // Get the original filename without the extension (e.g., "my_photo")
      final String baseName = p.basenameWithoutExtension(sourceFile.path);

      // Create a new target filename that *always* ends in .jpg
      final String targetFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${baseName}.jpg';

      // Create the full path in the app's private "Temp" folder
      final targetPath = p.join(
        tempDir.path,
        'SPOTATO',
        'Temp',
        targetFileName, // Use the new .jpg filename
      );

      // Ensure the "Temp" directory exists
      final targetDir = Directory(p.dirname(targetPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Compress and convert the file
      final result = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 1080,
        minHeight: 1080,
        // This converts PNGs (from Tello) to JPEGs, fixing the assertion error
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
