import 'allergen_safety_service.dart';
import 'food_additive_service.dart';

class ConditionSafetyResult {
  const ConditionSafetyResult({
    this.conflicts = const [],
    this.cautions = const [],
    this.unknowns = const [],
    this.scoreAdjustment = 0,
    this.hasCriticalConflict = false,
  });

  final List<String> conflicts;
  final List<String> cautions;
  final List<String> unknowns;
  final int scoreAdjustment;
  final bool hasCriticalConflict;
}

/// Deterministic, non-diagnostic ingredient and nutrient checks for saved
/// user conditions. Results stay on-device by default.
class ConditionSafetyService {
  ConditionSafetyService._();

  static final RegExp _glutenIngredients = RegExp(
    r'\b(gluten|wheat|maida|atta|suji|sooji|rava|semolina|barley|rye|malt|triticale|spelt|kamut|seitan)\b',
    caseSensitive: false,
  );
  static final RegExp _oatsPattern = RegExp(r'\boats?\b', caseSensitive: false);
  static final RegExp _lactoseIngredients = RegExp(
    r'\b(milk|lactose|whey|casein|caseinate|cream|butter|ghee|cheese|paneer|curd|yogurt|yoghurt|buttermilk|skimmed milk|milk solids|milk powder)\b',
    caseSensitive: false,
  );
  static final RegExp _addedSugarTerms = RegExp(
    r'\b(sugar|sucrose|glucose|fructose|high fructose|corn syrup|hfcs|maltose|dextrose|invert sugar|maltodextrin|jaggery|honey|molasses|cane syrup)\b',
    caseSensitive: false,
  );
  static final RegExp _transOrPalmFats = RegExp(
    r'\b(partially hydrogenated|hydrogenated vegetable|vanaspati|shortening|palm oil|palmolein)\b',
    caseSensitive: false,
  );
  static final RegExp _purineOrAlcohol = RegExp(
    r'\b(yeast extract|anchovy|anchovies|sardine|sardines|mackerel|herring|organ meat|liver|meat extract|alcohol|ethanol|wine|beer|rum)\b',
    caseSensitive: false,
  );
  static final RegExp _polyolsAndFodmaps = RegExp(
    r'\b(sorbitol|mannitol|xylitol|maltitol|isomalt|erythritol|polydextrose|inulin|chicory root|onion powder|garlic powder)\b',
    caseSensitive: false,
  );
  static final RegExp _renalPhosphateOrPotassiumTerms = RegExp(
    r'\b(phosphoric acid|sodium phosphate|monosodium phosphate|disodium phosphate|trisodium phosphate|pyrophosphate|triphosphate|polyphosphate|potassium chloride)\b',
    caseSensitive: false,
  );
  static const Set<String> _renalInsCodes = {
    '338',
    '339',
    '340',
    '341',
    '343',
    '450',
    '451',
    '452',
    '508',
  };
  static final RegExp _polyolInsCodes =
      RegExp(r'\b(?:420|421|953|965|966|967|968)\b');
  static final RegExp _soyConcentrateTerms = RegExp(
    r'\b(soy protein|soya protein|soy isolate|soya isolate|soybeans?|tofu|edamame|soy milk)\b',
    caseSensitive: false,
  );
  static final RegExp _alcoholTerms = RegExp(
    r'\b(alcohol|ethanol|wine|beer|rum|whisky|whiskey)\b',
    caseSensitive: false,
  );

  static String _normalizedIngredients(Map<String, dynamic> product) {
    final declared = (product['allergens'] as List? ?? [])
        .map((e) => e.toString().split(':').last.replaceAll('-', ' '))
        .join(' ');
    final listText = (product['ingredients'] as List? ?? [])
        .map((e) => e.toString())
        .join(' ');
    final raw = product['ingredientsText']?.toString() ?? '';
    return '$declared $raw $listText'.trim();
  }

  static String _normalizedTraces(Map<String, dynamic> product) {
    final traces = (product['traces'] as List? ?? [])
        .map((e) => e.toString().split(':').last.replaceAll('-', ' '))
        .join(' ');
    final raw = product['ingredientsText']?.toString() ?? '';
    final match =
        RegExp(r'may contain|traces of|made in a facility', caseSensitive: false)
            .firstMatch(raw);
    final inlineTraces = match == null ? '' : raw.substring(match.start);
    return '$traces $inlineTraces'.trim();
  }

