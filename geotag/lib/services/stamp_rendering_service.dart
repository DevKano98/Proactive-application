import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class StampRenderingService {
  static Future<Uint8List?> renderStampWidget(GlobalKey key) async {
    try {
      final context = key.currentContext;
      if (context == null) return null;

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Wait for frame completion
      await WidgetsBinding.instance.endOfFrame;
      
      // GPU buffer needs time for pixelRatio: 5.0
      await Future.delayed(const Duration(milliseconds: 100));

      // Attempt with retries
      for (int i = 0; i < 3; i++) {
        try {
          final ui.Image image = await boundary.toImage(pixelRatio: 5.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();

          final result = byteData?.buffer.asUint8List();
          if (result != null && result.isNotEmpty) {
            return result;
          }
        } catch (e) {
          if (i < 2) {
            await Future.delayed(const Duration(milliseconds: 32));
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Stamp render error: $e');
      return null;
    }
  }
}