import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';

/// Raised skeuomorphic card — looks physically lifted off the page.
/// Use everywhere instead of plain Container or Card.
class SkeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Gradient? gradient;
  final Color? color;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final Border? border;

  const SkeuCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0,
    this.gradient,
    this.color,
    this.shadows,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: FoodInsightAnimations.ultraFast,
        curve: FoodInsightAnimations.spring,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient ?? FoodInsightColors.cardGradient,
          color: gradient == null ? (color ?? Colors.white) : null,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: shadows ?? FoodInsightShadows.raisedCard,
          border: border ??
              Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.0,
              ),
        ),
        child: child,
      ),
    );
  }
}
