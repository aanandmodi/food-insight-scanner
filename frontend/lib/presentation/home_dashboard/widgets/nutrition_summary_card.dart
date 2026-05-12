import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_design_system.dart';
import '../../../widgets/skeuomorphic/skeu_card.dart';
import '../../../widgets/skeuomorphic/animated_nutrition_ring.dart';

class NutritionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> nutritionData;

  const NutritionSummaryCard({
    super.key,
    required this.nutritionData,
  });

  @override
  Widget build(BuildContext context) {
    final calories = (nutritionData['calories'] as num?)?.toInt() ?? 0;
    final caloriesGoal =
        (nutritionData['caloriesGoal'] as num?)?.toInt() ?? 2000;
    final sugar = (nutritionData['sugar'] as num?)?.toInt() ?? 0;
    final sugarGoal = (nutritionData['sugarGoal'] as num?)?.toInt() ?? 50;
    final protein = (nutritionData['protein'] as num?)?.toInt() ?? 0;
    final proteinGoal =
        (nutritionData['proteinGoal'] as num?)?.toInt() ?? 150;

    final caloriesPct =
        caloriesGoal > 0 ? (calories / caloriesGoal).clamp(0.0, 1.0) : 0.0;
    final proteinPct =
        proteinGoal > 0 ? (protein / proteinGoal).clamp(0.0, 1.0) : 0.0;
    final sugarPct =
        sugarGoal > 0 ? (sugar / sugarGoal).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: SkeuCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Nutrition",
                  style: FoodInsightTypography.heading(
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                ),
                // Small day progress badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _overallColor(caloriesPct).withValues(alpha: 0.12),
                    borderRadius: FoodInsightRadius.pillAll,
                  ),
                  child: Text(
                    '${(caloriesPct * 100).round()}%',
                    style: FoodInsightTypography.caption(
                      size: 11,
                      weight: FontWeight.w700,
                      color: _overallColor(caloriesPct),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Three rings in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AnimatedNutritionRing(
                  value: caloriesPct,
                  maxValue: caloriesGoal.toDouble(),
                  currentValue: calories.toDouble(),
                  label: 'Calories',
                  unit: 'kcal',
                  ringColor: FoodInsightColors.infoBlue,
                  size: 90,
                ),
                AnimatedNutritionRing(
                  value: proteinPct,
                  maxValue: proteinGoal.toDouble(),
                  currentValue: protein.toDouble(),
                  label: 'Protein',
                  unit: 'g',
                  ringColor: FoodInsightColors.scannerGreen,
                  size: 90,
                ),
                AnimatedNutritionRing(
                  value: sugarPct,
                  maxValue: sugarGoal.toDouble(),
                  currentValue: sugar.toDouble(),
                  label: 'Sugar',
                  unit: 'g',
                  ringColor: FoodInsightColors.warningAmber,
                  size: 90,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Bottom legend row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendChip(
                    'Calories', '$calories / $caloriesGoal', FoodInsightColors.infoBlue),
                _buildLegendChip(
                    'Protein', '$protein / ${proteinGoal}g', FoodInsightColors.scannerGreen),
                _buildLegendChip(
                    'Sugar', '$sugar / ${sugarGoal}g', FoodInsightColors.warningAmber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _overallColor(double pct) {
    if (pct < 0.3) return FoodInsightColors.midGray;
    if (pct < 0.7) return FoodInsightColors.scannerGreen;
    if (pct < 0.9) return FoodInsightColors.warningAmber;
    return FoodInsightColors.healthRed;
  }

  Widget _buildLegendChip(String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: FoodInsightTypography.caption(
                size: 10,
                weight: FontWeight.w600,
                color: FoodInsightColors.midGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: FoodInsightTypography.caption(
            size: 10,
            weight: FontWeight.w700,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
      ],
    );
  }
}
