import 'package:flutter/material.dart';

import '../../../services/product_facts_adapter.dart';
import '../../../theme/app_design_system.dart';

/// Opens a manual package-label recovery modal when a barcode isn't in Open Food Facts.
Future<Map<String, dynamic>?> showManualProductDialog(
  BuildContext context, {
  required String barcode,
}) async {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _ManualProductDialog(barcode: barcode),
  );
}

class _ManualProductDialog extends StatefulWidget {
  const _ManualProductDialog({required this.barcode});

  final String barcode;

  @override
  State<_ManualProductDialog> createState() => _ManualProductDialogState();
}

class _ManualProductDialogState extends State<_ManualProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _servingController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _sugarController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _allergensController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _servingController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _sugarController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sodiumController.dispose();
    _ingredientsController.dispose();
    _allergensController.dispose();
    super.dispose();
  }

  double? _parseNumber(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String? _validateOptionalMetric(String? value, {required double max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > max) {
      return '0–${max.round()}';
    }
    return null;
  }

  List<String> _splitList(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rawIngredients = _ingredientsController.text.trim();
    final ingredientsList = _splitList(rawIngredients);
    final allergensList = _splitList(_allergensController.text);

    final calories = _parseNumber(_caloriesController);
    final protein = _parseNumber(_proteinController);
    final carbs = _parseNumber(_carbsController);
    final sugar = _parseNumber(_sugarController);
    final fat = _parseNumber(_fatController);
    final fiber = _parseNumber(_fiberController);
    final sodium = _parseNumber(_sodiumController);

    final adapted = ProductFactsAdapter.adapt({
      'barcode': widget.barcode,
      'schemaVersion': 2,
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim().isEmpty
          ? 'Custom Label Entry'
          : _brandController.text.trim(),
      'servingSize': _servingController.text.trim(),
      'ingredientsText': rawIngredients,
      'ingredients': ingredientsList,
      'allergens': allergensList,
      'source': 'user_label',
      'sourceFetchedAt': DateTime.now().toUtc().toIso8601String(),
      'nutrition': {
        'energyKcalPer100g': calories,
        'proteinGPer100g': protein,
        'carbohydratesGPer100g': carbs,
        'sugarGPer100g': sugar,
        'fatGPer100g': fat,
        'fiberGPer100g': fiber,
        'sodiumMgPer100g': sodium,
      },
    });
    Navigator.pop(context, adapted);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Add From Package Label'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barcode: ${widget.barcode} · Enter values per 100 g or 100 ml. Leave blank fields unknown.',
              style: FoodInsightTypography.caption(
                size: 12,
                color: FoodInsightColors.midGray,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Roasted Chana Jor Garam',
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter product name' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _servingController,
                    decoration: const InputDecoration(
                      labelText: 'Serving Size',
                      hintText: 'e.g. 30 g / 200 ml',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _caloriesController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Energy (kcal)',
                    ),
                    validator: (v) => _validateOptionalMetric(v, max: 1000),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _proteinController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Protein (g)'),
                    validator: (v) => _validateOptionalMetric(v, max: 100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _carbsController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Carbs (g)'),
                    validator: (v) => _validateOptionalMetric(v, max: 100),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _sugarController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Sugar (g)'),
                    validator: (v) => _validateOptionalMetric(v, max: 100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fatController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Fat (g)'),
                    validator: (v) => _validateOptionalMetric(v, max: 100),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _fiberController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Fiber (g)'),
                    validator: (v) => _validateOptionalMetric(v, max: 100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _sodiumController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Sodium (mg)'),
              validator: (v) => _validateOptionalMetric(v, max: 100000),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _ingredientsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ingredients',
                hintText: 'Comma-separated (e.g. chickpeas, spices, INS 330)',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _allergensController,
              decoration: const InputDecoration(
                labelText: 'Allergen warnings',
                hintText: 'Comma-separated (e.g. milk, peanut)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
          child: const Text('Save & Analyze'),
        ),
      ],
    );
  }
}
