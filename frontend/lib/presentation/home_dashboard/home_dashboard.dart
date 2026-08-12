import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';


import '../../services/product_service.dart';
import '../../services/local_database_service.dart';
import '../../core/utils/user_utils.dart';
import '../../models/user_profile.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../theme/app_design_system.dart';
import '../profile/profile_screen.dart';
import '../barcode_scanner/barcode_scanner.dart';
import '../ai_chat_assistant/ai_chat_assistant.dart';
import './widgets/diet_log_preview.dart';
import './widgets/greeting_header.dart';
import './widgets/nutrition_summary_card.dart';
import './widgets/quick_actions_section.dart';
import './widgets/recent_scans_section.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _refreshController;
  bool _isRefreshing = false;

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

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProfileProvider>().fetchProfile();
    });
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final scanHistory = await ProductService().getScanHistory();

      // Load Diet Log for today from Local SQLite Database
      final dateString =
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      List<Map<String, dynamic>> entries = [];
      try {
        entries = await LocalDatabaseService().getDietLogByDate(dateString);
      } catch (e) {
        debugPrint('Error pulling home diet log from local db: $e');
      }

      // Calculate totals from today's diet log
      int totalCals = 0;
      double totalProtein = 0;
      double totalSugar = 0;
      for (var entry in entries) {
        totalCals += (entry['calories'] as num?)?.toInt() ?? 0;
        totalProtein += (entry['protein'] as num?)?.toDouble() ?? 0;
        totalSugar += (entry['sugar'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      final profile = context.read<UserProfileProvider>().profile;

      // Calculate dynamic targets based on user profile setup
      final calGoal = UserUtils.calculateTDEE(
        weightKg: profile?.weightKg ?? 70.0,
        heightCm: profile?.heightCm ?? 170.0,
        age: profile?.age ?? 25,
        gender: profile?.gender ?? 'Male',
        activityLevel: profile?.activityLevel ?? 'moderate',
        healthGoal: profile?.healthGoals ?? '',
      );

      final proteinGoal = UserUtils.calculateProteinGoal(
        weightKg: profile?.weightKg ?? 70.0,
        healthGoal: profile?.healthGoals ?? '',
      );

      final sugarGoal = UserUtils.calculateSugarGoal(calGoal);
      final carbsGoal = UserUtils.calculateCarbsGoal(calGoal);
      final fatGoal = UserUtils.calculateFatGoal(calGoal);

      setState(() {
        _nutritionData['calories'] = totalCals;
        _nutritionData['caloriesGoal'] = calGoal;
        _nutritionData['protein'] = totalProtein.round();
        _nutritionData['proteinGoal'] = proteinGoal;
        _nutritionData['sugar'] = totalSugar.round();
        _nutritionData['sugarGoal'] = sugarGoal;
        _nutritionData['carbsGoal'] = carbsGoal;
        _nutritionData['fatGoal'] = fatGoal;

        _dietLogEntries.clear();
        _dietLogEntries.addAll(entries);

        // Transform scan history into recent scans format
        _recentScans = scanHistory.take(10).map((scan) {
          return {
            'id': scan['barcode'] ?? '',
            'name': scan['name'] ?? 'Unknown',
            'image': scan['image'] ?? '',
            'safetyStatus': _determineSafety(scan, profile),
            'scannedAt': scan['scannedAt'] != null
                ? DateTime.tryParse(scan['scannedAt']) ?? DateTime.now()
                : DateTime.now(),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  String _determineSafety(Map<String, dynamic> scan, UserProfile? profile) {
    final allergens = (scan['allergens'] as List?)?.cast<String>() ?? [];
    final userAllergies = profile?.allergies ?? [];
    for (final allergen in allergens) {
      for (final userAllergen in userAllergies) {
        if (allergen.toLowerCase().contains(userAllergen.toLowerCase())) {
          return 'danger';
        }
      }
    }
    final nutrition = scan['nutrition'] as Map<String, dynamic>?;
    if (nutrition != null) {
      final sugar = (nutrition['sugar'] as num?)?.toDouble() ?? 0;
      if (sugar > 20) return 'warning';
    }
    return 'safe';
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    _refreshController.forward();

    await _loadUserData();

    _refreshController.reverse();

    setState(() {
      _isRefreshing = false;
    });
  }

  /// Bottom nav tap handler.
  Future<void> _onBottomNavTap(int index) async {
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      _loadUserData();
    }
  }

  /// Open the gallery picker and navigate to AI Chat with image context
  Future<void> _handleUploadImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (!mounted) return;

      setState(() {
        _selectedImage = pickedFile;
        _currentIndex = 2;
      });
    } catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    }
  }

  /// Navigate to AI Chat via IndexedStack
  void _navigateToAIChat() {
    setState(() {
      _currentIndex = 2;
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
      );
      _nutritionData['caloriesGoal'] = calGoal;
      _nutritionData['proteinGoal'] = UserUtils.calculateProteinGoal(
        weightKg: profile.weightKg,
        healthGoal: profile.healthGoals,
      );
      _nutritionData['sugarGoal'] = UserUtils.calculateSugarGoal(calGoal);
      _nutritionData['carbsGoal'] = UserUtils.calculateCarbsGoal(calGoal);
      _nutritionData['fatGoal'] = UserUtils.calculateFatGoal(calGoal);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: FoodInsightColors.warmBackground,
      ),
      child: SafeArea(
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
                    SizedBox(height: 2.h),
                    QuickActionsSection(
                      onScanBarcode: () {
                        setState(() {
                          _currentIndex = 1;
                        });
                      },
                      onUploadImage: _handleUploadImage,
                      onChatWithAI: _navigateToAIChat,
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
                    SizedBox(height: 20.h), // Ensures content scrolls fully above bottom nav and FAB
                  ],
                ),
              ),
            ],
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
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeContent(),
                const BarcodeScanner(),
                AiChatAssistant(initialImage: _selectedImage),
                const ProfileScreen(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNav(),
            ),
          ],
        ),
        // ──────────── Skeuomorphic FAB ────────────
        floatingActionButton: _currentIndex == 0
            ? Padding(
                padding: EdgeInsets.only(bottom: 9.h), // Push above bottom nav
                child: _buildScanFab(),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildScanFab() {
    return Container(
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
      child: GestureDetector(
        onTapDown: (_) => HapticFeedback.lightImpact(),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _currentIndex = 1;
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
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(left: 5.w, right: 5.w, bottom: 2.h),
        child: ClipRRect(
          borderRadius: FoodInsightRadius.xxlAll,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: FoodInsightRadius.xxlAll,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 1.h),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: _onBottomNavTap,
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    selectedItemColor: FoodInsightColors.scannerGreen,
                    unselectedItemColor: FoodInsightColors.midGray,
                    selectedLabelStyle: FoodInsightTypography.caption(
                      size: 10,
                      weight: FontWeight.w700,
                      color: FoodInsightColors.scannerGreen,
                    ),
                    unselectedLabelStyle: FoodInsightTypography.caption(
                      size: 10,
                      weight: FontWeight.w500,
                      color: FoodInsightColors.midGray,
                    ),
                    items: [
                      _buildNavItem(Icons.home_rounded, 'Home', 0),
                      _buildNavItem(Icons.qr_code_scanner_rounded, 'Scan', 1),
                      _buildNavItem(Icons.auto_awesome_rounded, 'AI Chat', 2),
                      _buildNavItem(Icons.person_rounded, 'Profile', 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(icon, size: 24),
      ),
      label: label,
    );
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return "${months[now.month - 1]} ${now.day}, ${now.year}";
  }
}
