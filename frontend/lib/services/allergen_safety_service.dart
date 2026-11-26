enum AllergenStatus { confirmedConflict, possibleTrace, noDetectedConflict, insufficientData }

class AllergenSafetyResult {
  final AllergenStatus status;
  final List<String> confirmed;
  final List<String> traces;
  const AllergenSafetyResult(this.status, this.confirmed, this.traces);
}

/// Deterministic label checks. Missing declarations never imply safety.
class AllergenSafetyService {
  static const _groups = <String, Set<String>>{
    'milk': {'milk', 'dairy', 'whey', 'casein', 'lactose', 'cheese', 'butter', 'cream', 'curd', 'yogurt', 'dahi', 'paneer', 'ghee', 'makkhan', 'khoya', 'mawa'},
    'peanut': {'peanut', 'peanuts', 'groundnut', 'groundnuts', 'moongfali', 'singdana'},
    'tree nuts': {'tree nuts', 'nuts', 'almond', 'almonds', 'badam', 'cashew', 'cashews', 'kaju', 'walnut', 'walnuts', 'akhrot', 'pistachio', 'pistachios', 'pista', 'hazelnut', 'hazelnuts', 'pecan', 'pecans'},
    'gluten': {'gluten', 'wheat', 'maida', 'atta', 'suji', 'sooji', 'rava', 'semolina', 'barley', 'rye'},
    'soy': {'soy', 'soya', 'soybean', 'soybeans', 'tofu'},
    'egg': {'egg', 'eggs', 'albumin', 'anda'},
    'fish': {'fish', 'salmon', 'tuna', 'anchovy', 'machli'},
    'shellfish': {'shellfish', 'shrimp', 'prawn', 'prawns', 'jhinga', 'crab', 'lobster'},
    'sesame': {'sesame', 'tahini', 'til'},
  };

  static Set<String> _terms(String allergy) {
    final lower = allergy.toLowerCase().trim();
    if (lower == 'nuts') return {..._groups['tree nuts']!, ..._groups['peanut']!};
    for (final entry in _groups.entries) {
      if (entry.key == lower || entry.value.contains(lower)) return entry.value;
    }
    return {lower};
  }

  static bool _containsTerm(String text, String term) {
    final escaped = RegExp.escape(term);
    return RegExp('(^|[^a-z])$escaped([^a-z]|\$)', caseSensitive: false)
        .hasMatch(text);
  }

  static String _joined(dynamic value) => value is List
      ? value.map((item) => item.toString().split(':').last.replaceAll('-', ' ')).join(' ')
      : '';

  static AllergenSafetyResult evaluate(
      Map<String, dynamic> product, List<String> userAllergies) {
    final declared = _joined(product['allergens']);
    final rawIngredients = [
      product['ingredientsText']?.toString() ?? '',
      _joined(product['ingredients']),
    ].join(' ');
    final traceStart = RegExp(r'may contain|traces of|made in a facility', caseSensitive: false).firstMatch(rawIngredients)?.start;
    final ingredients = traceStart == null ? rawIngredients : rawIngredients.substring(0, traceStart);
    final traces = '${_joined(product['traces'])} ${traceStart == null ? '' : rawIngredients.substring(traceStart)}'.trim();
    final hasEvidence = declared.isNotEmpty || traces.isNotEmpty || ingredients.trim().isNotEmpty;
    final confirmed = <String>[];
    final possible = <String>[];
    for (final allergy in userAllergies.where((item) => item.trim().isNotEmpty)) {
      final terms = _terms(allergy);
      if (terms.any((term) => _containsTerm(declared, term) || _containsTerm(ingredients, term))) {
        confirmed.add(allergy);
      } else if (terms.any((term) => _containsTerm(traces, term))) {
        possible.add(allergy);
      }
    }
    if (confirmed.isNotEmpty) return AllergenSafetyResult(AllergenStatus.confirmedConflict, confirmed, possible);
    if (possible.isNotEmpty) return AllergenSafetyResult(AllergenStatus.possibleTrace, confirmed, possible);
    if (!hasEvidence) return const AllergenSafetyResult(AllergenStatus.insufficientData, [], []);
    return const AllergenSafetyResult(AllergenStatus.noDetectedConflict, [], []);
  }
}
