import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/progress_model.dart';
import '../models/progress_tracking_data.dart';
import '../theme/app_theme.dart';

class ProgressChart extends StatefulWidget {
  const ProgressChart(
      {super.key,
      required this.entries,
      required this.period,
      required this.now,
      required this.onPeriod,
      required this.onLog,
      required this.onEdit,
      required this.onDetails,
      this.unavailable = false});
  final List<WeightEntry> entries;
  final ProgressPeriod period;
  final DateTime now;
  final ValueChanged<ProgressPeriod> onPeriod;
  final VoidCallback? onLog;
  final ValueChanged<WeightEntry>? onEdit;
  final VoidCallback onDetails;
  final bool unavailable;
  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart> {
  int? _selected;
  @override
  void didUpdateWidget(ProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period ||
        !identical(oldWidget.entries, widget.entries)) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), entries = widget.entries;
    final selected = entries.isEmpty
        ? null
        : entries[
            (_selected ?? entries.length - 1).clamp(0, entries.length - 1)];
    return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(color: theme.colorScheme.outlineVariant)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Weight Progress', style: theme.textTheme.titleLarge),
                TextButton(
                    onPressed: widget.onDetails,
                    child: const Text('See details')),
              ]),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final period in ProgressPeriod.values)
              ChoiceChip(
                  key: ValueKey('progress-period-${period.label}'),
                  label: Text(period.label),
                  selected: period == widget.period,
                  onSelected: (_) => widget.onPeriod(period))
          ]),
          const SizedBox(height: AppSpacing.md),
          if (widget.unavailable)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Weight history is unavailable. Retry to load it.'))
          else if (entries.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  const Text('No weight measurements in this period.'),
                  const SizedBox(height: 8),
                  const Text('Log a check-in to start your chart.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                      'Unowned legacy records stay on this device and are excluded from personal history.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: widget.onLog, child: const Text('Log weight')),
                ]))
          else ...[
            Semantics(
                liveRegion: true,
                child: Text(
                    '${selected!.weight.toStringAsFixed(1)} kg · ${DateFormat('d MMM y, HH:mm').format(selected.date)}',
                    key: const Key('progress-selected-weight'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.secondary))),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
                height:
                    MediaQuery.textScalerOf(context).scale(12) > 20 ? 230 : 190,
                child: _line(context, entries)),
            const SizedBox(height: AppSpacing.sm),
            Padding(
                padding: EdgeInsets.only(
                    left: MediaQuery.textScalerOf(context).scale(12) > 20
                        ? 76
                        : 46),
                child: Row(children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                        child: Text(
                            DateFormat(widget.period == ProgressPeriod.year
                                    ? 'MMM yy'
                                    : 'd MMM')
                                .format(DateTime.fromMillisecondsSinceEpoch(
                                    (widget.period
                                                .start(widget.now)
                                                .millisecondsSinceEpoch +
                                            (widget.now.millisecondsSinceEpoch -
                                                    widget.period
                                                        .start(widget.now)
                                                        .millisecondsSinceEpoch) *
                                                i /
                                                2)
                                        .round())),
                            textAlign: i == 0
                                ? TextAlign.left
                                : i == 1
                                    ? TextAlign.center
                                    : TextAlign.right,
                            style: theme.textTheme.bodySmall))
                ])),
            const SizedBox(height: AppSpacing.sm),
            Text(
                'kg · Date-spaced measurements; vertical axis shows the recorded range.',
                style: theme.textTheme.bodySmall),
            if (entries.length == 1)
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child:
                      Text('One check-in so far. Add another to see a trend.')),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: 'Previous measurement',
                        onPressed: (_selected ?? entries.length - 1) > 0
                            ? () => setState(() => _selected =
                                (_selected ?? entries.length - 1) - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left)),
                    IconButton(
                        tooltip: 'Next measurement',
                        onPressed: (_selected ?? entries.length - 1) <
                                entries.length - 1
                            ? () => setState(() => _selected =
                                (_selected ?? entries.length - 1) + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right)),
                  ]),
                  TextButton(
                      onPressed: selected.id.isNotEmpty && widget.onEdit != null
                          ? () => widget.onEdit!(selected)
                          : null,
                      child: const Text('Edit measurement')),
                ]),
          ],
        ]));
  }

  Widget _line(BuildContext context, List<WeightEntry> entries) {
    final theme = Theme.of(context);
    double x(DateTime date) =>
        date.millisecondsSinceEpoch / Duration.millisecondsPerDay;
    final values = entries.map((e) => e.weight),
        min = values.reduce(math.min),
        max = values.reduce(math.max);
    final pad = math.max(.5, (max - min) * .2);
    final minY = math.max(0.0, ((min - pad) * 10).floor() / 10),
        maxY = ((max + pad) * 10).ceil() / 10;
    final minX = x(widget.period.start(widget.now)),
        maxX = math.max(minX + 1, x(widget.now));
    final spots = [
      for (final entry in entries) FlSpot(x(entry.date), entry.weight)
    ];
    final large = MediaQuery.textScalerOf(context).scale(12) > 20;
    final line = LineChartBarData(
        spots: spots,
        isCurved: false,
        color: theme.colorScheme.primary,
        barWidth: 3,
        dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, _) =>
                entries.length <= 60 ||
                spot ==
                    spots[(_selected ?? entries.length - 1)
                        .clamp(0, entries.length - 1)],
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: index == (_selected ?? entries.length - 1) ? 5 : 3,
                color: theme.colorScheme.primary,
                strokeWidth: 2,
                strokeColor: theme.colorScheme.secondary)),
        belowBarData: BarAreaData(
            show: true,
            color: theme.colorScheme.primary.withValues(alpha: .12)));
    return Semantics(
        label:
            'Weight chart. Use previous and next measurement buttons or See details to inspect every recorded date and value.',
        child: ExcludeSemantics(
            child: LineChart(
                key: const Key('progress-line-chart'),
                duration: Duration.zero,
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                      getDrawingHorizontalLine: (_) => FlLine(
                          color: theme.colorScheme.outlineVariant,
                          strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: large ? 76 : 46,
                              interval: (maxY - minY) / (large ? 2 : 4),
                              getTitlesWidget: (value, meta) => Text(
                                  value.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall))),
                      bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false))),
                  lineTouchData: LineTouchData(
                      touchSpotThreshold: 20,
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent &&
                            response?.lineBarSpots?.isNotEmpty == true &&
                            mounted) {
                          setState(() => _selected =
                              response!.lineBarSpots!.first.spotIndex);
                        }
                      },
                      touchTooltipData: LineTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipColor: (_) =>
                              theme.colorScheme.surfaceContainerHighest,
                          getTooltipItems: (points) => [
                                for (final point in points)
                                  LineTooltipItem(
                                      '${entries[point.spotIndex].weight.toStringAsFixed(1)} kg\n${DateFormat('d MMM y, HH:mm').format(entries[point.spotIndex].date)}',
                                      TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontSize: 14))
                              ])),
                  lineBarsData: [line],
                ))));
  }
}
