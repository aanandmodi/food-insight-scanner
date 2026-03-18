import 'package:flutter/material.dart';
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
  
  // User Profile Data for AI
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
      final entries = await FirestoreService().getDietLog(dateString);
      
      // Load user profile for goals
      final profile = await FirestoreService().getUserProfile();
      final prefs = await SharedPreferences.getInstance();
      
      // Default goals if not set
      int calGoal = 2000;
      int proteinGoal = 150;
      
      // Simple logic to adjust goals based on profile (could be more complex)
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

      // Calculate totals
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
            'sugarGoal': 50, // Fixed sugar goal for now
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
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _deleteEntry(String id) async {
    try {
      await FirestoreService().deleteDietEntry(id);
      _loadData(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting entry: $e')),
      );
    }
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
    // Group entries by meal type
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
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Diet Log',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
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
          ? const Center(child: CircularProgressIndicator())
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
                         style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       IconButton(
                         icon: const Icon(Icons.chevron_right),
                         onPressed: () => _changeDate(1),
                       ),
                     ],
                   ),
                   SizedBox(height: 2.h),
                   
                   // Summary Card
                   NutritionSummaryCard(nutritionData: _nutritionSummary),
                   SizedBox(height: 3.h),
                   
                   // Generate Plan Button
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       onPressed: _generatePlanForTomorrow,
                       icon: const Icon(Icons.auto_awesome, color: Colors.white),
                       label: const Text('Generate Plan for Tomorrow'),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.lightTheme.colorScheme.secondary,
                         foregroundColor: Colors.white,
                         padding: EdgeInsets.symmetric(vertical: 1.5.h),
                       ),
                     ),
                   ),
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
                             style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                               fontWeight: FontWeight.bold,
                               color: AppTheme.lightTheme.colorScheme.primary,
                             ),
                           ),
                         ),
                         ...meals.map((meal) => _buildMealTile(meal)),
                         SizedBox(height: 1.h),
                       ],
                     );
                   }),
                   
                   if (_dietEntries.isEmpty)
                     Padding(
                       padding: EdgeInsets.only(top: 5.h),
                       child: Column(
                         children: [
                           Icon(Icons.restaurant_menu, size: 10.w, color: Colors.grey[300]),
                           SizedBox(height: 1.h),
                           Text(
                             'No meals logged for this day.',
                             style: TextStyle(color: Colors.grey[500]),
                           ),
                         ],
                       ),
                     ),
                   
                   SizedBox(height: 10.h),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           Navigator.pushNamed(context, '/barcode-scanner');
        },
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMealTile(Map<String, dynamic> meal) {
    return Dismissible(
      key: Key(meal['id'] ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 4.w),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteEntry(meal['id']),
      child: Card(
        margin: EdgeInsets.only(bottom: 1.h),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: ListTile(
          title: Text(
            meal['name'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${meal['brand'] ?? 'Unknown'} • ${meal['calories']} kcal',
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(meal['protein'] as num).toStringAsFixed(1)}g P',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                '${(meal['sugar'] as num).toStringAsFixed(1)}g S',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
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
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(5.w),
        child: Column(
          children: [
            Container(
              width: 10.w,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Recommended Plan for Tomorrow',
              style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTheme.colorScheme.secondary,
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : ListView(
                          controller: controller,
                          children: [
                             Text(
                               _plan?['summary'] ?? '',
                               style: const TextStyle(fontStyle: FontStyle.italic),
                             ),
                             SizedBox(height: 2.h),
                             ...(_plan?['meals'] as List? ?? []).map((meal) {
                               return Card(
                                 margin: EdgeInsets.only(bottom: 2.h),
                                 color: Colors.green[50],
                                 child: ListTile(
                                   leading: CircleAvatar(
                                     backgroundColor: Colors.white,
                                     child: Text(
                                       (meal['type'] as String)[0],
                                       style: TextStyle(color: Colors.green[800]),
                                     ),
                                   ),
                                   title: Text(
                                     meal['type'] ?? 'Meal',
                                     style: const TextStyle(fontWeight: FontWeight.bold),
                                   ),
                                   subtitle: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(meal['name'] ?? ''),
                                       Text(
                                         meal['description'] ?? '',
                                         style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                       ),
                                     ],
                                   ),
                                   trailing: Text(
                                     '${meal['calories']} kcal',
                                     style: const TextStyle(fontWeight: FontWeight.bold),
                                   ),
                                 ),
                               );
                             }),
                             SizedBox(height: 2.h),
                             Container(
                               padding: EdgeInsets.all(3.w),
                               decoration: BoxDecoration(
                                 color: Colors.blue[50],
                                 borderRadius: BorderRadius.circular(10),
                               ),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceAround,
                                 children: [
                                   Text('Total Calories: ${_plan?['totalCalories']}'),
                                   Text('Protein: ${_plan?['totalProtein']}g'),
                                 ],
                               ),
                             )
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
