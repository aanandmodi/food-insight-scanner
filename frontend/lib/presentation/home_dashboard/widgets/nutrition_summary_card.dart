import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

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

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: isDark
                ? AppTheme.glassmorphicDecoration()
                : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Today's Nutrition",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 0.5.h),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: isDark
                            ? Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.3),
                              )
                            : null,
                      ),
                      child: Text(
                        "$calories / $caloriesGoal kcal",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          shadows: isDark
                              ? AppTheme.textGlow(colorScheme.primary, blur: 6)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                _buildAnimatedNutritionBar(
                  context,
                  "Calories",
                  calories,
                  caloriesGoal,
                  colorScheme.primary,
                  isDark,
                ),
                SizedBox(height: 1.5.h),
                _buildAnimatedNutritionBar(
                  context,
                  "Sugar",
                  sugar,
                  sugarGoal,
                  AppTheme.getWarningColor(!isDark),
                  isDark,
                ),
                SizedBox(height: 1.5.h),
                _buildAnimatedNutritionBar(
                  context,
                  "Protein",
                  protein,
                  proteinGoal,
                  AppTheme.getSuccessColor(!isDark),
                  isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedNutritionBar(
    BuildContext context,
    String label,
    int current,
    int goal,
    Color color,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final unit = label == 'Calories' ? 'kcal' : 'g';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              "$current / $goal $unit",
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                shadows: isDark ? AppTheme.textGlow(color, blur: 4) : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 0.5.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Stack(
                children: [
                  // Track
                  Container(
                    height: 1.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? color.withValues(alpha: 0.12)
                          : color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Fill
                  Container(
                    height: 1.h,
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.8),
                              color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isDark
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
