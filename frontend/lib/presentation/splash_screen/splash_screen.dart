import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';

import '../../core/app_export.dart';
import '../../theme/app_design_system.dart';
import '../../data/providers/user_profile_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingText = 'Initializing...';
  bool _hasError = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _updateProgress(String text) {
    if (!mounted) return;
    setState(() {
      _loadingText = text;
    });
  }

  Future<void> _initializeApp() async {
    try {
      _updateProgress('Loading secure environment...');
      try {
        await Firebase.initializeApp().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Firebase init optional skip: $e');
      }

      _updateProgress('Loading your profile...');
      bool profileComplete = true;
      if (mounted) {
        final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
        await profileProvider.fetchProfile();
        profileComplete = profileProvider.profile?.profileCompleted ?? true;
      }
      
      _updateProgress('Ready!');
      await Future.delayed(const Duration(milliseconds: 600)); // Minimum splash duration
      
      if (!mounted) return;
      final navigator = Navigator.of(context);

      if (!profileComplete) {
        navigator.pushReplacementNamed(AppRoutes.profileSetup);
      } else {
        navigator.pushReplacementNamed(AppRoutes.homeDashboard);
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _loadingText = 'Failed to load: $e';
        });
        // Still attempt to navigate after a delay
        Future.delayed(const Duration(seconds: 2), () {
           if (mounted) {
              Navigator.of(context).pushReplacementNamed(AppRoutes.homeDashboard);
           }
        });
      }
    }
  }

  void _retryInitialization() {
    _retryCount++;
    setState(() {
      _hasError = false;
      _loadingText = 'Retrying... (attempt $_retryCount)';
    });
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      body: Container(
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                _buildLogo().animate().scaleXY(begin: 0.8, end: 1.0, duration: 800.ms, curve: Curves.easeOutBack).fadeIn(duration: 800.ms),
                SizedBox(height: 4.h),
                _buildTitle().animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                SizedBox(height: 1.h),
                _buildTagline().animate().fadeIn(delay: 600.ms, duration: 600.ms),
                const Spacer(flex: 2),
                _buildLoadingState().animate().fadeIn(delay: 800.ms),
                SizedBox(height: 5.h),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: FoodInsightShadows.floating,
      ),
      child: Center(
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: FoodInsightColors.scannerGreenLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.center_focus_strong_rounded,
            size: 40,
            color: FoodInsightColors.scannerGreen,
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scaleXY(begin: 1.0, end: 1.05, duration: 1.seconds, curve: Curves.easeInOut),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Food Insight',
      style: FoodInsightTypography.display(
        size: 32,
        weight: FontWeight.w900,
        color: FoodInsightColors.deepCharcoal,
      ),
    );
  }

  Widget _buildTagline() {
    return Text(
      'Scan. Discover. Thrive.',
      style: FoodInsightTypography.body(
        size: 16,
        color: FoodInsightColors.midGray,
      ),
    );
  }

  Widget _buildLoadingState() {
    if (_hasError) {
      return Column(
        children: [
          Icon(Icons.error_outline, color: FoodInsightColors.healthRed, size: 32),
          SizedBox(height: 1.5.h),
          Text(
            _loadingText,
            style: FoodInsightTypography.body(color: FoodInsightColors.healthRed),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2.h),
          ElevatedButton(
            onPressed: _retryInitialization,
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodInsightColors.deepCharcoal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.mdAll),
            ),
            child: Text('Retry', style: FoodInsightTypography.body(color: Colors.white, weight: FontWeight.w700)),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(FoodInsightColors.scannerGreen),
            strokeWidth: 3,
            backgroundColor: FoodInsightColors.scannerGreenLight,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          _loadingText,
          style: FoodInsightTypography.caption(
            size: 13,
            color: FoodInsightColors.midGray,
          ),
        ),
      ],
    );
  }
}
