// lib/widgets/motion/velocity_drag_dismissible.dart

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../theme/apple_motion.dart';

/// A gesture wrapper implementing Apple-grade gesture physics:
/// - 1:1 finger tracking with zero lag
/// - Non-linear rubber-banding when dragged past boundary
/// - Projected landing prediction via velocity & deceleration rate
/// - Seamless interruption and retargeting without snapping
/// - Continuous velocity handoff into spring animations
class VelocityDragDismissible extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDismiss;
  final Axis direction;
  final double dismissThreshold; // default: 120dp
  final bool enableRubberBand;

  const VelocityDragDismissible({
    super.key,
    required this.child,
    this.onDismiss,
    this.direction = Axis.vertical,
    this.dismissThreshold = 120.0,
    this.enableRubberBand = true,
  });

  @override
  State<VelocityDragDismissible> createState() => _VelocityDragDismissibleState();
}

class _VelocityDragDismissibleState extends State<VelocityDragDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _rawOffset = 0.0;
  bool _isDragging = false;

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

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _controller.stop(); // Seamless interrupt: stop at current position
    _rawOffset = _controller.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = widget.direction == Axis.vertical ? details.delta.dy : details.delta.dx;
    _rawOffset += delta;

    if (_rawOffset < 0 && widget.enableRubberBand) {
      // Rubber-band resistance when pulled past top limit
      final resistance = AppleMotion.rubberBand(_rawOffset, 400.0, 0.4);
      _controller.value = resistance;
    } else {
      // 1:1 finger tracking
      _controller.value = _rawOffset;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = widget.direction == Axis.vertical
        ? (details.primaryVelocity ?? 0.0)
        : (details.primaryVelocity ?? 0.0);

    // Calculate projected landing spot using Apple's deceleration projection
    final projected = AppleMotion.projectOffset(_controller.value, velocity);

    // Check if projected outcome reaches dismiss criteria
    final shouldDismiss = projected > widget.dismissThreshold || velocity > 750.0;

    if (shouldDismiss && widget.onDismiss != null) {
      HapticFeedback.lightImpact();
      // Continue motion toward dismissal with current velocity
      final dismissTarget = (_controller.value + 400.0).clamp(400.0, 1000.0);
      final sim = SpringSimulation(
        AppleMotion.smooth,
        _controller.value,
        dismissTarget,
        velocity,
      );
      _controller.animateWith(sim).whenComplete(() {
        if (mounted) widget.onDismiss?.call();
      });
    } else {
      // Soft haptic feedback when released and snapping back from a pull
      if (_rawOffset.abs() > 30.0) {
        HapticFeedback.lightImpact();
      }
      // Snap back to origin with spring physics preserving release momentum
      final sim = SpringSimulation(
        AppleMotion.smooth,
        _controller.value,
        0.0,
        velocity,
      );
      _controller.animateWith(sim);
      _rawOffset = 0.0;
    }
  }

  void _onDragCancel() {
    _isDragging = false;
    final sim = SpringSimulation(
      AppleMotion.smooth,
      _controller.value,
      0.0,
      _controller.velocity,
    );
    _controller.animateWith(sim);
    _rawOffset = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: widget.direction == Axis.vertical ? _onDragStart : null,
      onVerticalDragUpdate: widget.direction == Axis.vertical ? _onDragUpdate : null,
      onVerticalDragEnd: widget.direction == Axis.vertical ? _onDragEnd : null,
      onVerticalDragCancel: widget.direction == Axis.vertical ? _onDragCancel : null,
      onHorizontalDragStart: widget.direction == Axis.horizontal ? _onDragStart : null,
      onHorizontalDragUpdate: widget.direction == Axis.horizontal ? _onDragUpdate : null,
      onHorizontalDragEnd: widget.direction == Axis.horizontal ? _onDragEnd : null,
      onHorizontalDragCancel: widget.direction == Axis.horizontal ? _onDragCancel : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = _controller.value;
          final transform = widget.direction == Axis.vertical
              ? Matrix4.translationValues(0.0, offset, 0.0)
              : Matrix4.translationValues(offset, 0.0, 0.0);

          return Transform(
            transform: transform,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
