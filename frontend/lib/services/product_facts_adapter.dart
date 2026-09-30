/// Compatibility for stored rows. This does not normalize external OFF data;
/// that happens once on the backend. Unknown legacy sodium units stay unknown.
class ProductFactsAdapter {
  static Map<String, dynamic> adapt(Map<String, dynamic> source) {
    final nutrition =
        Map<String, dynamic>.from(source['nutrition'] as Map? ?? {});
    const names = {
      'calories': 'energyKcalPer100g',
      'protein': 'proteinGPer100g',
      'carbs': 'carbohydratesGPer100g',
      'sugar': 'sugarGPer100g',
      'fat': 'fatGPer100g',
      'fiber': 'fiberGPer100g',
    };
    for (final entry in names.entries) {
      final value = nutrition[entry.value] ?? nutrition[entry.key];
      final max = entry.key == 'calories' ? 1000 : 100;
      final valid = value is num && value.isFinite && value >= 0 && value <= max
          ? value
          : null;
      nutrition[entry.value] = valid;
      nutrition[entry.key] = valid;
    }
    final sodium = nutrition['sodiumMgPer100g'] ??
        (source['schemaVersion'] == 2 ? nutrition['sodium'] : null);
    nutrition['sodiumMgPer100g'] =
        sodium is num && sodium.isFinite && sodium >= 0 && sodium <= 100000
            ? sodium
            : null;
    nutrition['sodium'] = nutrition['sodiumMgPer100g'];
    return {
      ...source, 'nutrition': nutrition,
      // Old AI-generated safety verdicts are not reusable product facts.
      'aiAnalysis': null
    };
  }
}
