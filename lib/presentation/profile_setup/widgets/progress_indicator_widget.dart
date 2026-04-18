import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;

  const ProgressIndicatorWidget({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: isDark
          ? AppTheme.glassmorphicDecoration(borderRadius: 16)
          : BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                'Profile Setup',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$currentStep of $totalSteps',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildProgressBar(context),
          SizedBox(height: 2.h),
          _buildStepIndicators(context),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final double progress = currentStep / totalSteps;

    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: colorScheme.outline.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            width: progress * 100.w - (8.w),
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: isDark ? 0.5 : 0.3),
                  blurRadius: isDark ? 8 : 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicators(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: List.generate(totalSteps, (index) {
        final stepNumber = index + 1;
        final isCompleted = stepNumber < currentStep;
        final isCurrent = stepNumber == currentStep;
        final isUpcoming = stepNumber > currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? colorScheme.primary
                            : isCurrent
                                ? colorScheme.primary
                                : colorScheme.outline.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              )
                            : null,
                        boxShadow: (isCompleted || isCurrent) && isDark
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : (isCompleted || isCurrent)
                                ? [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? CustomIconWidget(
                                iconName: 'check',
                                color: colorScheme.onPrimary,
                                size: 16,
                              )
                            : Text(
                                stepNumber.toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isCurrent
                                      ? colorScheme.onPrimary
                                      : isUpcoming
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.sp,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      index < stepLabels.length
                          ? stepLabels[index]
                          : 'Step $stepNumber',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: (isCompleted || isCurrent)
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 9.sp,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (index < totalSteps - 1)
                Container(
                  width: 4.w,
                  height: 2,
                  margin: EdgeInsets.only(bottom: 4.h),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
