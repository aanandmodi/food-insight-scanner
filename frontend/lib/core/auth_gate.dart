import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/providers/user_profile_provider.dart';
import '../presentation/auth/login_screen/login_screen.dart';
import '../presentation/home_dashboard/home_dashboard.dart';
import '../presentation/profile_setup/profile_setup.dart';
import '../services/auth_service.dart';
import '../theme/app_design_system.dart';

/// Decides what the user sees on launch: login, onboarding, or the dashboard.
///
/// This listens to `authStateChanges` rather than reading `isAuthenticated`
/// once. The old one-shot read meant the gate never rebuilt after sign-in or
/// sign-out, so the app appeared stuck on the login screen until a hot restart.
/// It also fell through to onboarding when the profile load merely *failed*,
/// which made a flaky network look like a wiped profile — now that shows a
/// retry instead.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GateSplash(label: 'Getting things ready…');
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }

        return Consumer<UserProfileProvider>(
          builder: (context, provider, child) {
            return AuthGateContent(
              uid: snapshot.data!.uid,
              boundUid: provider.boundUid,
              loading: provider.isLoading,
              hasProfile: provider.profile != null,
              hasError: provider.hasError,
              complete: provider.isProfileComplete,
              onRetry: provider.fetchProfile,
              dashboard: () => HomeDashboard(key: ValueKey(snapshot.data!.uid)),
              onboarding: () => ProfileSetup(key: ValueKey(snapshot.data!.uid)),
            );
          },
        );
      },
    );
  }
}

/// Profile routing is separate from SDK subscriptions so account-switch and
/// failure states can be exercised without a real sign-in or device plugin.
class AuthGateContent extends StatelessWidget {
  const AuthGateContent(
      {super.key,
      required this.uid,
      required this.boundUid,
      required this.loading,
      required this.hasProfile,
      required this.hasError,
      required this.complete,
      required this.onRetry,
      required this.dashboard,
      required this.onboarding});
  final String uid;
  final String? boundUid;
  final bool loading, hasProfile, hasError, complete;
  final Future<void> Function() onRetry;
  final Widget Function() dashboard, onboarding;
  @override
  Widget build(BuildContext context) {
    if (boundUid != uid || (loading && !hasProfile)) {
      return const _GateSplash(label: 'Loading your profile…');
    }
    if (hasError && !hasProfile) return _GateError(onRetry: onRetry);
    return complete ? dashboard() : onboarding();
  }
}

/// Branded loading state, styled to match the splash so launch feels seamless.
class _GateSplash extends StatelessWidget {
  const _GateSplash({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: FoodInsightColors.healthyGradient,
                borderRadius: FoodInsightRadius.xlAll,
                boxShadow: FoodInsightShadows.scannerGlow(
                  FoodInsightColors.scannerGreen,
                ),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 34,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  duration: FoodInsightAnimations.verySlow,
                  begin: const Offset(1, 1),
                  end: const Offset(1.06, 1.06),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  FoodInsightColors.scannerGreen,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              style: FoodInsightTypography.caption(
                color: FoodInsightColors.midGray,
              ),
            )
                .animate()
                .fadeIn(duration: FoodInsightAnimations.medium, delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

class _GateError extends StatelessWidget {
  const _GateError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: FoodInsightColors.matteCard,
                    borderRadius: FoodInsightRadius.xlAll,
                    boxShadow: FoodInsightShadows.raisedCard,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: FoodInsightColors.midGray,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Couldn't load your profile",
                  textAlign: TextAlign.center,
                  style: FoodInsightTypography.heading(size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  'Check your connection and try again. Your saved profile has not been replaced.',
                  textAlign: TextAlign.center,
                  style: FoodInsightTypography.body(
                    color: FoodInsightColors.midGray,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: FoodInsightColors.scannerGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: FoodInsightRadius.lgAll,
                      ),
                    ),
                    child: Text(
                      'Try again',
                      style: FoodInsightTypography.body(
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => AuthService().signOut(),
                  child: Text(
                    'Sign in with a different account',
                    style: FoodInsightTypography.caption(
                      color: FoodInsightColors.midGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: FoodInsightAnimations.medium).slideY(
            begin: 0.06, end: 0, curve: FoodInsightAnimations.decelerate),
      ),
    );
  }
}
