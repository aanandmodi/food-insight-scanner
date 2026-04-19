// lib/presentation/shopping_list/shopping_list_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../services/firestore_service.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _firestoreService.getShoppingList();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shopping list: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleItem(String id, bool checked) async {
    HapticFeedback.lightImpact();
    try {
      await _firestoreService.toggleShoppingItem(id, checked);
      setState(() {
        final idx = _items.indexWhere((item) => item['id'] == id);
        if (idx != -1) {
          _items[idx]['checked'] = checked;
        }
      });
    } catch (e) {
      debugPrint('Error toggling item: $e');
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await _firestoreService.deleteShoppingItem(id);
      setState(() {
        _items.removeWhere((item) => item['id'] == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting item: $e');
    }
  }

  Future<void> _clearChecked() async {
    final checkedCount = _items.where((i) => i['checked'] == true).length;
    if (checkedCount == 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : null,
        title: const Text('Clear Checked Items'),
        content: Text('Remove $checkedCount checked item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.clearCheckedShoppingItems();
        _loadItems();
      } catch (e) {
        debugPrint('Error clearing items: $e');
      }
    }
  }

  Future<void> _addCustomItem() async {
    final nameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : null,
        title: const Text('Add Item'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'e.g. Organic Almonds',
          ),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, nameController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _firestoreService.addShoppingItem({
          'name': result,
          'brand': '',
          'category': 'Custom',
        });
        _loadItems();
      } catch (e) {
        debugPrint('Error adding item: $e');
      }
    }
    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final uncheckedItems =
        _items.where((i) => i['checked'] != true).toList();
    final checkedItems =
        _items.where((i) => i['checked'] == true).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Shopping List',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (checkedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: 'Clear checked',
              onPressed: _clearChecked,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _items.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  color: colorScheme.primary,
                  child: ListView(
                    padding: EdgeInsets.all(4.w),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (uncheckedItems.isNotEmpty) ...[
                        Text(
                          'To Buy (${uncheckedItems.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ).animate().fadeIn(duration: 400.ms),
                        SizedBox(height: 1.h),
                        ...uncheckedItems.asMap().entries.map((e) =>
                            _buildItemTile(context, e.value)
                                .animate()
                                .fadeIn(
                                    duration: 400.ms,
                                    delay: Duration(
                                        milliseconds:
                                            (e.key * 50).clamp(0, 300)))
                                .slideY(begin: 0.03, end: 0)),
                      ],
                      if (checkedItems.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          'Completed (${checkedItems.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ).animate().fadeIn(duration: 400.ms),
                        SizedBox(height: 1.h),
                        ...checkedItems
                            .map((item) => _buildItemTile(context, item)),
                      ],
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
      floatingActionButton: GlowButton(
        glowColor: colorScheme.primary,
        glowIntensity: isDark ? 0.25 : 0.1,
        onTap: _addCustomItem,
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
                'Add Item',
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 15.w,
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 2.h),
          Text(
            'Your shopping list is empty',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Add items from product scans or manually',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isChecked = item['checked'] == true;
    final id = item['id'] as String;

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 4.w),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(id),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: isDark
                  ? AppTheme.glassmorphicDecoration(borderRadius: 12)
                  : BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
              child: CheckboxListTile(
                value: isChecked,
                onChanged: (value) => _toggleItem(id, value ?? false),
                title: Text(
                  item['name'] ?? 'Unknown Item',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    decoration:
                        isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: (item['brand'] != null &&
                        item['brand'].toString().isNotEmpty)
                    ? Text(
                        item['brand'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                activeColor: colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
