// lib/presentation/auth/login_screen/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_design_system.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/user_profile_provider.dart';

enum _AuthMethod { none, email, google }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  _AuthMethod _activeMethod = _AuthMethod.none;
  bool _obscurePassword = true;
  bool _isRetrying = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: FoodInsightTypography.body(
                  size: 14,
                  weight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? FoodInsightColors.healthRed
            : FoodInsightColors.scannerGreen,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _setLoading(bool loading, [_AuthMethod method = _AuthMethod.none]) {
    if (!mounted) return;
    setState(() {
      _isLoading = loading;
      _activeMethod = loading ? method : _AuthMethod.none;
    });
  }

  void _navigateAfterAuth() {
    if (!mounted) return;
    
    // Force a fresh fetch/sync from Firestore now that the user is logged in
    Provider.of<UserProfileProvider>(context, listen: false).fetchProfile();

    // Go to authGate which will determine next screen (profile setup or home)
    Navigator.pushReplacementNamed(context, AppRoutes.authGate);
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    _setLoading(true, _AuthMethod.email);
    try {
      await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      _navigateAfterAuth();
    } catch (e) {
      _showSnackBar(AuthService.getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    _setLoading(true, _AuthMethod.google);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        _setLoading(false);
        return; // User cancelled
      }
      _navigateAfterAuth();
    } catch (e) {
      _showSnackBar(AuthService.getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }


  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email first.');
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      _showSnackBar('Password reset link sent to $email', isError: false);
    } catch (e) {
      _showSnackBar(AuthService.getErrorMessage(e));
    }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7.w),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _fadeController,
                          curve: Curves.easeOut,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 5.h),



                            // ── Logo & Brand ──
                            _buildBrandSection(),

                            SizedBox(height: 4.h),

                            // ── Email Form ──
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _slideController,
                                curve: Curves.easeOutCubic,
                              )),
                              child: _buildEmailForm(),
                            ),

                            SizedBox(height: 3.h),

                            // ── Divider ──
                            _buildDivider(),

                            SizedBox(height: 3.h),

                            // ── Google Sign In ──
                            _buildGoogleSignInButton(),

                            SizedBox(height: 2.h),



                            const Spacer(),

                            // ── Sign Up Link ──
                            _buildSignUpLink(),

                            SizedBox(height: 2.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildBrandSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scanner icon with glow
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF34C759), Color(0xFF30D158)],
            ),
            borderRadius: FoodInsightRadius.lgAll,
            boxShadow: [
              BoxShadow(
                color: FoodInsightColors.scannerGreen.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        SizedBox(height: 2.5.h),
        Text(
          'Welcome back',
          style: FoodInsightTypography.display(
            size: 32,
            weight: FontWeight.w800,
            color: FoodInsightColors.deepCharcoal,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to access your personalized nutrition insights.',
          style: FoodInsightTypography.body(
            size: 15,
            weight: FontWeight.w400,
            color: FoodInsightColors.midGray,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email field
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          SizedBox(height: 1.5.h),

          // Password field
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: FoodInsightColors.midGray,
                size: 20,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              child: Text(
                'Forgot Password?',
                style: FoodInsightTypography.caption(
                  size: 13,
                  weight: FontWeight.w600,
                  color: FoodInsightColors.infoBlue,
                ),
              ),
            ),
          ),

          SizedBox(height: 1.h),

          // Sign In button
          _buildPrimaryButton(
            label: 'Sign In',
            isLoading: _isLoading && _activeMethod == _AuthMethod.email,
            onPressed: _isLoading ? null : _handleEmailSignIn,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: FoodInsightTypography.body(
        size: 15,
        weight: FontWeight.w500,
        color: FoodInsightColors.deepCharcoal,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: FoodInsightColors.midGray, size: 20),
        ),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: suffixIcon,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        labelStyle: FoodInsightTypography.caption(
          size: 14,
          color: FoodInsightColors.midGray,
        ),
        hintStyle: FoodInsightTypography.caption(
          size: 14,
          color: FoodInsightColors.lightGray,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: FoodInsightRadius.mdAll,
          borderSide: BorderSide(
            color: FoodInsightColors.lightGray.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: FoodInsightRadius.mdAll,
          borderSide: BorderSide(
            color: FoodInsightColors.lightGray.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FoodInsightRadius.mdAll,
          borderSide: const BorderSide(
            color: FoodInsightColors.scannerGreen,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: FoodInsightRadius.mdAll,
          borderSide: const BorderSide(
            color: FoodInsightColors.healthRed,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: FoodInsightRadius.mdAll,
          borderSide: const BorderSide(
            color: FoodInsightColors.healthRed,
            width: 1.5,
          ),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34C759), Color(0xFF30D158)],
          ),
          borderRadius: FoodInsightRadius.mdAll,
          boxShadow: [
            BoxShadow(
              color: FoodInsightColors.scannerGreen.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: FoodInsightRadius.mdAll,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: FoodInsightTypography.body(
                        size: 16,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: FoodInsightColors.lightGray.withValues(alpha: 0.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: FoodInsightTypography.caption(
              size: 13,
              weight: FontWeight.w500,
              color: FoodInsightColors.midGray,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: FoodInsightColors.lightGray.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    final isGoogleLoading = _isLoading && _activeMethod == _AuthMethod.google;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: FoodInsightRadius.mdAll,
          border: Border.all(
            color: FoodInsightColors.lightGray.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _handleGoogleSignIn,
            borderRadius: FoodInsightRadius.mdAll,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isGoogleLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FoodInsightColors.midGray,
                      ),
                    ),
                  )
                else
                  // Google "G" logo built with text
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: FoodInsightTypography.body(
                    size: 15,
                    weight: FontWeight.w600,
                    color: FoodInsightColors.deepCharcoal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: FoodInsightTypography.body(
              size: 14,
              weight: FontWeight.w400,
              color: FoodInsightColors.midGray,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, AppRoutes.signup);
            },
            child: Text(
              'Sign Up',
              style: FoodInsightTypography.body(
                size: 14,
                weight: FontWeight.w700,
                color: FoodInsightColors.scannerGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
