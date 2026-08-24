// lib/core/utils/user_utils.dart

/// Centralized utility class for user-related calculations.
/// Eliminates duplicated logic across multiple screens.
class UserUtils {
  UserUtils._(); // Prevent instantiation

  // ──────────────────────────── Age ────────────────────────────

  /// Calculate age from a [DateTime] date of birth.
  /// Returns [defaultAge] if [dob] is null.
  static int calculateAge(DateTime? dob, {int defaultAge = 25}) {
    if (dob == null) return defaultAge;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Parse a DOB string (ISO 8601) and return the age.
  /// Returns [defaultAge] if the string is null or unparseable.
  static int calculateAgeFromString(String? dobString, {int defaultAge = 25}) {
    if (dobString == null) return defaultAge;
    final dob = DateTime.tryParse(dobString);
    return calculateAge(dob, defaultAge: defaultAge);
  }

  // ──────────────────────────── TDEE (Mifflin-St Jeor) ────────────────────────────

  /// Activity level multipliers for TDEE calculation.
  static const Map<String, double> _activityMultipliers = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'very active': 1.9,
  };

  /// Calculate Basal Metabolic Rate using the Mifflin-St Jeor Equation.
  ///
  /// - Male:   BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) + 5
  /// - Female: BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) - 161
  ///
  /// For non-binary / unspecified gender, averages the male and female values.
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) {
    final genderLower = gender.toLowerCase();
    if (genderLower == 'male') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else if (genderLower == 'female') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    } else {
      // Average of male and female for non-binary / unspecified
      final maleBMR = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
      final femaleBMR = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
      return (maleBMR + femaleBMR) / 2;
    }
  }

  // ──────────────────────────── Health goal matching ────────────────────────────

  /// Normalizes a stored health-goal value so matching works regardless of how
  /// it was written. The profile setup screen stores snake_case values
  /// (`weight_loss`, `muscle_gain`, `maintenance`, `general_health`) while
  /// older documents and free-text defaults store human labels
  /// (`Weight Loss`, `Healthy Lifestyle`). Underscores become spaces so a
  /// single set of substring checks covers both.
  static String _normalizeGoal(String? healthGoal) =>
      (healthGoal ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]+'), ' ');

  /// True when the goal is some form of weight loss.
  ///
  /// Note `weight_loss` normalizes to `weight loss`, which contains `loss`
  /// but *not* `lose` — both spellings must be checked.
  static bool _isWeightLoss(String? healthGoal) {
    final g = _normalizeGoal(healthGoal);
    return g.contains('lose') || g.contains('loss') || g.contains('cut');
  }

  /// True when the goal is some form of muscle gain / bulking.
  ///
  /// Weight loss wins ties so both calorie and protein maths agree on goals
  /// that mention each (e.g. "lose fat, gain definition").
  static bool _isMuscleGain(String? healthGoal) {
    if (_isWeightLoss(healthGoal)) return false;
    final g = _normalizeGoal(healthGoal);
    return g.contains('muscle') || g.contains('bulk') || g.contains('gain');
  }

  /// Calculate Total Daily Energy Expenditure.
  ///
  /// TDEE = BMR × activity multiplier, then adjusted by health goal:
  /// - Lose Weight:  TDEE - 500
  /// - Build Muscle: TDEE + 300
  /// - Maintain / General: TDEE as-is
  ///
  /// Returns a sensible default (2000) if height/weight data is unavailable.
  static int calculateTDEE({
    double? weightKg,
    double? heightCm,
    required int age,
    required String gender,
    String activityLevel = 'moderate',
    String? healthGoal,
    double? customGoal,
  }) {
    if (customGoal != null && customGoal > 0) {
      return customGoal.round();
    }

    // Fallback when body metrics are missing
    if (weightKg == null || heightCm == null || weightKg <= 0 || heightCm <= 0) {
      return _fallbackCalorieGoal(healthGoal);
    }

    final bmr = calculateBMR(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );

    final multiplier =
        _activityMultipliers[activityLevel.toLowerCase()] ?? 1.55;
    double tdee = bmr * multiplier;

    // Apply health goal adjustment
    if (_isWeightLoss(healthGoal)) {
      tdee -= 500;
    } else if (_isMuscleGain(healthGoal)) {
      tdee += 300;
    }

    // Clamp to reasonable bounds
    return tdee.round().clamp(1200, 5000);
  }

  /// Fallback calorie goals when body metrics are missing.
  static int _fallbackCalorieGoal(String? healthGoal) {
    if (_isWeightLoss(healthGoal)) return 1800;
    if (_isMuscleGain(healthGoal)) return 2500;
    return 2000;
  }

  // ──────────────────────────── Protein ────────────────────────────

  /// Calculate daily protein goal in grams based on body weight and health goal.
  ///
  /// - General wellness: 0.8 g/kg
  /// - Lose Weight:      1.2 g/kg
  /// - Build Muscle:     2.0 g/kg
  ///
  /// Returns a sensible default if weight is unavailable.
  static int calculateProteinGoal({
    double? weightKg,
    String? healthGoal,
    double? customGoal,
  }) {
    if (customGoal != null && customGoal > 0) {
      return customGoal.round();
    }

    if (weightKg == null || weightKg <= 0) {
      return _fallbackProteinGoal(healthGoal);
    }

    double gramsPerKg;

    if (_isMuscleGain(healthGoal)) {
      gramsPerKg = 2.0;
    } else if (_isWeightLoss(healthGoal)) {
      gramsPerKg = 1.2;
    } else {
      gramsPerKg = 0.8;
    }

    return (weightKg * gramsPerKg).round().clamp(30, 400);
  }

  static int _fallbackProteinGoal(String? healthGoal) {
    if (_isMuscleGain(healthGoal)) return 180;
    if (_isWeightLoss(healthGoal)) return 120;
    return 100;
  }

  // ──────────────────────────── Sugar ────────────────────────────

  /// Calculate daily sugar goal in grams.
  ///
  /// WHO recommends max 10% of total calories from free sugars.
  /// Sugar has ~4 calories per gram, so: sugarGoal = (calorieGoal × 0.10) / 4
  static int calculateSugarGoal(int calorieGoal, {double? customGoal}) {
    if (customGoal != null && customGoal > 0) return customGoal.round();
    return ((calorieGoal * 0.10) / 4).round().clamp(20, 100);
  }

  // ──────────────────────────── Carbs ────────────────────────────

  /// Calculate daily carbs goal in grams.
  /// Recommended ~50% of total calories from carbohydrates (4 kcal/g).
  static int calculateCarbsGoal(int calorieGoal, {double? customGoal}) {
    if (customGoal != null && customGoal > 0) return customGoal.round();
    return ((calorieGoal * 0.50) / 4).round().clamp(100, 600);
  }

  // ──────────────────────────── Fat ────────────────────────────

  /// Calculate daily fat goal in grams.
  /// Recommended ~25% of total calories from healthy fats (9 kcal/g).
  static int calculateFatGoal(int calorieGoal, {double? customGoal}) {
    if (customGoal != null && customGoal > 0) return customGoal.round();
    return ((calorieGoal * 0.25) / 9).round().clamp(30, 200);
  }
}

