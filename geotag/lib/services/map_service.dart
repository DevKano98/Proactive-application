import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

class MapService {
  // OpenStreetMap tile server (FREE!)
  static const String tileServer = 'https://tile.openstreetmap.org';
  
  static Future<Uint8List?> generateMapSnapshot(double lat, double lon) async {
    try {
      // Calculate tile coordinates for zoom level 15
      const zoom = 15;
      final x = _lon2tile(lon, zoom);
      final y = _lat2tile(lat, zoom);
      
      // Download the tile from OpenStreetMap
      final tileUrl = '$tileServer/$zoom/$x/$y.png';
      
      if (kDebugMode) {
        print('📍 Downloading map tile: $tileUrl');
      }
      
      final response = await http.get(
        Uri.parse(tileUrl),
        headers: {
          'User-Agent': 'ProActiveCamera/1.0', // Required by OSM
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        // Decode the tile image
        var tileImage = img.decodePng(response.bodyBytes);
        if (tileImage == null) {
          if (kDebugMode) {
            print('❌ Failed to decode tile image');
          }
          return _generateFallbackMap(lat, lon);
        }
        
        // Resize to 200x200
        tileImage = img.copyResize(tileImage, width: 200, height: 200);
        
        // Add location pin in center
        _drawLocationPin(tileImage, 100, 100);
        
        // Add border
        img.drawRect(
          tileImage,
          x1: 0,
          y1: 0,
          x2: 199,
          y2: 199,
          color: img.ColorRgb8(100, 100, 100),
          thickness: 3,
        );
        
        if (kDebugMode) {
          print('✓ Real map tile downloaded and processed');
        }
        
        final pngBytes = img.encodePng(tileImage);
        return Uint8List.fromList(pngBytes);
      } else {
        if (kDebugMode) {
          print('⚠ Tile server returned ${response.statusCode}, using fallback');
        }
        return _generateFallbackMap(lat, lon);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Map download failed: $e, using fallback');
      }
      return _generateFallbackMap(lat, lon);
    }
  }
  
  // Convert lat/lon to tile coordinates
  static int _lon2tile(double lon, int zoom) {
    return ((lon + 180) / 360 * pow(2, zoom)).floor();
  }
  
  static int _lat2tile(double lat, int zoom) {
    return ((1 - log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) / pi) / 2 * pow(2, zoom)).floor();
  }
  
  // Fallback map (offline)
  static Future<Uint8List?> _generateFallbackMap(double lat, double lon) {
    try {
      final mapSize = 200;
      final mapImage = img.Image(width: mapSize, height: mapSize, numChannels: 3);
      
      // Gray background
      img.fillRect(
        mapImage,
        x1: 0,
        y1: 0,
        x2: mapSize,
        y2: mapSize,
        color: img.ColorRgb8(220, 220, 220),
      );
      
      // Draw grid
      for (int i = 0; i < mapSize; i += 40) {
        img.drawLine(mapImage, x1: i, y1: 0, x2: i, y2: mapSize,
            color: img.ColorRgb8(200, 200, 200), thickness: 1);
        img.drawLine(mapImage, x1: 0, y1: i, x2: mapSize, y2: i,
            color: img.ColorRgb8(200, 200, 200), thickness: 1);
      }
      
      // Location pin
      _drawLocationPin(mapImage, mapSize ~/ 2, mapSize ~/ 2);
      
      // Border
      img.drawRect(
        mapImage,
        x1: 0,
        y1: 0,
        x2: mapSize - 1,
        y2: mapSize - 1,
        color: img.ColorRgb8(100, 100, 100),
        thickness: 3,
      );
      
      final pngBytes = img.encodePng(mapImage);
      return Future.value(Uint8List.fromList(pngBytes));
    } catch (e) {
      return Future.value(null);
    }
  }
  
  // Draw red location pin
  static void _drawLocationPin(img.Image image, int centerX, int centerY) {
    // Pin shadow
    img.fillCircle(image, x: centerX + 2, y: centerY + 2, radius: 12,
        color: img.ColorRgb8(60, 60, 60));
    
    // Pin white border
    img.fillCircle(image, x: centerX, y: centerY, radius: 12,
        color: img.ColorRgb8(255, 255, 255));
    
    // Pin red center
    img.fillCircle(image, x: centerX, y: centerY, radius: 9,
        color: img.ColorRgb8(234, 67, 53));
    
    // Pin white dot
    img.fillCircle(image, x: centerX, y: centerY, radius: 3,
        color: img.ColorRgb8(255, 255, 255));
  }
}