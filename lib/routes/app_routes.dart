import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../presentation/auth/login_screen.dart';
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

class AppRoutes {
  static const String initial = '/';
  static const String login = '/login';
  static const String profileSetup = '/profile-setup';
  static const String splash = '/splash-screen';
  static const String homeDashboard = '/home-dashboard';
  static const String barcodeScanner = '/barcode-scanner';
  static const String aiChatAssistant = '/ai-chat-assistant';
  static const String productDetails = '/product-details';
  static const String scanHistory = '/scan-history';
  static const String dietLog = '/diet-log';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    profileSetup: (context) => const ProfileSetup(),
    splash: (context) => const SplashScreen(),
    homeDashboard: (context) => const HomeDashboard(),
    barcodeScanner: (context) => const BarcodeScanner(),
    productDetails: (context) => const ProductDetails(),
    scanHistory: (context) => const ScanHistoryScreen(),
    dietLog: (context) => const DietLogScreen(),
    profile: (context) => const ProfileScreen(),
  };

  /// Use onGenerateRoute for routes that need dynamic arguments.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case aiChatAssistant:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => AiChatAssistant(
              userProfile: UserProfile.fromMap(args),
            ),
          );
        }
        // Fallback: Load profile from SharedPreferences
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => FutureBuilder<UserProfile>(
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

  static Future<UserProfile> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      name: prefs.getString('user_name') ?? 'User',
      allergies: prefs.getStringList('user_allergies') ?? [],
      dietaryPreferences:
          (prefs.getStringList('user_dietary_preferences') ?? []).join(', '),
      healthGoals: prefs.getString('user_health_goal') ?? 'general wellness',
      age: 25,
      activityLevel: 'moderate',
    );
  }
}
