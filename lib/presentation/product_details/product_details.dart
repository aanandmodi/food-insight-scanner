import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';


import '../../core/app_export.dart';
import '../../core/services/groq_service.dart';
import '../../core/services/firestore_service.dart';
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

      final results = await GroqService().getHealthyAlternatives(
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
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Pop context to return to previous screen
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
    if (productData.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
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
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.lightTheme.colorScheme.primary
                      .withValues(alpha: 0.05),
                  AppTheme.lightTheme.scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              // Custom app bar
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 2.h,
                  left: 4.w,
                  right: 4.w,
                  bottom: 2.h,
                ),
                decoration: BoxDecoration(
                  color: _isScrolled
                      ? AppTheme.lightTheme.colorScheme.surface
                          .withValues(alpha: 0.95)
                      : Colors.transparent,
                  boxShadow: _isScrolled
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: AppTheme.lightTheme.colorScheme.surface
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.lightTheme.colorScheme.outline
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: CustomIconWidget(
                          iconName: 'arrow_back',
                          size: 24,
                          color: AppTheme.lightTheme.colorScheme.onSurface,
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
                          style: AppTheme.lightTheme.textTheme.titleLarge
                              ?.copyWith(
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
                      onTap: _navigateToAIChat,
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: AppTheme.lightTheme.colorScheme.surface
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.lightTheme.colorScheme.outline
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: CustomIconWidget(
                          iconName: 'chat',
                          size: 24,
                          color: AppTheme.lightTheme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppTheme.lightTheme.colorScheme.primary,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 2.h),
                        // Product image
                        ProductImageWidget(
                          imageUrl: imageUrl,
                          productName: productName,
                        ),
                        SizedBox(height: 3.h),
                        // Product info
                        ProductInfoWidget(
                          productName: productName,
                          brand: brand,
                          category: category,
                          rating: null,
                        ),
                        SizedBox(height: 3.h),
                        // Nutrition bars
                        if (nutrition.isNotEmpty)
                          NutritionBarsWidget(
                            nutritionData: nutrition,
                          ),
                        SizedBox(height: 3.h),
                        // Safety alerts
                        SafetyAlertsWidget(
                          userAllergies: userAllergies,
                          ingredients: ingredients,
                          dietaryPreference: dietaryPreference,
                          nutritionData: nutrition,
                        ),
                        SizedBox(height: 3.h),
                        // Ingredients
                        IngredientsWidget(
                          ingredients: ingredients,
                          userAllergies: userAllergies,
                        ),
                        SizedBox(height: 3.h),
                        // Alternatives - empty for now since we use real data
                        if (_isLoadingAlternatives)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            child: const Center(child: CircularProgressIndicator()),
                          )
                        else
                          AlternativesWidget(
                            alternatives: _alternatives,
                          ),
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
