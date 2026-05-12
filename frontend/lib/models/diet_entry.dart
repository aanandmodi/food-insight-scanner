/// Typed model for diet log entries.
class DietEntry {
  final String entryId;
  final String date; // 'YYYY-MM-DD'
  final String mealType; // Breakfast / Lunch / Dinner / Snack
  final String name;
  final Map<String, dynamic> nutritionData;
  final DateTime createdAt;

  const DietEntry({
    required this.entryId,
    required this.date,
    required this.mealType,
    required this.name,
    required this.nutritionData,
    required this.createdAt,
  });

  factory DietEntry.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final raw = map['createdAt'];
    if (raw is String) {
      parsedDate = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      // Firestore Timestamp — access via .toDate() at the call site
      parsedDate = DateTime.now();
    }

    return DietEntry(
      entryId: map['entryId'] as String? ?? map['id'] as String? ?? '',
      date: map['date'] as String? ?? '',
      mealType: map['mealType'] as String? ?? 'Snack',
      name: map['name'] as String? ?? '',
      nutritionData:
          Map<String, dynamic>.from(map['nutritionData'] as Map? ?? {}),
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'date': date,
      'mealType': mealType,
      'name': name,
      'nutritionData': nutritionData,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
