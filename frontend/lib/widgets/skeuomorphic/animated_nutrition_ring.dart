import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';

/// Animated ring chart for nutrition values.
/// Draws with spring animation on mount. Apple Health-style.
class AnimatedNutritionRing extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final double maxValue;
  final double currentValue;
  final String label;
  final String unit;
  final Color ringColor;
  final double size;

  const AnimatedNutritionRing({
    super.key,
    required this.value,
    required this.maxValue,
    required this.currentValue,
    required this.label,
    required this.unit,
    required this.ringColor,
    this.size = 80,
  });

  @override
  State<AnimatedNutritionRing> createState() => _AnimatedNutritionRingState();
}

class _AnimatedNutritionRingState extends State<AnimatedNutritionRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: FoodInsightAnimations.slow,
    );
    _animation =
        Tween<double>(begin: 0, end: widget.value.clamp(0.0, 1.0)).animate(
      CurvedAnimation(
          parent: _controller,
          curve: FoodInsightAnimations.emphasizedDecelerate),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedNutritionRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation =
          Tween<double>(begin: _animation.value, end: widget.value.clamp(0.0, 1.0))
              .animate(CurvedAnimation(
                  parent: _controller,
                  curve: FoodInsightAnimations.emphasizedDecelerate));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: _animation.value,
                  ringColor: widget.ringColor,
                  trackColor: widget.ringColor.withValues(alpha: 0.15),
                  strokeWidth: widget.size * 0.1,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.currentValue > 999
                            ? '${(widget.currentValue / 1000).toStringAsFixed(1)}k'
                            : widget.currentValue.toStringAsFixed(0),
                        style: FoodInsightTypography.caption(
                          size: widget.size * 0.18,
                          weight: FontWeight.w700,
                          color: FoodInsightColors.deepCharcoal,
                        ),
                      ),
                      Text(
                        widget.unit,
                        style: FoodInsightTypography.caption(
                          size: widget.size * 0.12,
                          color: FoodInsightColors.midGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          widget.label,
          style:
              FoodInsightTypography.caption(size: 11, weight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90 degrees (start at top)
      6.2832, // Full circle
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress,
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
