import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/app_export.dart';
import '../../theme/app_design_system.dart';
import 'package:provider/provider.dart';
import '../../data/providers/user_profile_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _loadingText = 'Initializing...';
  bool _hasError = false;
  int _retryCount = 0;

  // Animation controllers
  late AnimationController _logoController;
  late AnimationController _beamController;
  late AnimationController _progressController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _logoScale;
  late Animation<double> _beamPosition;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
    _initializeApp();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _beamPosition = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _beamController, curve: Curves.easeInOut),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _titleSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
      ),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  void _startAnimationSequence() {
    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _beamController.repeat();
      }
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  void _updateProgress(double value, String text) {
    if (!mounted) return;
    setState(() {
      _loadingText = text;
    });
    _progressController.animateTo(value,
        duration: FoodInsightAnimations.medium,
        curve: FoodInsightAnimations.emphasizedDecelerate);
  }

  Future<void> _initializeApp() async {
    try {
      _updateProgress(0.2, 'Loading local database...');
      try {
        await Firebase.initializeApp().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Firebase init optional skip: $e');
      }

      _updateProgress(0.6, 'Loading user profile...');
      bool profileComplete = true;
      if (mounted) {
        final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
        await profileProvider.fetchProfile();
        profileComplete = profileProvider.profile?.profileCompleted ?? true;
      }
      
      _updateProgress(1.0, 'Ready!');
      await Future.delayed(const Duration(milliseconds: 300));
      
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
        final navigator = Navigator.of(context);
        navigator.pushReplacementNamed(AppRoutes.homeDashboard);
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
  void dispose() {
    _logoController.dispose();
    _beamController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.splashGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                _buildScannerLogo(),
                const SizedBox(height: 32),
                _buildTitle(),
                const SizedBox(height: 8),
                _buildTagline(),
                const Spacer(flex: 2),
                _buildLoadingState(),
                const SizedBox(height: 40),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScale.value,
          child: child,
        );
      },
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer matte ring
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FoodInsightColors.scannerReticle
                          .withValues(alpha: 0.2 + _pulseController.value * 0.1),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: FoodInsightColors.scannerReticle
                            .withValues(alpha: 0.1 + _pulseController.value * 0.05),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                );
              },
            ),
            // Inner glossy ring
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF0D0D0D),
                  ],
                ),
                border: Border.all(
                  color: FoodInsightColors.scannerGreen.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
            // Center lens
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  colors: [
                    Color(0xFF1A2A1A),
                    Color(0xFF0A0F0A),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gloss highlight
                  Positioned(
                    top: 12,
                    left: 20,
                    child: Container(
                      width: 30,
                      height: 15,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Scanner icon
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: FoodInsightColors.scannerReticle,
                    size: 44,
                  ),
                ],
              ),
            ),
            // Scanning beam
            AnimatedBuilder(
              animation: _beamController,
              builder: (context, _) {
                return Positioned(
                  top: 30 + (_beamPosition.value + 1) / 2 * 100,
                  left: 35,
                  right: 35,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          FoodInsightColors.scannerReticle.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: FoodInsightColors.scannerReticle.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Progress ring
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, _) {
                return SizedBox(
                  width: 155,
                  height: 155,
                  child: CustomPaint(
                    painter: _ProgressRingPainter(
                      progress: _progressController.value,
                      color: FoodInsightColors.scannerGreen,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _titleFade.value,
          child: Transform.translate(
            offset: Offset(0, _titleSlide.value),
            child: child,
          ),
        );
      },
      child: Text(
        'Food Insight',
        style: FoodInsightTypography.display(
          size: 28,
          weight: FontWeight.w800,
          color: FoodInsightColors.warmWhite,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _taglineFade.value,
          child: child,
        );
      },
      child: Text(
        'Personal nutrition intelligence',
        style: FoodInsightTypography.body(
          size: 14,
          weight: FontWeight.w500,
          color: FoodInsightColors.midGray,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    if (_hasError) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _hasError = false;
          });
          _retryInitialization();
        },
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FoodInsightColors.healthRed.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: FoodInsightColors.healthRed,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: FoodInsightTypography.body(
                weight: FontWeight.w600,
                color: FoodInsightColors.healthRed,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to retry',
              style: FoodInsightTypography.caption(
                color: FoodInsightColors.midGray,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        AnimatedSwitcher(
          duration: FoodInsightAnimations.fast,
          child: Text(
            _loadingText,
            key: ValueKey(_loadingText),
            style: FoodInsightTypography.caption(
              size: 13,
              weight: FontWeight.w500,
              color: FoodInsightColors.midGray,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final delay = index * 0.3;
                final animValue =
                    ((_pulseController.value + delay) % 1.0).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FoodInsightColors.scannerGreen
                        .withValues(alpha: 0.3 + animValue * 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: FoodInsightColors.scannerGreen
                            .withValues(alpha: animValue * 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

/// Custom painter for the progress ring around the logo
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Progress arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress;
}
