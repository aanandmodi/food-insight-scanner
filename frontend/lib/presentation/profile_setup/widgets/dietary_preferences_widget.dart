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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Expanded(
                  child: Text(
                'Dietary Preferences',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              )),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'Select all dietary preferences that apply to you:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: 2.h),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.5
                ? 2
                : 1;
            const gap = 12.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final option in dietaryOptions)
                SizedBox(width: width, child: _buildPreferenceCard(option)),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _buildPreferenceCard(Map<String, dynamic> option) {
    final bool isSelected =
        widget.selectedPreferences.contains(option['value']);

    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: .08)
              : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.outline.withValues(alpha: .2),
              width: 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _togglePreference(option['value']),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(10)),
                        child: CustomIconWidget(
                            iconName: option['icon'],
                            color: colors.primary,
                            size: 22),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: colors.primary, size: 22),
                    ]),
                    const SizedBox(height: 12),
                    Text(option['label'],
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(option['description'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant, height: 1.4)),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
