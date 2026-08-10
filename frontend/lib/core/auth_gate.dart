// lib/core/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../presentation/auth/login_screen/login_screen.dart';
import '../presentation/home_dashboard/home_dashboard.dart';
import '../presentation/profile_setup/profile_setup.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_design_system.dart';

/// A widget that listens to authentication state changes and shows the
/// appropriate screen, checking for profile completion as well.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    // If Firebase isn't ready, show login screen directly
    if (!authService.isFirebaseReady) {
      return const LoginScreen();
    }

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // 1. Still loading — show a minimal branded loading screen
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: FoodInsightColors.warmWhite,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: FoodInsightColors.healthyGradient,
                      borderRadius: FoodInsightRadius.lgAll,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FoodInsightColors.scannerGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 2. Error state — show login
        if (snapshot.hasError) {
          return const LoginScreen();
        }

        // 3. Not logged in — show login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 4. Logged in — check profile completion
        return FutureBuilder<bool>(
          future: FirestoreService()
              .isProfileCompleted()
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => false,
              ),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: FoodInsightColors.warmWhite,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: FoodInsightColors.healthyGradient,
                          borderRadius: FoodInsightRadius.lgAll,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your profile...',
                        style: FoodInsightTypography.caption(
                          size: 13,
                          color: FoodInsightColors.midGray,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (profileSnapshot.data == true) {
              return const HomeDashboard();
            }

            // Profile not yet completed
            return const ProfileSetup();
          },
        );
      },
    );
  }
}
