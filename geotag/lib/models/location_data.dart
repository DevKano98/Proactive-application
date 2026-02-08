import 'package:uuid/uuid.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String shortAddress;
  final String fullAddress;
  final String uniqueId;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.shortAddress,
    required this.fullAddress,
    String? uniqueId,
  }) : uniqueId = uniqueId ?? const Uuid().v4().substring(0, 12).toUpperCase();
}
