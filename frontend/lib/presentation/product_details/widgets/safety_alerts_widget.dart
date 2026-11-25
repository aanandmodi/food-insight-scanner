import 'package:flutter/material.dart';
import '../../../services/food_fit_service.dart';
import '../../../services/allergen_safety_service.dart';

/// Deterministic product facts and compatibility, including explicit unknowns.
class SafetyAlertsWidget extends StatelessWidget {
  final List<String> userAllergies;
  final List<String> userConditions;
  final List<String> ingredients;
  final String dietaryPreference;
  final Map<String, dynamic> nutritionData;
  final Map<String, dynamic> productData;
  final String healthGoal;
  final Map<String, num> dailyContext;

  const SafetyAlertsWidget(
      {super.key,
      required this.userAllergies,
      this.userConditions = const [],
      required this.ingredients,
      required this.dietaryPreference,
      required this.nutritionData,
      this.productData = const {},
      this.healthGoal = '',
      this.dailyContext = const {}});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = FoodFitService.evaluate({
      'ingredients': ingredients,
      'nutrition': nutritionData,
      ...productData,
    },
        allergies: userAllergies,
        conditions: userConditions,
        dietaryPreference: dietaryPreference,
        healthGoal: healthGoal,
        dailyContext: dailyContext);
    final criticalAllergen = result.hasCriticalAllergenConflict;
    final criticalCondition =
        !criticalAllergen && result.hasCriticalConditionConflict;
    final critical = criticalAllergen || criticalCondition;
    final color = critical ? const Color(0xFF9B2C2C) : theme.colorScheme.primary;
    final confidence = switch (result.confidence) {
      FoodFitConfidence.high => 'High confidence',
      FoodFitConfidence.medium => 'Medium confidence',
      FoodFitConfidence.low => 'Low confidence',
      FoodFitConfidence.insufficientData => 'Insufficient data',
    };
    final activeConditions = userConditions
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty && c.toLowerCase() != 'none')
        .toList();
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              criticalAllergen
                  ? 'ALLERGEN CONFLICT'
                  : criticalCondition
                      ? 'CONDITION CONFLICT'
                      : 'YOUR FOOD FIT',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (critical)
            Text('Avoid this product',
                style: theme.textTheme.headlineSmall?.copyWith(color: color))
          else if (result.score != null)
            Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text('${result.score} / 100',
                      style: theme.textTheme.headlineMedium?.copyWith(
                          color: color, fontWeight: FontWeight.w700)),
                  Text(result.score! >= 75
                      ? 'Good fit'
                      : result.score! >= 50
                          ? 'Consider portions'
                          : 'May not fit your goals'),
                ])
          else
            Text('More product data needed', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(confidence, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          for (final message in [
            ...result.conflicts,
            ...result.conditionConflicts,
          ])
            _line(context, Icons.warning_amber_rounded, message,
                const Color(0xFF9B2C2C)),
          for (final message in [
            ...result.cautions,
            ...result.conditionCautions,
          ])
            _line(context, Icons.info_outline_rounded, message,
                const Color(0xFF805000)),
          for (final message in result.positives)
            _line(context, Icons.check_circle_outline_rounded, message,
                theme.colorScheme.primary),
          for (final message in [
            ...result.unknowns,
            ...result.conditionUnknowns,
          ])
            _line(context, Icons.help_outline_rounded, message,
                theme.colorScheme.onSurfaceVariant),
          if (result.allergen.status == AllergenStatus.noDetectedConflict)
            _line(
                context,
                Icons.fact_check_rounded,
                userAllergies.isEmpty
                    ? 'No allergies recorded in your profile'
                    : 'No detected allergen conflicts',
                theme.colorScheme.onSurface),
          if (activeConditions.isNotEmpty &&
              result.conditionConflicts.isEmpty &&
              result.conditionCautions.isEmpty &&
              result.conditionUnknowns.isEmpty)
            _line(
                context,
                Icons.health_and_safety_outlined,
                'No condition flags triggered from available label facts (${activeConditions.join(', ')})',
                theme.colorScheme.onSurface),
          const Divider(height: 24),
          Text(
              'Based on available product information and your profile. Ingredient and allergen data may be incomplete. Always verify the package label if you have a serious allergy or medical condition, and consult a healthcare professional.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
        ]),
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String message, Color color) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Icon(icon, size: 20, color: color), const SizedBox(width: 10),
        Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, height: 1.4)))],
    ));
}
