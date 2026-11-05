import 'dart:io';
import 'dart:math' as math;
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/food_scanner_controller.dart';
import '../models/food_estimate.dart';
import '../repositories/meal_repository.dart';
import '../services/ai_service.dart';
import '../services/scanner_camera.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_widgets.dart' show AllenSparkle;
import '../widgets/food_estimate_editor.dart';
import '../widgets/scanner_widgets.dart';
import 'food_camera_page.dart';
import 'meal_planner_page.dart';

class CalorieScannerPage extends StatefulWidget {
  const CalorieScannerPage(
      {super.key,
      this.aiService,
      this.repository,
      this.pickGallery,
      this.cameraFactory});
  final AiService? aiService;
  final MealRepository? repository;
  final Future<File?> Function()? pickGallery;
  final ScannerCamera Function()? cameraFactory;
  @override
  State<CalorieScannerPage> createState() => _CalorieScannerPageState();
}

class _CalorieScannerPageState extends State<CalorieScannerPage> {
  late final FoodScannerController _scan;
  bool _choosing = false, _editing = false, _leaving = false;
  int _selection = 0;
  String? _pickerError;
  String _mealTime = 'Lunch';
  String? _verifiedUser() {
    final auth = context.read<AuthCubit>();
    if (auth.state is AuthLoading ||
        auth.state is AuthError &&
            (auth.state as AuthError).sessionUnresolved) {
      return null;
    }
    return auth.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    _scan = FoodScannerController(
        service: widget.aiService ?? AiService(),
        repository: widget.repository ?? MealRepository(),
        currentUser: _verifiedUser)
      ..addListener(_changed);
  }

  void _changed() {
    if (mounted && !_leaving) setState(() {});
  }

  void _accountChanged() {
    if (_scan.userId == _verifiedUser()) return;
    _selection++;
    _pickerError = null;
    _scan.syncUser();
  }

