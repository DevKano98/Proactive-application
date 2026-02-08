import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
import '../models/location_data.dart';
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  final DateTime selectedDate;
  const CameraScreen({super.key, required this.selectedDate});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _flashEnabled = false;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  String? _error;
  String _locationStatus = 'GPS: Acquiring...';
  LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeAll() async {
    await _requestPermissions();
    await _initializeCamera();
    _acquireLocationAsync();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.location,
      Permission.storage,
    ].request();
  }

  void _acquireLocationAsync() {
    LocationService.getCurrentLocation(timeout: const Duration(seconds: 15))
        .then((location) {
      if (!mounted) return;
      setState(() {
        _currentLocation = location;
        _locationStatus = location != null ? '✓ GPS Ready' : '⚠️ GPS Issue';
      });
    }).catchError((_) {
      if (mounted) {
        setState(() => _locationStatus = '⚠️ GPS Error');
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraStatus = await Permission.camera.status;
      final locationStatus = await Permission.location.status;

      if (!cameraStatus.isGranted || !locationStatus.isGranted) {
        setState(() {
          _error = 'Camera and Location permissions required';
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras found');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);

      _maxZoom = await _cameraController!.getMaxZoomLevel();
      _currentZoom = 1.0;

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Camera init failed: $e');
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      if (_flashEnabled) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.always);
      }

      setState(() => _flashEnabled = !_flashEnabled);
    } catch (_) {}
  }

  Future<void> _setZoom(double zoom) async {
    if (_cameraController == null) return;

    zoom = zoom.clamp(1.0, _maxZoom);

    try {
      await _cameraController!.setZoomLevel(zoom);
      setState(() => _currentZoom = zoom);
    } catch (_) {}
  }

  void _zoomIn() => _setZoom(_currentZoom + 0.5);
  void _zoomOut() => _setZoom(_currentZoom - 0.5);

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_isInitialized || _cameraController == null) return;

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _cameraController!.takePicture();

      if (!mounted) {
        setState(() => _isCapturing = false);
        return;
      }

      // Get fresh location if not available
      LocationData? location = _currentLocation;
      if (location == null) {
        location = await LocationService.getCurrentLocation(
          timeout: const Duration(seconds: 10),
        );
      }

      if (location == null) {
        _showError('Could not acquire GPS location');
        return;
      }

      if (!mounted) {
        setState(() => _isCapturing = false);
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            photoPath: photo.path,
            location: location!,
            selectedDate: widget.selectedDate,
          ),
        ),
      );

      if (mounted) {
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Capture error: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() => _isCapturing = false);
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
          title: Image.asset('assets/logo.png', height: 40),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _flashEnabled ? Icons.flash_on : Icons.flash_off,
                color: _flashEnabled ? Colors.orange : Colors.black,
              ),
              onPressed: _toggleFlash,
            )
          ],
        ),
        body: _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : !_isInitialized
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      CameraPreview(_cameraController!),
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
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _locationStatus,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
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
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_currentZoom.toStringAsFixed(1)}x',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FloatingActionButton(
                              mini: true,
                              heroTag: 'zoom_out',
                              backgroundColor: Colors.orange,
                              onPressed: _zoomOut,
                              child: const Icon(Icons.remove),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 32,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _isCapturing ? null : _capturePhoto,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border:
                                    Border.all(color: Colors.orange, width: 4),
                              ),
                              child: _isCapturing
                                  ? const CircularProgressIndicator(
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.orange),
                                    )
                                  : const Icon(Icons.camera_alt,
                                      size: 40, color: Colors.orange),
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