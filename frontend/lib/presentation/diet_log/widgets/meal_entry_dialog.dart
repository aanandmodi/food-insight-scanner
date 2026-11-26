import 'package:flutter/material.dart';

import '../../../core/utils/nutrition_trends.dart';

typedef MealValues = Map<String, dynamic>;

class MealEntryDialog extends StatefulWidget {
  const MealEntryDialog({
    super.key,
    required this.save,
    this.estimate,
    this.initialMeal,
  });

  final Future<void> Function(MealValues) save;
  final Future<MealValues?> Function(String)? estimate;
  final MealValues? initialMeal;

  @override
  State<MealEntryDialog> createState() => _MealEntryDialogState();
}

class _MealEntryDialogState extends State<MealEntryDialog> {
  final _name = TextEditingController();
  final _fields = {
    for (final key in [
      'calories',
      'protein',
      'carbs',
      'fat',
      'sugar',
      'fiber',
      'sodiumMg',
    ])
      key: TextEditingController()
  };
  String _type = 'Breakfast';
  String? _error;
  bool _busy = false, _estimated = false;
  static const _max = {
    'calories': 5000,
    'protein': 500,
    'carbs': 1000,
    'fat': 500,
    'sugar': 500,
    'fiber': 300,
    'sodiumMg': 50000,
  };
  static const _labels = {
    'calories': 'Calories (kcal)',
    'protein': 'Protein (g)',
    'carbs': 'Carbohydrates (g)',
    'fat': 'Fat (g)',
    'sugar': 'Sugar (g)',
    'fiber': 'Fiber (g, optional)',
    'sodiumMg': 'Sodium (mg, optional)',
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMeal;
    if (initial != null) {
      const validTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
      final rawType = initial['mealType']?.toString() ?? 'Breakfast';
      _type = validTypes.contains(rawType) ? rawType : 'Snack';
      _name.text = initial['name']?.toString() ?? '';
      for (final entry in _fields.entries) {
        final rawVal = initial[entry.key];
        if (rawVal is num && rawVal.isFinite) {
          entry.value.text = rawVal == rawVal.roundToDouble()
              ? rawVal.round().toString()
              : rawVal.toStringAsFixed(1);
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _applyIndianPreset(IndianServingPreset preset) {
    setState(() {
      _type = preset.mealType;
      _name.text = preset.mealName;
      final map = preset.toMealValues();
      for (final entry in _fields.entries) {
        final val = map[entry.key];
        entry.value.text = val is num
            ? (val == val.roundToDouble()
                ? val.round().toString()
                : val.toStringAsFixed(1))
            : '';
      }
      _estimated = false;
      _error = null;
    });
  }

  Future<void> _estimate() async {
    if (_busy || widget.estimate == null) return;
    if (_name.text.trim().isEmpty || _name.text.length > 2000) {
      setState(() => _error = 'Describe your meal in 1–2,000 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = await widget.estimate!(_name.text.trim());
      if (!mounted) return;
      if (values == null) {
        throw const FormatException('No estimate was returned.');
      }
      _name.text = values['name'] as String? ?? _name.text;
      for (final entry in _fields.entries) {
        entry.value.text = values[entry.key]?.toString() ?? '';
      }
      setState(() => _estimated = true);
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = '$error You can still enter nutrition manually.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    final initial = widget.initialMeal;
    final values = <String, dynamic>{
      if (initial != null) ...initial,
      'name': name,
      'mealType': _type,
      'brand': _estimated
          ? 'AI Estimate · reviewed'
          : (initial?['brand'] ?? 'Manual Entry'),
    };
    if (name.isEmpty || name.length > 2000) {
      setState(() => _error = 'Enter a meal name (up to 2,000 characters).');
      return;
    }
    for (final entry in _fields.entries) {
      final text = entry.value.text.trim();
      final value = double.tryParse(text);
      if (text.isEmpty && entry.key != 'calories') {
        values[entry.key] = null;
        continue;
      }
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          value > _max[entry.key]!) {
        setState(() => _error =
            '${_labels[entry.key]} must be between 0 and ${_max[entry.key]}.');
        return;
      }
      values[entry.key] = value;
    }
    values['nutritionIncomplete'] = ['calories', 'protein', 'carbs', 'fat', 'sugar']
        .any((key) => values[key] == null);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(values);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Your meal could not be saved. Check your connection or retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialMeal != null;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(isEditing ? 'Edit Meal' : 'Add Meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Meal type'),
              items: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged:
                  _busy ? null : (value) => setState(() => _type = value!),
            ),
            TextField(
              controller: _name,
              enabled: !_busy,
              maxLines: 2,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'What did you eat?'),
            ),
            if (widget.estimate != null)
              TextButton.icon(
                onPressed: _busy ? null : _estimate,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Estimate with AI'),
              ),
            if (!isEditing) ...[
              const SizedBox(height: 6),
              Text(
                'Indian household presets (approximate — adjust after filling):',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final preset in IndianServingPresets.all)
                    ActionChip(
                      label: Text(preset.label),
                      onPressed: _busy ? null : () => _applyIndianPreset(preset),
                    ),
                ],
              ),
            ],
            if (_estimated)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'AI estimate — review the portion and edit these values before saving.',
                ),
              ),
            for (final entry in _fields.entries)
              TextField(
                controller: entry.value,
                enabled: !_busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _labels[entry.key]),
              ),
            const SizedBox(height: 12),
            const Text(
              'Calories are required. Leave other unknown values blank. Daily totals include only recorded nutrients.',
            ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(isEditing ? 'Update meal' : 'Save meal'),
          ),
        ],
      ),
    );
  }
}
