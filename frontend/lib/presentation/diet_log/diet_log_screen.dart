// lib/presentation/diet_log/diet_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../core/utils/data_refresh_bus.dart';
import '../../core/utils/user_utils.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../models/user_profile.dart';
import '../../routes/app_routes.dart';
import '../../services/analytics_service.dart';
import '../../services/cloud_function_service.dart';
import '../../services/feature_flag_service.dart';
import '../../services/user_data_service.dart';
import '../../services/user_preferences.dart';
import '../../services/user_session.dart';
import '../../theme/app_design_system.dart';
import '../home_dashboard/widgets/nutrition_summary_card.dart';
import 'widgets/diet_trends_card.dart';
import 'widgets/meal_entry_dialog.dart';

class DietLogScreen extends StatefulWidget {
  const DietLogScreen({super.key});

  @override
  State<DietLogScreen> createState() => _DietLogScreenState();
}

class _DietLogScreenState extends State<DietLogScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _dietEntries = [];
  List<Map<String, dynamic>> _allDietLogs = [];
  Map<String, dynamic> _nutritionSummary = {
    'calories': 0,
    'caloriesGoal': 2000,
    'protein': 0,
    'proteinGoal': 150,
    'sugar': 0,
    'sugarGoal': 50,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    // Meals can be logged from Product Details, the AI chat and the Meal
    // Planner. Without this the log kept showing stale totals.
    DataRefreshBus.dietLogRevision.addListener(_onExternalChange);
    DataRefreshBus.profileRevision.addListener(_onExternalChange);
  }

  @override
  void dispose() {
    DataRefreshBus.dietLogRevision.removeListener(_onExternalChange);
    DataRefreshBus.profileRevision.removeListener(_onExternalChange);
    super.dispose();
  }

  void _onExternalChange() {
    if (mounted) _loadData(showSpinner: false);
  }

  int _loadRevision = 0;
  Future<void> _loadData({bool showSpinner = true}) async {
    final revision = ++_loadRevision;
    final session = UserSession.instance.capture();
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final prefs = await UserPreferences.getInstance();

      List<Map<String, dynamic>> entries = [];
      try {
        entries = await UserDataService().getDietLog(dateString);
      } catch (e) {
        debugPrint('Firestore diet log query failed: $e');
      }
      if (!mounted || !session.isActive || revision != _loadRevision) return;

      List<Map<String, dynamic>> allLogs = entries;
      try {
        allLogs = await UserDataService().getAllDietLogs();
      } catch (e) {
        debugPrint('All diet logs query failed: $e');
      }
      if (!mounted || !session.isActive || revision != _loadRevision) return;

      UserProfile? profileProviderData;
      if (mounted) {
        profileProviderData = context.read<UserProfileProvider>().profile;
      }

      final weightKg = profileProviderData?.weightKg ??
          prefs.getDouble('user_weight') ??
          70.0;
      final heightCm = profileProviderData?.heightCm ??
          prefs.getDouble('user_height') ??
          170.0;
      final age = profileProviderData?.age ?? prefs.getInt('user_age') ?? 25;
      final gender = profileProviderData?.gender ??
          prefs.getString('user_gender') ??
          'Male';
      final healthGoal = profileProviderData?.healthGoals ??
          prefs.getString('user_health_goal') ??
          '';

      final calGoal = UserUtils.calculateTDEE(
        weightKg: weightKg.toDouble(),
        heightCm: heightCm.toDouble(),
        age: age,
        gender: gender,
        activityLevel: profileProviderData?.activityLevel ?? 'moderate',
        healthGoal: healthGoal,
        customGoal: profileProviderData?.customCaloriesGoal,
      );

      final proteinGoal = UserUtils.calculateProteinGoal(
        weightKg: weightKg.toDouble(),
        healthGoal: healthGoal,
        customGoal: profileProviderData?.customProteinGoal,
      );

      final sugarGoal = UserUtils.calculateSugarGoal(calGoal);
      final carbsGoal = UserUtils.calculateCarbsGoal(calGoal,
          customGoal: profileProviderData?.customCarbsGoal);
      final fatGoal = UserUtils.calculateFatGoal(calGoal,
          customGoal: profileProviderData?.customFatGoal);

      int totalCals = 0;
      double totalProtein = 0;
      double totalSugar = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      for (final entry in entries) {
        totalCals += (entry['calories'] as num?)?.toInt() ?? 0;
        totalProtein += (entry['protein'] as num?)?.toDouble() ?? 0;
        totalSugar += (entry['sugar'] as num?)?.toDouble() ?? 0;
        totalCarbs += (entry['carbs'] as num?)?.toDouble() ?? 0;
        totalFat += (entry['fat'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _dietEntries = entries;
          _allDietLogs = allLogs;
          _nutritionSummary = {
            'calories': totalCals,
            'caloriesGoal': calGoal,
            'protein': totalProtein.round(),
            'proteinGoal': proteinGoal,
            'sugar': totalSugar.round(),
            'sugarGoal': sugarGoal,
            'carbs': totalCarbs.round(),
            'fat': totalFat.round(),
            'carbsGoal': carbsGoal,
            'fatGoal': fatGoal,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading diet log: $e');
    } finally {
      if (mounted &&
          session.isActive &&
          revision == _loadRevision &&
          _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Whether the user can move forward a day. Logging into the future made the
  /// date strip walk off indefinitely with nothing to show.
  bool get _canGoForward {
    final today = DateTime.now();
    final selected =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selected.isBefore(DateTime(today.year, today.month, today.day));
  }

  void _changeDate(int days) {
    if (days > 0 && !_canGoForward) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    // No full-screen spinner when only the date changed — the list swaps in
    // place instead of blanking the whole screen.
    _loadData(showSpinner: false);
  }

  List<Map<String, dynamic>> get _recentDistinctMeals {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final entry in _allDietLogs) {
      final name = entry['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(entry);
      if (out.length >= 8) break;
    }
    return out;
  }

  Future<void> _deleteEntry(String? id) async {
    if (id == null || id.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This entry can't be deleted.")),
        );
      }
      return;
    }
    try {
      await UserDataService().deleteDietEntry(id);
      _loadData(showSpinner: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted'),
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting entry: $e'),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    }
  }

  Future<void> _addManualEntry() async {
    final session = UserSession.instance.capture();
    final id = UserDataService.newId();
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final aiEnabled = context.read<FeatureFlagService>().aiMealParserEnabled;
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MealEntryDialog(
              estimate: aiEnabled ? CloudFunctionService().parseMeal : null,
              save: (values) async {
                session.check();
                await UserDataService()
                    .saveDietEntry({...values, 'id': id, 'date': date});
                AnalyticsService.record(UsageEvent.mealLogged);
              },
            ));
    if (saved == true && mounted && session.isActive) {
      await _loadData(showSpinner: false);
    }
  }

  Future<void> _editEntry(Map<String, dynamic> meal) async {
    final session = UserSession.instance.capture();
    final existingId = meal['id']?.toString().trim();
    final resolvedId = (existingId != null && existingId.isNotEmpty)
        ? existingId
        : UserDataService.newId();
    final fallbackDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final aiEnabled = context.read<FeatureFlagService>().aiMealParserEnabled;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MealEntryDialog(
        initialMeal: meal,
        estimate: aiEnabled ? CloudFunctionService().parseMeal : null,
        save: (values) async {
          session.check();
          await UserDataService().saveDietEntry({
            ...meal,
            ...values,
            'id': resolvedId,
            'date': meal['date'] ?? fallbackDate,
            if (meal['time'] != null) 'time': meal['time'],
          });
        },
      ),
    );
    if (saved == true && mounted && session.isActive) {
      await _loadData(showSpinner: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal updated'),
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
        );
      }
    }
  }

  Future<void> _quickRelog(Map<String, dynamic> meal) async {
    final session = UserSession.instance.capture();
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      await UserDataService().saveDietEntry({
        'id': UserDataService.newId(),
        'name': meal['name'] ?? 'Logged Meal',
        'brand': meal['brand'] ?? 'Quick Re-Log',
        'mealType': meal['mealType'] ?? 'Snack',
        'calories': (meal['calories'] as num?)?.toInt() ?? 0,
        'protein': (meal['protein'] as num?)?.toDouble() ?? 0.0,
        'carbs': (meal['carbs'] as num?)?.toDouble() ?? 0.0,
        'fat': (meal['fat'] as num?)?.toDouble() ?? 0.0,
        'sugar': (meal['sugar'] as num?)?.toDouble() ?? 0.0,
        if (meal['fiber'] != null)
          'fiber': (meal['fiber'] as num?)?.toDouble() ?? 0.0,
        if (meal['sodiumMg'] != null)
          'sodiumMg': (meal['sodiumMg'] as num?)?.toDouble() ?? 0.0,
        if (meal['portionDescription'] != null)
          'portionDescription': meal['portionDescription'],
        'date': date,
        'time': time,
        'createdAt': now.toUtc().toIso8601String(),
      });
      AnalyticsService.record(UsageEvent.mealLogged);
      if (!mounted || !session.isActive) return;
      await _loadData(showSpinner: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-logged "${meal['name'] ?? 'Meal'}"'),
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not re-log meal: $e'),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    }
  }

  void _openMealPlanner() {
    Navigator.pushNamed(context, AppRoutes.mealPlanner);
  }

  @override
  Widget build(BuildContext context) {
    final mealPlannerEnabled =
        context.watch<FeatureFlagService>().mealPlannerEnabled;
    final recentMeals = _recentDistinctMeals;

    final Map<String, List<Map<String, dynamic>>> groupedEntries = {
      'Breakfast': [],
      'Lunch': [],
      'Dinner': [],
      'Snack': [],
    };

    for (final entry in _dietEntries) {
      final type = entry['mealType'] as String? ?? 'Snack';
      if (groupedEntries.containsKey(type)) {
        groupedEntries[type]!.add(entry);
      } else {
        groupedEntries.putIfAbsent(type, () => []).add(entry);
      }
    }

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Diet Log',
          style: FoodInsightTypography.heading(
            size: 20,
            weight: FontWeight.w900,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
        centerTitle: true,
        backgroundColor: FoodInsightColors.warmWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: FoodInsightColors.deepCharcoal),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: FoodInsightColors.scannerGreen),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: FoodInsightColors.scannerGreen))
            : SingleChildScrollView(
                padding: EdgeInsets.all(5.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded,
                              color: FoodInsightColors.deepCharcoal),
                          onPressed: () => _changeDate(-1),
                        ),
                        Text(
                          DateFormat('EEEE, MMM d').format(_selectedDate),
                          style: FoodInsightTypography.heading(
                            size: 16,
                            weight: FontWeight.w800,
                            color: FoodInsightColors.deepCharcoal,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: _canGoForward
                                ? FoodInsightColors.deepCharcoal
                                : FoodInsightColors.lightGray,
                          ),
                          // Disabled on today so the strip can't wander into
                          // dates that can never have entries.
                          onPressed:
                              _canGoForward ? () => _changeDate(1) : null,
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms),
                    SizedBox(height: 2.h),

                    // Summary Card
                    NutritionSummaryCard(nutritionData: _nutritionSummary)
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 100.ms)
                        .scaleXY(begin: 0.95, end: 1.0),
                    SizedBox(height: 2.h),

                    DietTrendsCard(
                      entries: _allDietLogs,
                      calorieGoal:
                          (_nutritionSummary['caloriesGoal'] as num?)
                                  ?.toInt() ??
                              2000,
                    ).animate().fadeIn(duration: 450.ms, delay: 140.ms),
                    SizedBox(height: 2.h),

                    if (recentMeals.isNotEmpty) ...[
                      Text(
                        'Quick Re-Log',
                        style: FoodInsightTypography.caption(
                          size: 13,
                          weight: FontWeight.w800,
                          color: FoodInsightColors.midGray,
                        ),
                      ),
                      SizedBox(height: 0.8.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: recentMeals.map((meal) {
                            final name =
                                meal['name']?.toString().trim() ?? 'Meal';
                            final kcal =
                                (meal['calories'] as num?)?.toInt() ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                avatar: const Icon(
                                  Icons.replay_rounded,
                                  size: 16,
                                  color: FoodInsightColors.scannerGreenDark,
                                ),
                                backgroundColor:
                                    FoodInsightColors.scannerGreenLight,
                                side: BorderSide(
                                  color: FoodInsightColors.scannerGreen
                                      .withValues(alpha: 0.25),
                                ),
                                label: Text(
                                  '$name · $kcal kcal',
                                  style: FoodInsightTypography.caption(
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: FoodInsightColors.deepCharcoal,
                                  ),
                                ),
                                onPressed: () => _quickRelog(meal),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 2.h),
                    ],

                    if (mealPlannerEnabled) ...[
                      GestureDetector(
                        onTap: _openMealPlanner,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          decoration: BoxDecoration(
                            gradient: FoodInsightColors.healthyGradient,
                            borderRadius: FoodInsightRadius.mdAll,
                            boxShadow: [
                              BoxShadow(
                                color: FoodInsightColors.scannerGreen
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  color: Colors.white),
                              SizedBox(width: 2.w),
                              Text(
                                'Generate Plan for Tomorrow',
                                style: FoodInsightTypography.heading(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                      SizedBox(height: 3.h),
                    ],

                    // Meal Sections
                    ...['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
                      final meals = groupedEntries[type]!;
                      if (meals.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 1.h),
                            child: Text(
                              type,
                              style: FoodInsightTypography.heading(
                                size: 18,
                                weight: FontWeight.w800,
                                color: FoodInsightColors.scannerGreen,
                              ),
                            ),
                          ),
                          ...meals.map((meal) => _buildMealTile(context, meal)),
                          SizedBox(height: 1.h),
                        ],
                      );
                    }),

                    if (_dietEntries.isEmpty) ...[
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 5.h),
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(5.w),
                                decoration: const BoxDecoration(
                                  color: FoodInsightColors.scannerGreenLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.restaurant_menu_rounded,
                                    size: 15.w,
                                    color: FoodInsightColors.scannerGreen),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                'No meals logged yet',
                                style: FoodInsightTypography.heading(
                                  size: 20,
                                  weight: FontWeight.w800,
                                  color: FoodInsightColors.deepCharcoal,
                                ),
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'Start logging to see your summary.',
                                style: FoodInsightTypography.body(
                                  size: 15,
                                  color: FoodInsightColors.midGray,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              ElevatedButton.icon(
                                onPressed: _addManualEntry,
                                icon: const Icon(Icons.add_rounded,
                                    color: Colors.white),
                                label: Text('Add Your First Meal',
                                    style: FoodInsightTypography.caption(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      FoodInsightColors.scannerGreen,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 1.5.h),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: FoodInsightRadius.mdAll),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                      ),
                    ],

                    SizedBox(height: 12.h),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FoodInsightColors.scannerGreen,
        onPressed: _addManualEntry,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Meal',
          style: FoodInsightTypography.caption(
            size: 14,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ).animate().fadeIn(delay: 300.ms),
    );
  }

  Widget _buildMealTile(BuildContext context, Map<String, dynamic> meal) {
    final protein = (meal['protein'] as num?)?.toDouble();
    final sugar = (meal['sugar'] as num?)?.toDouble();
    final calories = (meal['calories'] as num?)?.toInt() ?? 0;
    final brand = meal['brand']?.toString().trim() ?? '';
    final portion = meal['portionDescription']?.toString().trim() ?? '';
    final subtitleParts = [
      if (brand.isNotEmpty) brand,
      if (portion.isNotEmpty) portion,
      '$calories kcal',
    ];

    return Dismissible(
      key: ValueKey('meal-${meal['id'] ?? meal['name']}-${meal['time']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        decoration: BoxDecoration(
          color: FoodInsightColors.healthRed,
          borderRadius: FoodInsightRadius.mdAll,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _deleteEntry(meal['id']?.toString()),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: FoodInsightRadius.mdAll,
          boxShadow: FoodInsightShadows.subtleCard,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: FoodInsightRadius.mdAll,
            onTap: () => _editEntry(meal),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal['name'] ?? 'Unknown',
                          style: FoodInsightTypography.body(
                            size: 16,
                            weight: FontWeight.w700,
                            color: FoodInsightColors.deepCharcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          subtitleParts.join(' • '),
                          style: FoodInsightTypography.caption(
                            size: 13,
                            color: FoodInsightColors.midGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${protein?.toStringAsFixed(1) ?? '—'}g P',
                        style: FoodInsightTypography.caption(
                          size: 14,
                          weight: FontWeight.w800,
                          color: FoodInsightColors.scannerGreen,
                        ),
                      ),
                      Text(
                        '${sugar?.toStringAsFixed(1) ?? '—'}g S',
                        style: FoodInsightTypography.caption(
                          size: 14,
                          weight: FontWeight.w800,
                          color: FoodInsightColors.healthRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: FoodInsightColors.midGray,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }
}
