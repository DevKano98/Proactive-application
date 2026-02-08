import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;

import '../models/location_data.dart';
import '../services/map_service.dart';
import '../services/native_gallery.dart';
import '../services/stamp_rendering_service.dart';
import '../services/image_composite_service.dart';
import '../widgets/stamp_overlay_widget.dart';

class PreviewScreen extends StatefulWidget {
  final String photoPath;
  final LocationData location;
  final DateTime selectedDate;

  const PreviewScreen({
    Key? key,
    required this.photoPath,
    required this.location,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final GlobalKey _stampKey = GlobalKey();

  late Future<_InitData> _initFuture;

  bool _saving = false;
  bool _uiReady = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();

    // Mark UI ready ONLY after widget is fully built and painted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait one more frame to ensure map image is painted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _uiReady = true);
        }
      });
    });
  }

  Future<_InitData> _initialize() async {
    final photoFile = File(widget.photoPath);
    if (!await photoFile.exists()) {
      throw Exception('Photo not found');
    }

    final photoBytes = await photoFile.readAsBytes();
    final photoImage = img.decodeImage(photoBytes);
    if (photoImage == null) {
      throw Exception('Invalid image');
    }

    // Pre-load map image so it's painted before buttons appear
    final mapBytes = await MapService.generateMapSnapshot(
      widget.location.latitude,
      widget.location.longitude,
    );

    return _InitData(
      photoImage: photoImage,
      mapBytes: mapBytes,
    );
  }

  Future<void> _saveImage() async {
    if (_saving || !_uiReady) return;

    setState(() => _saving = true);

    try {
      // Extra wait before final render
      await Future.delayed(const Duration(milliseconds: 50));

      final stampPng =
          await StampRenderingService.renderStampWidget(_stampKey);

      if (stampPng == null) {
        throw Exception('Stamp render failed');
      }

      final photoBytes = await File(widget.photoPath).readAsBytes();
      final photoImage = img.decodeImage(photoBytes);
      if (photoImage == null) {
        throw Exception('Invalid photo');
      }

      final photoWidth = photoImage.width;

      final compositeImage =
          await ImageCompositeService.compositeStampOntoPhoto(
        widget.photoPath,
        stampPng,
        (photoWidth * 0.92).toInt(),
      );

      if (compositeImage == null) {
        throw Exception('Composite failed');
      }

      final fileName =
          'PROACTIVE_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.jpg';

      final success = await NativeGallery.saveImage(compositeImage, fileName);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Saved'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) Navigator.pop(context);
      } else {
        throw Exception('Save failed');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_saving,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text('Preview', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: FutureBuilder<_InitData>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final data = snapshot.data!;

            return Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio:
                        data.photoImage.width / data.photoImage.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(widget.photoPath),
                          fit: BoxFit.cover,
                        ),

                        Positioned(
                          bottom: 24,
                          left: 24,
                          right: 24,
                          child: RepaintBoundary(
                            key: _stampKey,
                            child: StampOverlayWidget(
                              location: widget.location,
                              selectedDate: widget.selectedDate,
                              mapBytes: data.mapBytes,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Buttons appear ONLY when UI is fully ready
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _uiReady ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !_uiReady,
                      child: Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.all(16),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[700],
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Retake'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: (_saving || !_uiReady)
                                      ? null
                                      : _saveImage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.save),
                                  label: Text(
                                    _saving ? 'Saving...' : 'Save & Continue',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InitData {
  final img.Image photoImage;
  final Uint8List? mapBytes;

  _InitData({
    required this.photoImage,
    required this.mapBytes,
  });
}