import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'stamp_config.dart';

class ImageCompositeService {
  static Future<Uint8List?> compositeStampOntoPhoto(
    String photoPath,
    Uint8List stampPngBytes,
    int stampWidthPx,
  ) async {
    try {
      final photoFile = File(photoPath);
      if (!photoFile.existsSync()) return null;

      final photoBytes = photoFile.readAsBytesSync();
      final originalImage = img.decodeImage(photoBytes);
      if (originalImage == null) return null;

      final stampImageRaw = img.decodeImage(stampPngBytes);
      if (stampImageRaw == null) return null;

      final stampImage = img.copyResize(
        stampImageRaw,
        width: stampWidthPx,
      );

      final margin = (originalImage.width * 0.04).toInt();

      final dstX = (originalImage.width - stampImage.width) ~/ 2;
      final dstY = originalImage.height - stampImage.height - margin;

      img.compositeImage(
        originalImage,
        stampImage,
        dstX: dstX,
        dstY: dstY,
      );

      final jpegBytes = img.encodeJpg(
        originalImage,
        quality: StampConfig.jpegQuality,
      );

      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      if (kDebugMode) print('Composite error: $e');
      return null;
    }
  }
}
