import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../theme/apple_motion.dart';
import '../../theme/app_design_system.dart';

/// Tactile button with physical press animation.
/// Shrinks and deepens shadow on press — feels like pushing a real button.
class SkeuButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final bool isDestructive;
  final double? width;

  const SkeuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.width,
  });

  @override
  State<SkeuButton> createState() => _SkeuButtonState();
}

class _SkeuButtonState extends State<SkeuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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

  Color get _bgColor {
    if (widget.isDestructive) return FoodInsightColors.healthRed;
    return widget.backgroundColor ?? FoodInsightColors.scannerGreen;
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.isLoading || widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
      return;
    }
    final sim = SpringSimulation(
      AppleMotion.snappy,
      _controller.value,
      1.0,
      _controller.velocity,
    );
    _controller.animateWith(sim);
  }

  void _onTapUp(TapUpDetails _) {
    _animateRelease();
    if (!widget.isLoading) {
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    _animateRelease();
  }

  void _animateRelease() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.0;
      return;
    }
    final sim = SpringSimulation(
      AppleMotion.smooth,
      _controller.value,
      0.0,
      _controller.velocity,
    );
    _controller.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value.clamp(0.0, 1.2);
          final scale = 1.0 - (1.0 - AppleMotion.pressScaleButton) * progress;
          final shadow = (1.0 - 0.7 * progress).clamp(0.0, 1.0);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.width,
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: FoodInsightRadius.lgAll,
                boxShadow: [
                  BoxShadow(
                    color:
                        _bgColor.withValues(alpha: 0.4 * shadow),
                    blurRadius: 20 * shadow,
                    offset: Offset(0, 8 * shadow),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
                // Glossy top sheen over solid color
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(
                        _bgColor, Colors.white, 0.15)!,
                    _bgColor,
                  ],
                  stops: const [0.0, 0.5],
                ),
              ),
              child: child,
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:
              widget.width == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (widget.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else ...[
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: widget.textColor ?? Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: FoodInsightTypography.body(
                  weight: FontWeight.w700,
                  color: widget.textColor ?? Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
