import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AllergySelectionWidget extends StatefulWidget {
  final List<String> selectedAllergies;
  final Function(List<String>) onAllergyChanged;

  const AllergySelectionWidget({
    super.key,
    required this.selectedAllergies,
    required this.onAllergyChanged,
  });

  @override
  State<AllergySelectionWidget> createState() => _AllergySelectionWidgetState();
}

class _AllergySelectionWidgetState extends State<AllergySelectionWidget> {
  final List<String> commonAllergies = [
    'Nuts',
    'Dairy',
    'Gluten',
    'Eggs',
    'Soy',
    'Fish',
    'Shellfish',
    'Sesame'
  ];

  bool _showCustomInput = false;
  final TextEditingController _customAllergyController =
      TextEditingController();

  void _toggleAllergy(String allergy) {
    List<String> updatedAllergies = List.from(widget.selectedAllergies);

    if (updatedAllergies.contains(allergy)) {
      updatedAllergies.remove(allergy);
    } else {
      updatedAllergies.add(allergy);
    }

    widget.onAllergyChanged(updatedAllergies);
  }

  void _addCustomAllergy() {
    if (_customAllergyController.text.trim().isNotEmpty) {
      String customAllergy = _customAllergyController.text.trim();
      if (!widget.selectedAllergies.contains(customAllergy)) {
        List<String> updatedAllergies = List.from(widget.selectedAllergies);
        updatedAllergies.add(customAllergy);
        widget.onAllergyChanged(updatedAllergies);
      }
      _customAllergyController.clear();
      setState(() {
        _showCustomInput = false;
      });
    }
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
                iconName: 'warning',
                color: AppTheme.lightTheme.colorScheme.error,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                'Allergies & Restrictions',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Select any food allergies or dietary restrictions you have:',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 2.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: [
              ...commonAllergies.map((allergy) => _buildAllergyChip(allergy)),
              _buildCustomChip(),
            ],
          ),
          if (_showCustomInput) ...[
            SizedBox(height: 2.h),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _customAllergyController,
                decoration: InputDecoration(
                  hintText: 'Enter custom allergy',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 2.h,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _addCustomAllergy,
                        icon: CustomIconWidget(
                          iconName: 'check',
                          color: AppTheme.lightTheme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showCustomInput = false;
                            _customAllergyController.clear();
                          });
                        },
                        icon: CustomIconWidget(
                          iconName: 'close',
                          color: AppTheme.lightTheme.colorScheme.error,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                onSubmitted: (_) => _addCustomAllergy(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllergyChip(String allergy) {
    final bool isSelected = widget.selectedAllergies.contains(allergy);

    return GestureDetector(
      onTap: () => _toggleAllergy(allergy),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.lightTheme.colorScheme.primary
              : AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.primary
                : AppTheme.lightTheme.colorScheme.outline,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.lightTheme.colorScheme.primary
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: EdgeInsets.only(right: 1.w),
                child: CustomIconWidget(
                  iconName: 'check',
                  color: AppTheme.lightTheme.colorScheme.onPrimary,
                  size: 16,
                ),
              ),
            Text(
              allergy,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.onPrimary
                    : AppTheme.lightTheme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomChip() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomInput = !_showCustomInput;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.lightTheme.colorScheme.primary,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomIconWidget(
              iconName: 'add',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 16,
            ),
            SizedBox(width: 1.w),
            Text(
              'Custom',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customAllergyController.dispose();
    super.dispose();
  }
}
