// lib/presentation/meal_planner/meal_planner_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../../theme/app_design_system.dart';
import '../../services/cloud_function_service.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../data/providers/user_profile_provider.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  bool _isLoading = false;
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
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('saved_meal_plan');
      if (savedJson == null || !mounted) return;

      final decoded = jsonDecode(savedJson);
      if (decoded is! Map) return;

      final stamp = prefs.getString('saved_meal_plan_at');
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
      entries = await FirestoreService().getDietLog(dateString);
    } catch (e) {
      debugPrint('Cloud diet log unavailable for planner: $e');
    }
    if (entries.isEmpty) {
      try {
        entries = await LocalDatabaseService().getDietLogByDate(dateString);
      } catch (e) {
        debugPrint('Local diet log unavailable for planner: $e');
      }
    }

    double num0(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

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

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final profile = context.read<UserProfileProvider>().profile;
      final summary = await _todaysIntake();

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_meal_plan', jsonEncode(plan));
      await prefs.setString(
          'saved_meal_plan_at', generatedAt.toIso8601String());

      if (!mounted) return;
      setState(() {
        _mealPlan = plan;
        _generatedAt = generatedAt;
      });
      HapticFeedback.mediumImpact();
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

  @override
  Widget build(BuildContext context) {
    final hasPlan = _mealPlan != null;

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
          if (hasPlan)
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
                      ? _buildEmptyState()
                      : _buildPlanView(),
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
    ).animate().fadeIn(duration: FoodInsightAnimations.fast).slideY(begin: -0.2);
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
            'Building a plan around what you ate today…',
            textAlign: TextAlign.center,
            style: FoodInsightTypography.body(
                size: 16, color: FoodInsightColors.midGray),
          ).animate().fade().slideY(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
              'No Meal Plan Yet',
              style: FoodInsightTypography.heading(
                  size: 24, color: FoodInsightColors.deepCharcoal),
            ),
            SizedBox(height: 1.h),
            Text(
              'Generate a daily meal plan tailored to your macros, preferences and what you have already logged today.',
              textAlign: TextAlign.center,
              style: FoodInsightTypography.body(
                  size: 14, color: FoodInsightColors.midGray),
            ),
            SizedBox(height: 5.h),
            ElevatedButton(
              onPressed: _generateNewPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: FoodInsightColors.scannerGreen,
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
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

  Widget _buildPlanView() {
    final plan = _mealPlan!;
    final meals = plan['meals'] as List? ?? const [];

    return RefreshIndicator(
      onRefresh: _generateNewPlan,
      color: FoodInsightColors.scannerGreen,
      child: ListView(
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
              'Generated ${_freshness(_generatedAt!)} · pull down to refresh',
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
          SizedBox(height: 4.h),
          if (meals.isEmpty)
            Text(
              'The planner returned no meals. Pull down to try again.',
              style: FoodInsightTypography.body(
                  size: 14, color: FoodInsightColors.midGray),
            )
          else
            ...meals.asMap().entries.map((e) {
              final idx = e.key;
              final raw = e.value;
              if (raw is! Map) return const SizedBox.shrink();
              final meal = raw.map((k, v) => MapEntry(k.toString(), v));
              return _buildMealCard(meal).animate().fadeIn(
                  delay: Duration(milliseconds: 300 + (idx * 100))).slideY();
            }),
          SizedBox(height: 12.h),
        ],
      ),
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

  Widget _buildMealCard(Map<String, dynamic> meal) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FoodInsightRadius.lgAll,
        border: Border.all(
            color: FoodInsightColors.scannerGreen.withValues(alpha: 0.2)),
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: FoodInsightColors.scannerGreenLight,
                  borderRadius: FoodInsightRadius.smAll,
                ),
                child: Text(
                  meal['type']?.toString() ?? 'Meal',
                  style: FoodInsightTypography.caption(
                      size: 12,
                      weight: FontWeight.w700,
                      color: FoodInsightColors.scannerGreenDark),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 14, color: FoodInsightColors.healthRed),
                  SizedBox(width: 1.w),
                  Text('${meal['calories'] ?? 0} kcal',
                      style: FoodInsightTypography.caption(
                          size: 12,
                          weight: FontWeight.w600,
                          color: FoodInsightColors.healthRed)),
                  SizedBox(width: 2.w),
                  const Icon(Icons.fitness_center_rounded,
                      size: 14, color: FoodInsightColors.healthGreen),
                  SizedBox(width: 1.w),
                  Text('${meal['protein'] ?? 0}g P',
                      style: FoodInsightTypography.caption(
                          size: 12,
                          weight: FontWeight.w600,
                          color: FoodInsightColors.healthGreen)),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            meal['name']?.toString() ?? 'Unknown Meal',
            style: FoodInsightTypography.heading(
                size: 18, color: FoodInsightColors.deepCharcoal),
          ),
          SizedBox(height: 1.h),
          Text(
            meal['description']?.toString() ?? '',
            style: FoodInsightTypography.body(
                size: 14, color: FoodInsightColors.midGray),
          ),
        ],
      ),
    );
  }
}
