import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/data/user_repository.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/cubits/auth_cubit.dart';
import '../../features/auth/presentation/cubits/auth_state.dart';
import '../models/user_profile_model.dart';
import '../theme/app_theme.dart';
import 'profile_components.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor(
      {super.key, required this.user, required this.repository, this.profile});
  final AppUser user;
  final UserRepository repository;
  final UserProfile? profile;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _fields = <String, TextEditingController>{
    'Name': TextEditingController(
        text: widget.profile?.name ?? widget.user.displayName ?? ''),
    'Age': TextEditingController(text: widget.profile?.age?.toString() ?? ''),
    'Height (cm)':
        TextEditingController(text: widget.profile?.height?.toString() ?? ''),
    'Profile weight (kg)':
        TextEditingController(text: widget.profile?.weight?.toString() ?? ''),
    'Calories (kcal/day)': TextEditingController(
        text: widget.profile?.targetCalories?.toString() ?? ''),
    'Protein (g/day)': TextEditingController(
        text: widget.profile?.targetProtein?.toString() ?? ''),
    'Carbs (g/day)': TextEditingController(
        text: widget.profile?.targetCarbs?.toString() ?? ''),
    'Fat (g/day)': TextEditingController(
        text: widget.profile?.targetFat?.toString() ?? ''),
  };
  late String? _gender = widget.profile?.gender, _goal = widget.profile?.goal;
  bool _saving = false, _closing = false;
  String? _error;
  bool get _owns =>
      mounted && !_closing && verifiedAccount(context)?.uid == widget.user.uid;
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_owns) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      await Scrollable.ensureVisible(invalid.first.context, alignment: .15);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String? text(String k) {
      final s = _fields[k]!.text.trim();
      return s.isEmpty ? null : s;
    }

    double? number(String k) => double.tryParse(text(k) ?? '');
    final now = DateTime.now();
    final p = UserProfile(
        id: widget.user.uid,
        email: widget.user.email,
        name: text('Name'),
        age: int.tryParse(text('Age') ?? ''),
        height: number('Height (cm)'),
        weight: number('Profile weight (kg)'),
        gender: _gender,
        goal: _goal,
        targetCalories: int.tryParse(text('Calories (kcal/day)') ?? ''),
        targetProtein: number('Protein (g/day)'),
        targetCarbs: number('Carbs (g/day)'),
        targetFat: number('Fat (g/day)'),
        createdAt: widget.profile?.createdAt ?? now,
        updatedAt: now);
    try {
      await widget.repository.updateUserProfile(p);
      if (mounted && _owns) {
        _closing = true;
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (_owns) {
        setState(() => _error =
            'Your profile couldn’t be saved. Check your connection to this device’s storage and retry.');
      }
    } finally {
      if (_owns) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
      listener: (_, __) {
        if (!_owns && !_closing) {
          _closing = true;
          Navigator.of(context).pop();
        }
      },
      child: AppThemeScope(
          child: Builder(
              builder: (context) => PopScope(
                  canPop: !_saving,
                  child: Scaffold(
                    appBar: AppBar(title: const Text('Personal details')),
                    body: SafeArea(
                        child: Form(
                            key: _form,
                            child: ListView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Center(
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: AppLayout.formWidth),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const Text(
                                                    'Add what you want to share. Optional fields can be left blank.'),
                                                const SizedBox(height: 20),
                                                for (final entry
                                                    in _fields.entries) ...[
                                                  if (entry.key ==
                                                      'Calories (kcal/day)') ...[
                                                    _dropdown(
                                                        'Gender',
                                                        _gender,
                                                        [
                                                          'Male',
                                                          'Female',
                                                          'Other'
                                                        ],
                                                        (v) => setState(
                                                            () => _gender = v)),
                                                    _dropdown(
                                                        'Fitness goal',
                                                        _goal,
                                                        [
                                                          'Lose Weight',
                                                          'Maintain Weight',
                                                          'Gain Muscle'
                                                        ],
                                                        (v) => setState(
                                                            () => _goal = v)),
                                                    const Text(
                                                        'Daily nutrition targets',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                    const Text(
                                                        'Set your own targets. Allen will not guess these values.'),
                                                    const SizedBox(height: 16),
                                                  ],
                                                  TextFormField(
                                                      controller: entry.value,
                                                      onTapOutside: (_) =>
                                                          FocusManager.instance
                                                              .primaryFocus
                                                              ?.unfocus(),
                                                      enabled: !_saving,
                                                      decoration:
                                                          InputDecoration(
                                                              labelText:
                                                                  entry.key),
                                                      textCapitalization: entry
                                                                  .key ==
                                                              'Name'
                                                          ? TextCapitalization
                                                              .words
                                                          : TextCapitalization
                                                              .none,
                                                      keyboardType: entry.key ==
                                                              'Name'
                                                          ? TextInputType.name
                                                          : const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                      maxLength:
                                                          entry.key == 'Name'
                                                              ? 200
                                                              : null,
                                                      validator: (value) {
                                                        final s =
                                                            value?.trim() ?? '';
                                                        if (s.isEmpty ||
                                                            entry.key ==
                                                                'Name') {
                                                          return null;
                                                        }
                                                        final n =
                                                            double.tryParse(s);
                                                        final max = entry.key ==
                                                                'Age'
                                                            ? 130
                                                            : entry.key ==
                                                                    'Height (cm)'
                                                                ? 300
                                                                : entry.key ==
                                                                        'Profile weight (kg)'
                                                                    ? 1000
                                                                    : 100000;
                                                        if (n == null ||
                                                            !n.isFinite ||
                                                            n <= 0 ||
                                                            n > max) {
                                                          return 'Enter a value above 0 and no greater than $max.';
                                                        }
                                                        if ((entry.key ==
                                                                    'Age' ||
                                                                entry.key ==
                                                                    'Calories (kcal/day)') &&
                                                            int.tryParse(s) ==
                                                                null) {
                                                          return 'Enter a whole number.';
                                                        }
                                                        return null;
                                                      }),
                                                  if (entry.key ==
                                                      'Profile weight (kg)')
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                top: 8),
                                                        child: Text(
                                                            'Used for BMI only. Log dated check-ins in Progress.')),
                                                  const SizedBox(height: 16),
                                                ],
                                                if (_error != null)
                                                  ProfileFeedback(_error!),
                                                FilledButton(
                                                    onPressed:
                                                        _saving ? null : _save,
                                                    child: Text(_saving
                                                        ? 'Saving…'
                                                        : 'Save details')),
                                              ])))
                                ]))),
                  )))));
  Widget _dropdown(String title, String? value, List<String> options,
          ValueChanged<String?> changed) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: title),
              items: [
                const DropdownMenuItem(value: '', child: Text('Not set')),
                for (final item in options)
                  DropdownMenuItem(value: item, child: Text(item))
              ],
              onChanged: _saving ? null : (v) => changed(v == '' ? null : v)));
}
