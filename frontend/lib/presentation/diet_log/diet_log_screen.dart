// lib/presentation/diet_log/diet_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../core/app_export.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../services/cloud_function_service.dart';
import '../../core/utils/user_utils.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../models/user_profile.dart';
import '../home_dashboard/widgets/nutrition_summary_card.dart';
import '../../theme/app_design_system.dart';

class DietLogScreen extends StatefulWidget {
  const DietLogScreen({super.key});

  @override
  State<DietLogScreen> createState() => _DietLogScreenState();
}

class _DietLogScreenState extends State<DietLogScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _dietEntries = [];
  Map<String, dynamic> _nutritionSummary = {
    'calories': 0,
    'caloriesGoal': 2000,
    'protein': 0,
    'proteinGoal': 150,
    'sugar': 0,
    'sugarGoal': 50,
  };
  
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final prefs = await SharedPreferences.getInstance();

      List<Map<String, dynamic>> entries = [];
      try {
        entries = await LocalDatabaseService().getDietLogByDate(dateString);
      } catch (e) {
        debugPrint('Local diet log query failed: $e');
      }

      UserProfile? profileProviderData;
      if (mounted) {
        profileProviderData = context.read<UserProfileProvider>().profile;
      }
      
      final weightKg = profileProviderData?.weightKg ?? prefs.getDouble('user_weight') ?? 70.0;
      final heightCm = profileProviderData?.heightCm ?? prefs.getDouble('user_height') ?? 170.0;
      final age = profileProviderData?.age ?? prefs.getInt('user_age') ?? 25;
      final gender = profileProviderData?.gender ?? prefs.getString('user_gender') ?? 'Male';
      final healthGoal = profileProviderData?.healthGoals ?? prefs.getString('user_health_goal') ?? '';

      final calGoal = UserUtils.calculateTDEE(
        weightKg: weightKg.toDouble(),
        heightCm: heightCm.toDouble(),
        age: age,
        gender: gender,
        healthGoal: healthGoal,
      );
      
      final proteinGoal = UserUtils.calculateProteinGoal(
        weightKg: weightKg.toDouble(),
        healthGoal: healthGoal,
      );
      
      final sugarGoal = UserUtils.calculateSugarGoal(calGoal);

      _userProfile = {
        'healthGoal': healthGoal,
        'allergies': profileProviderData?.allergies ?? prefs.getStringList('user_allergies'),
      };

      int totalCals = 0;
      double totalProtein = 0;
      double totalSugar = 0;

      for (var entry in entries) {
        totalCals += (entry['calories'] as num?)?.toInt() ?? 0;
        totalProtein += (entry['protein'] as num?)?.toDouble() ?? 0;
        totalSugar += (entry['sugar'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _dietEntries = entries;
          _nutritionSummary = {
            'calories': totalCals,
            'caloriesGoal': calGoal,
            'protein': totalProtein.round(),
            'proteinGoal': proteinGoal,
            'sugar': totalSugar.round(),
            'sugarGoal': sugarGoal,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading diet log: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeDate(int days) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _deleteEntry(String id) async {
    try {
      await LocalDatabaseService().deleteDietEntry(id);
      try {
        await FirestoreService().deleteDietEntry(id);
      } catch (_) {}
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entry deleted'),
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting entry: $e'),
            backgroundColor: FoodInsightColors.healthRed,
          ),
        );
      }
    }
  }

  Future<void> _addManualEntry() async {
    final inputController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final sugarController = TextEditingController();
    String selectedType = 'Breakfast';
    bool isAnalyzing = false;
    bool showManualFields = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Add Meal', style: FoodInsightTypography.heading(size: 20, weight: FontWeight.w800, color: FoodInsightColors.deepCharcoal)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Meal Type',
                    labelStyle: FoodInsightTypography.caption(size: 14, color: FoodInsightColors.midGray),
                    border: OutlineInputBorder(borderRadius: FoodInsightRadius.smAll),
                  ),
                  dropdownColor: Colors.white,
                  items: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.deepCharcoal))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v ?? 'Breakfast'),
                ),
                SizedBox(height: 1.5.h),
                if (isAnalyzing) ...[
                  CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
                  SizedBox(height: 2.h),
                  Text('AI is estimating nutrition facts...', style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.midGray)),
                ] else ...[
                  TextField(
                    controller: inputController,
                    decoration: InputDecoration(
                      labelText: 'What did you eat?',
                      hintText: 'e.g., 2 masala dosas and chai',
                      border: OutlineInputBorder(borderRadius: FoodInsightRadius.smAll),
                    ),
                    style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.deepCharcoal),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (errorMessage != null) ...[
                    SizedBox(height: 1.h),
                    Text(
                      errorMessage!,
                      style: FoodInsightTypography.caption(size: 12, color: FoodInsightColors.healthRed),
                    ),
                  ],
                  if (showManualFields) ...[
                    SizedBox(height: 2.h),
                    Text(
                      'Enter nutrition manually:',
                      style: FoodInsightTypography.body(size: 14, weight: FontWeight.w700, color: FoodInsightColors.deepCharcoal),
                    ),
                    SizedBox(height: 1.h),
                    TextField(
                      controller: caloriesController,
                      decoration: InputDecoration(labelText: 'Calories (kcal)', border: OutlineInputBorder(borderRadius: FoodInsightRadius.smAll)),
                      style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.deepCharcoal),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 1.h),
                    TextField(
                      controller: proteinController,
                      decoration: InputDecoration(labelText: 'Protein (g)', border: OutlineInputBorder(borderRadius: FoodInsightRadius.smAll)),
                      style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.deepCharcoal),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 1.h),
                    TextField(
                      controller: sugarController,
                      decoration: InputDecoration(labelText: 'Sugar (g)', border: OutlineInputBorder(borderRadius: FoodInsightRadius.smAll)),
                      style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.deepCharcoal),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            if (!isAnalyzing)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: FoodInsightColors.midGray)),
              ),
            if (!isAnalyzing && showManualFields)
              ElevatedButton(
                onPressed: () async {
                  final text = inputController.text.trim();
                  if (text.isEmpty) return;

                  final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
                  final entry = {
                    'name': text,
                    'mealType': selectedType,
                    'calories': int.tryParse(caloriesController.text.trim()) ?? 0,
                    'protein': double.tryParse(proteinController.text.trim()) ?? 0.0,
                    'sugar': double.tryParse(sugarController.text.trim()) ?? 0.0,
                    'fat': 0.0,
                    'carbs': 0.0,
                    'brand': 'Manual Entry',
                    'time': DateFormat('HH:mm').format(DateTime.now()),
                    'date': dateString,
                  };

                  await LocalDatabaseService().insertDietEntry(entry);
                  try {
                    await FirestoreService().saveDietEntry(entry);
                  } catch (_) {}
                  if (ctx.mounted && Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  _loadData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: FoodInsightColors.scannerGreen, shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll)),
                child: Text('Save Manual', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
              ),
            if (!isAnalyzing && !showManualFields)
              ElevatedButton(
                onPressed: () async {
                  final text = inputController.text.trim();
                  if (text.isEmpty) return;

                  setDialogState(() {
                    isAnalyzing = true;
                    errorMessage = null;
                  });

                  try {
                    final macros = await CloudFunctionService().parseMeal(text);
                    if (macros != null) {
                      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
                      final entry = {
                        'name': macros['name'] ?? text,
                        'mealType': selectedType,
                        'calories': macros['calories'] ?? 0,
                        'protein': macros['protein'] ?? 0.0,
                        'sugar': macros['sugar'] ?? 0.0,
                        'fat': macros['fat'] ?? 0.0,
                        'carbs': macros['carbs'] ?? 0.0,
                        'brand': 'AI Estimate',
                        'time': DateFormat('HH:mm').format(DateTime.now()),
                        'date': dateString,
                      };
                      
                      await FirestoreService().saveDietEntry(entry);
                      if (ctx.mounted && Navigator.canPop(ctx)) {
                        Navigator.pop(ctx);
                      }
                      _loadData();
                    } else {
                      setDialogState(() {
                        isAnalyzing = false;
                        errorMessage = 'AI could not parse the meal. Enter nutrition manually.';
                        showManualFields = true;
                      });
                    }
                  } catch (e) {
                    debugPrint('Error with AI meal parsing: $e');
                    setDialogState(() {
                      isAnalyzing = false;
                      errorMessage = 'AI unavailable. Enter nutrition manually.';
                      showManualFields = true;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: FoodInsightColors.scannerGreen, shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll)),
                child: Text('Add', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
              ),
          ],
        ),
      ),
    );
    inputController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    sugarController.dispose();
  }

  Future<void> _generatePlanForTomorrow() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AIPlanSheet(
        dailySummary: _nutritionSummary,
        userProfile: _userProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> groupedEntries = {
      'Breakfast': [],
      'Lunch': [],
      'Dinner': [],
      'Snack': [],
    };

    for (var entry in _dietEntries) {
      final type = entry['mealType'] as String? ?? 'Snack';
      if (groupedEntries.containsKey(type)) {
        groupedEntries[type]!.add(entry);
      } else {
        groupedEntries.putIfAbsent(type, () => []).add(entry);
      }
    }

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Diet Log',
          style: FoodInsightTypography.heading(
            size: 20,
            weight: FontWeight.w900,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
        centerTitle: true,
        backgroundColor: FoodInsightColors.warmWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: FoodInsightColors.deepCharcoal),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: FoodInsightColors.scannerGreen),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: FoodInsightColors.scannerGreen))
            : SingleChildScrollView(
                padding: EdgeInsets.all(5.w),
                child: Column(
                  children: [
                     // Date Selector
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         IconButton(
                           icon: Icon(Icons.chevron_left_rounded, color: FoodInsightColors.deepCharcoal),
                           onPressed: () => _changeDate(-1),
                         ),
                         Text(
                           DateFormat('EEEE, MMM d').format(_selectedDate),
                           style: FoodInsightTypography.heading(
                             size: 16,
                             weight: FontWeight.w800,
                             color: FoodInsightColors.deepCharcoal,
                           ),
                         ),
                         IconButton(
                           icon: Icon(Icons.chevron_right_rounded, color: FoodInsightColors.deepCharcoal),
                           onPressed: () => _changeDate(1),
                         ),
                       ],
                     )
                         .animate()
                         .fadeIn(duration: 400.ms),
                     SizedBox(height: 2.h),
                     
                     // Summary Card
                     NutritionSummaryCard(nutritionData: _nutritionSummary)
                         .animate()
                         .fadeIn(duration: 500.ms, delay: 100.ms)
                         .scaleXY(begin: 0.95, end: 1.0),
                     SizedBox(height: 3.h),
                     
                     // Generate Plan Button
                     GestureDetector(
                       onTap: _generatePlanForTomorrow,
                       child: Container(
                         width: double.infinity,
                         padding: EdgeInsets.symmetric(vertical: 2.h),
                         decoration: BoxDecoration(
                           gradient: FoodInsightColors.healthyGradient,
                           borderRadius: FoodInsightRadius.mdAll,
                           boxShadow: [
                             BoxShadow(
                               color: FoodInsightColors.scannerGreen.withValues(alpha: 0.3),
                               blurRadius: 10,
                               offset: const Offset(0, 4),
                             ),
                           ],
                         ),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(Icons.auto_awesome_rounded, color: Colors.white),
                             SizedBox(width: 2.w),
                             Text(
                               'Generate Plan for Tomorrow',
                               style: FoodInsightTypography.heading(
                                 size: 15,
                                 weight: FontWeight.w700,
                                 color: Colors.white,
                               ),
                             ),
                           ],
                         ),
                       ),
                     )
                         .animate()
                         .fadeIn(duration: 500.ms, delay: 200.ms),
                     SizedBox(height: 3.h),
                     
                     // Meal Sections
                     ...['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
                       final meals = groupedEntries[type]!;
                       if (meals.isEmpty) return const SizedBox.shrink();
                       
                       return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Padding(
                             padding: EdgeInsets.symmetric(vertical: 1.h),
                             child: Text(
                               type,
                               style: FoodInsightTypography.heading(
                                 size: 18,
                                 weight: FontWeight.w800,
                                 color: FoodInsightColors.scannerGreen,
                               ),
                             ),
                           ),
                           ...meals.map((meal) => _buildMealTile(context, meal)),
                           SizedBox(height: 1.h),
                         ],
                       );
                     }),
                     
                     if (_dietEntries.isEmpty) ...[
                       Padding(
                         padding: EdgeInsets.only(top: 5.h),
                         child: Column(
                           children: [
                             Container(
                               padding: EdgeInsets.all(5.w),
                               decoration: BoxDecoration(
                                 color: FoodInsightColors.scannerGreenLight,
                                 shape: BoxShape.circle,
                               ),
                               child: Icon(Icons.restaurant_menu_rounded,
                                   size: 15.w, color: FoodInsightColors.scannerGreen),
                             ),
                             SizedBox(height: 3.h),
                             Text(
                               'No meals logged yet',
                               style: FoodInsightTypography.heading(
                                 size: 20,
                                 weight: FontWeight.w800,
                                 color: FoodInsightColors.deepCharcoal,
                               ),
                             ),
                             SizedBox(height: 1.h),
                             Text(
                               'Start logging to see your summary.',
                               style: FoodInsightTypography.body(
                                 size: 15,
                                 color: FoodInsightColors.midGray,
                               ),
                             ),
                             SizedBox(height: 4.h),
                             ElevatedButton.icon(
                               onPressed: _addManualEntry,
                               icon: const Icon(Icons.add_rounded, color: Colors.white),
                               label: Text('Add Your First Meal', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: FoodInsightColors.scannerGreen,
                                 padding: EdgeInsets.symmetric(
                                     horizontal: 6.w, vertical: 1.5.h),
                                 shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.mdAll),
                               ),
                             ),
                           ],
                         ),
                       ).animate().fadeIn(delay: 200.ms),
                     ],
                     
                     SizedBox(height: 12.h),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FoodInsightColors.scannerGreen,
        onPressed: _addManualEntry,
        icon: Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Meal',
          style: FoodInsightTypography.caption(
            size: 14,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ).animate().fadeIn(delay: 300.ms),
    );
  }

  Widget _buildMealTile(BuildContext context, Map<String, dynamic> meal) {
    final protein = (meal['protein'] as num?)?.toDouble() ?? 0;
    final sugar = (meal['sugar'] as num?)?.toDouble() ?? 0;
    final calories = (meal['calories'] as num?)?.toInt() ?? 0;

    return Dismissible(
      key: Key(meal['id'] ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        decoration: BoxDecoration(
          color: FoodInsightColors.healthRed,
          borderRadius: FoodInsightRadius.mdAll,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _deleteEntry(meal['id']),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: FoodInsightRadius.mdAll,
          boxShadow: FoodInsightShadows.subtleCard,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal['name'] ?? 'Unknown',
                    style: FoodInsightTypography.body(
                      size: 16,
                      weight: FontWeight.w700,
                      color: FoodInsightColors.deepCharcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    '${meal['brand'] ?? ''} • $calories kcal',
                    style: FoodInsightTypography.caption(
                      size: 13,
                      color: FoodInsightColors.midGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${protein.toStringAsFixed(1)}g P',
                  style: FoodInsightTypography.caption(
                    size: 14,
                    weight: FontWeight.w800,
                    color: FoodInsightColors.scannerGreen,
                  ),
                ),
                Text(
                  '${sugar.toStringAsFixed(1)}g S',
                  style: FoodInsightTypography.caption(
                    size: 14,
                    weight: FontWeight.w800,
                    color: FoodInsightColors.healthRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }
}

// AI Plan Sheet Widget
class _AIPlanSheet extends StatefulWidget {
  final Map<String, dynamic> dailySummary;
  final Map<String, dynamic>? userProfile;

  const _AIPlanSheet({
    required this.dailySummary,
    this.userProfile,
  });

  @override
  State<_AIPlanSheet> createState() => _AIPlanSheetState();
}

class _AIPlanSheetState extends State<_AIPlanSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _plan;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final result = await CloudFunctionService().generateDietPlan(
        dailySummary: widget.dailySummary,
        userProfile: widget.userProfile,
      );
      if (mounted) {
        setState(() {
          if (result.containsKey('error')) {
            _error = result['error'];
          } else {
            _plan = result;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: FoodInsightColors.warmWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.all(5.w),
        child: Column(
          children: [
            Container(
              width: 12.w,
              height: 6,
              decoration: BoxDecoration(
                color: FoodInsightColors.outlineGray,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: FoodInsightColors.scannerGreen, size: 7.w),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'AI Recommended Plan',
                    style: FoodInsightTypography.heading(
                      size: 20,
                      weight: FontWeight.w900,
                      color: FoodInsightColors.deepCharcoal,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
                          SizedBox(height: 2.h),
                          Text(
                            'Generating your personal diet plan...',
                            style: FoodInsightTypography.caption(size: 14, color: FoodInsightColors.midGray),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(4.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(4.w),
                                  decoration: BoxDecoration(
                                    color: FoodInsightColors.healthRedLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.error_outline_rounded,
                                      size: 12.w,
                                      color: FoodInsightColors.healthRed),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  _error!.contains('GROQ_API_KEY')
                                      ? 'AI plan requires a Groq API key.\nAdd it in Settings.'
                                      : 'Could not generate plan.\nPlease check your internet connection.',
                                  textAlign: TextAlign.center,
                                  style: FoodInsightTypography.body(
                                    size: 15,
                                    color: FoodInsightColors.healthRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          controller: controller,
                          children: [
                             Text(
                               _plan?['summary'] ?? '',
                               style: FoodInsightTypography.body(
                                 size: 15,
                                 color: FoodInsightColors.deepCharcoal,
                               ),
                             ),
                             SizedBox(height: 3.h),
                             ...(_plan?['meals'] as List? ?? []).map((meal) {
                               final mealType = (meal['type'] as String?) ?? 'Meal';
                               return Container(
                                 margin: EdgeInsets.only(bottom: 2.h),
                                 padding: EdgeInsets.all(4.w),
                                 decoration: BoxDecoration(
                                   color: Colors.white,
                                   borderRadius: FoodInsightRadius.mdAll,
                                   boxShadow: FoodInsightShadows.subtleCard,
                                   border: Border.all(color: FoodInsightColors.scannerGreenLight, width: 1),
                                 ),
                                 child: Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Container(
                                       padding: EdgeInsets.all(2.w),
                                       decoration: BoxDecoration(
                                         color: FoodInsightColors.scannerGreenLight,
                                         shape: BoxShape.circle,
                                       ),
                                       child: Text(
                                         mealType.isNotEmpty ? mealType[0] : 'M',
                                         style: FoodInsightTypography.heading(
                                           size: 16,
                                           weight: FontWeight.w800,
                                           color: FoodInsightColors.scannerGreenDark,
                                         ),
                                       ),
                                     ),
                                     SizedBox(width: 3.w),
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             mealType,
                                             style: FoodInsightTypography.caption(
                                               size: 12,
                                               weight: FontWeight.w800,
                                               color: FoodInsightColors.scannerGreen,
                                             ),
                                           ),
                                           SizedBox(height: 0.3.h),
                                           Text(
                                             meal['name'] ?? '',
                                             style: FoodInsightTypography.body(
                                               size: 16,
                                               weight: FontWeight.w700,
                                               color: FoodInsightColors.deepCharcoal,
                                             ),
                                           ),
                                           SizedBox(height: 0.5.h),
                                           Text(
                                             meal['description'] ?? '',
                                             style: FoodInsightTypography.caption(
                                               size: 13,
                                               color: FoodInsightColors.midGray,
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                     SizedBox(width: 2.w),
                                     Text(
                                       '${meal['calories'] ?? 0} kcal',
                                       style: FoodInsightTypography.caption(
                                         size: 14,
                                         weight: FontWeight.w800,
                                         color: FoodInsightColors.scannerGreen,
                                       ),
                                     ),
                                   ],
                                 ),
                               ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
                             }),
                             SizedBox(height: 2.h),
                             Container(
                               padding: EdgeInsets.all(4.w),
                               decoration: BoxDecoration(
                                   color: FoodInsightColors.scannerGreenLight,
                                   borderRadius: FoodInsightRadius.mdAll,
                                 ),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceAround,
                                 children: [
                                   Column(
                                     children: [
                                       Text(
                                         'Total Calories',
                                         style: FoodInsightTypography.caption(size: 12, color: FoodInsightColors.scannerGreenDark),
                                       ),
                                       Text(
                                         '${_plan?['totalCalories'] ?? 0} kcal',
                                         style: FoodInsightTypography.heading(size: 18, weight: FontWeight.w800, color: FoodInsightColors.scannerGreenDark),
                                       ),
                                     ],
                                   ),
                                   Container(width: 1, height: 4.h, color: FoodInsightColors.scannerGreen.withValues(alpha: 0.3)),
                                   Column(
                                     children: [
                                       Text(
                                         'Total Protein',
                                         style: FoodInsightTypography.caption(size: 12, color: FoodInsightColors.scannerGreenDark),
                                       ),
                                       Text(
                                         '${_plan?['totalProtein'] ?? 0}g',
                                         style: FoodInsightTypography.heading(size: 18, weight: FontWeight.w800, color: FoodInsightColors.scannerGreenDark),
                                       ),
                                     ],
                                   ),
                                 ],
                               ),
                             ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.95, end: 1.0),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
