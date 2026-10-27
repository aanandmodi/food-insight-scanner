import 'package:flutter/material.dart';

typedef MealValues = Map<String, dynamic>;

class MealEntryDialog extends StatefulWidget {
  const MealEntryDialog({super.key, required this.save, this.estimate});
  final Future<void> Function(MealValues) save;
  final Future<MealValues?> Function(String)? estimate;
  @override
  State<MealEntryDialog> createState() => _MealEntryDialogState();
}

class _MealEntryDialogState extends State<MealEntryDialog> {
  final _name = TextEditingController();
  final _fields = {
    for (final key in ['calories', 'protein', 'carbs', 'fat', 'sugar'])
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
    'sugar': 500
  };
  static const _labels = {
    'calories': 'Calories (kcal)',
    'protein': 'Protein (g)',
    'carbs': 'Carbohydrates (g)',
    'fat': 'Fat (g)',
    'sugar': 'Sugar (g)'
  };

  @override
  void dispose() {
    _name.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
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
    final values = <String, dynamic>{
      'name': name,
      'mealType': _type,
      'brand': _estimated ? 'AI Estimate · reviewed' : 'Manual Entry'
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
    values['nutritionIncomplete'] =
        _fields.keys.any((key) => values[key] == null);
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
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Add Meal'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Meal type'),
              items: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged:
                  _busy ? null : (value) => setState(() => _type = value!)),
          TextField(
              controller: _name,
              enabled: !_busy,
              maxLines: 2,
              maxLength: 2000,
              decoration:
                  const InputDecoration(labelText: 'What did you eat?')),
          if (widget.estimate != null)
            TextButton.icon(
                onPressed: _busy ? null : _estimate,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Estimate with AI')),
          if (_estimated)
            const Text(
                'AI estimate — review the portion and edit these values before saving.'),
          for (final entry in _fields.entries)
            TextField(
                controller: entry.value,
                enabled: !_busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _labels[entry.key])),
          const SizedBox(height: 12),
          const Text(
              'Calories are required. Leave other unknown values blank. Daily totals include only recorded nutrients.'),
          if (_error != null)
            Semantics(
                liveRegion: true,
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator()),
        ]),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _busy ? null : _save, child: const Text('Save meal'))
        ],
      ));
}
