import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitialized = false;
  String _loadingText = 'Initializing core modules...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Initial wait for animation
      await Future.delayed(const Duration(milliseconds: 800));

      // 2. Mock or real init processes
      if (mounted) setState(() => _loadingText = 'Connecting to backend...');
      // Ensure Firebase is initialized
      try {
         await Firebase.initializeApp();
      } catch (e) {
         // Already initialized or platform issue
      }
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) setState(() => _loadingText = 'Loading preferences...');
      final hasProfile = await _checkUserProfile();
      
      if (mounted) setState(() => _loadingText = 'Ready');
      await Future.delayed(const Duration(milliseconds: 300));

      final currentUser = FirebaseAuth.instance.currentUser;
      
      _isInitialized = true;
      _navigateToNextScreen(hasProfile, currentUser);
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() => _loadingText = 'Ready');
      }
      _isInitialized = true;
      _navigateToNextScreen(false, null);
    }
  }

  Future<bool> _checkUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('profile_completed') ?? false;
    } catch (e) {
      debugPrint('Profile check failed: $e');
      return false;
    }
  }

  void _navigateToNextScreen(bool hasProfile, User? user) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.authGate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Glow
          if (isDark)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3,
              left: -50,
              right: -50,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.mintGreen.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .fade(duration: 2000.ms)
             .scaleXY(begin: 0.9, end: 1.1, duration: 3000.ms, curve: Curves.easeInOut),

          // Main Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Spacer(flex: 3),

                   // Logo
                   Container(
                     width: 35.w,
                     height: 35.w,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: isDark ? AppTheme.glassDarkBg : Colors.white,
                       border: Border.all(
                         color: isDark ? AppTheme.glassDarkBorder : theme.colorScheme.primary.withValues(alpha: 0.2),
                         width: 2,
                       ),
                       boxShadow: isDark ? AppTheme.glowBoxShadow(AppTheme.emeraldGreen, intensity: 0.2, blur: 30) : [
                         BoxShadow(
                           color: theme.colorScheme.primary.withValues(alpha: 0.2),
                           blurRadius: 20,
                           offset: const Offset(0, 10),
                         )
                       ],
                     ),
                     child: Center(
                       child: CustomIconWidget(
                         iconName: 'fastfood',
                         size: 20.w,
                         color: AppTheme.emeraldGreen,
                       ).animate()
                         .scaleXY(begin: 0.8, end: 1.0, duration: 600.ms, curve: Curves.easeOutBack)
                         .then()
                         .shimmer(duration: 1200.ms, delay: 500.ms, color: Colors.white54),
                     ),
                   ).animate()
                     .fadeIn(duration: 800.ms)
                     .slideY(begin: 0.1, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),

                   SizedBox(height: 3.h),

                   // App Title
                   Text(
                     'NutriCore',
                     style: theme.textTheme.headlineLarge?.copyWith(
                       fontWeight: FontWeight.w900,
                       letterSpacing: -0.5,
                       color: isDark ? Colors.white : theme.colorScheme.primary,
                       shadows: isDark ? AppTheme.textGlow(AppTheme.emeraldGreen, blur: 8) : null,
                     ),
                   ).animate()
                     .fadeIn(duration: 600.ms, delay: 300.ms)
                     .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),

                   SizedBox(height: 1.h),

                   Text(
                     'Intelligent Food Insight Scanner',
                     style: theme.textTheme.titleMedium?.copyWith(
                       color: theme.colorScheme.onSurfaceVariant,
                       letterSpacing: 0.5,
                     ),
                   ).animate()
                     .fadeIn(duration: 600.ms, delay: 500.ms)
                     .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),

                   const Spacer(flex: 2),

                   // Loading Status
                   Column(
                     children: [
                       SizedBox(
                         width: 10.w,
                         height: 10.w,
                         child: CircularProgressIndicator(
                           strokeWidth: 3,
                           valueColor: AlwaysStoppedAnimation<Color>(AppTheme.emeraldGreen),
                         ),
                       ),
                       SizedBox(height: 2.h),
                       Text(
                         _loadingText,
                         style: theme.textTheme.bodyMedium?.copyWith(
                           color: theme.colorScheme.onSurfaceVariant,
                           fontStyle: FontStyle.italic,
                         ),
                       ).animate(key: ValueKey(_loadingText))
                         .fadeIn(duration: 300.ms),
                     ],
                   ).animate()
                     .fadeIn(duration: 800.ms, delay: 800.ms),

                   const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
