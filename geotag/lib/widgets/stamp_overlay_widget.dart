import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/location_data.dart';

class StampOverlayWidget extends StatelessWidget {
  final LocationData location;
  final DateTime selectedDate;
  final Uint8List? mapBytes;

  const StampOverlayWidget({
    super.key,
    required this.location,
    required this.selectedDate,
    required this.mapBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(185),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // ← CENTER MAP VERTICALLY
        children: [
          _buildMap(),
          const SizedBox(width: 12),
          Expanded(child: _buildText()),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 65,
        height: 65,
        child: mapBytes != null
            ? Image.memory(mapBytes!, fit: BoxFit.cover)
            : Container(color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildText() {
    final title = _extractCityStateCountry(location.fullAddress);

    final now = DateTime.now();
    final stampTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          location.fullAddress,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.white70,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEE, dd MMM yyyy, HH:mm:ss').format(stampTime),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          'Lat ${location.latitude.toStringAsFixed(6)}   Long ${location.longitude.toStringAsFixed(6)}',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  String _extractCityStateCountry(String address) {
    final parts = address.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 3) {
      return '${parts[parts.length - 3]}, ${parts[parts.length - 2]}, ${parts[parts.length - 1]}';
    }
    return address;
  }
}
