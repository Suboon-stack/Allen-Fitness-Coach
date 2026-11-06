import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/progress_model.dart';
import '../repositories/progress_repository.dart';
import '../theme/app_theme.dart';

class WeightEntrySheet extends StatefulWidget {
  const WeightEntrySheet(
      {super.key,
      required this.repository,
      required this.userId,
      required this.currentUser,
      this.entry});
  final ProgressRepository repository;
  final String userId;
  final String? Function() currentUser;
  final WeightEntry? entry;
  @override
  State<WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends State<WeightEntrySheet> {
  final _form = GlobalKey<FormState>();
  late final _weight =
      TextEditingController(text: widget.entry?.weight.toString());
  late final _notes = TextEditingController(text: widget.entry?.notes);
  late final _id = widget.entry?.id ?? const Uuid().v4();
  late final _created = widget.entry?.createdAt ?? DateTime.now();
  late DateTime _date = widget.entry?.date ?? DateTime.now();
  bool _saving = false, _attempted = false;
  String? _error;
  bool get _owned =>
      widget.currentUser() == widget.userId &&
      (widget.entry == null ||
          widget.entry!.userId == widget.userId && widget.entry!.id.isNotEmpty);
  @override
  void dispose() {
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _datePicker() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _date.isAfter(now) ? now : _date,
        firstDate: DateTime(1900),
        lastDate: now);
    if (!mounted || date == null) return;
    setState(() => _date = DateTime(date.year, date.month, date.day, _date.hour,
        _date.minute, _date.second));
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (!_owned) {
      setState(() =>
          _error = 'Your session changed. Close this form and sign in again.');
      return;
    }
    final retry = _attempted;
    _attempted = true;
    setState(() {
      _saving = true;
      _error = null;
    });
    final entry = WeightEntry(
        id: _id,
        userId: widget.userId,
        weight: double.parse(_weight.text.trim()),
        date: _date,
        createdAt: _created,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim());
    try {
      if (widget.entry == null) {
        await widget.repository.addWeightEntry(entry);
        if (retry && mounted && _owned) {
          await widget.repository.updateWeightEntry(entry);
        }
      } else {
        await widget.repository.updateWeightEntry(entry);
      }
      if (!mounted || !_owned) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ProgressStorageException
              ? error.message
              : 'The save couldn’t be confirmed. Your values are kept. Please retry.';
        });
      }
    }
  }

  Future<void> _delete() async {
    if (_saving || !_owned || widget.entry == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete this measurement?'),
                content: const Text(
                    'Only this account’s selected weight record will be removed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'))
                ]));
    if (!mounted || confirmed != true || !_owned) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.deleteWeightEntry(_id, userId: widget.userId);
      if (mounted && _owned) {
        setState(() => _saving = false);
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Deletion couldn’t be confirmed. Refresh your history and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: AppLayout.formWidth),
                          child: Form(
                              key: _form,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        widget.entry == null
                                            ? 'Log weight'
                                            : 'Edit measurement',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    const SizedBox(height: 8),
                                    const Text(
                                        'A check-in, not a judgment. Record the value and measurement date.'),
                                    const SizedBox(height: 24),
                                    TextFormField(
                                        key: const Key('weight-value'),
                                        controller: _weight,
                                        enabled: !_saving,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                            labelText: 'Weight',
                                            suffixText: 'kg'),
                                        validator: (text) {
                                          final value = double.tryParse(
                                              text?.trim() ?? '');
                                          return value == null ||
                                                  !value.isFinite ||
                                                  value <= 0 ||
                                                  value > 1000
                                              ? 'Enter a weight above 0 and up to 1,000 kg.'
                                              : null;
                                        }),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                        key: const Key('weight-date'),
                                        onPressed: _saving ? null : _datePicker,
                                        icon: const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 20),
                                        label: Text(DateFormat('d MMM y')
                                            .format(_date))),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        key: const Key('weight-notes'),
                                        controller: _notes,
                                        enabled: !_saving,
                                        maxLength: 500,
                                        minLines: 1,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                            labelText: 'Notes (optional)'),
                                        textInputAction: TextInputAction.done),
                                    if (_error != null)
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Semantics(
                                              liveRegion: true,
                                              child: Text(_error!,
                                                  style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error)))),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                        key: const Key('weight-save'),
                                        onPressed: _saving ? null : _save,
                                        child: Text(_saving
                                            ? 'Saving…'
                                            : widget.entry == null
                                                ? 'Save weight'
                                                : 'Save changes')),
                                    TextButton(
                                        onPressed: _saving
                                            ? null
                                            : () =>
                                                Navigator.pop(context, false),
                                        child: const Text('Cancel')),
                                    if (widget.entry != null)
                                      TextButton(
                                          key: const Key('weight-delete'),
                                          onPressed: _saving ? null : _delete,
                                          child:
                                              const Text('Delete measurement')),
                                  ]))))))));
}
