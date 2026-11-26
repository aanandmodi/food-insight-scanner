import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/nutrition_trends.dart';
import '../../../theme/app_design_system.dart';

/// Displays 7-day and 30-day logged calorie and macro trends cleanly.
class DietTrendsCard extends StatefulWidget {
  const DietTrendsCard({
    super.key,
    required this.entries,
    required this.calorieGoal,
  });

  final List<Map<String, dynamic>> entries;
  final int calorieGoal;

  @override
  State<DietTrendsCard> createState() => _DietTrendsCardState();
}

class _DietTrendsCardState extends State<DietTrendsCard> {
  int _windowDays = 7;

  @override
  Widget build(BuildContext context) {
    final summary = NutritionTrendCalculator.compute(
      widget.entries,
      daysWindow: _windowDays,
    );
    final goal = math.max(widget.calorieGoal, 1);
    final peak = summary.days.fold<double>(
      goal.toDouble(),
      (m, day) => math.max(m, day.calories),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FoodInsightRadius.mdAll,
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition Trends',
                      style: FoodInsightTypography.heading(
                        size: 16,
                        weight: FontWeight.w800,
                        color: FoodInsightColors.deepCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.loggedDays == 0
                          ? 'Log meals across days to see your averages'
                          : '${summary.loggedDays} of $_windowDays days logged · Avg per logged day',
                      style: FoodInsightTypography.caption(
                        size: 12,
                        color: FoodInsightColors.midGray,
                      ),
                    ),
                  ],
                ),
              ),
              ToggleButtons(
                isSelected: [_windowDays == 7, _windowDays == 30],
                onPressed: (idx) =>
                    setState(() => _windowDays = idx == 0 ? 7 : 30),
                borderRadius: BorderRadius.circular(10),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 42),
                selectedColor: Colors.white,
                fillColor: FoodInsightColors.scannerGreen,
                children: const [
                  Text('7D', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('30D', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _AvgChip(
                label: 'Avg kcal',
                value: summary.avgCalories == null
                    ? '—'
                    : '${summary.avgCalories!.round()}',
                color: FoodInsightColors.scannerGreenDark,
              ),
              _AvgChip(
                label: 'Avg protein',
                value: summary.avgProtein == null
                    ? '—'
                    : '${summary.avgProtein!.toStringAsFixed(1)} g',
                color: FoodInsightColors.infoBlue,
              ),
              _AvgChip(
                label: 'Avg sugar',
                value: summary.avgSugar == null
                    ? '—'
                    : '${summary.avgSugar!.toStringAsFixed(1)} g',
                color: FoodInsightColors.warningAmber,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 88,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in summary.days)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _windowDays <= 7 ? 4 : 1,
                      ),
                      child: Tooltip(
                        message:
                            '${day.dateKey}: ${day.calories.round()} kcal (${day.entriesCount} meals)',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: day.entriesCount == 0
                                      ? 0.06
                                      : (day.calories / peak).clamp(0.12, 1.0),
                                  widthFactor: 0.78,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: day.entriesCount == 0
                                          ? FoodInsightColors.lightGray
                                          : (day.calories > goal * 1.15
                                              ? FoodInsightColors.warningAmber
                                              : FoodInsightColors.scannerGreen),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_windowDays <= 7) ...[
                              const SizedBox(height: 4),
                              Text(
                                day.label,
                                style: FoodInsightTypography.caption(
                                  size: 11,
                                  color: FoodInsightColors.midGray,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvgChip extends StatelessWidget {
  const _AvgChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: FoodInsightTypography.caption(
          size: 12,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
