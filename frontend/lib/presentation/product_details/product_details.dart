import '../../services/analytics_service.dart';
import '../../services/ai_context_builder.dart';
import '../../services/feature_flag_service.dart';
// lib/presentation/product_details/product_details.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/user_preferences.dart';
import 'package:sizer/sizer.dart';

import 'package:provider/provider.dart';
import '../../services/user_data_service.dart';
import '../../services/cloud_function_service.dart';
import '../../services/product_service.dart';
import '../../data/providers/user_profile_provider.dart';
import './widgets/action_bar_widget.dart';
import './widgets/portion_picker_dialog.dart';
import '../../services/product_facts_adapter.dart';
import '../../services/food_fit_service.dart';
import './widgets/ingredients_widget.dart';
import './widgets/food_additives_widget.dart';
import './widgets/verified_alternatives_widget.dart';
import './widgets/nutrition_bars_widget.dart';
import './widgets/product_image_widget.dart';
import './widgets/product_info_widget.dart';
import './widgets/safety_alerts_widget.dart';
import './widgets/ai_analysis_widget.dart';
import '../../routes/app_routes.dart';
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
  List<String> userConditions = [];
  String dietaryPreference = '';
  String healthGoal = '';

  // Product data received from route arguments
  Map<String, dynamic> productData = {};

  // Loading state for when we receive a barcode string and need to fetch
  bool _isLoadingProduct = false;
  bool _didProcessArgs = false;
  bool _recordedFitView = false;

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
        productData = ProductFactsAdapter.adapt(args);
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
      if (mounted) _loadDailyContext();
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
          productData = ProductFactsAdapter.adapt(data);
          _isLoadingProduct = false;
        });
        await _loadUserProfile();
        if (mounted) _loadDailyContext();
      } else if (mounted) {
        setState(() {
          _isLoadingProduct = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load product details.',
                style: FoodInsightTypography.caption(
                    size: 14, weight: FontWeight.w700, color: Colors.white)),
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
          userConditions = profile.diseases;
          dietaryPreference = profile.dietaryPreferences.join(', ');
          healthGoal = profile.healthGoals;
        });
        return;
      }

      final prefs = await UserPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        userAllergies = prefs.getStringList('user_allergies') ?? [];
        userConditions = prefs.getStringList('user_diseases') ?? [];
        dietaryPreference =
            (prefs.getStringList('user_dietary_preferences') ?? []).join(', ');
        healthGoal = prefs.getString('user_health_goal') ?? '';
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Map<String, num> _dailyContext = {};
  Map<String, dynamic>? _explanation;
  bool _explaining = false;

  Future<void> _loadDailyContext() async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    try {
      final rows = await UserDataService().cachedDiet(date);
      if (!mounted) return;
      final snapshot = AIContextBuilder.build(
          task: 'analysis',
          userProfile:
              context.read<UserProfileProvider>().profile?.toMap() ?? {},
          logs: rows);
      final today = snapshot['today'] as Map;
      final remaining = today['remaining'] as Map;
      setState(() => _dailyContext = {
            for (final key in ['calories', 'protein', 'carbs', 'fat']) ...{
              if (today[key] is num) '${key}Consumed': today[key] as num,
              if (remaining[key] is num)
                '${key}Remaining': remaining[key] as num,
            },
            if (today['sugar'] is num) 'sugarGConsumed': today['sugar'] as num,
            if (today['sodium'] is num)
              'sodiumMgConsumed': today['sodium'] as num,
          });
    } catch (_) {/* No daily context is preferable to invented totals. */}
  }

  Future<void> _explainProduct() async {
    if (_explaining || _explanation != null) return;
    setState(() => _explaining = true);
    try {
      final fit = FoodFitService.evaluate(productData,
          allergies: userAllergies,
          conditions: userConditions,
          dietaryPreference: dietaryPreference,
          healthGoal: healthGoal,
          dailyContext: _dailyContext);
      final result = await CloudFunctionService().explainProduct(
          productData: productData,
          fitResult: fit.toMap(),
          userProfile: context.read<UserProfileProvider>().profile?.toMap());
      if (mounted) setState(() => _explanation = result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _explaining = false);
    }
  }

  void _discussProduct() {
    if (!context.read<FeatureFlagService>().aiChatEnabled) return;
    final fit = FoodFitService.evaluate(productData,
        allergies: userAllergies,
        conditions: userConditions,
        dietaryPreference: dietaryPreference,
        healthGoal: healthGoal,
        dailyContext: _dailyContext);
    Navigator.pushNamed(
      context,
      AppRoutes.aiChatAssistant,
      arguments: {
        'product': AIContextBuilder.productFacts(productData),
        'foodFit': fit.toMap(),
      },
    );
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

    final fresh =
        await ProductService().getProductByBarcode(barcode, forceRefresh: true);
    if (!mounted || fresh == null) return;

    setState(() {
      productData = ProductFactsAdapter.adapt(fresh);
      _explanation = null;
    });
    // Re-derive suggestions against the refreshed nutrition data.
    _loadDailyContext();
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

  bool _isLogging = false;
  bool _isAddingToShopping = false;

  Future<void> _onAddToShoppingList() async {
    if (_isAddingToShopping || productData.isEmpty) return;
    setState(() => _isAddingToShopping = true);
    HapticFeedback.lightImpact();
    try {
      final barcode = (productData['barcode'] ?? '').toString().trim();
      final rawBrand = (productData['brand'] ?? '').toString().trim();
      await UserDataService().addShoppingItem({
        if (barcode.isNotEmpty) 'id': 'product_$barcode',
        if (barcode.isNotEmpty) 'barcode': barcode,
        'name': productData['name'] ?? 'Unknown Product',
        'brand': rawBrand.isEmpty ? 'Saved product' : rawBrand,
        'image': productData['image'] ?? '',
        'score': (productData['nutriscore'] ?? '0').toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${productData['name'] ?? 'product'} to Shopping List',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: FoodInsightColors.scannerGreen,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                if (mounted) {
                  Navigator.pushNamed(context, '/shopping-list');
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not add item to shopping list.'),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToShopping = false);
    }
  }

  Future<void> _onAddToDietLog() async {
    if (_isLogging) return;
    setState(() => _isLogging = true);
    final scaledPortion = await showPortionPickerDialog(
      context,
      productData: productData,
    );
    if (!mounted) return;
    if (scaledPortion == null) {
      setState(() => _isLogging = false);
      return;
    }
    HapticFeedback.lightImpact();
    try {
      final now = DateTime.now();
      final dateString =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final entryData = {
        'name': productData['name'] ?? 'Unknown',
        'brand': productData['brand'] ?? 'Unknown',
        ...scaledPortion,
        'mealType': _mealTypeForNow(now),
        'date': dateString,
        'time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      };

      // Single write path: saveDietEntry writes SQLite *and* Firestore and
      // notifies the rest of the app. Calling insertDietEntry here as well used
      // to create the same meal twice in the local log.
      await UserDataService().saveDietEntry(entryData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(
                    child: Text('${productData['name']} logged to your diet!',
                        style: FoodInsightTypography.caption(
                            size: 14,
                            weight: FontWeight.w700,
                            color: Colors.white))),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: FoodInsightColors.scannerGreen,
            shape:
                RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error adding diet entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e is FormatException
                    ? e.message
                    : 'Could not save this meal. Please retry.',
                style: FoodInsightTypography.caption(
                    size: 14, weight: FontWeight.w700, color: Colors.white)),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (productData.isNotEmpty && !_recordedFitView) {
      _recordedFitView = true;
      AnalyticsService.record(UsageEvent.foodFitViewed);
    }
    if (productData.isEmpty) {
      return Scaffold(
        backgroundColor: FoodInsightColors.warmWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                  color: FoodInsightColors.scannerGreen),
              if (_isLoadingProduct) ...[
                const SizedBox(height: 16),
                Text(
                  'Loading product details...',
                  style: FoodInsightTypography.body(
                      size: 14, color: FoodInsightColors.midGray),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final String productName =
        productData['name'] as String? ?? 'Unknown Product';
    final rawDisplayBrand = productData['brand']?.toString().trim() ?? '';
    final String brand =
        rawDisplayBrand.isEmpty ? 'Unknown Brand' : rawDisplayBrand;
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
                  boxShadow: _isScrolled
                      ? [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5))
                        ]
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
                          color: FoodInsightColors.warmWhite,
                          borderRadius: FoodInsightRadius.smAll,
                          border: Border.all(
                            color: FoodInsightColors.outlineGray,
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: FoodInsightColors.deepCharcoal),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: _isScrolled ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          productName,
                          style: FoodInsightTypography.heading(
                              size: 18,
                              weight: FontWeight.w800,
                              color: FoodInsightColors.deepCharcoal),
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
                          color: _nutriscoreColor(nutriscore)
                              .withValues(alpha: 0.1),
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
                    if (context.watch<FeatureFlagService>().aiChatEnabled)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _discussProduct();
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
                          child: const Icon(Icons.restaurant_rounded,
                              color: FoodInsightColors.scannerGreen),
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
                          tag:
                              'scan_${productData['id'] ?? productData['barcode'] ?? ''}',
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
                        SafetyAlertsWidget(
                          userAllergies: userAllergies,
                          userConditions: userConditions,
                          ingredients: ingredients,
                          dietaryPreference: dietaryPreference,
                          nutritionData: nutrition,
                          productData: productData,
                          healthGoal: healthGoal,
                          dailyContext: _dailyContext,
                        ),
                        SizedBox(height: 3.h),
                        NutritionBarsWidget(nutritionData: nutrition),
                        SizedBox(height: 3.h),
                        // Ingredients
                        if (context
                            .watch<FeatureFlagService>()
                            .additiveInsightsEnabled)
                          FoodAdditivesWidget(product: productData),
                        IngredientsWidget(
                          ingredients: ingredients,
                          userAllergies: userAllergies,
                        ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                        SizedBox(height: 3.h),
                        if (context
                                .watch<FeatureFlagService>()
                                .aiProductAnalysisEnabled &&
                            _explanation != null)
                          AiAnalysisWidget(aiAnalysis: _explanation)
                        else if (context
                            .watch<FeatureFlagService>()
                            .aiProductAnalysisEnabled)
                          OutlinedButton.icon(
                            onPressed: _explaining ? null : _explainProduct,
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(_explaining
                                ? 'Preparing explanation…'
                                : 'Explain my Food Fit'),
                          ),
                        if (context.watch<FeatureFlagService>().aiChatEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: OutlinedButton.icon(
                              onPressed: _discussProduct,
                              icon: const Icon(
                                  Icons.chat_bubble_outline_rounded),
                              label: const Text('Discuss this product with AI'),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (context
                            .watch<FeatureFlagService>()
                            .alternativesEnabled)
                          VerifiedAlternativesWidget(
                              product: productData,
                              profile: context
                                      .watch<UserProfileProvider>()
                                      .profile
                                      ?.toMap() ??
                                  {}),
                        if (productData['isOfflineCopy'] == true)
                          const Text(
                              "You're offline — showing saved information."),
                        Text(
                            'Source: ${productData['source'] == 'user_label' ? 'Entered from package label' : 'Open Food Facts'}${productData['sourceFetchedAt'] == null ? '' : '\nRetrieved ${productData['sourceFetchedAt'].toString().split('T').first}'}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        const Text(
                            'General nutrition information. Food Insight is not a substitute for professional medical advice.'),
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
              onAddToDietLog: _isLogging ? null : _onAddToDietLog,
              onAddToShoppingList:
                  _isAddingToShopping ? null : _onAddToShoppingList,
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
