// lib/routes/app_routes.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/auth_gate.dart';
import '../presentation/auth/login_screen/login_screen.dart';
import '../presentation/auth/signup_screen/signup_screen.dart';
import '../presentation/profile_setup/profile_setup.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/home_dashboard/home_dashboard.dart';
import '../presentation/barcode_scanner/barcode_scanner.dart';
import '../presentation/ai_chat_assistant/ai_chat_assistant.dart';
import '../presentation/product_details/product_details.dart';
import '../models/user_profile.dart';
import '../presentation/scan_history/scan_history_screen.dart';
import '../presentation/profile/profile_screen.dart';
import '../presentation/diet_log/diet_log_screen.dart';
import '../presentation/settings/settings_screen.dart';
import '../presentation/shopping_list/shopping_list_screen.dart';
import '../core/utils/user_utils.dart';

class AppRoutes {
  static const String initial = '/';
  static const String authGate = '/auth-gate';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String profileSetup = '/profile-setup';
  static const String splash = '/splash-screen';
  static const String homeDashboard = '/home-dashboard';
  static const String barcodeScanner = '/barcode-scanner';
  static const String aiChatAssistant = '/ai-chat-assistant';
  static const String productDetails = '/product-details';
  static const String scanHistory = '/scan-history';
  static const String dietLog = '/diet-log';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String shoppingList = '/shopping-list';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const AuthGate(),
    authGate: (context) => const AuthGate(),
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    profileSetup: (context) => const ProfileSetup(),
    splash: (context) => const SplashScreen(),
    homeDashboard: (context) => const HomeDashboard(),
    barcodeScanner: (context) => const BarcodeScanner(),
    productDetails: (context) => const ProductDetails(),
    scanHistory: (context) => const ScanHistoryScreen(),
    dietLog: (context) => const DietLogScreen(),
    profile: (context) => const ProfileScreen(),
    settings: (context) => const SettingsScreen(),
    shoppingList: (context) => const ShoppingListScreen(),
  };

  /// Cinematic page transitions for all routes
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case aiChatAssistant:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return _buildCinematicRoute(
            settings: settings,
            child: AiChatAssistant(
              userProfile: UserProfile.fromMap(args),
            ),
          );
        }
        // Fallback: Load profile from SharedPreferences
        return _buildCinematicRoute(
          settings: settings,
          child: FutureBuilder<UserProfile>(
            future: _loadUserProfile(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return AiChatAssistant(userProfile: snapshot.data!);
              }
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        );
      default:
        return null;
    }
  }

  /// Creates a smooth fade + slide cinematic page transition
  static PageRouteBuilder _buildCinematicRoute({
    required RouteSettings settings,
    required Widget child,
  }) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.03),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  static Future<UserProfile> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    int userAge = 25;
    final dobStr = prefs.getString('user_dob');
    if (dobStr != null) {
      userAge = UserUtils.calculateAgeFromString(dobStr);
    }

    return UserProfile(
      name: prefs.getString('user_name') ?? 'User',
      allergies: prefs.getStringList('user_allergies') ?? [],
      dietaryPreferences:
          (prefs.getStringList('user_dietary_preferences') ?? []).join(', '),
      healthGoals: prefs.getString('user_health_goal') ?? 'general wellness',
      age: userAge,
      activityLevel: 'moderate',
    );
  }
}
