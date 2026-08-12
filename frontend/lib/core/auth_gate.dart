import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/providers/user_profile_provider.dart';
import '../presentation/home_dashboard/home_dashboard.dart';
import '../presentation/profile_setup/profile_setup.dart';
import '../theme/app_design_system.dart';

/// A gate widget that checks local user profile completion and renders
/// HomeDashboard or ProfileSetup.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
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
                  const SizedBox(
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

        final profile = provider.profile;
        if (profile != null && profile.profileCompleted) {
          return const HomeDashboard();
        }

        // If profile is incomplete, take to Profile Setup
        return const ProfileSetup();
      },
    );
  }
}

