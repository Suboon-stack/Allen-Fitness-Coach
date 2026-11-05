import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/scanner_camera.dart';
import '../theme/app_theme.dart';
import '../widgets/scanner_widgets.dart';

class FoodCameraPage extends StatefulWidget {
  const FoodCameraPage(
      {super.key,
      required this.pickGallery,
      required this.sessionValid,
      this.cameraFactory});
  final Future<File?> Function() pickGallery;
  final bool Function() sessionValid;
  final ScannerCamera Function()? cameraFactory;
  @override
  State<FoodCameraPage> createState() => _FoodCameraPageState();
}

class _FoodCameraPageState extends State<FoodCameraPage>
    with WidgetsBindingObserver {
  ScannerCamera? _camera;
  bool _loading = true, _capturing = false, _picking = false, _leaving = false;
  int _generation = 0;
  String? _error, _sourceError;
  Future<void> _closing = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _release() {
    _generation++;
    final camera = _camera;
    _camera = null;
    final previous = _closing;
    _closing = () async {
      try {
        await previous;
        await camera?.close();
      } catch (_) {/* No raw native diagnostics. */}
    }();
    return _closing;
  }

  Future<void> _open() async {
    final closing = _release();
    final generation = _generation;
    await closing;
    if (!mounted ||
        _leaving ||
        _picking ||
        generation != _generation ||
        !widget.sessionValid()) {
      return;
    }
    final camera = (widget.cameraFactory ?? DeviceScannerCamera.new)();
    _camera = camera;
    setState(() {
      _loading = true;
      _capturing = false;
      _error = null;
    });
    try {
      await camera.initialize();
      if (!mounted ||
          generation != _generation ||
          _leaving ||
          !widget.sessionValid()) {
        return;
      }
      setState(() => _loading = false);
    } catch (failure) {
      if (!mounted || generation != _generation || _leaving) return;
      setState(() {
        _loading = false;
        _error = failure is CameraException &&
                failure.code.startsWith('CameraAccess')
            ? 'Camera access is unavailable. Allow camera access in your phone settings, or choose a gallery photo.'
            : 'The camera couldn’t be opened. Retry or choose a gallery photo.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive && (_camera?.ready ?? false)) {
      unawaited(_release());
      if (mounted) {
        setState(() {
          _loading = true;
          _capturing = false;
        });
      }
    } else if (state == AppLifecycleState.resumed &&
        _camera == null &&
        !_picking &&
        !_leaving) {
      unawaited(_open());
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_capturing ||
        _loading ||
        _picking ||
        camera == null ||
        !camera.ready ||
        !widget.sessionValid()) {
      return;
    }
    final generation = _generation;
    setState(() => _capturing = true);
    try {
      final file = await camera.capture();
      if (!mounted ||
          _leaving ||
          generation != _generation ||
          !widget.sessionValid()) {
        return;
      }
      _leaving = true;
      await _release();
      if (mounted) Navigator.of(context).pop(file);
    } catch (_) {
      if (mounted && !_leaving && generation == _generation) {
        setState(() {
          _capturing = false;
          _error =
              'The photo couldn’t be captured. Retry or choose a gallery photo.';
        });
      }
    }
  }

  Future<void> _gallery() async {
    if (_picking || _capturing || _leaving || !widget.sessionValid()) return;
    setState(() {
      _picking = true;
      _sourceError = null;
    });
    await _release();
    try {
      final file = await widget.pickGallery();
      if (!mounted || _leaving || !widget.sessionValid()) return;
      if (file != null) {
        _leaving = true;
        Navigator.of(context).pop(file);
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _sourceError = 'The gallery couldn’t be opened. Please try again.');
      }
    } finally {
      _picking = false;
      if (mounted && !_leaving && widget.sessionValid()) unawaited(_open());
    }
  }

  Future<void> _switch() async {
    if (_loading || _capturing || _picking || !(_camera?.canSwitch ?? false)) {
      return;
    }
    final generation = _generation;
    setState(() => _loading = true);
    try {
      await _camera!.switchLens();
    } catch (_) {
      if (mounted && generation == _generation) {
        _error = 'Couldn’t switch cameras. Please retry.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _leaving = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppThemeScope(
      child: Builder(
          builder: (context) => PopScope(
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) {
                  _leaving = true;
                  unawaited(_release());
                }
              },
              child: Scaffold(
                  appBar: AppBar(title: const Text('Food Scanner')),
                  body: SafeArea(
                      top: false,
                      child: LayoutBuilder(builder: (context, constraints) {
                        final height =
                            (constraints.maxHeight - 270).clamp(220.0, 560.0);
                        return SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.page),
                            child: Center(
                                child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: AppLayout.formWidth),
                                    child: Column(children: [
                                      Text('Scan your food',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: AppSpacing.xs),
                                      const Text(
                                          'Keep the full portion in view.',
                                          textAlign: TextAlign.center),
                                      const SizedBox(height: AppSpacing.lg),
                                      SizedBox(
                                          height: height,
                                          child: _preview(context)),
                                      const SizedBox(height: AppSpacing.lg),
                                      _controls(context),
                                      if (_sourceError != null)
                                        ScannerFeedback(_sourceError!),
                                      const SizedBox(height: AppSpacing.md),
                                      const Text(
                                          'Review your photo before sending it for analysis.',
                                          textAlign: TextAlign.center),
                                    ]))));
                      }))))));

  Widget _preview(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Stack(fit: StackFit.expand, children: [
            if (!_loading && _error == null && (_camera?.ready ?? false))
              ClipRect(
                  child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                          width: 1000 *
                              (MediaQuery.orientationOf(context) ==
                                      Orientation.portrait
                                  ? 1 / _camera!.aspectRatio
                                  : _camera!.aspectRatio),
                          height: 1000,
                          child: _camera!.preview()))),
            const Padding(
                padding: EdgeInsets.all(24),
                child: IgnorePointer(child: ScannerFrame())),
            if (_loading)
              const Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Opening camera')),
            if (_error != null && !_loading)
              Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ScannerFeedback(_error!, onRetry: _open))),
          ])));

  Widget _controls(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton.filledTonal(
            tooltip: 'Choose from gallery',
            onPressed: _picking || _capturing ? null : _gallery,
            iconSize: 28,
            padding: const EdgeInsets.all(14),
            icon: const Icon(Icons.photo_library_outlined)),
        SizedBox.square(
            dimension: 76,
            child: FilledButton(
                key: const Key('scanner-shutter'),
                style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(9)),
                onPressed: _loading || _capturing || _picking || _error != null
                    ? null
                    : _capture,
                child: _capturing
                    ? const CircularProgressIndicator(
                        semanticsLabel: 'Taking photo')
                    : Semantics(
                        label: 'Take photo',
                        child: const Icon(Icons.circle, size: 52)))),
        if (_camera?.canSwitch ?? false)
          IconButton.filledTonal(
              tooltip: 'Switch camera',
              onPressed: _loading || _capturing || _picking ? null : _switch,
              iconSize: 28,
              padding: const EdgeInsets.all(14),
              icon: const Icon(Icons.cameraswitch_outlined))
        else
          const SizedBox(width: 56),
      ]);
}
