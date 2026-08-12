import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/app_design_system.dart';
import '../../../widgets/skeuomorphic/skeu_card.dart';

class NutritionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> nutritionData;

  const NutritionSummaryCard({
    super.key,
    required this.nutritionData,
  });

  @override
  Widget build(BuildContext context) {
    final calories = (nutritionData['calories'] as num?)?.toInt() ?? 0;
    final caloriesGoal =
        (nutritionData['caloriesGoal'] as num?)?.toInt() ?? 2000;
    final sugar = (nutritionData['sugar'] as num?)?.toInt() ?? 0;
    final protein = (nutritionData['protein'] as num?)?.toInt() ?? 0;
    final proteinGoal =
        (nutritionData['proteinGoal'] as num?)?.toInt() ?? 150;

    final caloriesPct =
        caloriesGoal > 0 ? (calories / caloriesGoal).clamp(0.0, 1.0) : 0.0;
    final proteinPct =
        proteinGoal > 0 ? (protein / proteinGoal).clamp(0.0, 1.0) : 0.0;

    // Derive carbs & fat from logged intake or remaining calories
    final fat = (nutritionData['fat'] as num?)?.round() ??
        (math.max(0, calories - (protein * 4) - (sugar * 4)) / 9).round();
    final fatGoal = (nutritionData['fatGoal'] as num?)?.toInt() ?? 65;
    final fatPct = fatGoal > 0 ? (fat / fatGoal).clamp(0.0, 1.0) : 0.0;

    final carbs = (nutritionData['carbs'] as num?)?.round() ?? sugar;
    final carbsGoal = (nutritionData['carbsGoal'] as num?)?.toInt() ??
        (caloriesGoal > 0 ? (caloriesGoal * 0.5 / 4).round() : 250);
    final carbsPct =
        carbsGoal > 0 ? (carbs / carbsGoal).clamp(0.0, 1.0) : 0.0;


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
                        color: FoodInsightColors.ctaRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAILY SUMMARY',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FoodInsightColors.ctaRed.withValues(alpha: 0.08),
                    borderRadius: FoodInsightRadius.pillAll,
                  ),
                  child: Text(
                    'Goal: ${_formatNumber(caloriesGoal)} kcal',
                    style: FoodInsightTypography.caption(
                      size: 11,
                      weight: FontWeight.w800,
                      color: FoodInsightColors.ctaRed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Main Content: Left Ring, Right Progress Details ──
            Row(
              children: [
                // Calorie Ring
                Expanded(
                  flex: 11,
                  child: Center(
                    child: _CalorieRing(
                      calories: calories,
                      caloriesGoal: caloriesGoal,
                      progress: caloriesPct,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Macros Info Panel
                Expanded(
                  flex: 13,
                  child: Column(
                    children: [
                      _MacroProgressRow(
                        label: 'Carbs',
                        current: carbs,
                        goal: carbsGoal,
                        progress: carbsPct,
                        color: FoodInsightColors.carbsBlue,
                        unit: 'g',
                      ),
                      const SizedBox(height: 12),
                      _MacroProgressRow(
                        label: 'Protein',
                        current: protein,
                        goal: proteinGoal,
                        progress: proteinPct,
                        color: FoodInsightColors.scannerGreen,
                        unit: 'g',
                      ),
                      const SizedBox(height: 12),
                      _MacroProgressRow(
                        label: 'Fat',
                        current: fat,
                        goal: fatGoal,
                        progress: fatPct,
                        color: FoodInsightColors.fatYellow,
                        unit: 'g',
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
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(0)},${(n % 1000).toString().padLeft(3, '0')}';
    }
    return n.toString();
  }
}

// ─────────────────────────────────────────────────────────────────
//  CALORIE RING — Glossy Skeuomorphic Progress Ring
// ─────────────────────────────────────────────────────────────────
class _CalorieRing extends StatefulWidget {
  final int calories;
  final int caloriesGoal;
  final double progress;

  const _CalorieRing({
    required this.calories,
    required this.caloriesGoal,
    required this.progress,
  });

  @override
  State<_CalorieRing> createState() => _CalorieRingState();
}

class _CalorieRingState extends State<_CalorieRing>
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
  void didUpdateWidget(_CalorieRing oldWidget) {
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
                      color: FoodInsightColors.ctaRed.withValues(alpha: 0.03),
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
                      FoodInsightColors.ctaRed,
                      Color(0xFFFF5E7E),
                    ],
                  ),
                  trackColor: FoodInsightColors.ctaRed.withValues(alpha: 0.08),
                  strokeWidth: strokeWidth,
                ),
              ),
              // Center texts
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatCalories(widget.calories),
                    style: FoodInsightTypography.display(
                      size: 26,
                      weight: FontWeight.w900,
                      color: FoodInsightColors.deepCharcoal,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'KCAL',
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

  String _formatCalories(int cal) {
    if (cal >= 1000) {
      final thousands = cal ~/ 1000;
      final remainder = (cal % 1000).toString().padLeft(3, '0');
      return '$thousands,$remainder';
    }
    return cal.toString();
  }
}

// ─────────────────────────────────────────────────────────────────
//  MACRO PROGRESS ROW — Capsule Style Progress Bar
// ─────────────────────────────────────────────────────────────────
class _MacroProgressRow extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  final double progress;
  final Color color;
  final String unit;

  const _MacroProgressRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.progress,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
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
              '$current/$goal $unit',
              style: FoodInsightTypography.caption(
                size: 11,
                weight: FontWeight.w700,
                color: FoodInsightColors.midGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress track
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
