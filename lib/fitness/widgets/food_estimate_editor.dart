import 'package:flutter/material.dart';
import '../models/food_estimate.dart';
import '../theme/app_theme.dart';

/// Editing quantities does not silently recalculate estimated total nutrition.
class FoodEstimateEditor extends StatefulWidget {
  const FoodEstimateEditor({super.key, required this.estimate});
  final FoodEstimate estimate;
  @override
  State<FoodEstimateEditor> createState() => _FoodEstimateEditorState();
}

class _FoodEstimateEditorState extends State<FoodEstimateEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.estimate.name);
  late final _portion = TextEditingController(text: widget.estimate.portion);
  late final _values = [
    widget.estimate.calories,
    widget.estimate.protein,
    widget.estimate.carbs,
    widget.estimate.fat
  ].map((v) => TextEditingController(text: v.toString())).toList();
  late final _names = widget.estimate.items
      .map((i) => TextEditingController(text: i.name))
      .toList();
  late final _portions = widget.estimate.items
      .map((i) => TextEditingController(text: i.portion))
      .toList();
  final Set<int> _removed = {};
  String? _label(String? text) =>
      text == null || text.trim().isEmpty ? 'Enter a food name.' : null;
  String? _optional(String text) => text.trim().isEmpty ? null : text.trim();
  void _apply() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(FoodEstimate(
        name: _name.text.trim(),
        portion: _optional(_portion.text),
        tip: widget.estimate.tip,
        calories: int.parse(_values[0].text.trim()),
        protein: double.parse(_values[1].text.trim()),
        carbs: double.parse(_values[2].text.trim()),
        fat: double.parse(_values[3].text.trim()),
        items: [
          for (var i = 0; i < _names.length; i++)
            if (!_removed.contains(i))
              IdentifiedFood(
                  name: _names[i].text.trim(),
                  portion: _optional(_portions[i].text)),
        ]));
  }

  @override
  void dispose() {
    for (final c in [_name, _portion, ..._values, ..._names, ..._portions]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
          top: false,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Center(
                  child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: AppLayout.formWidth),
                      child: Form(
                          key: _form,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Review your estimate',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: AppSpacing.sm),
                                const Text(
                                    'Values are for the entire portion. Changing a quantity does not recalculate nutrition.'),
                                const SizedBox(height: AppSpacing.lg),
                                TextFormField(
                                    key: const Key('scan-edit-name'),
                                    controller: _name,
                                    maxLength: 200,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                        labelText: 'Food name'),
                                    validator: _label),
                                const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                    key: const Key('scan-edit-portion'),
                                    controller: _portion,
                                    maxLength: 200,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Portion / quantity (optional)')),
                                for (var i = 0; i < _values.length; i++) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                      key: ValueKey('scan-edit-macro-$i'),
                                      controller: _values[i],
                                      decoration: InputDecoration(
                                          labelText: [
                                        'Calories (kcal)',
                                        'Protein (g)',
                                        'Carbohydrates (g)',
                                        'Fat (g)'
                                      ][i]),
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                              decimal: i > 0),
                                      textInputAction: TextInputAction.next,
                                      validator: (text) {
                                        final v = i == 0
                                            ? int.tryParse(text?.trim() ?? '')
                                            : double.tryParse(
                                                text?.trim() ?? '');
                                        return v == null || !v.isFinite || v < 0
                                            ? (i == 0
                                                ? 'Enter whole calories, 0 or more.'
                                                : 'Enter grams, 0 or more.')
                                            : null;
                                      }),
                                ],
                                if (_names.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  Text('Identified items',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ],
                                for (var i = 0; i < _names.length; i++)
                                  if (!_removed.contains(i)) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                        controller: _names[i],
                                        maxLength: 200,
                                        decoration: InputDecoration(
                                            labelText: 'Item ${i + 1}',
                                            suffixIcon: IconButton(
                                                tooltip: 'Remove item ${i + 1}',
                                                onPressed: () => setState(
                                                    () => _removed.add(i)),
                                                icon: const Icon(Icons.close))),
                                        validator: _label),
                                    const SizedBox(height: AppSpacing.sm),
                                    TextFormField(
                                        controller: _portions[i],
                                        maxLength: 200,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Item quantity (optional)')),
                                  ],
                                const SizedBox(height: AppSpacing.lg),
                                FilledButton(
                                    key: const Key('scan-apply-edit'),
                                    onPressed: _apply,
                                    child: const Text('Apply changes')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Cancel')),
                              ])))))));
}