  static ConditionSafetyResult evaluate(
    Map<String, dynamic> product, {
    required List<String> conditions,
    double? sugarGPer100g,
    double? carbsGPer100g,
    double? fiberGPer100g,
    double? sodiumMgPer100g,
    double? fatGPer100g,
    double? saturatedFatGPer100g,
    double? proteinGPer100g,
  }) {
    final active = conditions
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty && c.toLowerCase() != 'none')
        .toList();
    if (active.isEmpty) {
      return const ConditionSafetyResult();
    }

    final rawCombined = _normalizedIngredients(product);
    final traceStart =
        RegExp(r'may contain|traces of|made in a facility', caseSensitive: false)
            .firstMatch(rawCombined)
            ?.start;
    final primaryIngredients =
        traceStart == null ? rawCombined : rawCombined.substring(0, traceStart);
    final traces = _normalizedTraces(product);
    final hasIngredientEvidence =
        primaryIngredients.trim().isNotEmpty || traces.isNotEmpty;
    final additiveCodes = FoodAdditiveService.extract(
      '${product['ingredientsText'] ?? ''} ${(product['additives'] as List? ?? []).join(' ')}',
    );
    final labelText =
        '${product['name'] ?? ''} ${product['category'] ?? ''} $rawCombined'
            .toLowerCase();

    final conflicts = <String>[];
    final cautions = <String>[];
    final unknowns = <String>[];
    var adjustment = 0;
    var hasCritical = false;

    void addUnique(List<String> target, String message) {
      if (!target.contains(message)) target.add(message);
    }

    var evaluatedDiabetes = false;
    var evaluatedVascular = false;

