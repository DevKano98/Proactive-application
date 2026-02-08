import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class StampRenderingService {
  static Future<Uint8List?> renderStampWidget(GlobalKey key) async {
    try {
      final context = key.currentContext;
      if (context == null) return null;

      // Wait for layout + paint to finish
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 40));
      await WidgetsBinding.instance.endOfFrame;

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return null;

      // If still painting, wait again
      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 60));
        await WidgetsBinding.instance.endOfFrame;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 6.0);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Stamp render error: $e');
      return null;
    }
  }
}
