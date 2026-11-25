import 'allergen_safety_service.dart';
import 'condition_safety_service.dart';

enum FoodFitConfidence { high, medium, low, insufficientData }

class FoodFitResult {
  final int? score;
  final FoodFitConfidence confidence;
  final List<String> positives;
  final List<String> cautions;
  final List<String> conflicts;
  final List<String> unknowns;
  final List<String> conditionConflicts;
  final List<String> conditionCautions;
  final List<String> conditionUnknowns;
  final bool hasCriticalAllergenConflict;
  final bool hasCriticalConditionConflict;
  final AllergenSafetyResult allergen;
  const FoodFitResult(
      {required this.score,
      required this.confidence,
      required this.positives,
      required this.cautions,
      required this.conflicts,
      required this.unknowns,
      this.conditionConflicts = const [],
      this.conditionCautions = const [],
      this.conditionUnknowns = const [],
      required this.hasCriticalAllergenConflict,
      this.hasCriticalConditionConflict = false,
      required this.allergen});

  /// Safe summary for external AI explanations (never transmits condition names).
  Map<String, dynamic> toMap() => {
        'score': score,
        'scoreStatus': hasCriticalAllergenConflict
            ? 'withheld_due_to_allergen_conflict'
            : hasCriticalConditionConflict
                ? 'withheld_due_to_dietary_restriction'
                : score == null
                    ? 'insufficient_data'
                    : 'available',
        'confidence': confidence.name,
        'positives': positives,
        'cautions': cautions,
        'conflicts': conflicts,
        'unknowns': unknowns,
        'hasCriticalAllergenConflict': hasCriticalAllergenConflict
      };
}

class FoodFitService {
  static double? _number(dynamic value) =>
      value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