  Future<File?> _galleryFile() async {
    if (widget.pickGallery != null) return widget.pickGallery!();
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
        requestFullMetadata: false);
    return file == null ? null : File(file.path);
  }

  Future<void> _choose(BuildContext context, {required bool camera}) async {
    _accountChanged();
    if (_choosing || _editing || _scan.busy || !_scan.active || _leaving) {
      return;
    }
    final owner = _scan.userId, selection = ++_selection;
    bool valid() =>
        mounted &&
        !_leaving &&
        _scan.active &&
        owner == _verifiedUser() &&
        selection == _selection;
    setState(() {
      _choosing = true;
      _pickerError = null;
    });
    try {
      final file = camera
          ? await Navigator.of(context).push<File>(MaterialPageRoute(
              builder: (routeContext) => BlocListener<AuthCubit, AuthState>(
                  listener: (_, __) {
                    if (!valid() &&
                        ModalRoute.of(routeContext)?.isCurrent == true) {
                      Navigator.of(routeContext).pop();
                    }
                  },
                  child: FoodCameraPage(
                      pickGallery: _galleryFile,
                      sessionValid: valid,
                      cameraFactory: widget.cameraFactory))))
          : await _galleryFile();
      if (valid() && file != null) _scan.select(file);
    } catch (_) {
      if (valid()) {
        setState(() => _pickerError =
            'The photo couldn’t be opened. Check photo access or choose another image.');
      }
    } finally {
      if (mounted && !_leaving) setState(() => _choosing = false);
    }
  }

  Future<void> _edit(BuildContext context) async {
    if (_editing || _scan.busy || !_scan.active || _scan.saved) return;
    final estimate = _scan.estimate;
    if (estimate == null) return;
    final selection = _selection, owner = _scan.userId;
    setState(() => _editing = true);
    final value = await showModalBottomSheet<FoodEstimate>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => BlocListener<AuthCubit, AuthState>(
            listener: (_, __) {
              if (_verifiedUser() != owner &&
                  ModalRoute.of(sheetContext)?.isCurrent == true) {
                Navigator.of(sheetContext).pop();
              }
            },
            child: FoodEstimateEditor(estimate: estimate)));
    if (!mounted || _leaving) return;
    setState(() => _editing = false);
    if (selection == _selection && owner == _verifiedUser() && value != null) {
      _scan.edit(value);
    }
  }

  @override
  void dispose() {
    _leaving = true;
    _selection++;
    _scan.removeListener(_changed);
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
      listener: (_, __) => _accountChanged(),
      child: AppThemeScope(child: Builder(builder: (context) {
        final image = _scan.image, result = _scan.estimate;
        return PopScope(
            canPop: !_scan.saving && image == null,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                _leaving = true;
                _selection++;
                _scan.abandon();
              } else if (!_scan.saving && !_editing && !_choosing) {
                _scan.clear();
              }
            },
            child: Scaffold(
              appBar: AppBar(
                  toolbarHeight: image == null
                      ? math.max(72,
                          MediaQuery.textScalerOf(context).scale(20) * 3 + 12)
                      : kToolbarHeight,
                  leading: IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      icon: const BackButtonIcon(),
                      onPressed: _scan.saving
                          ? null
                          : () {
                              if (image != null) {
                                _scan.clear();
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            }),
                  title: image == null
                      ? Row(children: [
                          const AllenSparkle(),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Allen',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text('Food Scanner',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ]))
                        ])
                      : Text(result == null ? 'Review photo' : 'Scan Result')),
              body: SafeArea(
                  top: false,
                  child:
                      image == null ? _dashboard(context) : _review(context)),
            ));
      })));

  Widget _dashboard(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 40)),
              child: Center(
                  child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: AppLayout.formWidth),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.lg),
                            Center(
                                child: SizedBox.square(
                                    dimension: 120,
                                    child: ScannerFrame(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        child: Icon(Icons.camera_alt_outlined,
                                            size: 64,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary)))),
                            const SizedBox(height: AppSpacing.xl),
                            Text('Scan Your Food',
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                                'Take a photo or choose from your gallery to get an AI nutrition estimate.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.xl),
                            FilledButton.icon(
                                key: const Key('scanner-camera'),
                                onPressed: _choosing || !_scan.active
                                    ? null
                                    : () => _choose(context, camera: true),
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: Text(_choosing
                                    ? 'Opening photo source…'
                                    : 'Take Photo')),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                                key: const Key('scanner-gallery'),
                                onPressed: _choosing || !_scan.active
                                    ? null
                                    : () => _choose(context, camera: false),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Choose from Gallery')),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                                'You review the photo before it is sent to Gemini.',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center),
                            if (!_scan.active)
                              const ScannerFeedback(
                                  'Sign in to analyze and save food photos.'),
                            if (_pickerError != null)
                              ScannerFeedback(_pickerError!),
                            const SizedBox(height: AppSpacing.lg),
                          ]))))));

  Widget _review(BuildContext context) {
    final result = _scan.estimate;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Center(
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppLayout.contentWidth),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result == null) ...[
                        AspectRatio(
                            aspectRatio: 1,
                            child: ScannerPhoto(
                                file: _scan.image!, fit: BoxFit.contain)),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Ready to analyze?',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                            'Analyze sends this photo to Google Gemini for a nutrition estimate. It won’t be saved to Nutrition until you confirm.'),
                        if (_scan.analyzing) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const LinearProgressIndicator(
                              semanticsLabel: 'Analyzing food photo'),
                          const SizedBox(height: AppSpacing.sm),
                          Semantics(
                              liveRegion: true,
                              child: const Text(
                                  'Estimating your food’s nutrition…')),
                        ],
                        if (_scan.error != null) ScannerFeedback(_scan.error!),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                            key: const Key('scanner-analyze'),
                            onPressed: _scan.busy ? null : _scan.analyze,
                            child: Text(_scan.analyzing
                                ? 'Analyzing…'
                                : _scan.error == null
                                    ? 'Analyze photo'
                                    : 'Retry analysis')),
                        TextButton(
                            onPressed: _scan.busy ? null : _scan.clear,
                            child: const Text('Choose another photo')),
                      ] else ...[
                        _foodHeader(context, result),
                        const SizedBox(height: AppSpacing.lg),
                        _nutrition(context, result),
                        if (result.items.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                              padding: const EdgeInsets.all(AppSpacing.page),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.panel)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Identified items',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: AppSpacing.sm),
                                    for (final item in result.items)
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Text(
                                              '• ${item.name}${item.portion == null ? '' : ' (≈ ${item.portion})'}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge)),
                                  ])),
                        ],
                        if (result.tip != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text('AI note',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(result.tip!),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        if (_scan.saved) ...[
                          Semantics(
                              liveRegion: true,
                              child: const Text(
                                  'Saved to Nutrition as a reviewed AI estimate.')),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => MealPlannerPage(
                                          repository: _scan.repository))),
                              child: const Text('View Nutrition')),
                          TextButton(
                              onPressed: _scan.clear,
                              child: const Text('Scan another meal')),
                        ] else ...[
                          DropdownButtonFormField<String>(
                              key: const Key('scan-meal-type'),
                              initialValue: _mealTime,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Save as'),
                              items: [
                                for (final time in [
                                  'Breakfast',
                                  'Lunch',
                                  'Dinner',
                                  'Snack'
                                ])
                                  DropdownMenuItem(
                                      value: time, child: Text(time))
                              ],
                              onChanged: _scan.saving
                                  ? null
                                  : (v) {
                                      if (v != null) {
                                        setState(() => _mealTime = v);
                                      }
                                    }),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                              'Save confirms this reviewed estimate as a meal eaten today.'),
                          if (_scan.error != null)
                            ScannerFeedback(_scan.error!),
                          const SizedBox(height: AppSpacing.md),
                          LayoutBuilder(builder: (context, constraints) {
                            final edit = OutlinedButton(
                                key: const Key('scan-edit'),
                                onPressed: _scan.saving || _editing
                                    ? null
                                    : () => _edit(context),
                                child: const Text('Edit'));
                            final save = FilledButton(
                                key: const Key('scan-save'),
                                onPressed: _scan.saving || _editing
                                    ? null
                                    : () => _scan.save(mealTime: _mealTime),
                                child: Text(_scan.saving
                                    ? 'Saving…'
                                    : _scan.error == null
                                        ? 'Save to Nutrition'
                                        : 'Retry save'));
                            return MediaQuery.textScalerOf(context).scale(14) >
                                        21 ||
                                    constraints.maxWidth < 340
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                        edit,
                                        const SizedBox(height: 8),
                                        save
                                      ])
                                : Row(children: [
                                    Expanded(child: edit),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 2, child: save)
                                  ]);
                          }),
                          if (_scan.saving)
                            const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: LinearProgressIndicator(
                                    semanticsLabel: 'Saving reviewed meal')),
                        ],
                      ],
                    ]))));
  }

  Widget _foodHeader(BuildContext context, FoodEstimate result) {
    final description =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(result.name, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.sm),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.control)),
          child: Text('AI Estimate',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600))),
      const SizedBox(height: AppSpacing.sm),
      const Text('Identified from your photo. Nutrition values are estimates.'),
      if (result.portion != null) Text('Portion: ≈ ${result.portion}'),
    ]);
    return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(14) > 21
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(height: 180, child: ScannerPhoto(file: _scan.image!)),
                const SizedBox(height: 16),
                description
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox.square(
                    dimension: constraints.maxWidth * .4,
                    child: ScannerPhoto(file: _scan.image!)),
                const SizedBox(width: 16),
                Expanded(child: description)
              ]));
  }

  Widget _nutrition(BuildContext context, FoodEstimate result) => Container(
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.panel)),
      child: Column(children: [
        Text('≈ ${scanNumber(result.calories)} kcal',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        const Text('Estimated calories'),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
        LayoutBuilder(builder: (context, constraints) {
          final count = MediaQuery.textScalerOf(context).scale(14) > 21 ? 1 : 3;
          return Wrap(runSpacing: 16, children: [
            for (final macro in [
              ('Protein', result.protein),
              ('Carbs', result.carbs),
              ('Fat', result.fat)
            ])
              SizedBox(
                  width: constraints.maxWidth / count,
                  child: Column(children: [
                    Text('${scanNumber(macro.$2)} g',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(macro.$1),
                  ]))
          ]);
        }),
      ]));
}
