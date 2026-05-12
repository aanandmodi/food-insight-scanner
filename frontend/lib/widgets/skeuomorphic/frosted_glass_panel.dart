import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted glass panel — Apple-style blur backdrop.
/// Use for overlays, bottom sheets, scanner HUD panels.
class FrostedGlassPanel extends StatelessWidget {
  final Widget child;
  final double blurX;
  final double blurY;
  final Color? tintColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const FrostedGlassPanel({
    super.key,
    required this.child,
    this.blurX = 20,
    this.blurY = 20,
    this.tintColor,
    this.borderRadius = 24.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                (tintColor ?? Colors.white).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
