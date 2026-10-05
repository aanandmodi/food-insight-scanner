import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../theme/app_theme.dart';

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
      child: LayoutBuilder(
          builder: (context, constraints) => Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    width: constraints.maxWidth * progress,
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
                          color: colorScheme.primary
                              .withValues(alpha: isDark ? 0.5 : 0.3),
                          blurRadius: isDark ? 8 : 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              )),
    );
  }

  Widget _buildStepIndicators(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(children: [
      Row(
          children: List.generate(totalSteps, (index) {
        final step = index + 1;
        final active = step <= currentStep;
        return Expanded(
            child: Row(children: [
          Expanded(
              child: Semantics(
            label: 'Step $step of $totalSteps',
            selected: step == currentStep,
            child: CircleAvatar(
                radius: 16,
                backgroundColor: active
                    ? colors.primary
                    : colors.outline.withValues(alpha: .12),
                child: step < currentStep
                    ? Icon(Icons.check_rounded,
                        color: colors.onPrimary, size: 18)
                    : Text('$step',
                        style: TextStyle(
                            fontSize: 12,
                            color: active
                                ? colors.onPrimary
                                : colors.onSurfaceVariant))),
          )),
          if (step < totalSteps)
            Container(
                width: 12,
                height: 2,
                color: step < currentStep
                    ? colors.primary
                    : colors.outline.withValues(alpha: .2)),
        ]));
      })),
      const SizedBox(height: 10),
      Text(
          currentStep <= stepLabels.length
              ? stepLabels[currentStep - 1].replaceAll('\\n', ' ')
              : 'Step $currentStep',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
    ]);
  }
}
