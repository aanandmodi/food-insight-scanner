// lib/presentation/meal_planner/meal_planner_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../../theme/app_design_system.dart';
import '../../services/cloud_function_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSavedPlan();
  }

  Future<void> _loadSavedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('saved_meal_plan');
    if (savedJson != null) {
      setState(() {
        _mealPlan = jsonDecode(savedJson);
      });
    }
  }

  Future<void> _generateNewPlan() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final profile = context.read<UserProfileProvider>().profile;
      
      // Dummy daily summary (Ideally we fetch today's actual logs)
      final dummySummary = {
        'calories': 1800,
        'protein': 100,
        'carbs': 200,
        'fat': 60,
      };

      final plan = await CloudFunctionService().generateDietPlan(
        dailySummary: dummySummary,
        userProfile: profile?.toMap(),
      );

      if (plan.containsKey('error')) {
        setState(() => _error = plan['error']);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_meal_plan', jsonEncode(plan));
        setState(() {
          _mealPlan = plan;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Smart Meal Planner',
          style: FoodInsightTypography.heading(size: 20, weight: FontWeight.w900, color: FoodInsightColors.deepCharcoal),
        ),
        centerTitle: true,
        backgroundColor: FoodInsightColors.warmWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: FoodInsightColors.deepCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _mealPlan == null
                ? _buildEmptyState()
                : _buildPlanView(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
          SizedBox(height: 3.h),
          Text(
            'Groq is crafting your perfect plan...',
            style: FoodInsightTypography.body(size: 16, color: FoodInsightColors.midGray),
          ).animate().fade().slideY(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 80, color: FoodInsightColors.scannerGreen.withValues(alpha: 0.5)),
            SizedBox(height: 3.h),
            Text(
              'No Meal Plan Found',
              style: FoodInsightTypography.heading(size: 24, color: FoodInsightColors.deepCharcoal),
            ),
            SizedBox(height: 1.h),
            Text(
              'Generate a customized daily meal plan powered by AI, tailored exactly to your macros and preferences.',
              textAlign: TextAlign.center,
              style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.midGray),
            ),
            SizedBox(height: 5.h),
            ElevatedButton(
              onPressed: _generateNewPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: FoodInsightColors.scannerGreen,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.mdAll),
                elevation: 0,
              ),
              child: Text(
                'Generate Plan',
                style: FoodInsightTypography.body(size: 16, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanView() {
    final meals = _mealPlan!['meals'] as List? ?? [];
    
    return RefreshIndicator(
      onRefresh: _generateNewPlan,
      color: FoodInsightColors.scannerGreen,
      child: ListView(
        padding: EdgeInsets.all(5.w),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'Your AI Plan',
            style: FoodInsightTypography.heading(size: 28, weight: FontWeight.w900, color: FoodInsightColors.deepCharcoal),
          ).animate().fadeIn().slideX(),
          SizedBox(height: 1.h),
          Text(
            _mealPlan!['summary'] ?? 'Here is your optimized plan for the day.',
            style: FoodInsightTypography.body(size: 15, color: FoodInsightColors.midGray),
          ).animate().fadeIn(delay: 100.ms).slideX(),
          
          SizedBox(height: 3.h),
          
          // Totals
          Row(
            children: [
              Expanded(child: _buildTotalCard('Calories', '${_mealPlan!['totalCalories'] ?? 0} kcal')),
              SizedBox(width: 3.w),
              Expanded(child: _buildTotalCard('Protein', '${_mealPlan!['totalProtein'] ?? 0} g')),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(),
          
          SizedBox(height: 4.h),
          
          ...meals.asMap().entries.map((e) {
            final idx = e.key;
            final meal = e.value as Map<String, dynamic>;
            return _buildMealCard(meal).animate().fadeIn(delay: Duration(milliseconds: 300 + (idx * 100))).slideY();
          }).toList(),
          
          SizedBox(height: 10.h), // Bottom padding
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
          Text(label, style: FoodInsightTypography.caption(size: 12, color: FoodInsightColors.midGray)),
          SizedBox(height: 0.5.h),
          Text(value, style: FoodInsightTypography.heading(size: 20, weight: FontWeight.w800, color: FoodInsightColors.scannerGreen)),
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
        border: Border.all(color: FoodInsightColors.scannerGreen.withValues(alpha: 0.2)),
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: FoodInsightColors.scannerGreenLight,
                  borderRadius: FoodInsightRadius.smAll,
                ),
                child: Text(
                  meal['type'] ?? 'Meal',
                  style: FoodInsightTypography.caption(size: 12, weight: FontWeight.w700, color: FoodInsightColors.scannerGreenDark),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 14, color: FoodInsightColors.healthRed),
                  SizedBox(width: 1.w),
                  Text('${meal['calories']} kcal', style: FoodInsightTypography.caption(size: 12, weight: FontWeight.w600, color: FoodInsightColors.healthRed)),
                  SizedBox(width: 2.w),
                  Icon(Icons.fitness_center_rounded, size: 14, color: FoodInsightColors.healthGreen),
                  SizedBox(width: 1.w),
                  Text('${meal['protein']}g P', style: FoodInsightTypography.caption(size: 12, weight: FontWeight.w600, color: FoodInsightColors.healthGreen)),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            meal['name'] ?? 'Unknown Meal',
            style: FoodInsightTypography.heading(size: 18, color: FoodInsightColors.deepCharcoal),
          ),
          SizedBox(height: 1.h),
          Text(
            meal['description'] ?? '',
            style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.midGray),
          ),
        ],
      ),
    );
  }
}
