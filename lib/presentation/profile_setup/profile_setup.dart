// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'package:cloud_firestore/cloud_firestore.dart'; // For FieldValue
import '../../core/app_export.dart';
import '../../core/services/firestore_service.dart';
import './widgets/allergy_selection_widget.dart';
import './widgets/dietary_preferences_widget.dart';
import './widgets/health_goal_dropdown_widget.dart';
import './widgets/progress_indicator_widget.dart';

class ProfileSetup extends StatefulWidget {
  const ProfileSetup({super.key});

  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form data
  String _userName = '';
  List<String> _selectedAllergies = [];
  String? _selectedHealthGoal;
  List<String> _selectedDietaryPreferences = [];

  // UI state
  int _currentStep = 1;
  final int _totalSteps = 4;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  final List<String> _stepLabels = [
    'Personal Info',
    'Allergies',
    'Health Goals',
    'Diet Preferences'
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadExistingProfile();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadExistingProfile() async {
    try {
      // Try loading from Firestore first
      final cloudProfile = await FirestoreService().getUserProfile();
      
      final prefs = await SharedPreferences.getInstance();

      if (cloudProfile != null) {
        // Sync Cloud -> Local
        setState(() {
          _userName = cloudProfile['name'] ?? '';
          _nameController.text = _userName;
          _selectedAllergies = List<String>.from(cloudProfile['allergies'] ?? []);
          _selectedHealthGoal = cloudProfile['healthGoal'];
          _selectedDietaryPreferences = List<String>.from(cloudProfile['dietaryPreferences'] ?? []);
        });

        // Update SharedPreferences
        await prefs.setString('user_name', _userName);
        await prefs.setStringList('user_allergies', _selectedAllergies);
        if (_selectedHealthGoal != null) {
          await prefs.setString('user_health_goal', _selectedHealthGoal!);
        }
        await prefs.setStringList(
            'user_dietary_preferences', _selectedDietaryPreferences);
        await prefs.setBool('profile_completed', true);

      } else {
        // Fallback to Local only
        setState(() {
          _userName = prefs.getString('user_name') ?? '';
          _nameController.text = _userName;
          _selectedAllergies = prefs.getStringList('user_allergies') ?? [];
          _selectedHealthGoal = prefs.getString('user_health_goal');
          _selectedDietaryPreferences =
              prefs.getStringList('user_dietary_preferences') ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_isFormValid()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Prepare profile data map
      final profileData = {
        'name': _userName,
        'allergies': _selectedAllergies,
        'healthGoal': _selectedHealthGoal ?? '',
        'dietaryPreferences': _selectedDietaryPreferences,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to SharedPreferences (Local Cache)
      await prefs.setString('user_name', _userName);
      await prefs.setStringList('user_allergies', _selectedAllergies);
      if (_selectedHealthGoal != null) {
        await prefs.setString('user_health_goal', _selectedHealthGoal!);
      }
      await prefs.setStringList(
          'user_dietary_preferences', _selectedDietaryPreferences);
      await prefs.setBool('profile_completed', true);

      // Save to Firestore (Cloud)
      await FirestoreService().saveUserProfile(profileData);

      // Simulate network delay if needed, but Firestore is fast
      // await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        HapticFeedback.lightImpact();
        _showSuccessAnimation();

        // Navigate to home dashboard after success animation
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
           Navigator.pushReplacementNamed(context, '/home-dashboard');
        }
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to save profile. Please check connection.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasUnsavedChanges = false;
        });
      }
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: CustomIconWidget(
                  iconName: 'check',
                  color: AppTheme.lightTheme.colorScheme.onPrimary,
                  size: 40,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Profile Created!',
                style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Welcome to Food Insight Scanner, $_userName!',
                style: AppTheme.lightTheme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CustomIconWidget(
              iconName: 'error',
              color: AppTheme.lightTheme.colorScheme.onError,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                message,
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(4.w),
      ),
    );
  }

  bool _isFormValid() {
    return _userName.isNotEmpty && _selectedHealthGoal != null;
  }

  void _nextStep() {
    if (_currentStep < _totalSteps) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Unsaved Changes',
                style: AppTheme.lightTheme.textTheme.titleLarge,
              ),
              content: Text(
                'You have unsaved changes. Do you want to save your profile before leaving?',
                style: AppTheme.lightTheme.textTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Discard',
                    style:
                        TextStyle(color: AppTheme.lightTheme.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    _saveProfile();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ) ??
          false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        final bool shouldPop = await _onWillPop();
        if (shouldPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.lightTheme.colorScheme.primary.withOpacity(0.1),
                AppTheme.lightTheme.colorScheme.secondary
                    .withOpacity(0.05),
                AppTheme.lightTheme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Column(
                        children: [
                          SizedBox(height: 2.h),
                          ProgressIndicatorWidget(
                            currentStep: _currentStep,
                            totalSteps: _totalSteps,
                            stepLabels: _stepLabels,
                          ),
                          SizedBox(height: 3.h),
                          SlideTransition(
                            position: _slideAnimation,
                            child: SizedBox(
                              height: 60.h,
                              child: PageView(
                                controller: _pageController,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentStep = index + 1;
                                  });
                                  _slideController.reset();
                                  _slideController.forward();
                                },
                                children: [
                                  _buildPersonalInfoStep(),
                                  _buildAllergiesStep(),
                                  _buildHealthGoalStep(),
                                  _buildDietaryPreferencesStep(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Row(
        children: [
          GestureDetector(
            onTap:
                _currentStep > 1 ? _previousStep : () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface
                    .withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withOpacity(0.3),
                ),
              ),
              child: CustomIconWidget(
                iconName: 'arrow_back',
                color: AppTheme.lightTheme.colorScheme.onSurface,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup Your Profile',
                  style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Personalize your food scanning experience',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomIconWidget(
                  iconName: 'person',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 24,
                ),
                SizedBox(width: 3.w),
                Text(
                  'Personal Information',
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            Text(
              'What should we call you?',
              style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your full name',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'badge',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _userName = value.trim();
                  _hasUnsavedChanges = true;
                });
              },
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.primary
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.primary
                      .withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'info',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'Your name will be used to personalize your experience and AI chat interactions.',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllergiesStep() {
    return AllergySelectionWidget(
      selectedAllergies: _selectedAllergies,
      onAllergyChanged: (allergies) {
        setState(() {
          _selectedAllergies = allergies;
          _hasUnsavedChanges = true;
        });
      },
    );
  }

  Widget _buildHealthGoalStep() {
    return HealthGoalDropdownWidget(
      selectedGoal: _selectedHealthGoal,
      onGoalChanged: (goal) {
        setState(() {
          _selectedHealthGoal = goal;
          _hasUnsavedChanges = true;
        });
      },
    );
  }

  Widget _buildDietaryPreferencesStep() {
    return DietaryPreferencesWidget(
      selectedPreferences: _selectedDietaryPreferences,
      onPreferencesChanged: (preferences) {
        setState(() {
          _selectedDietaryPreferences = preferences;
          _hasUnsavedChanges = true;
        });
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color:
                AppTheme.lightTheme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 1)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'arrow_back',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 18,
                    ),
                    SizedBox(width: 2.w),
                    const Text('Previous'),
                  ],
                ),
              ),
            ),
          if (_currentStep > 1) SizedBox(width: 4.w),
          Expanded(
            flex: _currentStep == 1 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : _currentStep == _totalSteps
                      ? _saveProfile
                      : _nextStep,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.lightTheme.colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep == _totalSteps ? 'Save Profile' : 'Next',
                        ),
                        SizedBox(width: 2.w),
                        CustomIconWidget(
                          iconName: _currentStep == _totalSteps
                              ? 'save'
                              : 'arrow_forward',
                          color: AppTheme.lightTheme.colorScheme.onPrimary,
                          size: 18,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}