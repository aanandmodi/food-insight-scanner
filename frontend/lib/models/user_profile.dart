// lib/models/user_profile.dart

class UserProfile {
  final String? uid;
  final String name;
  final String? email;
  final String gender;
  final DateTime? dateOfBirth;
  final double? heightCm;
  final double? weightKg;
  final List<String> diseases;
  final List<String> allergies;
  final String dietaryPreferences;
  final String healthGoals;
  final int age;
  final String activityLevel;
  final bool profileCompleted;

  UserProfile({
    this.uid,
    required this.name,
    this.email,
    this.gender = '',
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.diseases = const [],
    required this.allergies,
    required this.dietaryPreferences,
    required this.healthGoals,
    required this.age,
    required this.activityLevel,
    this.profileCompleted = false,
  });

  /// Factory constructor from a Firestore-style map
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime? dob;
    if (map['dateOfBirth'] != null) {
      if (map['dateOfBirth'] is String) {
        dob = DateTime.tryParse(map['dateOfBirth']);
      }
    }

    return UserProfile(
      uid: map['uid'] as String?,
      name: (map['name'] as String?) ?? '',
      email: map['email'] as String?,
      gender: (map['gender'] as String?) ?? '',
      dateOfBirth: dob,
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      diseases: List<String>.from(map['diseases'] ?? []),
      allergies: List<String>.from(map['allergies'] ?? []),
      dietaryPreferences: map['dietaryPreferences'] is List
          ? (map['dietaryPreferences'] as List).join(', ')
          : (map['dietaryPreferences'] as String?) ?? '',
      healthGoals: (map['healthGoals'] ?? map['healthGoal'] ?? '') as String,
      age: (map['age'] as int?) ?? _calculateAge(dob),
      activityLevel: (map['activityLevel'] as String?) ?? 'moderate',
      profileCompleted: (map['profileCompleted'] as bool?) ?? false,
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      if (uid != null) 'uid': uid,
      'name': name,
      if (email != null) 'email': email,
      'gender': gender,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'heightCm': heightCm,
      'weightKg': weightKg,
      'diseases': diseases,
      'allergies': allergies,
      'dietaryPreferences': dietaryPreferences,
      'healthGoals': healthGoals,
      'age': age,
      'activityLevel': activityLevel,
      'profileCompleted': profileCompleted,
    };
  }

  /// Create a copy with certain fields changed
  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    double? heightCm,
    double? weightKg,
    List<String>? diseases,
    List<String>? allergies,
    String? dietaryPreferences,
    String? healthGoals,
    int? age,
    String? activityLevel,
    bool? profileCompleted,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      diseases: diseases ?? this.diseases,
      allergies: allergies ?? this.allergies,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      healthGoals: healthGoals ?? this.healthGoals,
      age: age ?? this.age,
      activityLevel: activityLevel ?? this.activityLevel,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }

  /// Calculate BMI
  double? get bmi {
    if (heightCm != null && weightKg != null && heightCm! > 0) {
      final heightM = heightCm! / 100;
      return weightKg! / (heightM * heightM);
    }
    return null;
  }

  /// Get BMI category
  String get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return 'Unknown';
    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }

  static int _calculateAge(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return 25;
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }
}
