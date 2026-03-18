import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../core/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _gradientAnimationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _gradientAnimation;

  bool _isInitialized = false;
  String _loadingText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Logo animation controller
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Gradient animation controller
    _gradientAnimationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Logo scale animation
    _logoScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    // Logo fade animation
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    // Gradient animation
    _gradientAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gradientAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _logoAnimationController.forward();
    _gradientAnimationController.repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    try {
      // Simulate app initialization tasks
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _loadingText = 'Step 1/4: Checking services...';
      });

      // ──────────────────────────────────────────────────────────────────────
      // SAFE CHECK: Ensure Firebase is actually initialized before using it.
      // ──────────────────────────────────────────────────────────────────────
      int retries = 0;
      while (Firebase.apps.isEmpty && retries < 5) {
        await Future.delayed(const Duration(seconds: 1));
        retries++;
      }

      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase not initialized. Please restart the app.');
      }

      setState(() {
        _loadingText = 'Step 2/4: Authenticating...';
      });

      // Check if user is already logged in
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        // User not logged in, wait for navigation to Login Screen
        // We do nothing here, the navigation logic below handles it
      }

      setState(() {
        _loadingText = 'Step 3/4: Loading profile...';
      });

      // Check user profile existence with timeout
      final hasProfile = await _checkUserProfile().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      
      if (mounted) {
        setState(() {
          _loadingText = 'Step 4/4: Ready...';
        });
      }

      // Initialize ML Kit for scanning
      await _initializeMLKit();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate based on user profile status
      if (mounted) {
        _navigateToNextScreen(hasProfile, user);
      }
    } catch (e) {
      // Handle initialization errors
      debugPrint('Initialization error: $e');
      if (mounted) {
         setState(() {
           _loadingText = 'Connection Error: \n${e.toString().replaceAll("Exception: ", "")}';
         });
      }
      _showRetryOption();
    }
  }

  Future<bool> _checkUserProfile() async {
    // Check if profile has been completed via SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('profile_completed') ?? false;
    } catch (e) {
      debugPrint('Profile check failed: $e');
      return false;
    }
  }

  Future<void> _initializeMLKit() async {
    // Simulate ML Kit initialization
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _cacheNutritionData() async {
    // Simulate caching nutrition data
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _navigateToNextScreen(bool hasProfile, User? user) {
    if (user == null) {
      // Not logged in — go to login screen
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (user.isAnonymous && !hasProfile) {
      // Anonymous users should probably set up a profile too for better AI results
      Navigator.pushReplacementNamed(context, '/profile-setup');
    } else if (hasProfile) {
      // Logged in with complete profile — go to home dashboard
      Navigator.pushReplacementNamed(context, '/home-dashboard');
    } else {
      // Logged in but no profile — go to profile setup
      Navigator.pushReplacementNamed(context, '/profile-setup');
    }
  }

  void _showRetryOption() {
    setState(() {
      _loadingText = 'Connection timeout';
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              'Connection Error',
              style: AppTheme.lightTheme.textTheme.titleLarge,
            ),
            content: Text(
              'Unable to connect to the server. You can retry or continue offline.',
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _retryInitialization();
                },
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/home-dashboard');
                },
                child: const Text('Continue Offline'),
              ),
            ],
          ),
        );
      }
    });
  }

  void _retryInitialization() {
    setState(() {
      _isInitialized = false;
      _loadingText = 'Retrying...';
    });
    _initializeApp();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _gradientAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide status bar on Android, match brand color on iOS
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    AppTheme.lightTheme.colorScheme.primary,
                    AppTheme.lightTheme.colorScheme.secondary,
                    _gradientAnimation.value * 0.3,
                  )!,
                  Color.lerp(
                    Colors.white,
                    AppTheme.lightTheme.colorScheme.primaryContainer,
                    _gradientAnimation.value * 0.2,
                  )!,
                ],
                stops: [
                  0.3 + (_gradientAnimation.value * 0.2),
                  0.9 - (_gradientAnimation.value * 0.1),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Spacer to push content to center
                  const Spacer(flex: 2),

                  // Animated Logo Section
                  AnimatedBuilder(
                    animation: _logoAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Opacity(
                          opacity: _logoFadeAnimation.value,
                          child: Container(
                            width: 35.w,
                            height: 35.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20.w),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.lightTheme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomIconWidget(
                                  iconName: 'qr_code_scanner',
                                  color:
                                      AppTheme.lightTheme.colorScheme.primary,
                                  size: 12.w,
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  'Food\nInsight',
                                  textAlign: TextAlign.center,
                                  style: AppTheme
                                      .lightTheme.textTheme.titleMedium
                                      ?.copyWith(
                                    color:
                                        AppTheme.lightTheme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 4.h),

                  // App Title
                  AnimatedBuilder(
                    animation: _logoFadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoFadeAnimation.value,
                        child: Column(
                          children: [
                            Text(
                              'Food Insight Scanner',
                              style: AppTheme.lightTheme.textTheme.headlineSmall
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'AI-Powered Nutrition Intelligence',
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  // Loading Section
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Column(
                      children: [
                        // Glassmorphism Loading Container
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Loading Indicator
                              SizedBox(
                                width: 8.w,
                                height: 8.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withValues(alpha: 0.9),
                                  ),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.3),
                                ),
                              ),

                              SizedBox(height: 2.h),

                              // Loading Text
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _loadingText,
                                  key: ValueKey(_loadingText),
                                  style: AppTheme
                                      .lightTheme.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              SizedBox(height: 1.h),

                              // Progress Dots
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (index) {
                                  return AnimatedContainer(
                                    duration: Duration(
                                        milliseconds: 300 + (index * 100)),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    width: _isInitialized ? 8 : 6,
                                    height: _isInitialized ? 8 : 6,
                                    decoration: BoxDecoration(
                                      color: _isInitialized
                                          ? AppTheme
                                              .lightTheme.colorScheme.secondary
                                          : Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 4.h),

                        // Version Info
                        Text(
                          'Version 1.0.0',
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 4.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
