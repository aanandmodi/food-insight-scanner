// lib/theme/apple_motion.dart

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Centralized Apple-style motion system definitions and physics springs.
///
/// Provides spring curves, standard scales, duration tokens, and GPU-accelerated
/// press scale interactions.
class AppleMotion {
  AppleMotion._();

  // ──────────────────────────── Springs ────────────────────────────
  /// Smooth spring: critically damped (~1.0), medium stiffness.
  /// Used for releases, dismissals, and natural settles.
  static const SpringDescription smooth = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 26.8, // damping ratio ~ 1.0
  );

  /// Snappy spring: slightly underdamped (~0.85), higher stiffness.
  /// Used for interactive taps, presses, and direct feedback.
  static const SpringDescription snappy = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 30.4, // damping ratio ~ 0.85
  );

  /// Bouncy spring: underdamped (~0.70), medium-low stiffness.
  /// Used sparingly for delightful feedback (e.g. active tab selection pop).
  static const SpringDescription bouncy = SpringDescription(
    mass: 1.0,
    stiffness: 150.0,
    damping: 17.1, // damping ratio ~ 0.70
  );

  // ────────────────────── Scale & Durations ──────────────────────
  /// Scale multiplier applied on press for standard buttons and list items.
  static const double pressScaleButton = 0.96;

  /// Scale multiplier applied on press for larger cards and sections.
  static const double pressScaleCard = 0.98;

  /// Scale multiplier applied on active pop for bottom navbar items.
  static const double activeScaleNavbarItem = 1.08;

  /// Small standard animation durations (for non-simulated fallbacks).
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationStandard = Duration(milliseconds: 300);
  static const Duration durationRelaxed = Duration(milliseconds: 500);

  /// iOS standard deceleration rate for velocity projections.
  static const double decelerationRate = 0.998;

  /// Deceleration projection formula: x_final = x_0 + v / (1 - d)
  static double projectOffset(double initialOffset, double velocity) {
    return initialOffset + (velocity / (1000 * (1.0 - decelerationRate)));
  }

  /// Rubber-banding resistance curve for drag boundaries and overscroll.
  /// f(x) = (x * c) / (x + c)
  static double rubberBand(double overscroll, double dimension, [double coefficient = 0.55]) {
    final c = dimension * coefficient;
    return (overscroll * c) / (overscroll.abs() + c);
  }
}

/// A tactile wrapper widget that applies an Apple-style spring press scale
/// without altering the component's layout dimensions.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final SpringDescription pressSpring;
  final SpringDescription releaseSpring;
  final bool enableHaptic;
  final HitTestBehavior behavior;
  final Alignment alignment;
  final bool enabled;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = AppleMotion.pressScaleButton,
    this.pressSpring = AppleMotion.snappy,
    this.releaseSpring = AppleMotion.smooth,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
    this.alignment = Alignment.center,
    this.enabled = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isDown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    _isDown = true;
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
      return;
    }
    final sim = SpringSimulation(
      widget.pressSpring,
      _controller.value,
      1.0,
      _controller.velocity,
    );
    _controller.animateWith(sim);
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isDown) return;
    _isDown = false;
    _animateRelease();
    if (widget.enabled) {
      widget.onTap?.call();
    }
  }

  void _onTapCancel() {
    if (!_isDown) return;
    _isDown = false;
    _animateRelease();
  }

  void _animateRelease() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.0;
      return;
    }
    final sim = SpringSimulation(
      widget.releaseSpring,
      _controller.value,
      0.0,
      _controller.velocity,
    );
    _controller.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled && widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Linear interpolation between 1.0 (unpressed) and scaleFactor (pressed)
          final progress = _controller.value.clamp(0.0, 1.25);
          final scale = 1.0 - (1.0 - widget.scaleFactor) * progress;
          return Transform.scale(
            scale: scale,
            alignment: widget.alignment,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Extension for adding [pressScale] cleanly to any Widget without layout modification.
extension AppleMotionExtension on Widget {
  Widget pressScale({
    Key? key,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double scaleFactor = AppleMotion.pressScaleButton,
    SpringDescription pressSpring = AppleMotion.snappy,
    SpringDescription releaseSpring = AppleMotion.smooth,
    bool enableHaptic = true,
    HitTestBehavior behavior = HitTestBehavior.opaque,
    Alignment alignment = Alignment.center,
    bool enabled = true,
  }) {
    return PressScale(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: scaleFactor,
      pressSpring: pressSpring,
      releaseSpring: releaseSpring,
      enableHaptic: enableHaptic,
      behavior: behavior,
      alignment: alignment,
      enabled: enabled,
      child: this,
    );
  }
}

/// App-wide Apple scroll behavior providing smooth scrolling and
/// iOS-style rubber-band bouncing overscroll physics across all platforms.
class AppleScrollBehavior extends MaterialScrollBehavior {
  const AppleScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
