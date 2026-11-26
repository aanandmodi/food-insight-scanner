import 'package:flutter/material.dart';

import '../../../theme/app_design_system.dart';

List<String> extractMealIngredients(Map<String, dynamic> meal) {
  final raw = meal['ingredients'];
  if (raw is! List) return const [];
  final seen = <String>{};
  final result = <String>[];
  for (final item in raw) {
    final text = item?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    final key = text.toLowerCase();
    if (seen.add(key)) {
      result.add(text);
    }
  }
  return result;
}

class PlannedMealCard extends StatelessWidget {
  const PlannedMealCard({
    super.key,
    required this.meal,
    this.onLogMeal,
    this.onAddIngredients,
    this.isLogging = false,
    this.isAddingIngredients = false,
  });

  final Map<String, dynamic> meal;
  final VoidCallback? onLogMeal;
  final VoidCallback? onAddIngredients;
  final bool isLogging;
  final bool isAddingIngredients;

  String _formatMacro(Object? raw) {
    if (raw is num) {
      return raw == raw.roundToDouble()
          ? raw.round().toString()
          : raw.toStringAsFixed(1);
    }
    final parsed = double.tryParse(raw?.toString() ?? '');
    if (parsed != null) {
      return parsed == parsed.roundToDouble()
          ? parsed.round().toString()
          : parsed.toStringAsFixed(1);
    }
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    final type = meal['type']?.toString().trim().isNotEmpty == true
        ? meal['type'].toString().trim()
        : 'Meal';
    final name = meal['name']?.toString().trim().isNotEmpty == true
        ? meal['name'].toString().trim()
        : 'Unknown Meal';
    final description = meal['description']?.toString().trim() ?? '';
    final portion = meal['portionDescription']?.toString().trim() ?? '';
    final ingredients = extractMealIngredients(meal);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FoodInsightRadius.lgAll,
        border: Border.all(
          color: FoodInsightColors.scannerGreen.withValues(alpha: 0.2),
        ),
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: FoodInsightColors.scannerGreenLight,
                  borderRadius: FoodInsightRadius.smAll,
                ),
                child: Text(
                  type,
                  style: FoodInsightTypography.caption(
                    size: 12,
                    weight: FontWeight.w700,
                    color: FoodInsightColors.scannerGreenDark,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: FoodInsightColors.healthRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatMacro(meal['calories'])} kcal',
                    style: FoodInsightTypography.caption(
                      size: 12,
                      weight: FontWeight.w600,
                      color: FoodInsightColors.healthRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.fitness_center_rounded,
                    size: 14,
                    color: FoodInsightColors.healthGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatMacro(meal['protein'])}g P',
                    style: FoodInsightTypography.caption(
                      size: 12,
                      weight: FontWeight.w600,
                      color: FoodInsightColors.healthGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: FoodInsightTypography.heading(
              size: 18,
              color: FoodInsightColors.deepCharcoal,
            ),
          ),
          if (portion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.restaurant_outlined,
                  size: 14,
                  color: FoodInsightColors.scannerGreenDark,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    portion,
                    style: FoodInsightTypography.caption(
                      size: 12,
                      weight: FontWeight.w700,
                      color: FoodInsightColors.scannerGreenDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _macroChip('${_formatMacro(meal['carbs'])}g Carbs'),
              _macroChip('${_formatMacro(meal['fat'])}g Fat'),
              _macroChip('${_formatMacro(meal['sugar'])}g Sugar'),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: FoodInsightTypography.body(
                size: 14,
                color: FoodInsightColors.midGray,
              ),
            ),
          ],
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ingredients',
              style: FoodInsightTypography.caption(
                size: 12,
                weight: FontWeight.w700,
                color: FoodInsightColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ingredients
                  .map(
                    (ingredient) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: FoodInsightColors.warmWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FoodInsightColors.lightGray,
                        ),
                      ),
                      child: Text(
                        ingredient,
                        style: FoodInsightTypography.caption(
                          size: 11,
                          color: FoodInsightColors.deepCharcoal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (onLogMeal != null ||
              (onAddIngredients != null && ingredients.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onLogMeal != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLogging ? null : onLogMeal,
                      icon: const Icon(Icons.add_task_rounded, size: 16),
                      label: Text(isLogging ? 'Logging...' : 'Log Meal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FoodInsightColors.scannerGreenDark,
                        side: BorderSide(
                          color: FoodInsightColors.scannerGreen
                              .withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                if (onLogMeal != null &&
                    onAddIngredients != null &&
                    ingredients.isNotEmpty)
                  const SizedBox(width: 8),
                if (onAddIngredients != null && ingredients.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          isAddingIngredients ? null : onAddIngredients,
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isAddingIngredients
                            ? 'Adding...'
                            : 'Add Ingredients',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FoodInsightColors.deepCharcoal,
                        side: const BorderSide(
                          color: FoodInsightColors.lightGray,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _macroChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FoodInsightColors.warmWhite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: FoodInsightTypography.caption(
          size: 11,
          weight: FontWeight.w600,
          color: FoodInsightColors.midGray,
        ),
      ),
    );
  }
}
