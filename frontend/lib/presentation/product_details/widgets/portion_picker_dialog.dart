import 'package:flutter/material.dart';

import '../../../services/product_portion_service.dart';
import '../../../theme/app_design_system.dart';

/// Opens an interactive portion dialog with g / ml / kg units, quick presets,
/// and live scaled nutrient preview.
Future<Map<String, dynamic>?> showPortionPickerDialog(
  BuildContext context, {
  required Map<String, dynamic> productData,
}) async {
  final servingSize = productData['servingSize']?.toString();
  final parsedServing = ProductPortionService.parseServingSize(servingSize);
  var selectedUnit = parsedServing?.unit ?? PortionUnit.g;
  final initialAmount = parsedServing?.amount ??
      (selectedUnit == PortionUnit.ml ? 250.0 : 100.0);
  final controller = TextEditingController(
    text: ProductPortionService.formatAmount(initialAmount),
  );
  String? validationError;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final presets = ProductPortionService.presetsForUnit(
          selectedUnit,
          servingSize: servingSize,
        );
        final parsedInput = double.tryParse(controller.text.trim());
        Map<String, dynamic>? preview;
        if (parsedInput != null) {
          try {
            preview = ProductPortionService.nutrientsForAmount(
              productData,
              parsedInput,
              selectedUnit,
            );
          } catch (_) {}
        }

        final helperRange = switch (selectedUnit) {
          PortionUnit.g => '1–2,000 g',
          PortionUnit.ml => '1–2,000 ml (100 ml = 100 g reference)',
          PortionUnit.kg => '0.001–2 kg',
        };

        void applyPreset(PortionPreset preset) {
          setDialogState(() {
            selectedUnit = preset.unit;
            controller.text = ProductPortionService.formatAmount(preset.amount);
            validationError = null;
          });
        }

        void switchUnit(PortionUnit nextUnit) {
          if (selectedUnit == nextUnit) return;
          setDialogState(() {
            final current = double.tryParse(controller.text.trim());
            if (current != null && current > 0) {
              final grams = ProductPortionService.toGrams(current, selectedUnit);
              final converted = switch (nextUnit) {
                PortionUnit.g => grams,
                PortionUnit.ml => grams,
                PortionUnit.kg => grams / 1000,
              };
              controller.text = ProductPortionService.formatAmount(converted);
            }
            selectedUnit = nextUnit;
            validationError = null;
          });
        }

        return AlertDialog(
          scrollable: true,
          title: const Text('How much did you consume?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a unit and portion size. Values scale from the product\'s per-100g/ml nutrition facts.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final unit in PortionUnit.values)
                    ChoiceChip(
                      label: Text(unit.symbol),
                      selected: selectedUnit == unit,
                      onSelected: (_) => switchUnit(unit),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Quick presets',
                style: FoodInsightTypography.caption(
                  size: 12,
                  weight: FontWeight.w700,
                  color: FoodInsightColors.midGray,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final preset in presets)
                    ActionChip(
                      label: Text(preset.label),
                      onPressed: () => applyPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setDialogState(() => validationError = null),
                decoration: InputDecoration(
                  labelText: 'Portion (${selectedUnit.symbol})',
                  helperText: helperRange,
                  errorText: validationError,
                ),
              ),
              if (preview != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FoodInsightColors.scannerGreenLight
                        .withValues(alpha: 0.45),
                    borderRadius: FoodInsightRadius.smAll,
                  ),
                  child: Text(
                    'Estimate (${preview['serving']}): '
                    '${(preview['calories'] as num).round()} kcal'
                    '${preview['protein'] is num ? ' · ${(preview['protein'] as num).toStringAsFixed(1)} g protein' : ''}'
                    '${preview['sugar'] is num ? ' · ${(preview['sugar'] as num).toStringAsFixed(1)} g sugar' : ''}',
                    style: FoodInsightTypography.caption(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: FoodInsightColors.scannerGreenDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(controller.text.trim());
                if (amount == null || !amount.isFinite || amount <= 0) {
                  setDialogState(
                    () => validationError =
                        'Enter a valid positive number in ${selectedUnit.symbol}',
                  );
                  return;
                }
                try {
                  final computed = ProductPortionService.nutrientsForAmount(
                    productData,
                    amount,
                    selectedUnit,
                  );
                  Navigator.pop(dialogContext, computed);
                } on FormatException catch (e) {
                  setDialogState(() => validationError = e.message);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: FoodInsightColors.scannerGreen,
              ),
              child: const Text('Add meal'),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  return result;
}
