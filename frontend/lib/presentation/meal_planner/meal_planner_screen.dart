// lib/presentation/meal_planner/meal_planner_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../data/providers/user_profile_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/cloud_function_service.dart';
import '../../services/feature_flag_service.dart';
import '../../services/user_data_service.dart';
import '../../services/user_session.dart';
import '../../theme/app_design_system.dart';
import 'widgets/planned_meal_card.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  bool _isLoading = false;
  bool _isExportingAll = false;
  int? _loggingIndex;
  int? _addingIngredientsIndex;
  Map<String, dynamic>? _mealPlan;
  String _error = '';
  DateTime? _generatedAt;

  @override
  void initState() {
    super.initState();
    _loadSavedPlan();
  }

  Future<void> _loadSavedPlan() async {
    try {
      final session = UserSession.instance.capture();
      final decoded = await UserDataService().getMealPlan();
      if (decoded == null || !mounted || !session.isActive) return;
      final profile = await UserDataService().getUserProfile();
      CloudFunctionService.validatePlanSafety(decoded, profile);
      if (!mounted || !session.isActive) return;
      final stamp = decoded['generatedAt']?.toString();
      setState(() {
        _mealPlan = decoded.map((k, v) => MapEntry(k.toString(), v));
        _generatedAt = stamp == null ? null : DateTime.tryParse(stamp);
      });
    } catch (e) {
      // A corrupt cached plan shouldn't wedge the screen on an error state —
      // just fall through to the empty state so the user can regenerate.
      debugPrint('Could not restore saved meal plan: $e');
    }
  }

  /// Today's real logged intake. The planner used to send a hardcoded
  /// `{calories: 1800, protein: 100, ...}` summary, so every plan it produced
  /// ignored what the user had actually eaten.
  Future<Map<String, dynamic>> _todaysIntake() async {
    final now = DateTime.now();
    final dateString =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    List<Map<String, dynamic>> entries = const [];
    try {
      entries = await UserDataService().getDietLog(dateString);
    } catch (e) {
      debugPrint('Diet log unavailable for planner: $e');
    }

    double num0(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

    double calories = 0, protein = 0, carbs = 0, fat = 0;
    for (final e in entries) {
      calories += num0(e['calories']);
      protein += num0(e['protein']);
      carbs += num0(e['carbs']);
      fat += num0(e['fat']);
    }

    return {
      'calories': calories.round(),
      'protein': protein.round(),
      'carbs': carbs.round(),
      'fat': fat.round(),
      'mealsLogged': entries.length,
    };
  }

  Future<void> _generateNewPlan() async {
    if (_isLoading) return;
    if (!context.read<FeatureFlagService>().mealPlannerEnabled) {
      setState(() {
        _error = 'AI Meal Planner is disabled by your current configuration.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    final session = UserSession.instance.capture();
    try {
      final profile = context.read<UserProfileProvider>().profile;
      final summary = await _todaysIntake();

      session.check();
      final plan = await CloudFunctionService().generateDietPlan(
        dailySummary: summary,
        userProfile: profile?.toMap(),
      );

      if (!mounted) return;

      if (plan.containsKey('error')) {
        setState(() => _error = plan['error'].toString());
        return;
      }

      final generatedAt = DateTime.now();
      session.check();
      await UserDataService().saveMealPlan(
          {...plan, 'generatedAt': generatedAt.toIso8601String()}, session);

      if (!mounted) return;
      setState(() {
        _mealPlan = plan;
        _generatedAt = generatedAt;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not reach the planner. $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _freshness(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  String _normalizeMealType(String? rawType) {
    final normalized = rawType?.trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
      case 'snacks':
        return 'Snack';
      default:
        return 'Snack';
    }
  }

  double _toDouble(Object? raw) =>
      raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;

  Future<void> _logPlannedMeal(int index, Map<String, dynamic> meal) async {
    if (_loggingIndex != null) return;
    setState(() => _loggingIndex = index);
    final session = UserSession.instance.capture();
    try {
      final name = meal['name']?.toString().trim().isNotEmpty == true
          ? meal['name'].toString().trim()
          : 'Planned Meal';
      final portion = meal['portionDescription']?.toString().trim() ?? '';
      await UserDataService().saveDietEntry({
        'id': UserDataService.newId(),
        'name': name,
        'brand': 'Meal Planner',
        'mealType': _normalizeMealType(meal['type']?.toString()),
        'calories': _toDouble(meal['calories']).round(),
        'protein': _toDouble(meal['protein']),
        'carbs': _toDouble(meal['carbs']),
        'fat': _toDouble(meal['fat']),
        'sugar': _toDouble(meal['sugar']),
        if (portion.isNotEmpty) 'portionDescription': portion,
      });
      AnalyticsService.record(UsageEvent.mealLogged);
      if (!mounted || !session.isActive) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged "$name" to today\'s Diet Log'),
          backgroundColor: FoodInsightColors.scannerGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not log planned meal: $e'),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingIndex = null);
    }
  }

  Future<void> _addIngredientsToShoppingList(
    List<String> rawIngredients, {
    int? mealIndex,
    String sourceLabel = 'Meal Plan',
  }) async {
    if (rawIngredients.isEmpty) return;
    if (mealIndex != null && _addingIngredientsIndex != null) return;
    if (mealIndex == null && _isExportingAll) return;

    setState(() {
      if (mealIndex != null) {
        _addingIngredientsIndex = mealIndex;
      } else {
        _isExportingAll = true;
      }
    });

    final session = UserSession.instance.capture();
    try {
      final existingItems = await UserDataService().getShoppingList();
      if (!mounted || !session.isActive) return;

      final existingNames = existingItems
          .map((item) => (item['name']?.toString() ?? '').trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet();

      var addedCount = 0;
      for (final raw in rawIngredients) {
        final ingredient = raw.trim();
        if (ingredient.isEmpty) continue;
        final key = ingredient.toLowerCase();
        if (!existingNames.add(key)) continue;

        await UserDataService().addShoppingItem({
          'id': UserDataService.newId(),
          'name': ingredient,
          'brand': sourceLabel,
        });
        addedCount++;
      }

      if (!mounted || !session.isActive) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount == 0
                ? 'All ingredients are already in your Shopping List'
                : 'Added $addedCount ${addedCount == 1 ? 'ingredient' : 'ingredients'} to Shopping List',
          ),
          backgroundColor: FoodInsightColors.scannerGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update Shopping List: $e'),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (mealIndex != null) {
            _addingIngredientsIndex = null;
          } else {
            _isExportingAll = false;
          }
        });
      }
    }
  }

  List<String> _collectAllPlanIngredients(List meals) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in meals) {
      if (raw is! Map) continue;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      for (final ingredient in extractMealIngredients(map)) {
        final key = ingredient.toLowerCase();
        if (seen.add(key)) out.add(ingredient);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final hasPlan = _mealPlan != null;
    final plannerEnabled =
        context.watch<FeatureFlagService>().mealPlannerEnabled;

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Smart Meal Planner',
          style: FoodInsightTypography.heading(
              size: 20,
              weight: FontWeight.w900,
              color: FoodInsightColors.deepCharcoal),
        ),
        centerTitle: true,
        backgroundColor: FoodInsightColors.warmWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: FoodInsightColors.deepCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (hasPlan && plannerEnabled)
            IconButton(
              tooltip: 'Regenerate plan',
              icon: Icon(Icons.autorenew_rounded,
                  color: _isLoading
                      ? FoodInsightColors.lightGray
                      : FoodInsightColors.scannerGreen),
              onPressed: _isLoading ? null : _generateNewPlan,
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: Column(
          children: [
            if (_error.isNotEmpty) _buildErrorBanner(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : !hasPlan
                      ? _buildEmptyState(plannerEnabled: plannerEnabled)
                      : _buildPlanView(plannerEnabled: plannerEnabled),
            ),
          ],
        ),
      ),
    );
  }

  /// The planner used to store failures in `_error` and never render them — a
  /// failed generation looked identical to "nothing happened".
  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: FoodInsightColors.healthRedLight,
        borderRadius: FoodInsightRadius.mdAll,
        border: Border.all(
            color: FoodInsightColors.healthRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: FoodInsightColors.healthRed, size: 20),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              _error,
              style: FoodInsightTypography.caption(
                  size: 13, color: FoodInsightColors.healthRed),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = ''),
            child: const Icon(Icons.close_rounded,
                color: FoodInsightColors.healthRed, size: 18),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: FoodInsightAnimations.fast)
        .slideY(begin: -0.2);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: FoodInsightColors.scannerGreen),
          SizedBox(height: 3.h),
          Text(
            'Crafting your personalized menu...',
            style: FoodInsightTypography.body(
                size: 16, color: FoodInsightColors.deepCharcoal),
          ).animate().fadeIn().scale(),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool plannerEnabled}) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded,
                size: 80,
                color: FoodInsightColors.scannerGreen.withValues(alpha: 0.5)),
            SizedBox(height: 3.h),
            Text(
              plannerEnabled ? 'No Meal Plan Yet' : 'Meal Planner Unavailable',
              style: FoodInsightTypography.heading(
                  size: 24, color: FoodInsightColors.deepCharcoal),
            ),
            SizedBox(height: 1.h),
            Text(
              plannerEnabled
                  ? 'Generate a daily meal plan tailored to your macros, preferences and what you have already logged today.'
                  : 'Smart Meal Planner is currently turned off in your app configuration.',
              textAlign: TextAlign.center,
              style: FoodInsightTypography.body(
                  size: 14, color: FoodInsightColors.midGray),
            ),
            SizedBox(height: 5.h),
            ElevatedButton(
              onPressed: plannerEnabled ? _generateNewPlan : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: FoodInsightColors.scannerGreen,
                disabledBackgroundColor: FoodInsightColors.lightGray,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                shape: RoundedRectangleBorder(
                    borderRadius: FoodInsightRadius.mdAll),
                elevation: 0,
              ),
              child: Text(
                'Generate Plan',
                style: FoodInsightTypography.body(
                    size: 16, weight: FontWeight.w700, color: Colors.white),
              ),
            ).animate().scale(
                duration: FoodInsightAnimations.medium,
                curve: FoodInsightAnimations.bounceIn),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanView({required bool plannerEnabled}) {
    final plan = _mealPlan!;
    final meals = plan['meals'] as List? ?? const [];
    final allIngredients = _collectAllPlanIngredients(meals);

    final listView = ListView(
      padding: EdgeInsets.all(5.w),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'Your AI Plan',
          style: FoodInsightTypography.heading(
              size: 28,
              weight: FontWeight.w900,
              color: FoodInsightColors.deepCharcoal),
        ).animate().fadeIn().slideX(),
        if (_generatedAt != null) ...[
          SizedBox(height: 0.4.h),
          Text(
            plannerEnabled
                ? 'Generated ${_freshness(_generatedAt!)} · pull down to refresh'
                : 'Generated ${_freshness(_generatedAt!)}',
            style: FoodInsightTypography.caption(
                size: 11, color: FoodInsightColors.midGray),
          ),
        ],
        SizedBox(height: 1.h),
        Text(
          plan['summary']?.toString() ??
              'Here is your optimized plan for the day.',
          style: FoodInsightTypography.body(
              size: 15, color: FoodInsightColors.midGray),
        ).animate().fadeIn(delay: 100.ms).slideX(),
        SizedBox(height: 3.h),
        Row(
          children: [
            Expanded(
                child: _buildTotalCard(
                    'Calories', '${plan['totalCalories'] ?? 0} kcal')),
            SizedBox(width: 3.w),
            Expanded(
                child: _buildTotalCard(
                    'Protein', '${plan['totalProtein'] ?? 0} g')),
          ],
        ).animate().fadeIn(delay: 200.ms).slideY(),
        if (allIngredients.isNotEmpty) ...[
          SizedBox(height: 2.h),
          OutlinedButton.icon(
            onPressed: _isExportingAll
                ? null
                : () => _addIngredientsToShoppingList(allIngredients),
            icon: const Icon(Icons.shopping_cart_checkout_rounded),
            label: Text(
              _isExportingAll
                  ? 'Exporting Ingredients...'
                  : 'Export ${allIngredients.length} Ingredients to Shopping List',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FoodInsightColors.scannerGreenDark,
              side: BorderSide(
                color: FoodInsightColors.scannerGreen.withValues(alpha: 0.45),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
        SizedBox(height: 3.h),
        if (meals.isEmpty)
          Text(
            plannerEnabled
                ? 'The planner returned no meals. Pull down to try again.'
                : 'This saved plan contains no meals.',
            style: FoodInsightTypography.body(
                size: 14, color: FoodInsightColors.midGray),
          )
        else
          ...meals.asMap().entries.map((e) {
            final idx = e.key;
            final raw = e.value;
            if (raw is! Map) return const SizedBox.shrink();
            final meal = raw.map((k, v) => MapEntry(k.toString(), v));
            final mealIngredients = extractMealIngredients(meal);
            final mealName = meal['name']?.toString().trim() ?? 'Meal Plan';
            return PlannedMealCard(
              meal: meal,
              isLogging: _loggingIndex == idx,
              isAddingIngredients: _addingIngredientsIndex == idx,
              onLogMeal: () => _logPlannedMeal(idx, meal),
              onAddIngredients: mealIngredients.isEmpty
                  ? null
                  : () => _addIngredientsToShoppingList(
                        mealIngredients,
                        mealIndex: idx,
                        sourceLabel: mealName,
                      ),
            )
                .animate()
                .fadeIn(delay: Duration(milliseconds: 300 + (idx * 100)))
                .slideY();
          }),
        SizedBox(height: 12.h),
      ],
    );

    if (!plannerEnabled) return listView;
    return RefreshIndicator(
      onRefresh: _generateNewPlan,
      color: FoodInsightColors.scannerGreen,
      child: listView,
    );
  }

  Widget _buildTotalCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FoodInsightRadius.mdAll,
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: FoodInsightTypography.caption(
                  size: 12, color: FoodInsightColors.midGray)),
          SizedBox(height: 0.5.h),
          Text(value,
              style: FoodInsightTypography.heading(
                  size: 20,
                  weight: FontWeight.w800,
                  color: FoodInsightColors.scannerGreen)),
        ],
      ),
    );
  }
}
