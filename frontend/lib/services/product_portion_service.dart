enum PortionUnit {
  g('g', 'Grams (g)'),
  ml('ml', 'Milliliters (ml)'),
  kg('kg', 'Kilograms (kg)');

  const PortionUnit(this.symbol, this.label);
  final String symbol;
  final String label;
}

class PortionPreset {
  const PortionPreset({
    required this.label,
    required this.amount,
    required this.unit,
  });

  final String label;
  final double amount;
  final PortionUnit unit;
}

class ProductPortionService {
  static const double maxPortionGrams = 2000;
  static const double minPortionGrams = 1;

  static final RegExp _servingPattern = RegExp(
    r'(\d+(?:\.\d+)?)\s*(kg|g|gm|gms|grams?|ml|milliliters?|l|liters?)\b',
    caseSensitive: false,
  );

  static double toGrams(double amount, PortionUnit unit) {
    return switch (unit) {
      PortionUnit.g => amount,
      PortionUnit.ml => amount,
      PortionUnit.kg => amount * 1000,
    };
  }

  static String formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }
    final fixed = amount.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// Parses package serving strings such as `30 g`, `250 ml`, or `0.5 kg`.
  static PortionPreset? parseServingSize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = _servingPattern.firstMatch(raw.trim());
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    final rawUnit = match.group(2)!.toLowerCase();
    if (value == null || !value.isFinite || value <= 0) return null;

    late PortionUnit unit;
    var normalizedAmount = value;
    if (rawUnit == 'kg') {
      unit = PortionUnit.kg;
    } else if (rawUnit == 'ml' || rawUnit.startsWith('milliliter')) {
      unit = PortionUnit.ml;
    } else if (rawUnit == 'l' || rawUnit.startsWith('liter')) {
      unit = PortionUnit.ml;
      normalizedAmount = value * 1000;
    } else {
      unit = PortionUnit.g;
    }

    final grams = toGrams(normalizedAmount, unit);
    if (grams < minPortionGrams || grams > maxPortionGrams) return null;

    return PortionPreset(
      label: '1 serving (${formatAmount(normalizedAmount)} ${unit.symbol})',
      amount: normalizedAmount,
      unit: unit,
    );
  }

  static List<PortionPreset> presetsForUnit(
    PortionUnit unit, {
    String? servingSize,
  }) {
    final list = <PortionPreset>[];
    final parsedServing = parseServingSize(servingSize);
    if (parsedServing != null) {
      list.add(parsedServing);
    }

    final defaults = switch (unit) {
      PortionUnit.g => [50.0, 100.0, 200.0],
      PortionUnit.ml => [100.0, 250.0, 500.0],
      PortionUnit.kg => [0.25, 0.5, 1.0],
    };

    for (final value in defaults) {
      final duplicateServing = parsedServing != null &&
          parsedServing.unit == unit &&
          (parsedServing.amount - value).abs() < 0.001;
      if (!duplicateServing) {
        list.add(
          PortionPreset(
            label: '${formatAmount(value)} ${unit.symbol}',
            amount: value,
            unit: unit,
          ),
        );
      }
    }
    return list;
  }

  static Map<String, dynamic> nutrients(
    Map<String, dynamic> product,
    double grams,
  ) {
    if (!grams.isFinite || grams <= 0 || grams > maxPortionGrams) {
      throw const FormatException('Enter a portion between 1 and 2,000 grams.');
    }
    final nutrition = product['nutrition'] as Map? ?? {};
    if (nutrition['calories'] is! num) {
      throw const FormatException(
          'Calories are unavailable. Add this meal manually using the package label.');
    }
    final result = <String, dynamic>{};
    for (final key in ['calories', 'protein', 'sugar', 'fat', 'carbs', 'fiber']) {
      final value = nutrition[key];
      result[key] =
          value is num && value.isFinite && value >= 0 ? value * grams / 100 : null;
    }
    final sodium = nutrition['sodiumMgPer100g'];
    result['sodiumMg'] = sodium is num ? sodium * grams / 100 : null;
    result['nutritionIncomplete'] = result.values.any((value) => value == null);
    result['serving'] = '${grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1)} g';
    result['portionGrams'] = grams;
    result['nutritionSource'] = 'product_data';
    return result;
  }

  static Map<String, dynamic> nutrientsForAmount(
    Map<String, dynamic> product,
    double amount,
    PortionUnit unit,
  ) {
    if (!amount.isFinite || amount <= 0) {
      throw FormatException(
          'Enter a valid positive amount in ${unit.symbol}.');
    }
    final grams = toGrams(amount, unit);
    if (!grams.isFinite || grams < minPortionGrams || grams > maxPortionGrams) {
      final range = switch (unit) {
        PortionUnit.g => '1 to 2,000 g',
        PortionUnit.ml => '1 to 2,000 ml',
        PortionUnit.kg => '0.001 to 2 kg',
      };
      throw FormatException('Enter a portion between $range.');
    }
    final scaled = nutrients(product, grams);
    scaled['serving'] = '${formatAmount(amount)} ${unit.symbol}';
    scaled['portionAmount'] = amount;
    scaled['portionUnit'] = unit.symbol;
    return scaled;
  }
}
