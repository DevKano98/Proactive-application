import 'package:uuid/uuid.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final DateTime timestamp;
  final String address;
  final String uniqueId;
  final double? humidity;
  final double? temperature;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.timestamp,
    required this.address,
    this.humidity,
    this.temperature,
    String? uniqueId,
  }) : uniqueId = uniqueId ?? const Uuid().v4().substring(0, 12).toUpperCase();

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lon: $longitude, alt: $altitude, accuracy: $accuracy, speed: $speed, address: $address)';
  }
}