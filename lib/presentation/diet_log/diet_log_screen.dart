import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_export.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/groq_service.dart';
import '../home_dashboard/widgets/nutrition_summary_card.dart';

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
        entries = await FirestoreService().getDietLog(dateString);
      } catch (e) {
        debugPrint('Firestore diet log failed: $e');
      }

      Map<String, dynamic>? profile;
      try {
        profile = await FirestoreService().getUserProfile().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('Firestore profile failed: $e');
      }
      
      int calGoal = 2000;
      int proteinGoal = 150;
      
      final healthGoal = profile?['healthGoal'] as String? ?? prefs.getString('user_health_goal');
      if (healthGoal == 'Lose Weight') calGoal = 1800;
      if (healthGoal == 'Build Muscle') {
        calGoal = 2500;
        proteinGoal = 180;
      }

      _userProfile = profile ?? {
        'healthGoal': healthGoal,
        'allergies': prefs.getStringList('user_allergies'),
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
            'sugarGoal': 50,
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
      await FirestoreService().deleteDietEntry(id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting entry: $e')),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : null,
          title: const Text('Add Meal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Meal Type'),
                  dropdownColor: isDark ? AppTheme.cardDark : null,
                  items: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v ?? 'Breakfast'),
                ),
                const SizedBox(height: 12),
                if (isAnalyzing) ...[
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text('AI is estimating nutrition facts...'),
                ] else ...[
                  TextField(
                    controller: inputController,
                    decoration: const InputDecoration(
                      labelText: 'What did you eat?',
                      hintText: 'e.g., 2 masala dosas and chai',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(color: colorScheme.error, fontSize: 12),
                    ),
                  ],
                  if (showManualFields) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Enter nutrition manually:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: caloriesController,
                      decoration: const InputDecoration(
                        labelText: 'Calories (kcal)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: proteinController,
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: sugarController,
                      decoration: const InputDecoration(
                        labelText: 'Sugar (g)',
                        border: OutlineInputBorder(),
                      ),
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
                child: const Text('Cancel'),
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

                  await FirestoreService().saveDietEntry(entry);
                  if (ctx.mounted && Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  _loadData();
                },
                child: const Text('Save Manual'),
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
                    final macros = await GroqService().parseMeal(text);
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
                child: const Text('Add'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Diet Log',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                children: [
                   // Date Selector
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       IconButton(
                         icon: const Icon(Icons.chevron_left),
                         onPressed: () => _changeDate(-1),
                       ),
                       Text(
                         DateFormat('EEEE, MMM d').format(_selectedDate),
                         style: theme.textTheme.titleMedium?.copyWith(
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       IconButton(
                         icon: const Icon(Icons.chevron_right),
                         onPressed: () => _changeDate(1),
                       ),
                     ],
                   )
                       .animate()
                       .fadeIn(duration: 400.ms),
                   SizedBox(height: 2.h),
                   
                   // Summary Card (already glassmorphic)
                   NutritionSummaryCard(nutritionData: _nutritionSummary)
                       .animate()
                       .fadeIn(duration: 500.ms, delay: 100.ms)
                       .scaleXY(begin: 0.95, end: 1.0),
                   SizedBox(height: 3.h),
                   
                   // Generate Plan Button
                   GlowButton(
                     glowColor: colorScheme.secondary,
                     glowIntensity: isDark ? 0.2 : 0.1,
                     onTap: _generatePlanForTomorrow,
                     child: Container(
                       width: double.infinity,
                       padding: EdgeInsets.symmetric(vertical: 1.5.h),
                       decoration: BoxDecoration(
                         color: colorScheme.secondary,
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.auto_awesome, color: colorScheme.onSecondary),
                           SizedBox(width: 2.w),
                           Text(
                             'Generate Plan for Tomorrow',
                             style: theme.textTheme.titleSmall?.copyWith(
                               color: colorScheme.onSecondary,
                               fontWeight: FontWeight.w600,
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
                             style: theme.textTheme.titleMedium?.copyWith(
                               fontWeight: FontWeight.bold,
                               color: colorScheme.primary,
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
                           Icon(Icons.restaurant_menu,
                               size: 10.w, color: colorScheme.onSurfaceVariant),
                           SizedBox(height: 1.h),
                           Text(
                             'No meals logged for this day.',
                             style: theme.textTheme.bodyMedium?.copyWith(
                               color: colorScheme.onSurfaceVariant,
                             ),
                           ),
                           SizedBox(height: 2.h),
                           OutlinedButton.icon(
                             onPressed: _addManualEntry,
                             icon: const Icon(Icons.add),
                             label: const Text('Add Your First Meal'),
                             style: OutlinedButton.styleFrom(
                               padding: EdgeInsets.symmetric(
                                   horizontal: 6.w, vertical: 1.5.h),
                             ),
                           ),
                         ],
                       ),
                     ),
                   ],
                   
                   SizedBox(height: 10.h),
                ],
              ),
            ),
      floatingActionButton: GlowButton(
        glowColor: colorScheme.primary,
        glowIntensity: isDark ? 0.25 : 0.1,
        onTap: _addManualEntry,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: colorScheme.onPrimary),
              SizedBox(width: 2.w),
              Text(
                'Add Meal',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealTile(BuildContext context, Map<String, dynamic> meal) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final protein = (meal['protein'] as num?)?.toDouble() ?? 0;
    final sugar = (meal['sugar'] as num?)?.toDouble() ?? 0;
    final calories = (meal['calories'] as num?)?.toInt() ?? 0;

    return Dismissible(
      key: Key(meal['id'] ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.error,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 4.w),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteEntry(meal['id']),
      child: Card(
        margin: EdgeInsets.only(bottom: 1.h),
        elevation: isDark ? 0 : 1,
        color: isDark ? AppTheme.glassDarkBg : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? AppTheme.glassDarkBorder
                : Colors.grey[200]!,
          ),
        ),
        child: ListTile(
          title: Text(
            meal['name'] ?? 'Unknown',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${meal['brand'] ?? ''} • $calories kcal',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${protein.toStringAsFixed(1)}g P',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                '${sugar.toStringAsFixed(1)}g S',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.getWarningColor(
                      theme.brightness == Brightness.light),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      final result = await GroqService().generateDietPlan(
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: isDark
                  ? Border(
                      top: BorderSide(color: AppTheme.glassDarkBorder),
                      left: BorderSide(color: AppTheme.glassDarkBorder),
                      right: BorderSide(color: AppTheme.glassDarkBorder),
                    )
                  : null,
            ),
            padding: EdgeInsets.all(5.w),
            child: Column(
              children: [
                Container(
                  width: 10.w,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Recommended Plan for Tomorrow',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
                Divider(color: isDark ? AppTheme.dividerDark : null),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(4.w),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 12.w,
                                        color: AppTheme.getWarningColor(
                                            !isDark)),
                                    SizedBox(height: 2.h),
                                    Text(
                                      _error!.contains('GROQ_API_KEY')
                                          ? 'AI plan requires a Groq API key.\nAdd it in assets/env.json'
                                          : 'Could not generate plan.\nPlease check your internet connection.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
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
                                   style: theme.textTheme.bodyMedium?.copyWith(
                                     fontStyle: FontStyle.italic,
                                     color: colorScheme.onSurfaceVariant,
                                   ),
                                 ),
                                 SizedBox(height: 2.h),
                                 ...(_plan?['meals'] as List? ?? []).map((meal) {
                                   final mealType = (meal['type'] as String?) ?? 'Meal';
                                   return Card(
                                     margin: EdgeInsets.only(bottom: 2.h),
                                     color: isDark
                                         ? colorScheme.primary.withValues(alpha: 0.1)
                                         : Colors.green[50],
                                     shape: RoundedRectangleBorder(
                                       borderRadius: BorderRadius.circular(12),
                                       side: isDark
                                           ? BorderSide(
                                               color: colorScheme.primary
                                                   .withValues(alpha: 0.2))
                                           : BorderSide.none,
                                     ),
                                     child: ListTile(
                                       leading: CircleAvatar(
                                         backgroundColor: isDark
                                             ? colorScheme.primary
                                                 .withValues(alpha: 0.2)
                                             : Colors.white,
                                         child: Text(
                                           mealType.isNotEmpty ? mealType[0] : 'M',
                                           style: TextStyle(
                                             color: colorScheme.primary,
                                           ),
                                         ),
                                       ),
                                       title: Text(
                                         mealType,
                                         style: theme.textTheme.titleSmall?.copyWith(
                                           fontWeight: FontWeight.bold,
                                         ),
                                       ),
                                       subtitle: Column(
                                         crossAxisAlignment:
                                             CrossAxisAlignment.start,
                                         children: [
                                           Text(meal['name'] ?? ''),
                                           Text(
                                             meal['description'] ?? '',
                                             style: theme.textTheme.bodySmall?.copyWith(
                                               color: colorScheme.onSurfaceVariant,
                                             ),
                                           ),
                                         ],
                                       ),
                                       trailing: Text(
                                         '${meal['calories'] ?? 0} kcal',
                                         style: theme.textTheme.labelMedium?.copyWith(
                                           fontWeight: FontWeight.bold,
                                           color: colorScheme.primary,
                                         ),
                                       ),
                                     ),
                                   );
                                 }),
                                 SizedBox(height: 2.h),
                                 ClipRRect(
                                   borderRadius: BorderRadius.circular(10),
                                   child: BackdropFilter(
                                     filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                     child: Container(
                                       padding: EdgeInsets.all(3.w),
                                       decoration: isDark
                                           ? AppTheme.glassmorphicDecoration(
                                               borderRadius: 10)
                                           : BoxDecoration(
                                               color: Colors.blue[50],
                                               borderRadius:
                                                   BorderRadius.circular(10),
                                             ),
                                       child: Row(
                                         mainAxisAlignment:
                                             MainAxisAlignment.spaceAround,
                                         children: [
                                           Text(
                                             'Total Calories: ${_plan?['totalCalories'] ?? 0}',
                                             style: theme.textTheme.bodyMedium,
                                           ),
                                           Text(
                                             'Protein: ${_plan?['totalProtein'] ?? 0}g',
                                             style: theme.textTheme.bodyMedium,
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                 ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
