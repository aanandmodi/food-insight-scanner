// lib/presentation/product_details/product_details.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/cloud_function_service.dart';
import '../../services/product_service.dart';
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

  // Loading state for when we receive a barcode string and need to fetch
  bool _isLoadingProduct = false;
  bool _didProcessArgs = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didProcessArgs) return;
    _didProcessArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      // Direct product data (from barcode scanner)
      setState(() {
        productData = args;
      });
    } else if (args is String && args.isNotEmpty) {
      // Barcode string (from scan history) — need to fetch product data
      _fetchProductByBarcode(args);
      return;
    }

    // Alternatives are personalised, so they must wait for the profile.
    // Previously both ran concurrently and the AI was prompted with empty
    // allergies/goals on almost every open.
    _loadUserProfile().then((_) {
      if (mounted) _loadAlternatives();
    });
  }

  Future<void> _fetchProductByBarcode(String barcode) async {
    setState(() {
      _isLoadingProduct = true;
    });

    try {
      // Goes through ProductService so we inherit the network timeout and the
      // offline fallback to the last cached copy of this product.
      final data = await ProductService().getProductByBarcode(barcode);
      if (data != null && mounted) {
        setState(() {
          productData = data;
          _isLoadingProduct = false;
        });
        await _loadUserProfile();
        if (mounted) _loadAlternatives();
      } else if (mounted) {
        setState(() {
          _isLoadingProduct = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load product details.', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error fetching product by barcode: $e');
      if (mounted) {
        setState(() {
          _isLoadingProduct = false;
        });
        Navigator.pop(context);
      }
    }
  }

  /// Reads the profile from [UserProfileProvider] (the single source of truth)
  /// and only falls back to SharedPreferences when it hasn't loaded yet.
  Future<void> _loadUserProfile() async {
    try {
      final profile = context.read<UserProfileProvider>().profile;
      if (profile != null) {
        if (!mounted) return;
        setState(() {
          userAllergies = profile.allergies;
          dietaryPreference = profile.dietaryPreferences.join(', ');
          healthGoal = profile.healthGoals;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
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

  /// Pull-to-refresh actually re-fetches the product now; it used to just
  /// `await Future.delayed(1s)` and show the same stale data.
  Future<void> _onRefresh() async {
    final barcode = (productData['barcode'] ?? '').toString();
    if (barcode.isEmpty) return;

    final fresh = await ProductService().getProductByBarcode(barcode);
    if (!mounted || fresh == null) return;

    setState(() {
      productData = fresh;
      _alternatives.clear();
    });
    // Re-derive suggestions against the refreshed nutrition data.
    _loadAlternatives();
  }

  /// Cached rows and Firestore documents hand back maps with varying generic
  /// types; a hard `as Map<String, dynamic>?` cast threw and blanked the whole
  /// AI section. This normalises instead.
  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Sensible default meal slot based on the time of day — everything used to
  /// be filed as "Snack".
  String _mealTypeForNow(DateTime now) {
    final h = now.hour;
    if (h < 11) return 'Breakfast';
    if (h < 16) return 'Lunch';
    if (h < 21) return 'Dinner';
    return 'Snack';
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
        // The normalized product map uses `servingSize`; the old `serving_size`
        // key was always null, so every logged item said "1 serving".
        'serving': productData['servingSize'] ??
            productData['serving_size'] ??
            '1 serving',
        'mealType': _mealTypeForNow(now),
        'date': dateString,
        'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      };

      // Single write path: saveDietEntry writes SQLite *and* Firestore and
      // notifies the rest of the app. Calling insertDietEntry here as well used
      // to create the same meal twice in the local log.
      await FirestoreService().saveDietEntry(entryData);

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
              if (_isLoadingProduct) ...[
                SizedBox(height: 16),
                Text(
                  'Loading product details...',
                  style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.midGray),
                ),
              ],
            ],
          ),
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
                          aiAnalysis: _asStringMap(productData['aiAnalysis']),
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
