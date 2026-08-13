import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../data/providers/activity_provider.dart';
import '../../../theme/app_design_system.dart';
import '../../../widgets/skeuomorphic/skeu_card.dart';

class ActivitySummaryCard extends StatelessWidget {
  const ActivitySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: const SkeuCard(
              child: SizedBox(
                height: 160,
                child: Center(
                  child: CircularProgressIndicator(
                    color: FoodInsightColors.scannerGreen,
                  ),
                ),
              ),
            ),
          );
        }

        final steps = provider.steps;
        final stepGoal = provider.dailyStepGoal;
        final stepPct = stepGoal > 0 ? (steps / stepGoal).clamp(0.0, 1.0) : 0.0;

        final calories = provider.activeCalories;
        final calorieGoal = provider.dailyCalorieGoal;
        final caloriePct = calorieGoal > 0 ? (calories / calorieGoal).clamp(0.0, 1.0) : 0.0;

        final distanceKm = provider.distanceKm;
        final distanceGoal = provider.dailyDistanceGoal;
        final distancePct = distanceGoal > 0 ? (distanceKm / distanceGoal).clamp(0.0, 1.0) : 0.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: SkeuCard(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row: Title & Badge ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: FoodInsightColors.scannerGreen,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ACTIVITY & STEPS',
                          style: FoodInsightTypography.smallCaps(
                            size: 11,
                            weight: FontWeight.w900,
                            color: FoodInsightColors.deepCharcoal.withValues(alpha: 0.8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: FoodInsightColors.scannerGreen.withValues(alpha: 0.08),
                        borderRadius: FoodInsightRadius.pillAll,
                      ),
                      child: Text(
                        'Goal: ${_formatNumber(stepGoal)} steps',
                        style: FoodInsightTypography.caption(
                          size: 11,
                          weight: FontWeight.w800,
                          color: FoodInsightColors.scannerGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Main Content: Left Step Ring, Right Progress Details ──
                Row(
                  children: [
                    // Step Progress Ring
                    Expanded(
                      flex: 11,
                      child: Center(
                        child: _StepRing(
                          steps: steps,
                          stepGoal: stepGoal,
                          progress: stepPct,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Activity Details Panel
                    Expanded(
                      flex: 13,
                      child: Column(
                        children: [
                          _ActivityProgressRow(
                            label: 'Steps',
                            currentStr: _formatNumber(steps),
                            goalStr: _formatNumber(stepGoal),
                            progress: stepPct,
                            color: FoodInsightColors.scannerGreen,
                            unit: '',
                          ),
                          const SizedBox(height: 12),
                          _ActivityProgressRow(
                            label: 'Active Cals',
                            currentStr: _formatNumber(calories),
                            goalStr: _formatNumber(calorieGoal),
                            progress: caloriePct,
                            color: const Color(0xFFFF5252),
                            unit: 'kcal',
                          ),
                          const SizedBox(height: 12),
                          _ActivityProgressRow(
                            label: 'Distance',
                            currentStr: distanceKm.toStringAsFixed(1),
                            goalStr: distanceGoal.toStringAsFixed(1),
                            progress: distancePct,
                            color: FoodInsightColors.carbsBlue,
                            unit: 'km',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = (n % 1000).toString().padLeft(3, '0');
      return '$thousands,$remainder';
    }
    return n.toString();
  }
}

// ─────────────────────────────────────────────────────────────────
//  STEP RING — Glossy Skeuomorphic Progress Ring
// ─────────────────────────────────────────────────────────────────
class _StepRing extends StatefulWidget {
  final int steps;
  final int stepGoal;
  final double progress;

  const _StepRing({
    required this.steps,
    required this.stepGoal,
    required this.progress,
  });

  @override
  State<_StepRing> createState() => _StepRingState();
}

class _StepRingState extends State<_StepRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(
        parent: _controller,
        curve: FoodInsightAnimations.emphasizedDecelerate,
      ),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_StepRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: FoodInsightAnimations.emphasizedDecelerate,
      ));
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
    const double ringSize = 135;
    const double strokeWidth = 12;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ring track background glow (skeuomorphic depth)
              Container(
                width: ringSize - strokeWidth,
                height: ringSize - strokeWidth,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: FoodInsightColors.scannerGreen.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Main ring custom paint
              CustomPaint(
                size: const Size(ringSize, ringSize),
                painter: _GradientRingPainter(
                  progress: _animation.value,
                  gradient: const LinearGradient(
                    colors: [
                      FoodInsightColors.scannerGreen,
                      Color(0xFF34D399),
                    ],
                  ),
                  trackColor: FoodInsightColors.scannerGreen.withValues(alpha: 0.08),
                  strokeWidth: strokeWidth,
                ),
              ),
              // Center texts
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatSteps(widget.steps),
                    style: FoodInsightTypography.display(
                      size: 24,
                      weight: FontWeight.w900,
                      color: FoodInsightColors.deepCharcoal,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'STEPS',
                    style: FoodInsightTypography.smallCaps(
                      size: 10,
                      weight: FontWeight.w800,
                      color: FoodInsightColors.midGray,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 100000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    } else if (steps >= 1000) {
      final thousands = steps ~/ 1000;
      final remainder = (steps % 1000).toString().padLeft(3, '0');
      return '$thousands,$remainder';
    }
    return steps.toString();
  }
}

// ─────────────────────────────────────────────────────────────────
//  ACTIVITY PROGRESS ROW — Capsule Style Progress Bar
// ─────────────────────────────────────────────────────────────────
class _ActivityProgressRow extends StatelessWidget {
  final String label;
  final String currentStr;
  final String goalStr;
  final double progress;
  final Color color;
  final String unit;

  const _ActivityProgressRow({
    required this.label,
    required this.currentStr,
    required this.goalStr,
    required this.progress,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final String valueText = unit.isEmpty
        ? '$currentStr/$goalStr'
        : '$currentStr/$goalStr $unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: FoodInsightTypography.body(
                size: 13,
                weight: FontWeight.w700,
                color: FoodInsightColors.deepCharcoal,
              ),
            ),
            Text(
              valueText,
              style: FoodInsightTypography.caption(
                size: 11,
                weight: FontWeight.w700,
                color: FoodInsightColors.midGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress track capsule
        Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  GRADIENT RING PAINTER
// ─────────────────────────────────────────────────────────────────
class _GradientRingPainter extends CustomPainter {
  final double progress;
  final Gradient gradient;
  final Color trackColor;
  final double strokeWidth;

  _GradientRingPainter({
    required this.progress,
    required this.gradient,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress Arc
    if (progress > 0) {
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) =>
      old.progress != progress || old.trackColor != trackColor;
}

