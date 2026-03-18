import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class NutritionBarsWidget extends StatefulWidget {
  final Map<String, dynamic> nutritionData;

  const NutritionBarsWidget({
    super.key,
    required this.nutritionData,
  });

  @override
  State<NutritionBarsWidget> createState() => _NutritionBarsWidgetState();
}

class _NutritionBarsWidgetState extends State<NutritionBarsWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationControllers = List.generate(
      4,
      (index) => AnimationController(
        duration: Duration(milliseconds: 800 + (index * 200)),
        vsync: this,
      ),
    );

    _animations = _animationControllers
        .map((controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
            ))
        .toList();

    // Start animations with delay
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _animationControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Color _getSafetyColor(String nutrient, double value) {
    switch (nutrient.toLowerCase()) {
      case 'calories':
        if (value > 400) return Colors.red;
        if (value > 200) return Colors.orange;
        return AppTheme.lightTheme.colorScheme.primary;
      case 'sugar':
        if (value > 15) return Colors.red;
        if (value > 8) return Colors.orange;
        return AppTheme.lightTheme.colorScheme.primary;
      case 'sodium':
        if (value > 600) return Colors.red;
        if (value > 300) return Colors.orange;
        return AppTheme.lightTheme.colorScheme.primary;
      case 'protein':
        if (value < 5) return Colors.orange;
        return AppTheme.lightTheme.colorScheme.primary;
      default:
        return AppTheme.lightTheme.colorScheme.primary;
    }
  }

  double _getNormalizedValue(String nutrient, double value) {
    switch (nutrient.toLowerCase()) {
      case 'calories':
        return (value / 500).clamp(0.0, 1.0);
      case 'sugar':
        return (value / 25).clamp(0.0, 1.0);
      case 'sodium':
        return (value / 1000).clamp(0.0, 1.0);
      case 'protein':
        return (value / 30).clamp(0.0, 1.0);
      default:
        return 0.5;
    }
  }

  Widget _buildNutritionBar({
    required String label,
    required double value,
    required String unit,
    required int index,
  }) {
    final normalizedValue = _getNormalizedValue(label, value);
    final safetyColor = _getSafetyColor(label, value);

    return AnimatedBuilder(
      animation: _animations[index],
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.only(bottom: 2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTheme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$unit',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: safetyColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.2),
                ),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: AppTheme.lightTheme.colorScheme.outline
                            .withValues(alpha: 0.1),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: normalizedValue * _animations[index].value,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              safetyColor.withValues(alpha: 0.7),
                              safetyColor,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: safetyColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final calories =
        (widget.nutritionData['calories'] as num?)?.toDouble() ?? 0.0;
    final sugar = (widget.nutritionData['sugar'] as num?)?.toDouble() ?? 0.0;
    final protein =
        (widget.nutritionData['protein'] as num?)?.toDouble() ?? 0.0;
    final sodium = (widget.nutritionData['sodium'] as num?)?.toDouble() ?? 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.9),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: 'bar_chart',
                size: 24,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
              SizedBox(width: 2.w),
              Text(
                'Nutrition Facts',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          _buildNutritionBar(
            label: 'Calories',
            value: calories,
            unit: ' kcal',
            index: 0,
          ),
          _buildNutritionBar(
            label: 'Sugar',
            value: sugar,
            unit: 'g',
            index: 1,
          ),
          _buildNutritionBar(
            label: 'Protein',
            value: protein,
            unit: 'g',
            index: 2,
          ),
          _buildNutritionBar(
            label: 'Sodium',
            value: sodium,
            unit: 'mg',
            index: 3,
          ),
        ],
      ),
    );
  }
}