  /// Product nutrition is per 100g. Legacy sodium is accepted only for schema v2,
  /// whose compatibility key is explicitly milligrams. Old ambiguous rows are unknown.
  static FoodFitResult evaluate(Map<String, dynamic> product,
      {required List<String> allergies,
      List<String> conditions = const [],
      String dietaryPreference = '',
      String healthGoal = '',
      Map<String, num> dailyContext = const {}}) {
    final allergen = AllergenSafetyService.evaluate(product, allergies);
    final nutrition =
        product['nutrition'] is Map ? product['nutrition'] as Map : const {};
    double? value(String canonical, String legacy) =>
        _number(nutrition[canonical] ?? nutrition[legacy]);
    final calories = value('energyKcalPer100g', 'calories');
    final sugar = value('sugarGPer100g', 'sugar');
    final protein = value('proteinGPer100g', 'protein');
    final fiber = value('fiberGPer100g', 'fiber');
    final carbs = value('carbohydratesGPer100g', 'carbs');
    final fat = value('fatGPer100g', 'fat');
    final saturatedFat = value('saturatedFatGPer100g', 'saturatedFat');
    final sodium = _number(nutrition['sodiumMgPer100g'] ??
        (product['schemaVersion'] == 2 ? nutrition['sodium'] : null));
    final conditionResult = ConditionSafetyService.evaluate(
      product,
      conditions: conditions,
      sugarGPer100g: sugar,
      carbsGPer100g: carbs,
      fiberGPer100g: fiber,
      sodiumMgPer100g: sodium,
      fatGPer100g: fat,
      saturatedFatGPer100g: saturatedFat,
      proteinGPer100g: protein,
    );
    final known =
        [calories, sugar, protein, fiber, sodium].whereType<double>().length;
    final positives = <String>[];
    final cautions = <String>[];
    final conflicts = <String>[];
    final unknowns = <String>[];
    if (allergen.confirmed.isNotEmpty) {
      conflicts.add('Contains ${allergen.confirmed.join(', ')}');
    }
    if (allergen.traces.isNotEmpty) {
      cautions.add('May contain traces of ${allergen.traces.join(', ')}');
    }
    if (allergen.status == AllergenStatus.insufficientData) {
      unknowns.add('Allergen information is missing');
    }
    if (sodium == null) unknowns.add('Sodium amount is unknown');
    if (sugar == null) unknowns.add('Sugar amount is unknown');
    if (protein == null) unknowns.add('Protein amount is unknown');
    var score = 70;
    final grade = product['nutriscore']?.toString().toLowerCase();
    score += const {'a': 8, 'b': 4, 'c': 0, 'd': -4, 'e': -8}[grade] ?? 0;
    if (sodium != null && sodium >= 600) {
      score -= 15;
      cautions.add('High sodium (${sodium.round()} mg per 100g)');
    }
    if (sugar != null && sugar > 15) {
      score -= 12;
      cautions.add('High sugar (${sugar.toStringAsFixed(1)} g per 100g)');
    }
    if (protein != null && protein >= 10) {
      score += 9;
      positives.add('Good protein (${protein.toStringAsFixed(1)} g per 100g)');
    }
    if (fiber != null && fiber >= 6) {
      score += 8;
      positives.add('Good fiber (${fiber.toStringAsFixed(1)} g per 100g)');
    }
    if (calories != null && calories >= 400) {
      score -= 8;
      cautions.add('Energy dense (${calories.round()} kcal per 100g)');
    }
    final nova = product['novaGroup'];
    if (nova is num && nova == 4) {
      score -= 8;
      cautions.add('Ultra processed (NOVA 4)');
    }
    final ingredients =
        (product['ingredientsText'] ?? product['ingredients'] ?? '')
            .toString()
            .toLowerCase();
    final diet = dietaryPreference.toLowerCase().replaceAll('-', ' ');
    final wantsVegan = diet.contains('vegan') && !diet.contains('non vegan');
    final wantsVegetarian =
        diet.contains('vegetarian') && !diet.contains('non vegetarian');
    final tags = (product['ingredientsAnalysisTags'] as List? ?? [])
        .join(' ')
        .toLowerCase();
    if (wantsVegan &&
        (tags.contains('non vegan') ||
            RegExp(r'\b(milk|whey|casein|egg|honey|cheese|butter|fish|meat|chicken)\b')
                .hasMatch(ingredients))) {
      conflicts.add('Ingredients may not fit a vegan diet');
    } else if (wantsVegetarian &&
        (tags.contains('non vegetarian') ||
            RegExp(r'\b(fish|meat|chicken|beef|pork|gelatin)\b')
                .hasMatch(ingredients))) {
      conflicts.add('Ingredients may not fit a vegetarian diet');
    }
    final goal = healthGoal.toLowerCase();
    if ((goal.contains('loss') || goal.contains('lose')) &&
        calories != null &&
        calories >= 400) {
      score -= 5;
      cautions.add('Smaller portions may better fit your weight goal');
    }
    if ((goal.contains('muscle') || goal.contains('protein')) &&
        protein != null &&
        protein >= 10) {
      score += 4;
      positives.add('Protein supports your stated goal');
    }
    if (wantsVegan &&
        tags.contains('vegan') &&
        !tags.contains('non vegan') &&
        !tags.contains('unknown')) {
      positives.add('Product data identifies vegan ingredients');
    }
    if (diet.isNotEmpty && ingredients.isEmpty && tags.isEmpty) {
      unknowns.add('Dietary compatibility is unknown');
    }
    if ((dailyContext['sodiumMgConsumed'] ?? 0) >= 1600 &&
        sodium != null &&
        sodium >= 300) {
      cautions.add(
          'Sodium already logged today is substantial; check your portion');
      score -= 5;
    }
    if ((dailyContext['sugarGConsumed'] ?? 0) >= 40 &&
        sugar != null &&
        sugar > 8) {
      cautions.add(
          'Sugar already logged today is substantial; consider your portion');
      score -= 4;
    }
    if (healthGoal.toLowerCase().contains('protein') && protein == null) {
      unknowns.add('Protein goal fit cannot be assessed');
    }
    final remainingProtein = dailyContext['proteinRemaining'];
    if (remainingProtein != null &&
        remainingProtein > 0 &&
        protein != null &&
        protein >= 10) {
      positives.add(
          'Protein per 100g contributes toward your ${remainingProtein.round()} g remaining logged target; adjust for your portion');
    }
    final remainingCalories = dailyContext['caloriesRemaining'];
    if (remainingCalories != null &&
        calories != null &&
        calories > remainingCalories) {
      cautions.add(
          '100g provides more energy than your remaining logged calorie target; check your portion');
    }
    for (final entry
        in {'carbs': 'carbohydratesGPer100g', 'fat': 'fatGPer100g'}.entries) {
      final remaining = dailyContext['${entry.key}Remaining'];
      final amount = value(entry.value, entry.key);
      if (remaining != null && amount != null && amount > remaining) {
        cautions.add(
            '100g exceeds your remaining logged ${entry.key} target; portion size matters');
      }
    }
    score += conditionResult.scoreAdjustment;
    if (conflicts.isNotEmpty || conditionResult.conflicts.isNotEmpty) {
      score = score.clamp(0, 25);
    }
    if (allergen.traces.isNotEmpty) score = score.clamp(0, 45);
    final criticalAllergen = allergen.status == AllergenStatus.confirmedConflict;
    final criticalCondition = conditionResult.hasCriticalConflict;
    final confidence = known < 3
        ? FoodFitConfidence.insufficientData
        : known == 5 &&
                allergen.status != AllergenStatus.insufficientData &&
                (product['allergens'] as List? ?? []).isNotEmpty
            ? FoodFitConfidence.high
            : known >= 4
                ? FoodFitConfidence.medium
                : FoodFitConfidence.low;
    return FoodFitResult(
        score: criticalAllergen ||
                criticalCondition ||
                confidence == FoodFitConfidence.insufficientData
            ? null
            : score.clamp(0, 100),
        confidence: confidence,
        positives: positives,
        cautions: cautions,
        conflicts: conflicts,
        unknowns: unknowns,
        conditionConflicts: conditionResult.conflicts,
        conditionCautions: conditionResult.cautions,
        conditionUnknowns: conditionResult.unknowns,
        hasCriticalAllergenConflict: criticalAllergen,
        hasCriticalConditionConflict: criticalCondition,
        allergen: allergen);
  }
}
