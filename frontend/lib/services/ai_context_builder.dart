import '../core/utils/user_utils.dart';

/// Pure, allowlisted snapshots. No account identifiers or raw health records.
class AIContextBuilder {
  static Map<String, dynamic> productFacts(Map<String, dynamic> input) {
    final nutrition = input['nutrition'] as Map? ?? {};
    return {
      for (final key in [
        'name',
        'productName',
        'nutriscore',
        'ingredientsText'
      ])
        if (input[key] is String)
          key: (input[key] as String).substring(
              0,
              (input[key] as String)
                  .length
                  .clamp(0, key == 'ingredientsText' ? 1600 : 160)),
      'nutrition': {
        for (final key in [
          ...nutrients,
          'energyKcalPer100g',
          'proteinGPer100g',
          'carbohydratesGPer100g',
          'fatGPer100g',
          'sugarGPer100g',
          'sodiumMgPer100g',
          'fiberGPer100g'
        ])
          if (number(nutrition[key]) != null) key: number(nutrition[key])
      },
      if (number(input['novaGroup']) != null)
        'novaGroup': number(input['novaGroup']),
      for (final key in ['allergens', 'traces'])
        key: (input[key] as List? ?? [])
            .whereType<String>()
            .take(30)
            .map((s) => s.substring(0, s.length.clamp(0, 80)))
            .toList(),
    };
  }

  static const nutrients = [
    'calories',
    'protein',
    'carbs',
    'fat',
    'sugar',
    'sodium'
  ];
  static double? number(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.toDouble() : null;
  static Map<String, dynamic> profile(Map<String, dynamic> input) => {
        for (final key in [
          'country',
          'region',
          'healthGoals',
          'activityLevel',
          'gender',
          'allergies',
          'dietaryPreferences',
          'age',
          'heightCm',
          'weightKg'
        ])
          if (input[key] != null) key: input[key],
      };

  static Map<String, num> targets(Map<String, dynamic> p) {
    final age = number(p['age'])?.toInt();
    final weight = number(p['weightKg']);
    final height = number(p['heightCm']);
    final custom = number(p['customCaloriesGoal']);
    // No implicit age/body measurements in AI context.
    final calories = custom != null && custom > 0
        ? custom.round()
        : age != null && age >= 18 && weight != null && height != null
            ? UserUtils.calculateTDEE(
                weightKg: weight,
                heightCm: height,
                age: age,
                gender: p['gender']?.toString() ?? '',
                activityLevel: p['activityLevel']?.toString() ?? 'moderate',
                healthGoal: p['healthGoals']?.toString())
            : null;
    return {
      if (calories != null) 'calories': calories,
      if (weight != null || number(p['customProteinGoal']) != null)
        'protein': UserUtils.calculateProteinGoal(
            weightKg: weight,
            healthGoal: p['healthGoals']?.toString(),
            customGoal: number(p['customProteinGoal'])),
      if (calories != null)
        'carbs': UserUtils.calculateCarbsGoal(calories,
            customGoal: number(p['customCarbsGoal'])),
      if (calories != null)
        'fat': UserUtils.calculateFatGoal(calories,
            customGoal: number(p['customFatGoal'])),
    };
  }

  static Map<String, dynamic> totals(List<Map<String, dynamic>> logs) => {
        'entriesLogged': logs.length,
        for (final nutrient in nutrients)
          nutrient: logs.isEmpty ||
                  logs.any((r) =>
                      number(r[nutrient == 'sodium' ? 'sodiumMg' : nutrient]) ==
                      null)
              ? null
              : logs.fold<double>(
                  0,
                  (sum, r) =>
                      sum +
                      number(r[nutrient == 'sodium' ? 'sodiumMg' : nutrient])!),
      };

  static Map<String, dynamic> build(
      {required String task,
      required Map<String, dynamic> userProfile,
      List<Map<String, dynamic>> logs = const [],
      List<Map<String, dynamic>> scans = const [],
      Map<String, dynamic>? activity,
      DateTime? now}) {
    final clock = now ?? DateTime.now();
    String day(DateTime date) => date.toIso8601String().split('T')[0];
    final today = day(clock);
    final dates = List.generate(
        7, (i) => day(DateTime(clock.year, clock.month, clock.day - i)));
    final recent = logs.where((r) => dates.contains(r['date'])).toList()
      ..sort((a, b) =>
          '${b['date']} ${b['time']}'.compareTo('${a['date']} ${a['time']}'));
    final p = profile(userProfile);
    if (task == 'meal') {
      return {
        'profile': {
          for (final key in ['country', 'region', 'dietaryPreferences'])
            if (p[key] != null) key: p[key]
        }
      };
    }
    final goals = targets(userProfile);
    final intake = totals(recent.where((r) => r['date'] == today).toList());
    final daily = dates
        .map((d) => totals(recent.where((r) => r['date'] == d).toList()))
        .where((r) => r['entriesLogged'] > 0)
        .toList();
    final sevenDay = <String, dynamic>{
      'daysLogged': daily.length,
      'confidence': daily.length < 3 ? 'low' : 'partial',
      'note':
          'Logged intake only. Incomplete logging is not evidence of undereating.',
      for (final nutrient in nutrients)
        'average${nutrient[0].toUpperCase()}${nutrient.substring(1)}':
            daily.isEmpty || daily.any((r) => r[nutrient] == null)
                ? null
                : daily.fold<double>(
                        0, (sum, r) => sum + (r[nutrient] as num)) /
                    daily.length,
    };
    return {
      'profile': p,
      'units':
          'calories=kcal; sodium=mg; other nutrients=g. Intake describes logs, not proof of total consumption.',
      'targets': goals,
      'today': {
        ...intake,
        'remaining': {
          for (final entry in goals.entries)
            entry.key: intake[entry.key] is num
                ? entry.value - (intake[entry.key] as num)
                : null
        }
      },
      if (task == 'chat' || task == 'macros') 'sevenDay': sevenDay,
      if ((task == 'chat' || task == 'macros') &&
          ['healthConnect', 'pedometerEstimate'].contains(activity?['source']))
        'activity': {
          'source': activity!['source'],
          for (final key in ['steps', 'activeCalories'])
            if (number(activity[key]) != null) key: number(activity[key])
        },
      if (task == 'chat' || task == 'plan')
        'recentMeals': recent
            .take(8)
            .map((r) => {
                  if (r['name'] is String)
                    'name': (r['name'] as String).substring(
                        0, (r['name'] as String).length.clamp(0, 160)),
                  for (final key in nutrients)
                    if (number(r[key == 'sodium' ? 'sodiumMg' : key]) != null)
                      key: number(r[key == 'sodium' ? 'sodiumMg' : key]),
                })
            .toList(),
      if (task == 'chat')
        'recentScans': scans.take(5).map(productFacts).toList(),
    };
  }
}
