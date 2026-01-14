import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
import '../services/image_stamp_service.dart';
import '../screens/preview_screen.dart';

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
        // Use push() instead of pushReplacement() so we can return to camera screen
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Only go back if user explicitly taps back
            // Don't go back when returning from preview
            Navigator.pop(context);
          },
        ),
        title: Image.asset(
          'assets/logo.png',
          height: 40,
        ),
        centerTitle: true,
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

                    // Date overlay
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

                    // Capture button
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
    );
  }
}