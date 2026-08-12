// lib/presentation/product_details/product_details.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../services/cloud_function_service.dart';
import '../../data/providers/user_profile_provider.dart';
import './widgets/action_bar_widget.dart';
import './widgets/alternatives_widget.dart';
import './widgets/ingredients_widget.dart';
import './widgets/nutrition_bars_widget.dart';
import './widgets/product_image_widget.dart';
import './widgets/product_info_widget.dart';
import './widgets/safety_alerts_widget.dart';
import './widgets/ai_analysis_widget.dart';
import '../../theme/app_design_system.dart';

class ProductDetails extends StatefulWidget {
  const ProductDetails({super.key});

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  // User profile loaded from SharedPreferences
  List<String> userAllergies = [];
  String dietaryPreference = '';
  String healthGoal = '';

  // Product data received from route arguments
  Map<String, dynamic> productData = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        productData = args;
      });
      _loadAlternatives(); 
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userAllergies = prefs.getStringList('user_allergies') ?? [];
        dietaryPreference =
            (prefs.getStringList('user_dietary_preferences') ?? []).join(', ');
        healthGoal = prefs.getString('user_health_goal') ?? '';
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  // AI Alternatives State
  final List<Map<String, dynamic>> _alternatives = [];
  bool _isLoadingAlternatives = false;

  Future<void> _loadAlternatives() async {
    if (productData.isEmpty || _isLoadingAlternatives || _alternatives.isNotEmpty) return;

    setState(() {
      _isLoadingAlternatives = true;
    });

    try {
      final profileMap = <String, dynamic>{
        'allergies': userAllergies,
        'dietaryPreference': dietaryPreference,
        'healthGoal': healthGoal,
      };

      final results = await CloudFunctionService().getAlternatives(
        productData: productData,
        userProfile: profileMap,
      );

      if (mounted) {
        setState(() {
          _alternatives.addAll(results);
        });
      }
    } catch (e) {
      debugPrint('Error loading alternatives: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAlternatives = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 50 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> _onAddToDietLog() async {
    HapticFeedback.mediumImpact();
    try {
      final now = DateTime.now();
      final dateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final entryData = {
        'name': productData['name'] ?? 'Unknown',
        'brand': productData['brand'] ?? 'Unknown',
        'calories': (productData['nutrition']?['calories'] as num?)?.toInt() ?? 0,
        'protein': (productData['nutrition']?['protein'] as num?)?.toDouble() ?? 0.0,
        'sugar': (productData['nutrition']?['sugar'] as num?)?.toDouble() ?? 0.0,
        'fat': (productData['nutrition']?['fat'] as num?)?.toDouble() ?? 0.0,
        'carbs': (productData['nutrition']?['carbs'] as num?)?.toDouble() ?? 0.0,
        'serving': productData['serving_size'] ?? '1 serving',
        'mealType': 'Snack',
        'date': dateString,
        'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      };

      await LocalDatabaseService().insertDietEntry(entryData);

      try {
        await FirestoreService().saveDietEntry(entryData);
      } catch (e) {
        debugPrint('Firestore save option skipped: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(child: Text('${productData['name']} logged to your diet!', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white))),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: FoodInsightColors.scannerGreen,
            shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error adding diet entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to diet log. Please try again.', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    }
  }

  void _navigateToAIChat() async {
    final profile = context.read<UserProfileProvider>().profile;
    
    if (mounted) {
      Navigator.pushNamed(
        context,
        '/ai-chat-assistant',
        arguments: {
          'name': profile?.name ?? 'User',
          'allergies': profile?.allergies ?? [],
          'dietaryPreferences': profile?.dietaryPreferences.join(', ') ?? '',
          'healthGoals': profile?.healthGoals ?? '',
          'age': profile?.age ?? 25,
          'activityLevel': profile?.activityLevel ?? 'moderate',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (productData.isEmpty) {
      return Scaffold(
        backgroundColor: FoodInsightColors.warmWhite,
        body: Center(
          child: CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
        ),
      );
    }

    final String productName =
        productData['name'] as String? ?? 'Unknown Product';
    final String brand = productData['brand'] as String? ?? 'Unknown Brand';
    final String category = productData['category'] as String? ?? '';
    final String? imageUrl = productData['image'] as String?;
    final Map<String, dynamic> nutrition =
        (productData['nutrition'] as Map<String, dynamic>?) ?? {};
    final List<String> ingredients =
        (productData['ingredients'] as List?)?.cast<String>() ?? [];
    final String? nutriscore = productData['nutriscore'] as String?;

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: FoodInsightColors.warmBackground,
            ),
          ),
          // Main content
          Column(
            children: [
              // Custom solid app bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 2.h,
                  left: 4.w,
                  right: 4.w,
                  bottom: 2.h,
                ),
                decoration: BoxDecoration(
                  color: _isScrolled ? Colors.white : Colors.transparent,
                  boxShadow: _isScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))] : null,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: FoodInsightColors.warmWhite,
                          borderRadius: FoodInsightRadius.smAll,
                          border: Border.all(
                            color: FoodInsightColors.outlineGray,
                          ),
                        ),
                        child: Icon(Icons.arrow_back_rounded, color: FoodInsightColors.deepCharcoal),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: _isScrolled ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          productName,
                          style: FoodInsightTypography.heading(size: 18, weight: FontWeight.w800, color: FoodInsightColors.deepCharcoal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Nutri-Score badge
                    if (nutriscore != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 3.w, vertical: 0.5.h),
                        margin: EdgeInsets.only(right: 2.w),
                        decoration: BoxDecoration(
                          color: _nutriscoreColor(nutriscore).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          nutriscore.toUpperCase(),
                          style: TextStyle(
                            color: _nutriscoreColor(nutriscore),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _navigateToAIChat();
                      },
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: FoodInsightColors.warmWhite,
                          borderRadius: FoodInsightRadius.smAll,
                          border: Border.all(
                            color: FoodInsightColors.outlineGray,
                          ),
                        ),
                        child: Icon(Icons.restaurant_rounded, color: FoodInsightColors.scannerGreen),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable content with staggered animations
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: FoodInsightColors.scannerGreen,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 2.h),
                        // Product image
                        Hero(
                          tag: 'scan_${productData['id'] ?? productData['barcode'] ?? ''}',
                          child: ProductImageWidget(
                            imageUrl: imageUrl,
                            productName: productName,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .scaleXY(begin: 0.95, end: 1.0, duration: 500.ms),
                        SizedBox(height: 3.h),
                        // Product info
                        ProductInfoWidget(
                          productName: productName,
                          brand: brand,
                          category: category,
                          rating: null,
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 100.ms)
                            .slideY(begin: 0.03, end: 0),
                        SizedBox(height: 3.h),
                        // Nutrition bars
                        if (nutrition.isNotEmpty)
                          NutritionBarsWidget(
                            nutritionData: nutrition,
                          )
                              .animate()
                              .fadeIn(duration: 500.ms, delay: 200.ms)
                              .slideY(begin: 0.03, end: 0),
                        SizedBox(height: 3.h),
                        // Safety alerts
                        SafetyAlertsWidget(
                          userAllergies: userAllergies,
                          ingredients: ingredients,
                          dietaryPreference: dietaryPreference,
                          nutritionData: nutrition,
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 300.ms)
                            .slideY(begin: 0.03, end: 0),
                        SizedBox(height: 3.h),
                        // Ingredients
                        IngredientsWidget(
                          ingredients: ingredients,
                          userAllergies: userAllergies,
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 400.ms),
                        SizedBox(height: 3.h),
                        // AI Analysis & Micro-nutrients
                        AiAnalysisWidget(
                          aiAnalysis: productData['aiAnalysis'] as Map<String, dynamic>?,
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 450.ms)
                            .slideY(begin: 0.03, end: 0),
                        SizedBox(height: 3.h),
                        // AI insights alternatives
                        if (_isLoadingAlternatives)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: FoodInsightColors.scannerGreen,
                              ),
                            ),
                          )
                        else
                          AlternativesWidget(
                            alternatives: _alternatives,
                          )
                              .animate()
                              .fadeIn(duration: 500.ms, delay: 500.ms),
                        SizedBox(height: 12.h),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ActionBarWidget(
              productData: productData,
              onAddToDietLog: _onAddToDietLog,
            ),
          ),
        ],
      ),
    );
  }

  Color _nutriscoreColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'a':
        return FoodInsightColors.healthGreen;
      case 'b':
        return FoodInsightColors.healthLightGreen;
      case 'c':
        return FoodInsightColors.healthYellow;
      case 'd':
        return FoodInsightColors.healthOrange;
      case 'e':
        return FoodInsightColors.healthRed;
      default:
        return FoodInsightColors.midGray;
    }
  }
}
