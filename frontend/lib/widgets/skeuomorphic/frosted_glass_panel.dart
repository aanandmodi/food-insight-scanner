import 'package:flutter/material.dart';

class FrostedGlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurX;
  final double blurY;
  final Color? tintColor;
  final EdgeInsetsGeometry? padding;

  const FrostedGlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurX = 10.0,
    this.blurY = 10.0,
    this.tintColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: (tintColor ?? Colors.white).withValues(alpha: 0.95), // Highly opaque color instead of blur for performance
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
