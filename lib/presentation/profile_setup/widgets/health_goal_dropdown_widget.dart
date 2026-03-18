import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class HealthGoalDropdownWidget extends StatefulWidget {
  final String? selectedGoal;
  final Function(String?) onGoalChanged;

  const HealthGoalDropdownWidget({
    super.key,
    required this.selectedGoal,
    required this.onGoalChanged,
  });

  @override
  State<HealthGoalDropdownWidget> createState() =>
      _HealthGoalDropdownWidgetState();
}

class _HealthGoalDropdownWidgetState extends State<HealthGoalDropdownWidget> {
  final List<Map<String, dynamic>> healthGoals = [
    {
      'value': 'weight_loss',
      'label': 'Weight Loss',
      'icon': 'trending_down',
      'description': 'Reduce body weight and improve fitness'
    },
    {
      'value': 'muscle_gain',
      'label': 'Muscle Gain',
      'icon': 'fitness_center',
      'description': 'Build muscle mass and strength'
    },
    {
      'value': 'maintenance',
      'label': 'Maintenance',
      'icon': 'balance',
      'description': 'Maintain current weight and health'
    },
    {
      'value': 'general_health',
      'label': 'General Health',
      'icon': 'favorite',
      'description': 'Overall wellness and nutrition'
    },
  ];

  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'track_changes',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Health Goal',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'What\'s your primary health objective?',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isExpanded
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.outline,
                  width: _isExpanded ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (widget.selectedGoal != null) ...[
                    CustomIconWidget(
                      iconName: _getSelectedGoalIcon(),
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 3.w),
                  ],
                  Expanded(
                    child: Text(
                      widget.selectedGoal != null
                          ? _getSelectedGoalLabel()
                          : 'Select your health goal',
                      style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                        color: widget.selectedGoal != null
                            ? AppTheme.lightTheme.colorScheme.onSurface
                            : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: CustomIconWidget(
                      iconName: 'keyboard_arrow_down',
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isExpanded ? null : 0,
            child: _isExpanded
                ? Container(
                    margin: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppTheme.lightTheme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.lightTheme.colorScheme.outline
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: healthGoals
                          .map((goal) => _buildGoalOption(goal))
                          .toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  Widget _buildGoalOption(Map<String, dynamic> goal) {
    final bool isSelected = widget.selectedGoal == goal['value'];

    return GestureDetector(
      onTap: () {
        widget.onGoalChanged(goal['value']);
        setState(() {
          _isExpanded = false;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppTheme.lightTheme.colorScheme.outline
                  .withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.primary
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomIconWidget(
                iconName: goal['icon'],
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.onPrimary
                    : AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal['label'],
                    style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.lightTheme.colorScheme.primary
                          : AppTheme.lightTheme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    goal['description'],
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              CustomIconWidget(
                iconName: 'check_circle',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _getSelectedGoalIcon() {
    if (widget.selectedGoal == null) return 'track_changes';
    final goal = healthGoals.firstWhere(
      (goal) => goal['value'] == widget.selectedGoal,
      orElse: () => healthGoals.first,
    );
    return goal['icon'];
  }

  String _getSelectedGoalLabel() {
    if (widget.selectedGoal == null) return 'Select your health goal';
    final goal = healthGoals.firstWhere(
      (goal) => goal['value'] == widget.selectedGoal,
      orElse: () => healthGoals.first,
    );
    return goal['label'];
  }
}