    for (final condition in active) {
      final lower = condition.toLowerCase();

      if (lower.contains('diabetes')) {
        if (evaluatedDiabetes) continue;
        evaluatedDiabetes = true;
        if (sugarGPer100g == null) {
          addUnique(unknowns,
              'Sugar amount is missing — check the nutrition panel before relying on this for diabetes management.');
        } else if (sugarGPer100g > 10) {
          addUnique(conflicts,
              'High sugar (${sugarGPer100g.toStringAsFixed(1)} g/100g) may raise blood glucose quickly; limit portion or consult your doctor ($condition).');
          adjustment -= 15;
        } else if (sugarGPer100g > 5) {
          addUnique(cautions,
              'Moderate sugar (${sugarGPer100g.toStringAsFixed(1)} g/100g) — account for portion size ($condition).');
          adjustment -= 8;
        } else if (_addedSugarTerms.hasMatch(primaryIngredients)) {
          addUnique(cautions,
              'Contains added sugars or syrups — check glycemic impact for $condition.');
          adjustment -= 4;
        }
        if (carbsGPer100g != null &&
            carbsGPer100g >= 45 &&
            (fiberGPer100g == null || fiberGPer100g < 3)) {
          addUnique(cautions,
              'High carbohydrate (${carbsGPer100g.toStringAsFixed(1)} g/100g) with low fiber — pair or portion carefully.');
          adjustment -= 5;
        }
        continue;
      }

      if (lower.contains('hypertension') ||
          lower.contains('heart disease') ||
          lower.contains('cholesterol')) {
        if (lower.contains('hypertension')) {
          if (sodiumMgPer100g == null) {
            addUnique(unknowns,
                'Sodium amount is missing — verify the label for blood pressure tracking.');
          } else if (sodiumMgPer100g >= 500) {
            addUnique(conflicts,
                'High sodium (${sodiumMgPer100g.round()} mg/100g) may conflict with low-sodium blood pressure guidance ($condition).');
            adjustment -= 15;
          } else if (sodiumMgPer100g > 300) {
            addUnique(cautions,
                'Elevated sodium (${sodiumMgPer100g.round()} mg/100g) — watch your serving size ($condition).');
            adjustment -= 8;
          }
        }
        if ((lower.contains('heart') || lower.contains('cholesterol')) &&
            !evaluatedVascular) {
          evaluatedVascular = true;
          if (!lower.contains('hypertension') && sodiumMgPer100g != null) {
            if (sodiumMgPer100g >= 500) {
              addUnique(cautions,
                  'High sodium (${sodiumMgPer100g.round()} mg/100g) — check heart-health sodium limits ($condition).');
              adjustment -= 8;
            }
          }
          if (saturatedFatGPer100g != null && saturatedFatGPer100g >= 5) {
            addUnique(conflicts,
                'High saturated fat (${saturatedFatGPer100g.toStringAsFixed(1)} g/100g) — limit intake for cardiovascular health ($condition).');
            adjustment -= 12;
          } else if (fatGPer100g != null && fatGPer100g >= 17.5) {
            addUnique(cautions,
                'High total fat (${fatGPer100g.toStringAsFixed(1)} g/100g) — check saturated/trans fat content ($condition).');
            adjustment -= 6;
          } else if (fatGPer100g == null && saturatedFatGPer100g == null) {
            addUnique(unknowns,
                'Fat profile is missing — check label for saturated fat ($condition).');
          }
          if (_transOrPalmFats.hasMatch(primaryIngredients)) {
            addUnique(cautions,
                'Contains hydrogenated or palm oils — check fat quality for $condition.');
            adjustment -= 6;
          }
        }
        continue;
      }

      if (lower.contains('celiac')) {
        final glutenCheck = AllergenSafetyService.evaluate(product, ['gluten']);
        final hasGlutenIngredient =
            glutenCheck.status == AllergenStatus.confirmedConflict ||
                _glutenIngredients.hasMatch(primaryIngredients);
        final hasOats = _oatsPattern.hasMatch(primaryIngredients) &&
            !labelText.contains('gluten free') &&
            !labelText.contains('gluten-free');
        if (hasGlutenIngredient) {
          hasCritical = true;
          addUnique(conflicts,
              'Contains wheat/barley/rye or gluten — avoid with Celiac Disease; verify certified gluten-free labels.');
        } else if (hasOats) {
          addUnique(conflicts,
              'Contains oats without a verified gluten-free statement — oats are frequently cross-contaminated (Celiac Disease).');
          adjustment -= 15;
        } else if (glutenCheck.status == AllergenStatus.possibleTrace ||
            _glutenIngredients.hasMatch(traces) ||
            _oatsPattern.hasMatch(traces)) {
          addUnique(conflicts,
              'May contain traces of gluten — check certified gluten-free packaging for Celiac Disease.');
          adjustment -= 15;
        } else if (!hasIngredientEvidence) {
          addUnique(unknowns,
              'Ingredients and allergens are missing — cannot verify gluten-free status for Celiac Disease.');
        }
        continue;
      }

      if (lower.contains('lactose')) {
        if (labelText.contains('lactose free') ||
            labelText.contains('lactose-free')) {
          continue;
        }
        final milkCheck = AllergenSafetyService.evaluate(product, ['milk']);
        if (milkCheck.status == AllergenStatus.confirmedConflict ||
            _lactoseIngredients.hasMatch(primaryIngredients)) {
          addUnique(conflicts,
              'Contains milk or lactose-derived ingredients — check tolerance ($condition).');
          adjustment -= 15;
        } else if (milkCheck.status == AllergenStatus.possibleTrace ||
            _lactoseIngredients.hasMatch(traces)) {
          addUnique(cautions,
              'May contain dairy/lactose traces — verify sensitivity ($condition).');
          adjustment -= 5;
        } else if (!hasIngredientEvidence) {
          addUnique(unknowns,
              'Ingredient list is missing — cannot check lactose ingredients ($condition).');
        }
        continue;
      }

      if (lower.contains('kidney')) {
        if (sodiumMgPer100g == null) {
          addUnique(unknowns,
              'Sodium amount is missing — verify label for Kidney Disease.');
        } else if (sodiumMgPer100g >= 400) {
          addUnique(conflicts,
              'High sodium (${sodiumMgPer100g.round()} mg/100g) — consult your nephrologist/dietitian about suitability ($condition).');
          adjustment -= 14;
        } else if (sodiumMgPer100g >= 250) {
          addUnique(cautions,
              'Moderate sodium (${sodiumMgPer100g.round()} mg/100g) — monitor portion size for $condition.');
          adjustment -= 6;
        }
        final hasRenalAdditives =
            additiveCodes.any(_renalInsCodes.contains) ||
                _renalPhosphateOrPotassiumTerms.hasMatch(primaryIngredients);
        if (hasRenalAdditives) {
          addUnique(conflicts,
              'Phosphate or potassium additives detected (INS 338–343, 450–452, or 508) — verify with your doctor ($condition).');
          adjustment -= 12;
        }
        if (proteinGPer100g != null && proteinGPer100g >= 20) {
          addUnique(cautions,
              'High protein (${proteinGPer100g.toStringAsFixed(1)} g/100g) — verify against any protein restriction ($condition).');
        }
        continue;
      }

      if (lower.contains('gout')) {
        if (_purineOrAlcohol.hasMatch(primaryIngredients)) {
          addUnique(conflicts,
              'Contains high-purine/yeast extract or alcohol ingredients that may trigger flares ($condition).');
          adjustment -= 12;
        }
        if ((sugarGPer100g != null && sugarGPer100g > 10) ||
            RegExp(r'\b(fructose|hfcs|high fructose)\b', caseSensitive: false)
                .hasMatch(primaryIngredients)) {
          addUnique(cautions,
              'High fructose/sugar content can raise uric acid levels — moderate portion size ($condition).');
          adjustment -= 8;
        }
        continue;
      }

      if (lower.contains('pcos')) {
        if (sugarGPer100g != null && sugarGPer100g > 10) {
          addUnique(cautions,
              'High added/total sugar (${sugarGPer100g.toStringAsFixed(1)} g/100g) — lower-glycemic portions may better fit $condition.');
          adjustment -= 6;
        } else if (_addedSugarTerms.hasMatch(primaryIngredients) &&
            (fiberGPer100g == null || fiberGPer100g < 3)) {
          addUnique(cautions,
              'Refined sweeteners with low fiber — keep portions modest ($condition).');
          adjustment -= 4;
        }
        continue;
      }

      if (lower.contains('liver')) {
        if (_alcoholTerms.hasMatch(primaryIngredients)) {
          addUnique(conflicts,
              'Contains alcohol/ethanol ingredients — avoid or check with your doctor ($condition).');
          adjustment -= 15;
        }
        if ((sugarGPer100g != null && sugarGPer100g > 12) ||
            (fatGPer100g != null && fatGPer100g >= 17.5) ||
            _transOrPalmFats.hasMatch(primaryIngredients)) {
          addUnique(cautions,
              'High sugar, fat, or refined oils — limit portions for $condition.');
          adjustment -= 6;
        }
        continue;
      }

      if (lower.contains('ibs') || lower.contains('crohn')) {
        final hasPolyolIns =
            additiveCodes.any((code) => _polyolInsCodes.hasMatch(code));
        if (_polyolsAndFodmaps.hasMatch(primaryIngredients) || hasPolyolIns) {
          addUnique(cautions,
              'Contains polyols, chicory/inulin, or high-FODMAP triggers that may bother gut sensitivity ($condition).');
          adjustment -= 6;
        }
        if (!labelText.contains('lactose free') &&
            _lactoseIngredients.hasMatch(primaryIngredients)) {
          addUnique(cautions,
              'Contains dairy/lactose — check tolerance if dairy triggers symptoms ($condition).');
        }
        continue;
      }

      if (lower.contains('thyroid')) {
        if (_soyConcentrateTerms.hasMatch(primaryIngredients)) {
          addUnique(cautions,
              'Contains concentrated soy ingredients — check timing around thyroid medication if advised by your doctor.');
        }
        continue;
      }

      if (lower.contains('anemia')) {
        if (RegExp(r'\b(coffee|tea extract|black tea|green tea)\b',
                caseSensitive: false)
            .hasMatch(primaryIngredients)) {
          addUnique(cautions,
              'Tea/coffee polyphenols can reduce iron absorption when consumed directly with iron-rich meals ($condition).');
        }
        continue;
      }
    }

    return ConditionSafetyResult(
      conflicts: conflicts,
      cautions: cautions,
      unknowns: unknowns,
      scoreAdjustment: adjustment.clamp(-30, 0),
      hasCriticalConflict: hasCritical,
    );
  }
}
