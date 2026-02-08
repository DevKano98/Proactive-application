import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class MapService {
  static String get googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static const String googleMapsEndpoint =
      'https://maps.googleapis.com/maps/api/staticmap';

  static Future<Uint8List?> generateMapSnapshot(
    double lat,
    double lon, {
    int zoom = 19,
  }) async {
    try {
      if (googleApiKey.isEmpty) {
        if (kDebugMode) print('⚠️ API key missing → fallback map');
        return _generateFallbackMap();
      }

      final mapUrl = '$googleMapsEndpoint?'
          'center=$lat,$lon'
          '&zoom=19'
          '&size=700x700'
          '&scale=2'
          '&maptype=satellite'
          '&markers=icon:https://maps.gstatic.com/mapfiles/api-3/images/spotlight-poi3_hdpi.png%7C$lat,$lon'
          '&key=$googleApiKey';

      final response =
          await http.get(Uri.parse(mapUrl)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      if (kDebugMode) {
        print('Map API error: ${response.statusCode}');
      }

      return _generateFallbackMap();
    } on TimeoutException {
      return _generateFallbackMap();
    } catch (_) {
      return _generateFallbackMap();
    }
  }

  static Future<Uint8List?> _generateFallbackMap() async {
    const size = 512;
    final image = img.Image(width: size, height: size);

    img.fill(image, color: img.ColorRgb8(235, 235, 235));

    for (int i = 0; i < size; i += 64) {
      img.drawLine(image,
          x1: i, y1: 0, x2: i, y2: size, color: img.ColorRgb8(210, 210, 210));
      img.drawLine(image,
          x1: 0, y1: i, x2: size, y2: i, color: img.ColorRgb8(210, 210, 210));
    }

    img.fillCircle(
      image,
      x: size ~/ 2,
      y: size ~/ 2,
      radius: 18,
      color: img.ColorRgb8(234, 67, 53),
    );

    img.fillCircle(
      image,
      x: size ~/ 2,
      y: size ~/ 2,
      radius: 6,
      color: img.ColorRgb8(255, 255, 255),
    );

    return Uint8List.fromList(img.encodePng(image));
  }
}
