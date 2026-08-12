import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/providers/activity_provider.dart';
import '../../../theme/app_design_system.dart';

class ActivitySummaryCard extends StatelessWidget {
  const ActivitySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final double stepProgress = (provider.steps / provider.dailyStepGoal).clamp(0.0, 1.0);

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 5.w),
          padding: EdgeInsets.all(5.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: FoodInsightRadius.xlAll,
            boxShadow: FoodInsightShadows.subtleCard,
            border: Border.all(
              color: FoodInsightColors.outlineGray,
              width: 1,
            ),
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
                          color: FoodInsightColors.scannerGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_walk_rounded,
                          color: FoodInsightColors.scannerGreen,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'Activity & Steps',
                        style: FoodInsightTypography.heading(
                          size: 16,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 3.h),
              Row(
                children: [
                  // Circular Progress Indicator for Steps
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 80,
                            width: 80,
                            child: CircularProgressIndicator(
                              value: stepProgress,
                              strokeWidth: 8,
                              backgroundColor: FoodInsightColors.lightGray,
                              valueColor: const AlwaysStoppedAnimation<Color>(FoodInsightColors.scannerGreen),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(stepProgress * 100).toInt()}%',
                                style: FoodInsightTypography.body(
                                  size: 18,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  // Detailed Stats
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatRow(
                          icon: Icons.directions_walk_rounded,
                          label: 'Steps',
                          value: '${provider.steps}',
                          target: '/ ${provider.dailyStepGoal}',
                          color: FoodInsightColors.scannerGreen,
                        ),
                        SizedBox(height: 1.5.h),
                        _buildStatRow(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Active Calories',
                          value: '${provider.activeCalories}',
                          target: ' kcal',
                          color: FoodInsightColors.healthRed,
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required String target,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 2.w),
        Text(
          label,
          style: FoodInsightTypography.caption(
            size: 13,
            color: FoodInsightColors.midGray,
            weight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: FoodInsightTypography.body(
            size: 14,
            weight: FontWeight.w800,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
        Text(
          target,
          style: FoodInsightTypography.caption(
            size: 12,
            color: FoodInsightColors.midGray,
          ),
        ),
      ],
    );
  }
}
