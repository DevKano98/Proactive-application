import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeGallery {
  static const MethodChannel _channel = MethodChannel('proactive/gallery');

  static Future<bool> saveImage(Uint8List bytes, String filename) async {
    try {
      final bool success = await _channel.invokeMethod('saveImage', {
        'bytes': bytes,
        'filename': filename,
      });
      return success;
    } catch (e) {
      print('Error calling native saveImage: $e');
      return false;
    }
  }
}