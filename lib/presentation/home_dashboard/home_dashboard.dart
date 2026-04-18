import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'dart:ui';

import '../../core/app_export.dart';
import '../../core/services/product_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/user_utils.dart';
import '../../models/user_profile.dart';
import '../profile/profile_screen.dart';
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
  late AnimationController _fabGlowController;
  bool _isRefreshing = false;

  String _userName = 'User';
  List<String> _userAllergies = [];
  String? _userHealthGoal;
  List<String> _userDietaryPrefs = [];
  int _userAge = 25;
  String _userGender = '';
  double? _userHeightCm;
  double? _userWeightKg;

  // Nutrition data — goals computed dynamically from user metrics
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

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fabGlowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scanHistory = await ProductService().getScanHistory();

      // Load Diet Log for today from Firestore
      final dateString =
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      List<Map<String, dynamic>> entries = [];
      try {
        entries = await FirestoreService().getDietLog(dateString);
      } catch (e) {
        debugPrint('Error pulling home diet log from Firestore: $e');
      }

      // Read user body metrics for dynamic goal calculation
      final healthGoal = prefs.getString('user_health_goal');
      final gender = prefs.getString('user_gender') ?? '';
      final heightCm = prefs.getDouble('user_height');
      final weightKg = prefs.getDouble('user_weight');
      final dobStr = prefs.getString('user_dob');
      final userAge = UserUtils.calculateAgeFromString(dobStr);

      // Dynamic goals via Mifflin-St Jeor TDEE
      final calGoal = UserUtils.calculateTDEE(
        weightKg: weightKg,
        heightCm: heightCm,
        age: userAge,
        gender: gender,
        healthGoal: healthGoal,
      );
      final proteinGoal = UserUtils.calculateProteinGoal(
        weightKg: weightKg,
        healthGoal: healthGoal,
      );
      final sugarGoal = UserUtils.calculateSugarGoal(calGoal);

      // Calculate totals from today's diet log
      int totalCals = 0;
      double totalProtein = 0;
      double totalSugar = 0;
      for (var entry in entries) {
        totalCals += (entry['calories'] as num?)?.toInt() ?? 0;
        totalProtein += (entry['protein'] as num?)?.toDouble() ?? 0;
        totalSugar += (entry['sugar'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
        _userAllergies = prefs.getStringList('user_allergies') ?? [];
        _userHealthGoal = healthGoal;
        _userDietaryPrefs =
            prefs.getStringList('user_dietary_preferences') ?? [];
        _userAge = userAge;
        _userGender = gender;
        _userHeightCm = heightCm;
        _userWeightKg = weightKg;

        _nutritionData['calories'] = totalCals;
        _nutritionData['caloriesGoal'] = calGoal;
        _nutritionData['protein'] = totalProtein.round();
        _nutritionData['proteinGoal'] = proteinGoal;
        _nutritionData['sugar'] = totalSugar.round();
        _nutritionData['sugarGoal'] = sugarGoal;

        _dietLogEntries.clear();
        _dietLogEntries.addAll(entries);

        // Transform scan history into recent scans format
        _recentScans = scanHistory.take(10).map((scan) {
          return {
            'id': scan['barcode'] ?? '',
            'name': scan['name'] ?? 'Unknown',
            'image': scan['image'] ?? '',
            'safetyStatus': _determineSafety(scan),
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

  String _determineSafety(Map<String, dynamic> scan) {
    final allergens = (scan['allergens'] as List?)?.cast<String>() ?? [];
    for (final allergen in allergens) {
      for (final userAllergen in _userAllergies) {
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
    _fabGlowController.dispose();
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
    switch (index) {
      case 0:
        setState(() => _currentIndex = 0);
        _loadUserData();
        break;
      case 1:
        await Navigator.pushNamed(context, '/barcode-scanner');
        _loadUserData();
        setState(() => _currentIndex = 0);
        break;
      case 2:
        await _navigateToAIChat();
        setState(() => _currentIndex = 0);
        break;
      case 3:
        setState(() => _currentIndex = 3);
        break;
    }
  }

  /// Build a UserProfile for passing to AI Chat
  UserProfile _buildUserProfile() {
    return UserProfile(
      name: _userName,
      allergies: _userAllergies,
      dietaryPreferences: _userDietaryPrefs.join(', '),
      healthGoals: _userHealthGoal ?? 'general wellness',
      age: _userAge,
      activityLevel: 'moderate',
      gender: _userGender,
      heightCm: _userHeightCm,
      weightKg: _userWeightKg,
    );
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

      await Navigator.pushNamed(
        context,
        '/ai-chat-assistant',
        arguments: {
          ..._buildUserProfile().toMap(),
          'uploadedImagePath': pickedFile.path,
        },
      );
      _loadUserData();
    } catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Navigate to AI Chat as a pushed screen
  Future<void> _navigateToAIChat() async {
    await Navigator.pushNamed(
      context,
      '/ai-chat-assistant',
      arguments: _buildUserProfile().toMap(),
    );
    _loadUserData();
  }

  // ──────────────────────── Tab Content Builders ────────────────────────

  /// The Home tab content with staggered cinematic animations
  Widget _buildHomeContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: 0.08),
            theme.scaffoldBackgroundColor,
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: colorScheme.primary,
          backgroundColor: colorScheme.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Staggered entrance animations
                    GreetingHeader(
                      userName: _userName,
                      currentDate: _formatCurrentDate(),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 0.ms)
                        .slideX(begin: -0.1, end: 0, duration: 500.ms),
                    SizedBox(height: 1.h),
                    NutritionSummaryCard(
                      nutritionData: _nutritionData,
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 100.ms)
                        .scaleXY(begin: 0.95, end: 1.0, duration: 500.ms),
                    SizedBox(height: 2.h),
                    QuickActionsSection(
                      onScanBarcode: () async {
                        await Navigator.pushNamed(
                            context, '/barcode-scanner');
                        _loadUserData();
                      },
                      onUploadImage: _handleUploadImage,
                      onChatWithAI: () async {
                        await _navigateToAIChat();
                      },
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 200.ms)
                        .slideY(begin: 0.05, end: 0, duration: 500.ms),
                    SizedBox(height: 2.h),
                    RecentScansSection(
                      recentScans: _recentScans,
                      onViewAll: () {
                        Navigator.pushNamed(context, '/scan-history');
                      },
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 300.ms)
                        .slideX(begin: 0.1, end: 0, duration: 500.ms),
                    SizedBox(height: 2.h),
                    DietLogPreview(
                      recentEntries: _dietLogEntries,
                      onViewAll: () async {
                        await Navigator.pushNamed(context, '/diet-log');
                        _loadUserData();
                      },
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 400.ms)
                        .slideY(begin: 0.08, end: 0, duration: 500.ms),
                    SizedBox(height: 10.h),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex == 3 ? 1 : 0,
        children: [
          _buildHomeContent(),
          const ProfileScreen(),
        ],
      ),
      // ──────────── Glowing FAB ────────────
      floatingActionButton: _currentIndex == 0
          ? AnimatedBuilder(
              animation: _fabGlowController,
              builder: (context, child) {
                final glowValue = _fabGlowController.value;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                  alpha: 0.3 + glowValue * 0.15),
                              blurRadius: 20 + glowValue * 10,
                              spreadRadius: 1 + glowValue * 2,
                            ),
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                  alpha: 0.15 + glowValue * 0.1),
                              blurRadius: 35 + glowValue * 10,
                              spreadRadius: 0,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: child,
                );
              },
              child: GestureDetector(
                onTapDown: (_) => HapticFeedback.lightImpact(),
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await Navigator.pushNamed(context, '/barcode-scanner');
                    _loadUserData();
                  },
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  icon: CustomIconWidget(
                    iconName: 'qr_code_scanner',
                    size: 6.w,
                    color: colorScheme.onPrimary,
                  ),
                  label: Text(
                    "Scan Now",
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // ──────────── Floating Glass Bottom Nav ────────────
      bottomNavigationBar: Container(
        margin: EdgeInsets.only(left: 5.w, right: 5.w, bottom: 2.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.glassDarkBg
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? AppTheme.glassDarkBorder
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onBottomNavTap,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: colorScheme.primary,
                unselectedItemColor: colorScheme.onSurfaceVariant,
                selectedLabelStyle:
                    theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle:
                    theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
                items: [
                  _buildNavItem('home', 'Home', 0, colorScheme),
                  _buildNavItem('qr_code_scanner', 'Scan', 1, colorScheme),
                  _buildNavItem('smart_toy', 'AI Chat', 2, colorScheme),
                  _buildNavItem('person', 'Profile', 3, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      String iconName, String label, int index, ColorScheme colorScheme) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: CustomIconWidget(
              iconName: iconName,
              size: 6.w,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
        ],
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
