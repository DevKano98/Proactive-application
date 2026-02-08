import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../models/location_data.dart';

class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;

  static final Map<String, CachedGeocodeResult> _geocodeCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  static LocationData? _lastLocation;
  static DateTime? _lastLocationTime;
  static const Duration _locationRefreshInterval = Duration(seconds: 10);

  /// MAIN LOCATION FETCH - WITH SAMSUNG FIX
  static Future<LocationData?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 30), // Increased from 25 for Samsung
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) print("Location service disabled");
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) print("Location permission denied");
        return null;
      }

      // SAMSUNG FIX: Use forceAndroidLocationManager
      // This forces use of Android's native location manager instead of Samsung's layer
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // Changed from bestForNavigation
        timeLimit: timeout,
        forceAndroidLocationManager: true, // ← KEY FIX FOR SAMSUNG
      );

      if (kDebugMode) {
        print("✓ GPS Position acquired: ${position.latitude}, ${position.longitude}");
      }

      final addressParts = await _getCleanAddressParts(
        position.latitude,
        position.longitude,
      );

      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        shortAddress: addressParts.shortAddress,
        fullAddress: addressParts.fullAddress,
      );

      _lastLocation = locationData;
      _lastLocationTime = DateTime.now();

      return locationData;
    } catch (e) {
      if (kDebugMode) print("❌ Location error: $e");
      return null;
    }
  }

  /// FAST CACHE ACCESS
  static LocationData? getLastKnownLocation() {
    if (_lastLocation != null &&
        _lastLocationTime != null &&
        DateTime.now().difference(_lastLocationTime!) <
            _locationRefreshInterval) {
      return _lastLocation;
    }
    return null;
  }

  /// CLEAN ADDRESS GENERATOR
  static Future<AddressParts> _getCleanAddressParts(
    double lat,
    double lon,
  ) async {
    try {
      final cacheKey =
          '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';

      if (_geocodeCache.containsKey(cacheKey)) {
        final cached = _geocodeCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
          return cached.parts;
        } else {
          _geocodeCache.remove(cacheKey);
        }
      }

      final placemarks =
          await placemarkFromCoordinates(lat, lon)
              .timeout(const Duration(seconds: 8));

      if (placemarks.isEmpty) {
        return _fallbackParts(lat, lon);
      }

      final p = placemarks.first;

      final city = p.locality ?? '';
      final state = p.administrativeArea ?? '';
      final country = p.country ?? '';

      final street = p.street ?? '';
      final subLocality = p.subLocality ?? '';

      final shortAddress = [
        city,
        state,
        country
      ].where((e) => e.isNotEmpty).join(', ');

      final fullAddress = [
        street,
        subLocality,
        city,
        state,
        country
      ].where((e) => e.isNotEmpty).join(', ');

      final parts = AddressParts(
        shortAddress: shortAddress.isEmpty
            ? 'Unknown Location'
            : shortAddress,
        fullAddress: fullAddress.isEmpty
            ? shortAddress
            : fullAddress,
      );

      _geocodeCache[cacheKey] = CachedGeocodeResult(
        parts: parts,
        timestamp: DateTime.now(),
      );

      return parts;
    } catch (e) {
      if (kDebugMode) print("Geocode error: $e");
      return _fallbackParts(lat, lon);
    }
  }

  static AddressParts _fallbackParts(double lat, double lon) {
    final coords =
        'Lat ${lat.toStringAsFixed(6)}, Lon ${lon.toStringAsFixed(6)}';

    return AddressParts(
      shortAddress: 'Unknown Location',
      fullAddress: coords,
    );
  }

  static void clearGeocodeCache() {
    _geocodeCache.clear();
  }

  static void dispose() {
    _geocodeCache.clear();
  }
}

/// CLEAN STRUCT FOR ADDRESS
class AddressParts {
  final String shortAddress;
  final String fullAddress;

  AddressParts({
    required this.shortAddress,
    required this.fullAddress,
  });
}

class CachedGeocodeResult {
  final AddressParts parts;
  final DateTime timestamp;

  CachedGeocodeResult({
    required this.parts,
    required this.timestamp,
  });
}