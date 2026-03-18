import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/services/product_service.dart';
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

  String _userName = 'User';
  List<String> _userAllergies = [];
  String? _userHealthGoal;
  List<String> _userDietaryPrefs = [];

  // Nutrition data (will be computed from scan history in production)
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
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scanHistory = await ProductService().getScanHistory();

      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
        _userAllergies = prefs.getStringList('user_allergies') ?? [];
        _userHealthGoal = prefs.getString('user_health_goal');
        _userDietaryPrefs =
            prefs.getStringList('user_dietary_preferences') ?? [];

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

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushNamed(context, '/barcode-scanner');
        break;
      case 2:
        _navigateToAIChat();
        break;
      case 3:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  void _navigateToAIChat() {
    Navigator.pushNamed(
      context,
      '/ai-chat-assistant',
      arguments: {
        'name': _userName,
        'allergies': _userAllergies,
        'dietaryPreferences': _userDietaryPrefs.join(', '),
        'healthGoals': _userHealthGoal ?? 'general wellness',
        'age': 25,
        'activityLevel': 'moderate',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.lightTheme.colorScheme.primary.withOpacity(0.05),
              AppTheme.lightTheme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppTheme.lightTheme.colorScheme.primary,
            backgroundColor: AppTheme.lightTheme.colorScheme.surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GreetingHeader(
                        userName: _userName,
                        currentDate: _formatCurrentDate(),
                      ),
                      SizedBox(height: 1.h),
                      NutritionSummaryCard(
                        nutritionData: _nutritionData,
                      ),
                      SizedBox(height: 2.h),
                      QuickActionsSection(
                        onScanBarcode: () {
                          Navigator.pushNamed(context, '/barcode-scanner');
                        },
                        onUploadImage: () {
                          Navigator.pushNamed(context, '/barcode-scanner');
                        },
                        onChatWithAI: _navigateToAIChat,
                      ),
                      SizedBox(height: 2.h),
                      RecentScansSection(
                        recentScans: _recentScans,
                        onViewAll: () {
                          Navigator.pushNamed(context, '/scan-history');
                        },
                      ),
                      SizedBox(height: 2.h),
                      DietLogPreview(
                        recentEntries: _dietLogEntries,
                        onViewAll: () {
                           Navigator.pushNamed(context, '/diet-log');
                        },
                      ),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/barcode-scanner');
        },
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
        foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
        elevation: 4.0,
        icon: CustomIconWidget(
          iconName: 'qr_code_scanner',
          size: 6.w,
          color: AppTheme.lightTheme.colorScheme.onPrimary,
        ),
        label: Text(
          "Scan Now",
          style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.lightTheme.colorScheme.surface.withOpacity(0.9),
              AppTheme.lightTheme.colorScheme.surface,
            ],
          ),
          border: Border(
            top: BorderSide(
              color: AppTheme.lightTheme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onBottomNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.lightTheme.colorScheme.primary,
          unselectedItemColor: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
          selectedLabelStyle:
              AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle:
              AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w400,
          ),
          items: [
            BottomNavigationBarItem(
              icon: CustomIconWidget(
                iconName: 'home',
                size: 6.w,
                color: _currentIndex == 0
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: CustomIconWidget(
                iconName: 'qr_code_scanner',
                size: 6.w,
                color: _currentIndex == 1
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: CustomIconWidget(
                iconName: 'smart_toy',
                size: 6.w,
                color: _currentIndex == 2
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
              label: 'AI Chat',
            ),
            BottomNavigationBarItem(
              icon: CustomIconWidget(
                iconName: 'person',
                size: 6.w,
                color: _currentIndex == 3
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
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
