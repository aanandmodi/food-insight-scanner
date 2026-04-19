import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/cloud_function_service.dart';
import '../../services/firestore_service.dart';
import './widgets/action_bar_widget.dart';
import './widgets/alternatives_widget.dart';
import './widgets/ingredients_widget.dart';
import './widgets/nutrition_bars_widget.dart';
import './widgets/product_image_widget.dart';
import './widgets/product_info_widget.dart';
import './widgets/safety_alerts_widget.dart';

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
    // Load product data from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        productData = args;
      });
      _loadAlternatives(); // Trigger AI fetch
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
  List<Map<String, dynamic>> _alternatives = [];
  bool _isLoadingAlternatives = false;

  Future<void> _loadAlternatives() async {
    if (productData.isEmpty || _isLoadingAlternatives || _alternatives.isNotEmpty) return;

    setState(() {
      _isLoadingAlternatives = true;
    });

    try {
      // Create a profile map for the AI
      final profileMap = {
        'allergies': userAllergies,
        'dietaryPreferences': dietaryPreference,
        'healthGoals': healthGoal,
      };

      final results = await CloudFunctionService().getHealthyAlternatives(
        productData: productData,
        userProfile: profileMap,
      );

      if (mounted) {
        setState(() {
          _alternatives = results;
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
    if (_scrollController.offset > 100 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 100 && _isScrolled) {
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

      final savedToCloud = await FirestoreService().saveDietEntry(entryData);

      if (mounted) {
        final theme = Theme.of(context);
        final message = savedToCloud
            ? '${productData['name']} added to diet log!'
            : '${productData['name']} saved locally to diet log!';
        final icon = savedToCloud ? Icons.cloud_done : Icons.save;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(child: Text(message)),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving diet entry: $e');
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add to diet log. Please try again.')),
        );
      }
    }
  }

  void _navigateToAIChat() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? 'User';
    final allergies = prefs.getStringList('user_allergies') ?? [];
    final goal = prefs.getString('user_health_goal') ?? '';
    final dietPrefs = prefs.getStringList('user_dietary_preferences') ?? [];

    if (mounted) {
      Navigator.pushNamed(
        context,
        '/ai-chat-assistant',
        arguments: {
          'name': userName,
          'allergies': allergies,
          'dietaryPreferences': dietPrefs.join(', '),
          'healthGoals': goal,
          'age': 25,
          'activityLevel': 'moderate',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (productData.isEmpty) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        colorScheme.primary.withValues(alpha: 0.08),
                        theme.scaffoldBackgroundColor,
                        theme.scaffoldBackgroundColor,
                      ]
                    : [
                        colorScheme.primary.withValues(alpha: 0.05),
                        theme.scaffoldBackgroundColor,
                      ],
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              // Custom glass app bar
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _isScrolled ? 15 : 0,
                    sigmaY: _isScrolled ? 15 : 0,
                  ),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 2.h,
                      left: 4.w,
                      right: 4.w,
                      bottom: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: _isScrolled
                          ? (isDark
                              ? AppTheme.glassDarkBg
                              : colorScheme.surface.withValues(alpha: 0.95))
                          : Colors.transparent,
                      border: _isScrolled
                          ? Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? AppTheme.glassDarkBorder
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            )
                          : null,
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
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : colorScheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: CustomIconWidget(
                              iconName: 'arrow_back',
                              size: 24,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: _isScrolled ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              productName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
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
                              color: _nutriscoreColor(nutriscore),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isDark
                                  ? [
                                      BoxShadow(
                                        color: _nutriscoreColor(nutriscore)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              nutriscore.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
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
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : colorScheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: CustomIconWidget(
                              iconName: 'chat',
                              size: 24,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Scrollable content with staggered animations
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: colorScheme.primary,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 2.h),
                        // Product image with parallax feel
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
                        // Alternatives
                        if (_isLoadingAlternatives)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
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
        return const Color(0xFF1B8B2D);
      case 'b':
        return const Color(0xFF7AC143);
      case 'c':
        return const Color(0xFFF5C623);
      case 'd':
        return const Color(0xFFE8A317);
      case 'e':
        return const Color(0xFFE63E11);
      default:
        return Colors.grey;
    }
  }
}
