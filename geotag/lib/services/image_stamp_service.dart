import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../models/location_data.dart';
import '../services/map_service.dart';

class ImageStampService {
  static Future<Uint8List?> stampImage(
    String imagePath,
    LocationData location,
    DateTime selectedDate,
  ) async {
    try {
      // Load image
      final originalFile = File(imagePath);
      final originalBytes = await originalFile.readAsBytes();
      var originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) return null;

      // Resize if needed
      if (originalImage.width > 1920) {
        originalImage = img.copyResize(originalImage, width: 1920);
      }

      // Get real map tile
      final mapBytes = await MapService.generateMapSnapshot(
        location.latitude,
        location.longitude,
      );
      img.Image? mapImage;
      if (mapBytes != null) {
        mapImage = img.decodeImage(mapBytes);
      }

      // Create stamped image with bottom footer
      final barHeight = 340;
      final stamped = img.Image(
        width: originalImage.width,
        height: originalImage.height + barHeight,
        numChannels: 3,
      );

      // Fill with original photo
      img.compositeImage(stamped, originalImage, dstY: 0);

      // Dark background for footer
      img.fillRect(
        stamped,
        x1: 0,
        y1: originalImage.height,
        x2: stamped.width,
        y2: stamped.height,
        color: img.ColorRgb8(0, 0, 0),
      );

      // Add accent line at top of footer
      img.drawLine(
        stamped,
        x1: 0,
        y1: originalImage.height,
        x2: stamped.width,
        y2: originalImage.height,
        color: img.ColorRgb8(255, 140, 0),
        thickness: 2,
      );

      // === LEFT SECTION: Map ===
      if (mapImage != null) {
        final mapSize = 160;
        final mapResized = img.copyResize(mapImage, width: mapSize, height: mapSize);
        
        // Place map in bottom left
        img.compositeImage(
          stamped,
          mapResized,
          dstX: 15,
          dstY: originalImage.height + 50,
        );
        
        // Border around map
        img.drawRect(
          stamped,
          x1: 14,
          y1: originalImage.height + 49,
          x2: 14 + mapSize,
          y2: originalImage.height + 49 + mapSize,
          color: img.ColorRgb8(255, 140, 0),
          thickness: 2,
        );
      }

      // === RIGHT SECTION: Information ===
      final textStartX = 195;
      var currentY = originalImage.height + 10;

      // Location address (heading)
      String address = location.address;
      if (address.length > 50) {
        address = '${address.substring(0, 47)}...';
      }
      
      img.drawString(
        stamped,
        address,
        font: img.arial24,
        x: textStartX,
        y: currentY,
        color: img.ColorRgb8(255, 255, 255),
      );

      currentY += 32;

      // Latitude
      final latText = 'Lat: ${location.latitude.toStringAsFixed(6)}';
      img.drawString(
        stamped,
        latText,
        font: img.arial24,
        x: textStartX,
        y: currentY,
        color: img.ColorRgb8(220, 220, 220),
      );

      currentY += 28;

      // Longitude
      final lonText = 'Long: ${location.longitude.toStringAsFixed(6)}';
      img.drawString(
        stamped,
        lonText,
        font: img.arial24,
        x: textStartX,
        y: currentY,
        color: img.ColorRgb8(220, 220, 220),
      );

      currentY += 28;

      // Altitude
      final altText = location.altitude != null && location.altitude! > 0
          ? 'Alt: ${location.altitude!.toStringAsFixed(1)}m'
          : 'Alt: N/A';
      img.drawString(
        stamped,
        altText,
        font: img.arial24,
        x: textStartX,
        y: currentY,
        color: img.ColorRgb8(220, 220, 220),
      );

      currentY += 28;

      // Accuracy (GPS accuracy)
      final accuracyText = location.accuracy != null
          ? 'Accuracy: ±${location.accuracy!.toStringAsFixed(1)}m'
          : 'Accuracy: N/A';
      img.drawString(
        stamped,
        accuracyText,
        font: img.arial24,
        x: textStartX,
        y: currentY,
        color: img.ColorRgb8(220, 220, 220),
      );

      currentY += 28;

      // Speed
      final speedText = location.speed != null && location.speed! > 0
          ? 'Speed: ${(location.speed! * 3.6).toStringAsFixed(1)}km/h'
          : 'Speed: 0km/h';
      img.drawString(
        stamped,
        speedText,
        font: img.arial24,
        x: textStartX,
        y: currentY,
        color: img.ColorRgb8(220, 220, 220),
      );

      currentY += 28;

      // Unique ID
      final idText = 'ID: ${location.uniqueId}';
      img.drawString(
        stamped,
        idText,
        font: img.arial24,
        x: textStartX,
        y: currentY,
        color: img.ColorRgb8(100, 200, 255),
      );

      currentY += 28;

      // Date & Time
      final now = DateTime.now();
      final stampDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      );
      final dateValue = DateFormat('dd-MMM-yyyy hh:mm a').format(stampDateTime);
      img.drawString(
        stamped,
        dateValue,
        font: img.arial24,
        x: textStartX,
        y: currentY,
        color: img.ColorRgb8(255, 140, 0),
      );

      // Encode
      final jpegBytes = img.encodeJpg(stamped, quality: 95);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      print('Error stamping image: $e');
      return null;
    }
  }
}