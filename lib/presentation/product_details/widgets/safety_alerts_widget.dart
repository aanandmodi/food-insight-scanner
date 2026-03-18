import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SafetyAlertsWidget extends StatelessWidget {
  final List<String> userAllergies;
  final List<String> ingredients;
  final String dietaryPreference;
  final Map<String, dynamic> nutritionData;

  const SafetyAlertsWidget({
    super.key,
    required this.userAllergies,
    required this.ingredients,
    required this.dietaryPreference,
    required this.nutritionData,
  });

  List<Map<String, dynamic>> _generateAlerts() {
    List<Map<String, dynamic>> alerts = [];

    // Check for allergen warnings
    for (String allergy in userAllergies) {
      bool containsAllergen = (ingredients as List).any((dynamic ingredient) =>
          (ingredient as String).toLowerCase().contains(allergy.toLowerCase()));

      if (containsAllergen) {
        alerts.add({
          'type': 'danger',
          'title': 'Allergen Warning',
          'message': 'Contains $allergy - Avoid this product',
          'icon': 'warning',
        });
      }
    }

    // Check dietary compatibility
    if (dietaryPreference.toLowerCase() == 'vegetarian') {
      bool containsMeat = (ingredients as List).any((dynamic ingredient) {
        String ing = (ingredient as String).toLowerCase();
        return ing.contains('chicken') ||
            ing.contains('beef') ||
            ing.contains('pork') ||
            ing.contains('fish') ||
            ing.contains('meat');
      });

      if (containsMeat) {
        alerts.add({
          'type': 'warning',
          'title': 'Dietary Alert',
          'message': 'Contains meat - Not suitable for vegetarians',
          'icon': 'restaurant',
        });
      }
    }

    if (dietaryPreference.toLowerCase() == 'vegan') {
      bool containsAnimalProducts =
          (ingredients as List).any((dynamic ingredient) {
        String ing = (ingredient as String).toLowerCase();
        return ing.contains('milk') ||
            ing.contains('egg') ||
            ing.contains('honey') ||
            ing.contains('cheese') ||
            ing.contains('butter') ||
            ing.contains('cream');
      });

      if (containsAnimalProducts) {
        alerts.add({
          'type': 'warning',
          'title': 'Dietary Alert',
          'message': 'Contains animal products - Not suitable for vegans',
          'icon': 'eco',
        });
      }
    }

    // Check nutrition warnings
    final calories = (nutritionData['calories'] as num?)?.toDouble() ?? 0.0;
    final sugar = (nutritionData['sugar'] as num?)?.toDouble() ?? 0.0;
    final sodium = (nutritionData['sodium'] as num?)?.toDouble() ?? 0.0;

    if (calories > 400) {
      alerts.add({
        'type': 'caution',
        'title': 'High Calorie Content',
        'message':
            'This product is high in calories (${calories.toInt()} kcal)',
        'icon': 'local_fire_department',
      });
    }

    if (sugar > 15) {
      alerts.add({
        'type': 'caution',
        'title': 'High Sugar Content',
        'message':
            'This product is high in sugar (${sugar.toStringAsFixed(1)}g)',
        'icon': 'cake',
      });
    }

    if (sodium > 600) {
      alerts.add({
        'type': 'caution',
        'title': 'High Sodium Content',
        'message': 'This product is high in sodium (${sodium.toInt()}mg)',
        'icon': 'grain',
      });
    }

    // Add positive alerts if no issues
    if (alerts.isEmpty) {
      alerts.add({
        'type': 'success',
        'title': 'Safe for You',
        'message':
            'This product matches your dietary preferences and contains no known allergens',
        'icon': 'check_circle',
      });
    }

    return alerts;
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'danger':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'caution':
        return Colors.amber;
      case 'success':
        return AppTheme.lightTheme.colorScheme.primary;
      default:
        return AppTheme.lightTheme.colorScheme.primary;
    }
  }

  Widget _buildAlert(Map<String, dynamic> alert) {
    final color = _getAlertColor(alert['type']);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomIconWidget(
              iconName: alert['icon'],
              size: 24,
              color: color,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'],
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  alert['message'],
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _generateAlerts();

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
                iconName: 'security',
                size: 24,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
              SizedBox(width: 2.w),
              Text(
                'Safety & Compatibility',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          ...alerts.map((alert) => _buildAlert(alert)),
        ],
      ),
    );
  }
}
