// lib/presentation/home_dashboard/widgets/meal_plan_preview.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../theme/app_design_system.dart';

class MealPlanPreviewWidget extends StatelessWidget {
  final VoidCallback onViewPlan;

  const MealPlanPreviewWidget({super.key, required this.onViewPlan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: FoodInsightRadius.lgAll,
          boxShadow: FoodInsightShadows.subtleCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FoodInsightColors.scannerGreenLight,
                        borderRadius: FoodInsightRadius.smAll,
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: FoodInsightColors.scannerGreen,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Smart Meal Plan',
                      style: FoodInsightTypography.heading(
                        size: 18,
                        weight: FontWeight.w800,
                        color: FoodInsightColors.deepCharcoal,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onViewPlan,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Open Planner',
                    style: FoodInsightTypography.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: FoodInsightColors.scannerGreen,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              'Generate a customized daily meal plan powered by AI.',
              style: FoodInsightTypography.body(
                size: 14,
                color: FoodInsightColors.midGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
