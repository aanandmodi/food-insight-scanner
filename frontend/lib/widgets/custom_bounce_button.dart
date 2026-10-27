import 'package:flutter/material.dart';
import '../theme/apple_motion.dart';

/// Legacy bounce button upgraded with Apple-style spring physics.
class CustomBounceButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;
  final Duration duration;

  const CustomBounceButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = AppleMotion.pressScaleButton,
    this.duration = AppleMotion.durationFast,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scaleFactor: scaleFactor,
      pressSpring: AppleMotion.snappy,
      releaseSpring: AppleMotion.smooth,
      child: child,
    );
  }
}

