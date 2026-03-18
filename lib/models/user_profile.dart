// lib/models/user_profile.dart

class UserProfile {
  final String name;
  final List<String> allergies;
  final String dietaryPreferences;
  final String healthGoals;
  final int age;
  final String activityLevel;

  UserProfile({
    required this.name,
    required this.allergies,
    required this.dietaryPreferences,
    required this.healthGoals,
    required this.age,
    required this.activityLevel,
  });

  // A factory constructor to create a UserProfile from a map (e.g., from JSON or SharedPreferences)
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] as String,
      allergies: List<String>.from(map['allergies'] as List),
      dietaryPreferences: map['dietaryPreferences'] as String,
      healthGoals: map['healthGoals'] as String,
      age: map['age'] as int,
      activityLevel: map['activityLevel'] as String,
    );
  }

  // A method to convert a UserProfile to a map (e.g., to save to SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'allergies': allergies,
      'dietaryPreferences': dietaryPreferences,
      'healthGoals': healthGoals,
      'age': age,
      'activityLevel': activityLevel,
    };
  }
}