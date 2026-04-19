import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/app_export.dart';

class NutritionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> nutritionData;

  const NutritionSummaryCard({
    super.key,
    required this.nutritionData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final calories = (nutritionData['calories'] as num?)?.toInt() ?? 0;
    final caloriesGoal = (nutritionData['caloriesGoal'] as num?)?.toInt() ?? 2000;
    final sugar = (nutritionData['sugar'] as num?)?.toInt() ?? 0;
    final sugarGoal = (nutritionData['sugarGoal'] as num?)?.toInt() ?? 50;
    final protein = (nutritionData['protein'] as num?)?.toInt() ?? 0;
    final proteinGoal = (nutritionData['proteinGoal'] as num?)?.toInt() ?? 150;

    final caloriesColor = colorScheme.primary;
    final proteinColor = AppTheme.getSuccessColor(!isDark);
    final sugarColor = AppTheme.getWarningColor(!isDark);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: isDark 
                  ? AppTheme.glassDarkBg 
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.1) 
                    : Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withValues(alpha: 0.2) 
                      : colorScheme.primary.withValues(alpha: 0.05),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Nutrition",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    // Concentric Circular Progress Rings
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildRing(160, calories, caloriesGoal, caloriesColor, isDark),
                          _buildRing(125, protein, proteinGoal, proteinColor, isDark),
                          _buildRing(90, sugar, sugarGoal, sugarColor, isDark),
                          // Center Text
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "$calories",
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                  shadows: isDark ? AppTheme.textGlow(caloriesColor, blur: 10) : null,
                                ),
                              ),
                              Text(
                                "kcal",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    // Legend
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem(context, 'Calories', calories, caloriesGoal, caloriesColor, isDark, "kcal"),
                          SizedBox(height: 2.h),
                          _buildLegendItem(context, 'Protein', protein, proteinGoal, proteinColor, isDark, "g"),
                          SizedBox(height: 2.h),
                          _buildLegendItem(context, 'Sugar', sugar, sugarGoal, sugarColor, isDark, "g"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRing(double size, int current, int goal, Color color, bool isDark) {
    if (goal <= 0) goal = 1; // Prevent division by zero
    double progress = (current / goal).clamp(0.0, 1.0);
    double remainder = 1.0 - progress;

    return SizedBox(
      height: size,
      width: size,
      child: PieChart(
        PieChartData(
          startDegreeOffset: -90,
          sectionsSpace: 0,
          centerSpaceRadius: (size / 2) - 10,
          sections: [
            PieChartSectionData(
              value: progress,
              color: color,
              radius: 10,
              showTitle: false,
            ),
            PieChartSectionData(
              value: remainder,
              color: isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.15),
              radius: 10,
              showTitle: false,
            ),
          ],
        ),
        swapAnimationDuration: const Duration(milliseconds: 1500),
        swapAnimationCurve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, int current, int goal, Color color, bool isDark, String unit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isDark ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 6)] : null,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "$current / $goal $unit",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
