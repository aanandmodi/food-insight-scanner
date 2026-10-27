// lib/routes/app_routes.dart

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../theme/apple_motion.dart';
import 'tap_origin.dart';
import '../core/auth_gate.dart';
import '../presentation/auth/login_screen/login_screen.dart';
import '../presentation/auth/signup_screen/signup_screen.dart';
import '../presentation/profile_setup/profile_setup.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/home_dashboard/home_dashboard.dart';
import '../presentation/barcode_scanner/barcode_scanner.dart';
import '../presentation/ai_chat_assistant/ai_chat_assistant.dart';
import '../presentation/product_details/product_details.dart';
import '../presentation/scan_history/scan_history_screen.dart';
import '../presentation/profile/profile_screen.dart';
import '../presentation/diet_log/diet_log_screen.dart';
import '../presentation/settings/settings_screen.dart';
import '../presentation/shopping_list/shopping_list_screen.dart';
import '../presentation/meal_planner/meal_planner_screen.dart';

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
  static const String mealPlanner = '/meal-planner';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const AuthGate(),
    authGate: (context) => const AuthGate(),
    splash: (context) => const SplashScreen(),
    homeDashboard: (context) => const HomeDashboard(),
  };

  /// Cinematic page transitions for all navigated routes
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    Widget? page;
    switch (settings.name) {
      case login:
        page = const LoginScreen();
        break;
      case signup:
        page = const SignupScreen();
        break;
      case profileSetup:
        page = const ProfileSetup();
        break;
      case barcodeScanner:
        page = const BarcodeScanner();
        break;
      case aiChatAssistant:
        page = const AiChatAssistant();
        break;
      case productDetails:
        page = const ProductDetails();
        break;
      case scanHistory:
        page = const ScanHistoryScreen();
        break;
      case dietLog:
        page = const DietLogScreen();
        break;
      case profile:
        page = const ProfileScreen();
        break;
      case AppRoutes.settings:
        page = const SettingsScreen();
        break;
      case shoppingList:
        page = const ShoppingListScreen();
        break;
      case mealPlanner:
        page = const MealPlannerScreen();
        break;
      default:
        return null;
    }
    return _buildCinematicRoute(settings: settings, child: page);
  }

  /// Creates an Apple-style spring-driven cinematic page transition
  static Route<dynamic> _buildCinematicRoute({
    required RouteSettings settings,
    required Widget child,
  }) {
    final origin = TapOrigin.take();
    return _SpringPageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;

        return FadeTransition(
          opacity: animation.drive(Tween<double>(begin: 0.0, end: 1.0)),
          child: ScaleTransition(
            alignment: origin,
            scale: animation.drive(Tween<double>(begin: 0.94, end: 1.0)),
            child: child,
          ),
        );
      },
    );
  }
}

class _SpringPageRouteBuilder<T> extends PageRouteBuilder<T> {
  _SpringPageRouteBuilder({
    required super.pageBuilder,
    super.settings,
    super.transitionsBuilder,
    super.transitionDuration = const Duration(milliseconds: 350),
    super.reverseTransitionDuration = const Duration(milliseconds: 280),
  });

  @override
  AnimationController createAnimationController() {
    return _SpringAnimationController(
      vsync: navigator!,
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
    );
  }
}

class _SpringAnimationController extends AnimationController {
  _SpringAnimationController({
    required super.vsync,
    super.duration,
    super.reverseDuration,
  });

  @override
  TickerFuture forward({double? from}) {
    final start = from ?? value;
    final sim = SpringSimulation(AppleMotion.smooth, start, 1.0, velocity);
    return animateWith(sim);
  }

  @override
  TickerFuture reverse({double? from}) {
    final start = from ?? value;
    final sim = SpringSimulation(AppleMotion.smooth, start, 0.0, velocity);
    return animateWith(sim);
  }
}

