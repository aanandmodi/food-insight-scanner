// lib/presentation/shopping_list/shopping_list_screen.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../core/services/firestore_service.dart';

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
    final uncheckedItems =
        _items.where((i) => i['checked'] != true).toList();
    final checkedItems =
        _items.where((i) => i['checked'] == true).toList();

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Shopping List',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
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
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  child: ListView(
                    padding: EdgeInsets.all(4.w),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // Unchecked items
                      if (uncheckedItems.isNotEmpty) ...[
                        Text(
                          'To Buy (${uncheckedItems.length})',
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                AppTheme.lightTheme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        ...uncheckedItems
                            .map((item) => _buildItemTile(item)),
                      ],
                      // Checked items
                      if (checkedItems.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          'Completed (${checkedItems.length})',
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                AppTheme.lightTheme.colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        ...checkedItems
                            .map((item) => _buildItemTile(item)),
                      ],
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomItem,
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
        foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 15.w,
            color: AppTheme.lightTheme.disabledColor,
          ),
          SizedBox(height: 2.h),
          Text(
            'Your shopping list is empty',
            style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.lightTheme.disabledColor,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Add items from product scans or manually',
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final isChecked = item['checked'] == true;
    final id = item['id'] as String;

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(id),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        decoration: BoxDecoration(
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
            style: TextStyle(
              fontWeight: FontWeight.w500,
              decoration:
                  isChecked ? TextDecoration.lineThrough : null,
              color: isChecked ? Colors.grey : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: (item['brand'] != null &&
                  item['brand'].toString().isNotEmpty)
              ? Text(
                  item['brand'],
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
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
          activeColor: AppTheme.lightTheme.colorScheme.primary,
        ),
      ),
    );
  }
}
