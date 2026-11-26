import 'package:flutter/material.dart';

import '../../../services/product_report_service.dart';
import '../../../theme/app_design_system.dart';

class ReportProductSheet extends StatefulWidget {
  const ReportProductSheet({
    super.key,
    required this.barcode,
    required this.productName,
    this.onSubmit,
  });

  final String barcode;
  final String productName;
  final Future<void> Function({
    required String barcode,
    required String productName,
    required String issueType,
    required String notes,
  })? onSubmit;

  static Future<bool?> show(
    BuildContext context, {
    required String barcode,
    required String productName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FoodInsightColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReportProductSheet(
        barcode: barcode,
        productName: productName,
      ),
    );
  }

  @override
  State<ReportProductSheet> createState() => _ReportProductSheetState();
}

class _ReportProductSheetState extends State<ReportProductSheet> {
  String _selectedIssue = 'wrong_nutrition';
  final TextEditingController _notesController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final submitFn = widget.onSubmit ?? ProductReportService.submitReport;
      await submitFn(
        barcode: widget.barcode,
        productName: widget.productName,
        issueType: _selectedIssue,
        notes: _notesController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString().replaceFirst('Bad state: ', '');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report inaccurate product info',
                style: FoodInsightTypography.heading(size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.productName} · Barcode ${widget.barcode}',
                style: FoodInsightTypography.caption(
                  color: FoodInsightColors.midGray,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in ProductReportService.issueLabels.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _selectedIssue == entry.key,
                      onSelected: _submitting
                          ? null
                          : (_) => setState(() => _selectedIssue = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                enabled: !_submitting,
                maxLength: 600,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  hintText:
                      'e.g. Label shows 12g protein per 100g, or contains soy lecithin.',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: FoodInsightTypography.caption(
                    color: FoodInsightColors.healthRed,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: FoodInsightColors.scannerGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
