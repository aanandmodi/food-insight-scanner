import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../theme/apple_motion.dart';
import '../theme/app_theme.dart';

/// A button widget with glow bloom effect and squishy press animation.
/// Features haptic feedback and Apple-style spring physics on tap.
class GlowButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? glowColor;
  final double glowIntensity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool enableHaptic;

  const GlowButton({
    super.key,
    required this.child,
    this.onTap,
    this.glowColor,
    this.glowIntensity = 0.3,
    this.borderRadius = 999.0,
    this.padding,
    this.enableHaptic = true,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _scaleController.value = 1.0;
      return;
    }
    final sim = SpringSimulation(
      AppleMotion.snappy,
      _scaleController.value,
      1.0,
      _scaleController.velocity,
    );
    _scaleController.animateWith(sim);
  }

  void _handleTapUp(TapUpDetails details) {
    _animateRelease();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _animateRelease();
  }

  void _animateRelease() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scaleController.value = 0.0;
      return;
    }
    final sim = SpringSimulation(
      AppleMotion.smooth,
      _scaleController.value,
      0.0,
      _scaleController.velocity,
    );
    _scaleController.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = widget.glowColor ??
        (isDark ? AppTheme.primaryDark : AppTheme.primaryLight);

    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        final progress = _scaleController.value.clamp(0.0, 1.25);
        final scale = 1.0 - (1.0 - 0.95) * progress;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: isDark
                  ? AppTheme.glowBoxShadow(
                      glow,
                      intensity: widget.glowIntensity,
                    )
                  : const [
                      BoxShadow(
                        color: Color(0x4DBA0034),
                        blurRadius: 15,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
