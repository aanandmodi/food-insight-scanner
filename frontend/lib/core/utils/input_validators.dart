/// Shared input validation helpers for authentication and profile forms.
class InputValidators {
  InputValidators._();

  static final RegExp _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static const int minAgeYears = 13;
  static const int maxAgeYears = 120;
  static const double minHeightCm = 50;
  static const double maxHeightCm = 280;
  static const double minWeightKg = 20;
  static const double maxWeightKg = 400;

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please enter your email';
    }
    if (trimmed.length > 254 || !_emailPattern.hasMatch(trimmed)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validateDisplayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please enter your name';
    }
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (trimmed.length > 120) {
      return 'Name must be 120 characters or fewer';
    }
    return null;
  }

  static String? validateHeightCm(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Please enter your height in cm' : null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || !parsed.isFinite) {
      return 'Enter a valid height';
    }
    if (parsed < minHeightCm || parsed > maxHeightCm) {
      return 'Height must be between ${minHeightCm.toInt()} and ${maxHeightCm.toInt()} cm';
    }
    return null;
  }

  static String? validateWeightKg(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Please enter your weight in kg' : null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || !parsed.isFinite) {
      return 'Enter a valid weight';
    }
    if (parsed < minWeightKg || parsed > maxWeightKg) {
      return 'Weight must be between ${minWeightKg.toInt()} and ${maxWeightKg.toInt()} kg';
    }
    return null;
  }

  static int? calculateAge(DateTime? dob, {DateTime? now}) {
    if (dob == null) return null;
    final ref = now ?? DateTime.now();
    var age = ref.year - dob.year;
    if (ref.month < dob.month ||
        (ref.month == dob.month && ref.day < dob.day)) {
      age--;
    }
    return age;
  }

  static String? validateBirthDate(DateTime? dob, {DateTime? now}) {
    if (dob == null) {
      return 'Please select your date of birth.';
    }
    final age = calculateAge(dob, now: now)!;
    if (age < minAgeYears || age > maxAgeYears) {
      return 'Age must be between $minAgeYears and $maxAgeYears years.';
    }
    return null;
  }
}
