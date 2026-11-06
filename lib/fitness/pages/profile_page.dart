import 'package:flutter/material.dart';
import '../../features/auth/data/user_repository.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../models/user_profile_model.dart';
import '../models/profile_overview_data.dart';
import '../repositories/progress_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/feature_navigation.dart';
import '../widgets/profile_components.dart';
import '../widgets/profile_edit_sheet.dart';
import 'settings_page.dart';
import 'account_security_page.dart';
import 'data_privacy_page.dart';
import 'about_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.repository, this.progressRepository});
  final UserRepository? repository;
  final ProgressRepository? progressRepository;
  @override
  Widget build(BuildContext context) => AccountBoundary(
      builder: (context, user) => _ProfileOverview(
          user: user,
          repository: repository ?? UserRepository(),
          progress: progressRepository ?? ProgressRepository()));
}

class _ProfileOverview extends StatefulWidget {
  const _ProfileOverview(
      {required this.user, required this.repository, required this.progress});
  final AppUser user;
  final UserRepository repository;
  final ProgressRepository progress;
  @override
  State<_ProfileOverview> createState() => _ProfileOverviewState();
}

class _ProfileOverviewState extends State<_ProfileOverview>
    with WidgetsBindingObserver {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  int _request = 0;
  int? _count, _streak;
  double? _weight;
  bool _valid(int request) =>
      mounted &&
      request == _request &&
      verifiedAccount(context)?.uid == widget.user.uid;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant _ProfileOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loading && verifiedAccount(context)?.uid == widget.user.uid) _load();
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _profile = null;
        _count = null;
        _streak = null;
        _weight = null;
      });
    }
    try {
      final (profile, workouts, weights) = await (
        widget.repository.getUserProfile(widget.user.uid),
        widget.progress.getCompletedWorkouts(widget.user.uid),
        widget.progress.getWeightEntries(widget.user.uid, limit: 0x7fffffff)
      ).wait;
      if (!_valid(request)) return;
      setState(() {
        _profile = profile;
        _count = workouts.length;
        _streak = ownedWorkoutStreak(workouts, DateTime.now());
        final dated =
            weights.where((entry) => !entry.date.isAfter(DateTime.now()));
        _weight = dated.isEmpty ? null : dated.first.weight;
        _loading = false;
      });
    } catch (_) {
      if (_valid(request)) {
        setState(() {
          _loading = false;
          _error =
              'Your profile couldn’t be loaded. Retry to view or edit your saved details.';
        });
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted && verifiedAccount(context)?.uid == widget.user.uid) _load();
  }

  Future<void> _edit() async {
    if (_loading || _error != null) return;
    await Navigator.of(context).push(MaterialPageRoute<bool>(
        builder: (_) => ProfileEditor(
            user: widget.user,
            repository: widget.repository,
            profile: _profile)));
    if (mounted && verifiedAccount(context)?.uid == widget.user.uid) _load();
  }

  @override
  Widget build(BuildContext context) =>
      AppThemeScope(child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final name = (_profile?.name?.trim().isNotEmpty ?? false)
            ? _profile!.name!.trim()
            : (widget.user.displayName?.trim().isNotEmpty ?? false)
                ? widget.user.displayName!.trim()
                : 'Your profile';
        final initials = name == 'Your profile'
            ? 'A'
            : name
                .split(RegExp(r'\s+'))
                .take(2)
                .map((s) => String.fromCharCode(s.runes.first))
                .join()
                .toUpperCase();
        return Scaffold(
            appBar: AppBar(title: const Text('Profile'), actions: [
              IconButton(
                  tooltip: 'App settings',
                  onPressed: () => _open(const SettingsPage()),
                  icon: const Icon(Icons.settings_outlined))
            ]),
            bottomNavigationBar: FeatureNavigation(index: 4, onReturn: _load),
            body: SafeArea(
                top: false,
                bottom: false,
                child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Center(
                              child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: AppLayout.contentWidth),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const SizedBox(height: 4),
                                        Center(
                                            child: Semantics(
                                                label: 'Profile initials',
                                                child: CircleAvatar(
                                                    radius: 44,
                                                    backgroundColor: theme
                                                        .colorScheme
                                                        .secondaryContainer,
                                                    foregroundColor: theme
                                                        .colorScheme.secondary,
                                                    child: Text(initials,
                                                        style: theme.textTheme
                                                            .headlineMedium)))),
                                        const SizedBox(height: 14),
                                        Text(name,
                                            textAlign: TextAlign.center,
                                            style:
                                                theme.textTheme.headlineSmall),
                                        const SizedBox(height: 4),
                                        Text(widget.user.email,
                                            textAlign: TextAlign.center),
                                        Center(
                                            child: TextButton(
                                                onPressed:
                                                    _loading || _error != null
                                                        ? null
                                                        : _edit,
                                                child: const Text(
                                                    'Edit personal details'))),
                                        if (_loading)
                                          const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 16),
                                              child: LinearProgressIndicator(
                                                  semanticsLabel:
                                                      'Loading profile')),
                                        if (_error != null)
                                          ProfileFeedback(_error!,
                                              retry: _load),
                                        LayoutBuilder(builder: (context, box) {
                                          final cards = [
                                            _stat(
                                                context,
                                                Icons.fitness_center,
                                                _count?.toString() ?? '—',
                                                'Workouts',
                                                'Recorded completions'),
                                            _stat(
                                                context,
                                                Icons.monitor_weight_outlined,
                                                _weight?.toStringAsFixed(1) ??
                                                    '—',
                                                'Weight (kg)',
                                                'Latest check-in · kg'),
                                            _stat(
                                                context,
                                                Icons.calendar_today_outlined,
                                                _streak?.toString() ?? '—',
                                                'Day streak',
                                                'Recorded workout dates')
                                          ];
                                          final width = box.maxWidth;
                                          return Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                for (final card in cards)
                                                  SizedBox(
                                                      width: width < 330 ||
                                                              MediaQuery.textScalerOf(
                                                                          context)
                                                                      .scale(
                                                                          16) >
                                                                  24
                                                          ? width
                                                          : (width - 16) / 3,
                                                      child: card)
                                              ]);
                                        }),
                                        const SizedBox(height: 16),
                                        ProfileGroup(children: [
                                          ProfileRow(
                                              icon: Icons.flag_outlined,
                                              title: _profile?.goal == null
                                                  ? 'Your fitness goal'
                                                  : 'My goal',
                                              subtitle: _profile?.goal ??
                                                  'Add a goal in personal details',
                                              onTap: _loading || _error != null
                                                  ? null
                                                  : _edit)
                                        ]),
                                        const SizedBox(height: 16),
                                        ProfileGroup(children: [
                                          ProfileRow(
                                              icon: Icons.person_outline,
                                              title: 'Account & Security',
                                              onTap: () => _open(
                                                  const AccountSecurityPage())),
                                          ProfileRow(
                                              icon: Icons.tune,
                                              title: 'App Settings',
                                              onTap: () =>
                                                  _open(const SettingsPage())),
                                          ProfileRow(
                                              icon: Icons.privacy_tip_outlined,
                                              title: 'Data & Privacy',
                                              onTap: () => _open(
                                                  DataPrivacyPage(
                                                      repository:
                                                          widget.repository))),
                                          ProfileRow(
                                              icon: Icons.info_outline,
                                              title: 'About Allen',
                                              onTap: () =>
                                                  _open(const AboutPage())),
                                        ]),
                                        if (_profile != null) ...[
                                          const ProfileSection(
                                              'Personal details'),
                                          ProfileGroup(children: [
                                            if (_profile!.age != null)
                                              ProfileRow(
                                                  icon: Icons.person_outline,
                                                  title: 'Age',
                                                  value:
                                                      '${_profile!.age} years'),
                                            if (_profile!.height != null)
                                              ProfileRow(
                                                  icon: Icons.height,
                                                  title: 'Height',
                                                  value:
                                                      '${_profile!.height} cm'),
                                            if (_profile!.weight != null)
                                              ProfileRow(
                                                  icon: Icons
                                                      .monitor_weight_outlined,
                                                  title: 'Profile weight',
                                                  value:
                                                      '${_profile!.weight} kg'),
                                            if (_profile!.gender != null)
                                              ProfileRow(
                                                  icon: Icons.person_outline,
                                                  title: 'Gender',
                                                  value: _profile!.gender),
                                            if (_profile!.bmi != null)
                                              ProfileRow(
                                                  icon: Icons.straighten,
                                                  title: 'BMI',
                                                  subtitle:
                                                      'Based on profile height and weight; a general screening measure, not a diagnosis.',
                                                  value:
                                                      '${_profile!.bmi!.toStringAsFixed(1)} · ${_profile!.bmiCategory}'),
                                            ProfileRow(
                                                icon: Icons.edit_outlined,
                                                title:
                                                    'Edit details & nutrition targets',
                                                onTap: _edit),
                                          ])
                                        ],
                                        if (_profile != null &&
                                            [
                                              _profile!.targetCalories,
                                              _profile!.targetProtein,
                                              _profile!.targetCarbs,
                                              _profile!.targetFat
                                            ].any((v) => v != null)) ...[
                                          const ProfileSection(
                                              'Daily nutrition targets'),
                                          ProfileGroup(children: [
                                            if (_profile!.targetCalories !=
                                                null)
                                              ProfileRow(
                                                  icon:
                                                      Icons.restaurant_outlined,
                                                  title: 'Calories',
                                                  value:
                                                      '${_profile!.targetCalories} kcal'),
                                            if (_profile!.targetProtein != null)
                                              ProfileRow(
                                                  icon:
                                                      Icons.restaurant_outlined,
                                                  title: 'Protein',
                                                  value:
                                                      '${_profile!.targetProtein} g'),
                                            if (_profile!.targetCarbs != null)
                                              ProfileRow(
                                                  icon:
                                                      Icons.restaurant_outlined,
                                                  title: 'Carbs',
                                                  value:
                                                      '${_profile!.targetCarbs} g'),
                                            if (_profile!.targetFat != null)
                                              ProfileRow(
                                                  icon:
                                                      Icons.restaurant_outlined,
                                                  title: 'Fat',
                                                  value:
                                                      '${_profile!.targetFat} g'),
                                          ]),
                                        ],
                                        const SizedBox(height: 16),
                                      ])))
                        ]))));
      }));
  Widget _stat(BuildContext context, IconData icon, String value, String label,
          String hint) =>
      Semantics(
          label: '$label: $value. $hint',
          excludeSemantics: true,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Icon(icon,
                    color: Theme.of(context).colorScheme.secondary, size: 23),
                const SizedBox(height: 8),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ])));
}
