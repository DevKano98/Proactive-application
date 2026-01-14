import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import '../models/location_data.dart';

class LocationService {
  static Future<LocationData?> getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('❌ Location service is disabled');
        }
        return null;
      }

      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Check if permission is granted
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('❌ Location permission denied');
        }
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('❌ Location permission denied forever');
        }
        return null;
      }

      // Get current position with all available data
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 30),
      );

      if (kDebugMode) {
        print('✓ Location acquired: Lat ${position.latitude}, Lon ${position.longitude}');
        print('✓ Accuracy: ${position.accuracy}m, Speed: ${position.speed}m/s, Altitude: ${position.altitude}m');
      }

      // Get address from coordinates
      String address = 'Unknown Location';
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final Placemark p = placemarks[0];
          final street = p.street ?? '';
          final locality = p.locality ?? '';
          final country = p.country ?? '';

          address =
              '$street, $locality, $country'.replaceAll(RegExp(r',\s*,'), ',').trim();

          if (address.isEmpty || address == ',' || address == ', ,') {
            address = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }
          
          if (kDebugMode) {
            print('✓ Address: $address');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Geocoding error: $e');
        }
        address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lon: ${position.longitude.toStringAsFixed(6)}';
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed,
        timestamp: DateTime.now(),
        address: address,
        // These would require additional sensors/APIs
        humidity: null,
        temperature: null,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Location service error: $e');
      }
      return null;
    }
  }
}