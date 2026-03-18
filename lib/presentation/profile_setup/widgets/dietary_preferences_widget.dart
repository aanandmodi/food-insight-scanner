import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class DietaryPreferencesWidget extends StatefulWidget {
  final List<String> selectedPreferences;
  final Function(List<String>) onPreferencesChanged;

  const DietaryPreferencesWidget({
    super.key,
    required this.selectedPreferences,
    required this.onPreferencesChanged,
  });

  @override
  State<DietaryPreferencesWidget> createState() =>
      _DietaryPreferencesWidgetState();
}

class _DietaryPreferencesWidgetState extends State<DietaryPreferencesWidget> {
  final List<Map<String, dynamic>> dietaryOptions = [
    {
      'value': 'vegetarian',
      'label': 'Vegetarian',
      'icon': 'eco',
      'description': 'No meat, fish, or poultry',
      'color': Colors.green,
    },
    {
      'value': 'vegan',
      'label': 'Vegan',
      'icon': 'local_florist',
      'description': 'No animal products',
      'color': Colors.lightGreen,
    },
    {
      'value': 'keto',
      'label': 'Keto',
      'icon': 'whatshot',
      'description': 'Low carb, high fat',
      'color': Colors.orange,
    },
    {
      'value': 'paleo',
      'label': 'Paleo',
      'icon': 'nature_people',
      'description': 'Whole foods, no processed',
      'color': Colors.brown,
    },
    {
      'value': 'gluten_free',
      'label': 'Gluten-Free',
      'icon': 'no_meals',
      'description': 'No gluten-containing grains',
      'color': Colors.amber,
    },
    {
      'value': 'dairy_free',
      'label': 'Dairy-Free',
      'icon': 'block',
      'description': 'No dairy products',
      'color': Colors.blue,
    },
  ];

  void _togglePreference(String preference) {
    List<String> updatedPreferences = List.from(widget.selectedPreferences);

    if (updatedPreferences.contains(preference)) {
      updatedPreferences.remove(preference);
    } else {
      updatedPreferences.add(preference);
    }

    widget.onPreferencesChanged(updatedPreferences);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: 'restaurant_menu',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                'Dietary Preferences',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'Select all dietary preferences that apply to you:',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 2.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 2.h,
              childAspectRatio: 2.5,
            ),
            itemCount: dietaryOptions.length,
            itemBuilder: (context, index) {
              return _buildPreferenceCard(dietaryOptions[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceCard(Map<String, dynamic> option) {
    final bool isSelected =
        widget.selectedPreferences.contains(option['value']);

    return GestureDetector(
      onTap: () => _togglePreference(option['value']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1)
              : AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.primary
                : AppTheme.lightTheme.colorScheme.outline
                    .withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.lightTheme.colorScheme.primary
                        .withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(1.5.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.lightTheme.colorScheme.primary
                        : (option['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: CustomIconWidget(
                    iconName: option['icon'],
                    color: isSelected
                        ? AppTheme.lightTheme.colorScheme.onPrimary
                        : option['color'],
                    size: 16,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  CustomIconWidget(
                    iconName: 'check_circle',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 18,
                  ),
              ],
            ),
            SizedBox(height: 1.h),
            Text(
              option['label'],
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              option['description'],
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                fontSize: 10.sp,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
