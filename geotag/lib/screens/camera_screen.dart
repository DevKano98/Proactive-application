import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
import '../services/image_stamp_service.dart';
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  final DateTime selectedDate;
  const CameraScreen({super.key, required this.selectedDate});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _flashEnabled = false;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request permissions
      final cameraStatus = await Permission.camera.request();
      final locationStatus = await Permission.location.request();

      if (!cameraStatus.isGranted || !locationStatus.isGranted) {
        setState(() {
          _error = 'Camera and Location permissions are required';
        });
        return;
      }

      // Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No cameras found on device';
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Turn off flash by default
      if (_cameraController != null) {
        await _cameraController!.setFlashMode(FlashMode.off);
        
        // Get max zoom
        final maxZoom = await _cameraController!.getMaxZoomLevel();
        setState(() {
          _maxZoom = maxZoom;
          _currentZoom = 1.0;
        });
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Camera initialization failed: $e';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController != null) {
      try {
        if (_flashEnabled) {
          await _cameraController!.setFlashMode(FlashMode.off);
        } else {
          await _cameraController!.setFlashMode(FlashMode.always);
        }
        setState(() {
          _flashEnabled = !_flashEnabled;
        });
      } catch (e) {
        print('Error toggling flash: $e');
      }
    }
  }

  Future<void> _setZoom(double zoom) async {
    if (_cameraController != null && zoom >= 1.0 && zoom <= _maxZoom) {
      try {
        await _cameraController!.setZoomLevel(zoom);
        setState(() {
          _currentZoom = zoom;
        });
      } catch (e) {
        print('Error setting zoom: $e');
      }
    }
  }

  void _zoomIn() {
    double newZoom = (_currentZoom + 0.5).clamp(1.0, _maxZoom);
    _setZoom(newZoom);
  }

  void _zoomOut() {
    double newZoom = (_currentZoom - 0.5).clamp(1.0, _maxZoom);
    _setZoom(newZoom);
  }

  Future<void> _captureAndStampPhoto() async {
    if (_isCapturing || !_isInitialized) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Take photo
      final XFile photo = await _cameraController!.takePicture();

      // Get location
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get location')),
          );
        }
        setState(() {
          _isCapturing = false;
        });
        return;
      }

      // Stamp image
      final stampedImageBytes = await ImageStampService.stampImage(
        photo.path,
        location,
        widget.selectedDate,
      );

      if (stampedImageBytes != null && mounted) {
        // Use push() to keep camera screen in stack
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(imageBytes: stampedImageBytes),
          ),
        );
        
        // Reset capturing flag after navigation
        setState(() {
          _isCapturing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Image.asset(
            'assets/logo.png',
            height: 40,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _flashEnabled ? Icons.flash_on : Icons.flash_off,
                color: _flashEnabled ? Colors.orange : Colors.black,
                size: 28,
              ),
              onPressed: _toggleFlash,
            ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              )
            : !_isInitialized
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      // Camera preview
                      CameraPreview(_cameraController!),

                      // Date overlay (top)
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Evidence Date: ${widget.selectedDate.toIso8601String().split('T')[0]}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      // Zoom controls (right side)
                      Positioned(
                        right: 20,
                        top: 120,
                        child: Column(
                          children: [
                            FloatingActionButton(
                              mini: true,
                              heroTag: 'zoom_in',
                              backgroundColor: Colors.orange,
                              onPressed: _zoomIn,
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_currentZoom.toStringAsFixed(1)}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FloatingActionButton(
                              mini: true,
                              heroTag: 'zoom_out',
                              backgroundColor: Colors.orange,
                              onPressed: _zoomOut,
                              child: const Icon(
                                Icons.remove,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Capture button (bottom center)
                      Positioned(
                        bottom: 32,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _isCapturing ? null : _captureAndStampPhoto,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.orange,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _isCapturing
                                  ? const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.orange,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 40,
                                      color: Colors.orange,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}