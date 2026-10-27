import '../../services/food_fit_service.dart';
import '../../services/feature_flag_service.dart';
import 'dart:async';
import '../../services/user_session.dart';
import '../../core/utils/data_refresh_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';

import '../../services/user_data_service.dart';
import '../../core/utils/user_utils.dart';
import '../../models/user_profile.dart';
import '../../data/providers/user_profile_provider.dart';
import 'package:flutter/rendering.dart';
import '../../theme/apple_motion.dart';
import '../../theme/app_design_system.dart';
import '../../widgets/glass/liquid_glass_nav_bar.dart';
import '../../routes/app_routes.dart';
import '../profile/profile_screen.dart';
import '../barcode_scanner/barcode_scanner.dart';
import '../ai_chat_assistant/ai_chat_assistant.dart';
import 'widgets/diet_log_preview.dart';
import 'widgets/meal_plan_preview.dart';
import './widgets/greeting_header.dart';
import './widgets/nutrition_summary_card.dart';
import './widgets/quick_actions_section.dart';
import './widgets/recent_scans_section.dart';
import './widgets/activity_summary_card.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription<List<Map<String, dynamic>>>? _scanSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _dietSubscription;
  String? _subscribedDate;
  int _loadRevision = 0;
  int _currentIndex = 0;
  late AnimationController _tabController;
  late AnimationController _refreshController;
  bool _isRefreshing = false;
  bool _isNavCompact = false;
  int _unlockAnimationKey = 0;

  final Map<String, dynamic> _nutritionData = {
    'calories': 0,
    'caloriesGoal': 2000,
    'sugar': 0,
    'sugarGoal': 50,
    'protein': 0,
    'proteinGoal': 150,
    'totalCalories': 0,
  };

  List<Map<String, dynamic>> _recentScans = [];

  final List<Map<String, dynamic>> _dietLogEntries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _tabController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180), value: 1);
    _subscribe();
    DataRefreshBus.profileRevision.addListener(_loadUserData);
    _loadUserData();
  }

  void _subscribe() {
    _scanSubscription ??= UserDataService().scanHistoryStream().listen(
        (_) => _loadUserData(),
        onError: (Object e) => debugPrint('$e'));
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (_subscribedDate == today) return;
    _subscribedDate = today;
    _dietSubscription?.cancel();
    _dietSubscription = UserDataService().dietLogStream(today).listen(
        (_) => _loadUserData(),
        onError: (Object e) => debugPrint('$e'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _subscribe();
      _loadUserData();
      setState(() {
        _unlockAnimationKey++;
      });
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _dietSubscription?.cancel();
    DataRefreshBus.profileRevision.removeListener(_loadUserData);
    WidgetsBinding.instance.removeObserver(this);
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final revision = ++_loadRevision;
    if (UserSession.instance.uid == null) return;
    final session = UserSession.instance.capture();
    try {
      final scanHistory = await UserDataService().cachedScans();

      // Load Diet Log for today from merged Firestore + local SQLite
      final dateString =
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      List<Map<String, dynamic>> entries = [];
      try {
        entries = await UserDataService().cachedDiet(dateString);
      } catch (e) {
        debugPrint('Error pulling home diet log: $e');
        // Fallback to local-only if Firestore merge fails
        try {
          entries = await UserDataService().cachedDiet(dateString);
        } catch (e2) {
          debugPrint('Error pulling home diet log from local db: $e2');
        }
      }

      // Calculate totals from today's diet log
      int totalCals = 0;
      double totalProtein = 0;
      double totalSugar = 0;
      double totalCarbs = 0;
      double totalFat = 0;
      for (var entry in entries) {
        totalCals += (entry['calories'] as num?)?.toInt() ?? 0;
        totalProtein += (entry['protein'] as num?)?.toDouble() ?? 0;
        totalSugar += (entry['sugar'] as num?)?.toDouble() ?? 0;
        totalCarbs += (entry['carbs'] as num?)?.toDouble() ?? 0;
        totalFat += (entry['fat'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted || !session.isActive || revision != _loadRevision) return;
      final profile = context.read<UserProfileProvider>().profile;

      // Calculate dynamic targets based on user profile setup
      final calGoal = UserUtils.calculateTDEE(
        weightKg: profile?.weightKg ?? 70.0,
        heightCm: profile?.heightCm ?? 170.0,
        age: profile?.age ?? 25,
        gender: profile?.gender ?? 'Male',
        activityLevel: profile?.activityLevel ?? 'moderate',
        healthGoal: profile?.healthGoals ?? '',
        customGoal: profile?.customCaloriesGoal,
      );

      final proteinGoal = UserUtils.calculateProteinGoal(
        weightKg: profile?.weightKg ?? 70.0,
        healthGoal: profile?.healthGoals ?? '',
        customGoal: profile?.customProteinGoal,
      );

      final sugarGoal = UserUtils.calculateSugarGoal(calGoal);
      final carbsGoal = UserUtils.calculateCarbsGoal(calGoal,
          customGoal: profile?.customCarbsGoal);
      final fatGoal = UserUtils.calculateFatGoal(calGoal,
          customGoal: profile?.customFatGoal);

      setState(() {
        _nutritionData['calories'] = totalCals;
        _nutritionData['caloriesGoal'] = calGoal;
        _nutritionData['protein'] = totalProtein.round();
        _nutritionData['proteinGoal'] = proteinGoal;
        _nutritionData['sugar'] = totalSugar.round();
        _nutritionData['sugarGoal'] = sugarGoal;
        _nutritionData['carbs'] = totalCarbs.round();
        _nutritionData['fat'] = totalFat.round();
        _nutritionData['carbsGoal'] = carbsGoal;
        _nutritionData['fatGoal'] = fatGoal;

        _dietLogEntries.clear();
        _dietLogEntries.addAll(entries);

        // Sync Data to Android Widget
        _syncWidgetData(totalCals, calGoal, totalProtein.round(), proteinGoal,
            carbsGoal, fatGoal);

        // Transform scan history into recent scans format
        _recentScans = scanHistory.take(10).map((scan) {
          return {
            'id': scan['barcode'] ?? '',
            'name': scan['name'] ?? 'Unknown',
            'image': scan['image'] ?? '',
            'safetyStatus': _determineSafety(scan, profile),
            'scannedAt': scan['scannedAt'] != null
                ? DateTime.tryParse(scan['scannedAt'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _syncWidgetData(int calConsumed, int calGoal,
      int proteinConsumed, int proteinGoal, int carbsGoal, int fatGoal) async {
    final session = UserSession.instance.capture();
    try {
      session.check();
      session.check();
      await HomeWidget.saveWidgetData<int>('calories_consumed', calConsumed);
      session.check();
      await HomeWidget.saveWidgetData<int>('calories_goal', calGoal);
      session.check();
      await HomeWidget.saveWidgetData<int>(
          'carbs_consumed', (_nutritionData['carbs'] as num?)?.toInt() ?? 0);
      session.check();
      await HomeWidget.saveWidgetData<int>('carbs_goal', carbsGoal);
      session.check();
      await HomeWidget.saveWidgetData<int>('protein_consumed', proteinConsumed);
      session.check();
      await HomeWidget.saveWidgetData<int>('protein_goal', proteinGoal);
      session.check();
      await HomeWidget.saveWidgetData<int>(
          'fat_consumed', (_nutritionData['fat'] as num?)?.toInt() ?? 0);
      session.check();
      await HomeWidget.saveWidgetData<int>('fat_goal', fatGoal);
      session.check();
      for (final name in [
        'MacroWidgetProvider',
        'SmallWidgetProvider',
        'LargeWidgetProvider'
      ]) {
        await HomeWidget.updateWidget(
            androidName: 'com.food_insight_scanner.app.$name');
      }
    } catch (e) {
      debugPrint('Failed to sync widget data: $e');
    }
  }

  String _determineSafety(Map<String, dynamic> scan, UserProfile? profile) {
    final fit = FoodFitService.evaluate(scan,
        allergies: profile?.allergies ?? [],
        dietaryPreference: profile?.dietaryPreferences.join(', ') ?? '',
        healthGoal: profile?.healthGoals ?? '');
    if (fit.hasCriticalAllergenConflict) return 'danger';
    if (fit.conflicts.isNotEmpty || fit.cautions.isNotEmpty) return 'warning';
    return 'unknown';
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    _refreshController.forward();

    await Future.wait([
      UserDataService().getScanHistory(),
      UserDataService()
          .getDietLog(DateTime.now().toIso8601String().split('T')[0]),
    ]);
    await _loadUserData();

    if (!mounted) return;
    _refreshController.reverse();

    setState(() {
      _isRefreshing = false;
    });
  }

  /// Bottom nav tap handler.
  Future<void> _onBottomNavTap(int index) async {
    if (index == 2 && !context.read<FeatureFlagService>().aiChatEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('AI chat is currently unavailable.'),
      ));
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
      _tabController.forward(from: 0);
    });
    if (index == 0) {
      _loadUserData();
    }
  }

  Future<void> _handleUploadImage() async {
    await Navigator.pushNamed(context, AppRoutes.dietLog);
    if (mounted) _loadUserData();
  }

  /// Navigate to AI Chat via IndexedStack
  void _navigateToAIChat() {
    if (!context.read<FeatureFlagService>().aiChatEnabled) return;
    setState(() {
      _currentIndex = 2;
      _tabController.forward(from: 0);
    });
  }

  // ──────────────────────── Tab Content Builders ────────────────────────

  /// The Home tab content with staggered cinematic animations
  Widget _buildHomeContent() {
    final profile = context.watch<UserProfileProvider>().profile;
    // Calculate dynamic goals in build so they reflect the latest profile
    if (profile != null) {
      final calGoal = UserUtils.calculateTDEE(
        weightKg: profile.weightKg,
        heightCm: profile.heightCm,
        age: profile.age,
        gender: profile.gender,
        activityLevel: profile.activityLevel,
        healthGoal: profile.healthGoals,
        customGoal: profile.customCaloriesGoal,
      );
      _nutritionData['caloriesGoal'] = calGoal;
      _nutritionData['proteinGoal'] = UserUtils.calculateProteinGoal(
        weightKg: profile.weightKg,
        healthGoal: profile.healthGoals,
        customGoal: profile.customProteinGoal,
      );
      _nutritionData['sugarGoal'] = UserUtils.calculateSugarGoal(calGoal);
      _nutritionData['carbsGoal'] = UserUtils.calculateCarbsGoal(calGoal,
          customGoal: profile.customCarbsGoal);
      _nutritionData['fatGoal'] = UserUtils.calculateFatGoal(calGoal,
          customGoal: profile.customFatGoal);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: FoodInsightColors.warmBackground,
      ),
      child: SafeArea(
        bottom: false,
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.reverse && !_isNavCompact) {
              setState(() => _isNavCompact = true);
            } else if (notification.direction == ScrollDirection.forward && _isNavCompact) {
              setState(() => _isNavCompact = false);
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
          color: FoodInsightColors.scannerGreen,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Staggered entrance animations
                    GreetingHeader(
                      userName: profile?.name ?? 'User',
                      currentDate: _formatCurrentDate(),
                      photoUrl: profile?.photoUrl,
                      email: profile?.email,
                    )
                        .animate()
                        .fadeIn(
                            duration: 500.ms,
                            delay: 0.ms,
                            curve: Curves.easeOutCubic)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                    SizedBox(height: 0.5.h),
                    NutritionSummaryCard(
                      nutritionData: _nutritionData,
                    )
                        .animate()
                        .fadeIn(
                            duration: 500.ms,
                            delay: 100.ms,
                            curve: Curves.easeOutCubic)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                    SizedBox(height: 1.5.h),
                    const ActivitySummaryCard()
                        .animate()
                        .fadeIn(
                            duration: 500.ms,
                            delay: 150.ms,
                            curve: Curves.easeOutCubic)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                    SizedBox(height: 2.h),
                    QuickActionsSection(
                      onScanBarcode: () {
                        setState(() {
                          _currentIndex = 1;
                          _tabController.forward(from: 0);
                        });
                      },
                      onUploadImage: _handleUploadImage,
                      onChatWithAI: _navigateToAIChat,
                      aiChatEnabled:
                          context.watch<FeatureFlagService>().aiChatEnabled,
                      onShoppingList: () {
                        Navigator.pushNamed(context, '/shopping-list');
                      },
                    )
                        .animate()
                        .fadeIn(
                            duration: 500.ms,
                            delay: 200.ms,
                            curve: Curves.easeOutCubic)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                    SizedBox(height: 2.h),
                    RecentScansSection(
                      recentScans: _recentScans,
                      onViewAll: () {
                        Navigator.pushNamed(context, '/scan-history');
                      },
                    )
                        .animate()
                        .fadeIn(
                            duration: 500.ms,
                            delay: 300.ms,
                            curve: Curves.easeOutCubic)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                    SizedBox(height: 1.h),
                    DietLogPreview(
                      recentEntries: _dietLogEntries,
                      onViewAll: () async {
                        await Navigator.pushNamed(context, '/diet-log');
                        _loadUserData();
                      },
                    )
                        .animate()
                        .fadeIn(
                            duration: 500.ms,
                            delay: 400.ms,
                            curve: Curves.easeOutCubic)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                    SizedBox(height: 2.h),
                    if (context.watch<FeatureFlagService>().mealPlannerEnabled)
                      MealPlanPreviewWidget(
                        onViewPlan: () {
                          Navigator.pushNamed(context, AppRoutes.mealPlanner);
                        },
                      )
                          .animate()
                          .fadeIn(
                              duration: 500.ms,
                              delay: 500.ms,
                              curve: Curves.easeOutCubic)
                          .slideY(
                              begin: 0.1,
                              end: 0,
                              duration: 500.ms,
                              curve: Curves.easeOutCubic),
                    SizedBox(
                        height: 20
                            .h), // Ensures content scrolls fully above bottom nav and FAB
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}



  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Exit App?'),
              content: const Text('Are you sure you want to exit?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Exit'),
                ),
              ],
            ),
          ).then((exit) {
            if (exit == true) {
              SystemNavigator.pop();
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: FoodInsightColors.warmWhite,
        extendBody: true,
        body: FadeTransition(
          opacity: MediaQuery.disableAnimationsOf(context)
              ? const AlwaysStoppedAnimation(1.0)
              : CurvedAnimation(
                  parent: _tabController, curve: Curves.easeOutCubic),
          child: IndexedStack(
            index: _currentIndex,
            children: [
              KeyedSubtree(
                key: ValueKey('home_content_$_unlockAnimationKey'),
                child: _buildHomeContent(),
              ),
              BarcodeScanner(
                isActive: _currentIndex == 1,
                onExitRequested: () => setState(() => _currentIndex = 0),
              ),
              context.watch<FeatureFlagService>().aiChatEnabled
                  ? AiChatAssistant(
                      onExitRequested: () => setState(() => _currentIndex = 0))
                  : const Center(
                      child: Text('AI chat is currently unavailable.')),
              const ProfileScreen(),
            ]
                .asMap()
                .entries
                .map((tab) => TickerMode(
                    enabled: tab.key == _currentIndex, child: tab.value))
                .toList(),
          ),
        ),
        bottomNavigationBar: RepaintBoundary(child: _buildBottomNav()),
        // ──────────── Skeuomorphic FAB ────────────
        floatingActionButton: _currentIndex == 0 ? _buildScanFab() : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildScanFab() {
    return PressScale(
      scaleFactor: AppleMotion.pressScaleButton,
      pressSpring: AppleMotion.snappy,
      releaseSpring: AppleMotion.smooth,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: FoodInsightColors.scannerGreen.withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _currentIndex = 1;
              _tabController.forward(from: 0);
            });
          },
          backgroundColor: FoodInsightColors.scannerGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
          label: Text(
            'Scan Now',
            style: FoodInsightTypography.body(
              size: 15,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBottomNav() {
    return LiquidGlassNavBar(
      currentIndex: _currentIndex,
      onTap: _onBottomNavTap,
      isCompact: _isNavCompact,
      items: const [
        LiquidGlassNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        LiquidGlassNavItem(
          icon: Icons.qr_code_scanner_outlined,
          activeIcon: Icons.qr_code_scanner_rounded,
          label: 'Scan',
        ),
        LiquidGlassNavItem(
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome_rounded,
          label: 'AI Chat',
        ),
        LiquidGlassNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      ],

    );
  }


  String _formatCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return "${months[now.month - 1]} ${now.day}, ${now.year}";
  }
}
