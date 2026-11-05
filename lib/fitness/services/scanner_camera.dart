import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Small device boundary so navigation/permissions/lifecycle can be tested
/// without a native camera. No recordings, streaming or microphone capture.
abstract class ScannerCamera {
  bool get ready;
  bool get canSwitch;
  double get aspectRatio;
  Widget preview();
  Future<void> initialize();
  Future<void> switchLens();
  Future<File> capture();
  Future<void> close();
}

class DeviceScannerCamera implements ScannerCamera {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  Future<void>? _opening;
  bool _closed = false;
  int _index = 0;
  @override
  bool get ready => !_closed && (_controller?.value.isInitialized ?? false);
  @override
  bool get canSwitch => _cameras.length > 1;
  @override
  double get aspectRatio => _controller?.value.aspectRatio ?? 1;
  @override
  Widget preview() => CameraPreview(_controller!);

  @override
  Future<void> initialize() => _opening ??= _initialize();
  Future<void> _initialize() async {
    _cameras = await availableCameras();
    if (_closed) return;
    if (_cameras.isEmpty) throw CameraException('Unavailable', '');
    final back =
        _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    _index = back < 0 ? 0 : back;
    await _openLens();
  }

  Future<void> _openLens() async {
    if (_closed) return;
    final camera = CameraController(_cameras[_index], ResolutionPreset.high,
        enableAudio: false);
    _controller = camera;
    await camera.initialize();
  }

  @override
  Future<void> switchLens() async {
    if (!ready || !canSwitch) return;
    await _controller?.dispose();
    _controller = null;
    _index = (_index + 1) % _cameras.length;
    // Track lens initialization as well so close never races initialization.
    _opening = _openLens();
    await _opening;
  }

  @override
  Future<File> capture() async {
    if (!ready) throw CameraException('Unavailable', '');
    return File((await _controller!.takePicture()).path);
  }

  @override
  Future<void> close() async {
    _closed = true;
    try {
      await _opening;
    } catch (_) {/* Errors are shown by the page. */}
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
