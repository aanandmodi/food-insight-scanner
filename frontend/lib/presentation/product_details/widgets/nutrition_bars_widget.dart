import 'package:flutter/material.dart';
import '../../../theme/app_design_system.dart';

class NutritionBarsWidget extends StatelessWidget {
  final Map<String, dynamic> nutritionData;
  const NutritionBarsWidget({super.key, required this.nutritionData});
  @override
  Widget build(BuildContext context) {
    const fields = [
      ('Calories', 'calories', 'kcal', 500.0), ('Protein', 'protein', 'g', 30.0),
      ('Carbohydrates', 'carbs', 'g', 100.0), ('Sugar', 'sugar', 'g', 25.0),
      ('Fat', 'fat', 'g', 50.0), ('Fiber', 'fiber', 'g', 15.0),
      ('Sodium', 'sodiumMgPer100g', 'mg', 1000.0),
    ];
    final theme = Theme.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: FoodInsightRadius.mdAll,
        border: Border.all(color: FoodInsightColors.outlineGray)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nutrition per 100g', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        for (final field in fields) Padding(padding: const EdgeInsets.only(bottom: 16),
          child: Builder(builder: (context) {
            final raw = nutritionData[field.$2];
            final value = raw is num && raw.isFinite && raw >= 0 ? raw.toDouble() : null;
            final label = value == null ? 'Unavailable' : '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} ${field.$3}';
            return Semantics(label: '${field.$1}: $label per 100 grams', excludeSemantics: true,
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(field.$1, style: theme.textTheme.bodyMedium)),
                  const SizedBox(width: 12),
                  Flexible(child: Text(label, textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                ]),
                if (value != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (value / field.$4).clamp(0, 1),
                    minHeight: 5, borderRadius: BorderRadius.circular(4),
                    color: FoodInsightColors.scannerGreen, backgroundColor: FoodInsightColors.scannerGreenLight),
                ],
              ]));
          })),
        Text('Bars show nutrient density, not a daily allowance. Missing values are unknown.', style: theme.textTheme.bodySmall),
      ]));
  }
}
