/// Password strength rating used during signup and password changes.
enum PasswordStrengthLevel { empty, weak, fair, good, strong }

class PasswordStrength {
  const PasswordStrength({
    required this.level,
    required this.score,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecial,
    required this.hasCommonWeakPattern,
  });

  final PasswordStrengthLevel level;
  final int score;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecial;
  final bool hasCommonWeakPattern;

  String get label => switch (level) {
        PasswordStrengthLevel.empty => 'Enter a password',
        PasswordStrengthLevel.weak => 'Weak',
        PasswordStrengthLevel.fair => 'Fair',
        PasswordStrengthLevel.good => 'Good',
        PasswordStrengthLevel.strong => 'Strong',
      };

  double get progress => switch (level) {
        PasswordStrengthLevel.empty => 0.0,
        PasswordStrengthLevel.weak => 0.25,
        PasswordStrengthLevel.fair => 0.5,
        PasswordStrengthLevel.good => 0.75,
        PasswordStrengthLevel.strong => 1.0,
      };
}

/// Shared input validation helpers for authentication and profile forms.
class InputValidators {
  InputValidators._();

  static final RegExp _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );
  static final RegExp _upperPattern = RegExp(r'[A-Z]');
  static final RegExp _lowerPattern = RegExp(r'[a-z]');
  static final RegExp _digitPattern = RegExp(r'[0-9]');
  static final RegExp _specialPattern = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`';]''');

  static const List<String> _commonWeakPatterns = [
    'password',
    '123456',
    'qwerty',
    'letmein',
    'admin123',
    'welcome',
    'foodinsight',
  ];

  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minAgeYears = 13;
  static const int maxAgeYears = 120;
  static const double minHeightCm = 50;
  static const double maxHeightCm = 280;
  static const double minWeightKg = 20;
  static const double maxWeightKg = 400;

  static PasswordStrength evaluatePasswordStrength(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(
        level: PasswordStrengthLevel.empty,
        score: 0,
        hasMinLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasDigit: false,
        hasSpecial: false,
        hasCommonWeakPattern: false,
      );
    }

    final hasMinLength = password.length >= minPasswordLength;
    final hasUppercase = _upperPattern.hasMatch(password);
    final hasLowercase = _lowerPattern.hasMatch(password);
    final hasDigit = _digitPattern.hasMatch(password);
    final hasSpecial = _specialPattern.hasMatch(password);
    final lower = password.toLowerCase();
    final hasCommonWeakPattern =
        _commonWeakPatterns.any((pattern) => lower.contains(pattern));

    var points = 0;
    if (hasMinLength) points++;
    if (password.length >= 12) points++;
    if (hasUppercase && hasLowercase) points++;
    if (hasDigit) points++;
    if (hasSpecial) points++;
    if (hasCommonWeakPattern) points = (points - 2).clamp(0, 5);

    final PasswordStrengthLevel level;
    if (!hasMinLength || points <= 1) {
      level = PasswordStrengthLevel.weak;
    } else if (points <= 2) {
      level = PasswordStrengthLevel.fair;
    } else if (!hasUppercase || !hasLowercase || !hasDigit || !hasSpecial || points <= 3) {
      level = PasswordStrengthLevel.good;
    } else {
      level = PasswordStrengthLevel.strong;
    }

    return PasswordStrength(
      level: level,
      score: points.clamp(0, 4),
      hasMinLength: hasMinLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasDigit: hasDigit,
      hasSpecial: hasSpecial,
      hasCommonWeakPattern: hasCommonWeakPattern,
    );
  }

  static String? validateStrongPassword(
    String? value, {
    String? disallowMatch,
    String? email,
  }) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Please enter a password';
    }
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    if (password.length > maxPasswordLength) {
      return 'Password must be $maxPasswordLength characters or fewer';
    }
    final strength = evaluatePasswordStrength(password);
    if (!strength.hasUppercase) {
      return 'Include at least one uppercase letter';
    }
    if (!strength.hasLowercase) {
      return 'Include at least one lowercase letter';
    }
    if (!strength.hasDigit) {
      return 'Include at least one number';
    }
    if (!strength.hasSpecial) {
      return 'Include at least one special character';
    }
    if (strength.hasCommonWeakPattern) {
      return 'Avoid common easy-to-guess password patterns';
    }
    final localPart = email?.trim().split('@').first.toLowerCase() ?? '';
    if (localPart.length >= 4 &&
        password.toLowerCase().contains(localPart)) {
      return 'Password must not contain your email name';
    }
    if (disallowMatch != null &&
        disallowMatch.isNotEmpty &&
        password == disallowMatch) {
      return 'New password must differ from your current password';
    }
    return null;
  }

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
