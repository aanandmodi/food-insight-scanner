// lib/presentation/profile_setup/profile_setup.dart


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form data
  String _userName = '';
  String _selectedGender = '';
  DateTime? _dateOfBirth;
  double? _heightCm;
  double? _weightKg;
  List<String> _selectedDiseases = [];
  List<String> _selectedAllergies = [];
  String? _selectedHealthGoal;
  List<String> _selectedDietaryPreferences = [];

  // UI state
  int _currentStep = 1;
  final int _totalSteps = 6;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  final List<String> _stepLabels = [
    'Basic Info',
    'Birth Date',
    'Body Metrics',
    'Conditions',
    'Allergies',
    'Goals & Diet',
  ];

  final List<String> _genderOptions = ['Male', 'Female', 'Non-Binary', 'Prefer not to say'];

  final List<String> _diseaseOptions = [
    'Diabetes (Type 1)',
    'Diabetes (Type 2)',
    'Hypertension',
    'Heart Disease',
    'Celiac Disease',
    'IBS / Crohn\'s',
    'PCOS',
    'Thyroid Disorder',
    'Kidney Disease',
    'Liver Disease',
    'High Cholesterol',
    'Anemia',
    'Gout',
    'Lactose Intolerance',
    'None',
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
      final prefs = await SharedPreferences.getInstance();

      // Try Firestore first (with timeout), fall back to local
      Map<String, dynamic>? cloudProfile;
      try {
        cloudProfile = await FirestoreService().getUserProfile().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('Firestore load failed, using local cache: $e');
      }

      if (cloudProfile != null) {
        setState(() {
          _userName = cloudProfile!['name'] ?? '';
          _nameController.text = _userName;
          _selectedGender = cloudProfile['gender'] ?? '';
          if (cloudProfile['dateOfBirth'] != null) {
            _dateOfBirth = DateTime.tryParse(cloudProfile['dateOfBirth']);
          }
          _heightCm = (cloudProfile['heightCm'] as num?)?.toDouble();
          _weightKg = (cloudProfile['weightKg'] as num?)?.toDouble();
          if (_heightCm != null) _heightController.text = _heightCm!.toStringAsFixed(0);
          if (_weightKg != null) _weightController.text = _weightKg!.toStringAsFixed(1);
          _selectedDiseases = List<String>.from(cloudProfile['diseases'] ?? []);
          _selectedAllergies = List<String>.from(cloudProfile['allergies'] ?? []);
          _selectedHealthGoal = cloudProfile['healthGoal'];
          _selectedDietaryPreferences =
              List<String>.from(cloudProfile['dietaryPreferences'] ?? []);
        });
      } else {
        // Load from local SharedPreferences
        setState(() {
          _userName = prefs.getString('user_name') ?? '';
          _nameController.text = _userName;
          _selectedGender = prefs.getString('user_gender') ?? '';
          final dobStr = prefs.getString('user_dob');
          if (dobStr != null) _dateOfBirth = DateTime.tryParse(dobStr);
          _heightCm = prefs.getDouble('user_height');
          _weightKg = prefs.getDouble('user_weight');
          if (_heightCm != null) _heightController.text = _heightCm!.toStringAsFixed(0);
          if (_weightKg != null) _weightController.text = _weightKg!.toStringAsFixed(1);
          _selectedDiseases = prefs.getStringList('user_diseases') ?? [];
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

      // ── 1. Always save to Local Cache first (this never fails) ──
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_gender', _selectedGender);
      if (_dateOfBirth != null) {
        await prefs.setString('user_dob', _dateOfBirth!.toIso8601String());
      }
      if (_heightCm != null) {
        await prefs.setDouble('user_height', _heightCm!);
      }
      if (_weightKg != null) {
        await prefs.setDouble('user_weight', _weightKg!);
      }
      await prefs.setStringList('user_diseases', _selectedDiseases);
      await prefs.setStringList('user_allergies', _selectedAllergies);
      if (_selectedHealthGoal != null) {
        await prefs.setString('user_health_goal', _selectedHealthGoal!);
      }
      await prefs.setStringList(
          'user_dietary_preferences', _selectedDietaryPreferences);
      await prefs.setBool('profile_completed', true);

      // ── 2. Try to save to Firestore (best-effort, non-blocking) ──
      try {
        final profileData = {
          'name': _userName,
          'gender': _selectedGender,
          'dateOfBirth': _dateOfBirth?.toIso8601String(),
          'heightCm': _heightCm,
          'weightKg': _weightKg,
          'diseases': _selectedDiseases,
          'allergies': _selectedAllergies,
          'healthGoal': _selectedHealthGoal ?? '',
          'dietaryPreferences': _selectedDietaryPreferences,
          'profileCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await FirestoreService().saveUserProfile(profileData).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Firestore save timed out — profile saved locally.');
          },
        );
      } catch (e) {
        debugPrint('Firestore save failed (profile is saved locally): $e');
        // Don't rethrow — local save succeeded, we can sync later
      }

      // ── 3. Navigate to home ──
      if (mounted) {
        HapticFeedback.lightImpact();
        _showSuccessAnimation();

        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home-dashboard');
        }
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to save profile. Please try again.');
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: CustomIconWidget(
                  iconName: 'check',
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 40,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Profile Created!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Welcome to Food Insight Scanner, $_userName!',
                style: Theme.of(context).textTheme.bodyLarge,
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
              color: Theme.of(context).colorScheme.onError,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Text(
                'You have unsaved changes. Do you want to save your profile before leaving?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Discard',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
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

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Select your date of birth',
      builder: (context, child) {
        return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: Theme.of(context).colorScheme,
           ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _hasUnsavedChanges = true;
      });
    }
  }

  int? get _calculatedAge {
    if (_dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final bool shouldPop = await _onWillPop();
        if (!context.mounted) return;
        if (shouldPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.secondary
                    .withValues(alpha: 0.05),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildAppBar(),
                  // Progress indicator
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: ProgressIndicatorWidget(
                      currentStep: _currentStep,
                      totalSteps: _totalSteps,
                      stepLabels: _stepLabels,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  // Page content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentStep = index + 1;
                        });
                        _slideController.reset();
                        _slideController.forward();
                      },
                      children: [
                        _buildBasicInfoStep(),
                        _buildDateOfBirthStep(),
                        _buildBodyMetricsStep(),
                        _buildDiseasesStep(),
                        _buildAllergiesStep(),
                        _buildGoalsAndDietStep(),
                      ],
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
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      child: Row(
        children: [
          GestureDetector(
            onTap:
                _currentStep > 1 ? _previousStep : () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: 0.3),
                ),
              ),
              child: CustomIconWidget(
                iconName: 'arrow_back',
                color: Theme.of(context).colorScheme.onSurface,
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Step $_currentStep of $_totalSteps',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Step 1: Basic Info ───────────────────

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: _cardDecoration(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepHeader('person', 'Personal Information'),
                SizedBox(height: 2.h),
                Text('What should we call you?',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500)),
                SizedBox(height: 1.5.h),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your full name',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(3.w),
                      child: CustomIconWidget(
                        iconName: 'badge',
                        color: Theme.of(context).colorScheme.primary,
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
                SizedBox(height: 3.h),
                Text('Gender',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500)),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 2.w,
                  runSpacing: 1.h,
                  children: _genderOptions.map((gender) {
                    final isSelected = _selectedGender == gender;
                    return ChoiceChip(
                      label: Text(gender),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedGender = selected ? gender : '';
                          _hasUnsavedChanges = true;
                        });
                      },
                      selectedColor: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 2.h),
                _buildInfoTip(
                    'Your name and gender help us personalize nutrition advice.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────── Step 2: Date of Birth ───────────────────

  Widget _buildDateOfBirthStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader('cake', 'Date of Birth'),
            SizedBox(height: 2.h),
            Text('When were you born?',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w500)),
            SizedBox(height: 2.h),
            GestureDetector(
              onTap: _pickDateOfBirth,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _dateOfBirth != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: _dateOfBirth != null ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'calendar_today',
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        _dateOfBirth != null
                            ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                            : 'Tap to select your date of birth',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _dateOfBirth != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    CustomIconWidget(
                      iconName: 'chevron_right',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            if (_calculatedAge != null) ...[
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'info',
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Your age: $_calculatedAge years',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 2.h),
            _buildInfoTip(
                'Your age helps us calculate daily nutritional requirements and recommended calorie intake.'),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Step 3: Body Metrics ───────────────────

  Widget _buildBodyMetricsStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader('monitor_weight', 'Body Metrics'),
            SizedBox(height: 2.h),
            // Height
            Text('Height (cm)',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w500)),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _heightController,
              decoration: InputDecoration(
                hintText: 'e.g. 170',
                suffixText: 'cm',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'height',
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              onChanged: (value) {
                setState(() {
                  _heightCm = double.tryParse(value);
                  _hasUnsavedChanges = true;
                });
              },
            ),
            SizedBox(height: 3.h),
            // Weight
            Text('Weight (kg)',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w500)),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _weightController,
              decoration: InputDecoration(
                hintText: 'e.g. 65.5',
                suffixText: 'kg',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'fitness_center',
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              onChanged: (value) {
                setState(() {
                  _weightKg = double.tryParse(value);
                  _hasUnsavedChanges = true;
                });
              },
            ),
            // BMI Preview
            if (_heightCm != null &&
                _weightKg != null &&
                _heightCm! > 0 &&
                _weightKg! > 0) ...[
              SizedBox(height: 3.h),
              _buildBMIPreview(),
            ],
            SizedBox(height: 2.h),
            _buildInfoTip(
                'Height and weight help us calculate your BMI and personalize calorie goals.'),
          ],
        ),
      ),
    );
  }

  Widget _buildBMIPreview() {
    final heightM = _heightCm! / 100;
    final bmi = _weightKg! / (heightM * heightM);
    String category;
    Color categoryColor;

    if (bmi < 18.5) {
      category = 'Underweight';
      categoryColor = Colors.orange;
    } else if (bmi < 25) {
      category = 'Normal';
      categoryColor = Theme.of(context).colorScheme.primary;
    } else if (bmi < 30) {
      category = 'Overweight';
      categoryColor = Colors.orange;
    } else {
      category = 'Obese';
      categoryColor = Theme.of(context).colorScheme.error;
    }

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              bmi.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: categoryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your BMI',
                  style: Theme.of(context).textTheme.bodySmall),
              Text(
                category,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────── Step 4: Diseases ───────────────────

  Widget _buildDiseasesStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader('medical_services', 'Medical Conditions'),
            SizedBox(height: 1.h),
            Text(
              'Select any conditions that apply to you. This helps us identify foods to avoid.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 2.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: _diseaseOptions.map((disease) {
                final isSelected = _selectedDiseases.contains(disease);
                return FilterChip(
                  label: Text(disease),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (disease == 'None') {
                        _selectedDiseases = selected ? ['None'] : [];
                      } else {
                        _selectedDiseases.remove('None');
                        if (selected) {
                          _selectedDiseases.add(disease);
                        } else {
                          _selectedDiseases.remove(disease);
                        }
                      }
                      _hasUnsavedChanges = true;
                    });
                  },
                  selectedColor: Theme.of(context).colorScheme.error
                      .withValues(alpha: 0.15),
                  checkmarkColor: Theme.of(context).colorScheme.error,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 2.h),
            _buildInfoTip(
                'We\'ll flag foods that could be harmful based on your conditions.'),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Step 5: Allergies ───────────────────

  Widget _buildAllergiesStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: AllergySelectionWidget(
        selectedAllergies: _selectedAllergies,
        onAllergyChanged: (allergies) {
          setState(() {
            _selectedAllergies = allergies;
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  // ─────────────────── Step 6: Goals & Diet ───────────────────

  Widget _buildGoalsAndDietStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        children: [
          HealthGoalDropdownWidget(
            selectedGoal: _selectedHealthGoal,
            onGoalChanged: (goal) {
              setState(() {
                _selectedHealthGoal = goal;
                _hasUnsavedChanges = true;
              });
            },
          ),
          SizedBox(height: 2.h),
          DietaryPreferencesWidget(
            selectedPreferences: _selectedDietaryPreferences,
            onPreferencesChanged: (preferences) {
              setState(() {
                _selectedDietaryPreferences = preferences;
                _hasUnsavedChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────── Bottom Actions ───────────────────

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                    SizedBox(width: 2.w),
                    const Text('Back'),
                  ],
                ),
              ),
            ),
          if (_currentStep > 1) SizedBox(width: 4.w),
          Expanded(
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
                          Theme.of(context).colorScheme.onPrimary,
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
                          color: Theme.of(context).colorScheme.onPrimary,
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

  // ─────────────────── Helper Widgets ───────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildStepHeader(String iconName, String title) {
    return Row(
      children: [
        CustomIconWidget(
          iconName: iconName,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTip(String text) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomIconWidget(
            iconName: 'info',
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
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
    _heightController.dispose();
    _weightController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
