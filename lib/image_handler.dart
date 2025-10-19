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

  /// Finds and returns a list of recent image files from the Tello drone's directory.
  static Future<List<File>> importFromTello() async {
    try {
      final telloDir = Directory('/storage/emulated/0/Pictures/TelloPhoto');
      if (!await telloDir.exists()) return [];

      final now = DateTime.now();
      return telloDir.listSync().whereType<File>().where((f) {
        final mod = f.lastModifiedSync();
        // Return files modified in the last 10 minutes.
        return now.difference(mod).inMinutes <= 10;
      }).toList();
    } catch (e) {
      debugPrint("Error reading Tello folder: $e");
      return [];
    }
  }

  /// Compresses a given image file and saves it to a temporary directory.
  /// Returns the new, compressed file.
  static Future<File?> compressImage(File sourceFile) async {
    try {
      final tempDir = await getApplicationDocumentsDirectory();
      final sourceFileName = p.basename(sourceFile.path);
      // Create a unique target path to avoid file name collisions.
      final targetPath = p.join(
        tempDir.path,
        'SPOTATO',
        'Temp',
        '${DateTime.now().millisecondsSinceEpoch}_$sourceFileName',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        targetPath,
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
