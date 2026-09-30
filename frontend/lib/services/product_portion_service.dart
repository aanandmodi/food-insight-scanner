class ProductPortionService {
  static Map<String, dynamic> nutrients(Map<String, dynamic> product, double grams) {
    if (!grams.isFinite || grams <= 0 || grams > 2000) {
      throw const FormatException('Enter a portion between 1 and 2,000 grams.');
    }
    final nutrition = product['nutrition'] as Map? ?? {};
    if (nutrition['calories'] is! num) {
      throw const FormatException('Calories are unavailable. Add this meal manually using the package label.');
    }
    final result = <String, dynamic>{};
    for (final key in ['calories', 'protein', 'sugar', 'fat', 'carbs', 'fiber']) {
      final value = nutrition[key];
      result[key] = value is num && value.isFinite && value >= 0 ? value * grams / 100 : null;
    }
    final sodium = nutrition['sodiumMgPer100g'];
    result['sodiumMg'] = sodium is num ? sodium * grams / 100 : null;
    result['nutritionIncomplete'] = result.values.any((value) => value == null);
    result['serving'] = '${grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1)} g';
    result['portionGrams'] = grams;
    result['nutritionSource'] = 'product_data';
    return result;
  }
}
