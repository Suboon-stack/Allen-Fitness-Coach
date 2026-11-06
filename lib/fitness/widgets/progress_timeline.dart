import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/progress_tracking_data.dart';
import '../models/progress_model.dart';
import '../theme/app_theme.dart';

class ProgressTimeline extends StatefulWidget {
  const ProgressTimeline(
      {super.key,
      required this.events,
      required this.now,
      required this.onEdit});
  final List<ProgressEvent> events;
  final DateTime now;
  final ValueChanged<WeightEntry>? onEdit;
  @override
  State<ProgressTimeline> createState() => _ProgressTimelineState();
}

class _ProgressTimelineState extends State<ProgressTimeline> {
  int _visible = 40;
  List<ProgressEvent> get events => widget.events;
  DateTime get now => widget.now;
  ValueChanged<WeightEntry>? get onEdit => widget.onEdit;
  @override
  void didUpdateWidget(ProgressTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events.length != events.length ||
        (events.isNotEmpty &&
            oldWidget.events.isNotEmpty &&
            oldWidget.events.first.id != events.first.id)) {
      _visible = 40;
    }
  }

  String _day(DateTime value) {
    final day = DateTime(value.year, value.month, value.day),
        today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday';
    }
    return DateFormat('d MMM y').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
              'No recorded activity in this period. Your next check-in will appear here.'));
    }
    return Column(children: [
      for (var i = 0; i < events.length && i < _visible; i++)
        _event(context, events[i], i < events.length - 1, theme),
      if (events.length > _visible)
        TextButton(
            onPressed: () => setState(() => _visible += 40),
            child: Text(
                'Show more activity (${events.length - _visible} remaining)')),
    ]);
  }

  Widget _event(
      BuildContext context, ProgressEvent event, bool more, ThemeData theme) {
    final icon = switch (event.kind) {
      ProgressEventKind.weight => Icons.monitor_weight_outlined,
      ProgressEventKind.workout => Icons.fitness_center,
      ProgressEventKind.meal => Icons.restaurant_outlined,
      ProgressEventKind.milestone => Icons.flag_outlined
    };
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          width: 24,
          child: Column(children: [
            const SizedBox(height: 8),
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary, shape: BoxShape.circle)),
            if (more)
              Expanded(
                  child: Container(
                      width: 1, color: theme.colorScheme.outlineVariant)),
          ])),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_day(event.date),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(height: 6),
                    Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadii.panel)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                  padding:
                                      const EdgeInsets.only(top: 2, right: 12),
                                  child: Icon(icon,
                                      color: theme.colorScheme.secondary,
                                      size: 22)),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(event.title,
                                        style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(event.detail),
                                    if (event.estimated)
                                      Text('AI Estimate · reviewed',
                                          style: theme.textTheme.bodySmall),
                                    if (event.weight?.notes?.isNotEmpty ??
                                        false)
                                      Text(event.weight!.notes!,
                                          style: theme.textTheme.bodySmall),
                                    if (event.weight != null &&
                                        event.weight!.id.isNotEmpty)
                                      TextButton(
                                          onPressed: onEdit == null
                                              ? null
                                              : () => onEdit!(event.weight!),
                                          child: const Text('Edit weight')),
                                  ])),
                            ])),
                  ]))),
    ]));
  }
}
