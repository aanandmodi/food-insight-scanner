// lib/presentation/product_details/widgets/action_bar_widget.dart

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_design_system.dart';

class ActionBarWidget extends StatelessWidget {
  final Map<String, dynamic> productData;
  final VoidCallback? onAddToDietLog;

  const ActionBarWidget({
    super.key,
    required this.productData,
    this.onAddToDietLog,
  });

  void _addToDietLog(BuildContext context) {
    if (onAddToDietLog != null) {
      onAddToDietLog!();
    }
  }

  void _shareProduct(BuildContext context) {
    Fluttertoast.showToast(
      msg: "Product shared successfully",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FoodInsightColors.scannerGreen,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: FoodInsightColors.outlineGray,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Share button
            GestureDetector(
              onTap: () => _shareProduct(context),
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: FoodInsightColors.warmWhite,
                  borderRadius: FoodInsightRadius.smAll,
                  border: Border.all(
                    color: FoodInsightColors.outlineGray,
                  ),
                ),
                child: Icon(Icons.share_rounded, color: FoodInsightColors.deepCharcoal),
              ),
            ),
            SizedBox(width: 4.w),
            // Add to Diet Log button
            Expanded(
              child: GestureDetector(
                onTap: () => _addToDietLog(context),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 3.5.w),
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
                      Icon(Icons.add_rounded, color: Colors.white),
                      SizedBox(width: 2.w),
                      Text(
                        'Add to Diet Log',
                        style: FoodInsightTypography.heading(size: 15, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
