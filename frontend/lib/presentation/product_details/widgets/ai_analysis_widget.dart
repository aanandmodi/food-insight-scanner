// lib/presentation/product_details/widgets/ai_analysis_widget.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../../theme/app_design_system.dart';

class AiAnalysisWidget extends StatelessWidget {
  final Map<String, dynamic>? aiAnalysis;

  const AiAnalysisWidget({super.key, required this.aiAnalysis});

  @override
  Widget build(BuildContext context) {
    if (aiAnalysis == null || aiAnalysis!.isEmpty) {
      return const SizedBox.shrink();
    }

    final summary = aiAnalysis!['summary'] as String? ?? '';
    final isHealthy = aiAnalysis!['isHealthy'] as bool? ?? true;
    final warnings = (aiAnalysis!['warnings'] as List?)?.cast<String>() ?? [];
    final micro = aiAnalysis!['microNutrients'] as Map<String, dynamic>?;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FoodInsightRadius.lgAll,
        boxShadow: FoodInsightShadows.subtleCard,
        border: Border.all(
          color: isHealthy ? FoodInsightColors.scannerGreen.withValues(alpha: 0.3) : FoodInsightColors.healthRed.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: FoodInsightColors.scannerGreen,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                'AI Analysis',
                style: FoodInsightTypography.heading(
                  size: 18,
                  weight: FontWeight.w800,
                  color: FoodInsightColors.deepCharcoal,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          if (summary.isNotEmpty) ...[
            Text(
              summary,
              style: FoodInsightTypography.body(
                size: 15,
                color: FoodInsightColors.midGray,
              ),
            ),
            SizedBox(height: 2.h),
          ],
          
          if (warnings.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: FoodInsightColors.healthRed.withValues(alpha: 0.1),
                borderRadius: FoodInsightRadius.mdAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_rounded, color: FoodInsightColors.healthRed, size: 16),
                      SizedBox(width: 1.w),
                      Text('Warnings', style: FoodInsightTypography.caption(size: 12, weight: FontWeight.w700, color: FoodInsightColors.healthRed)),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  ...warnings.map((w) => Padding(
                        padding: EdgeInsets.only(bottom: 0.5.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: FoodInsightColors.healthRed)),
                            Expanded(child: Text(w, style: FoodInsightTypography.caption(size: 13, color: FoodInsightColors.healthRed))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            SizedBox(height: 2.h),
          ],

          if (micro != null) ...[
            Text(
              'Micro-Nutrient Breakdown',
              style: FoodInsightTypography.heading(
                size: 15,
                weight: FontWeight.w700,
                color: FoodInsightColors.deepCharcoal,
              ),
            ),
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.5.h,
              children: [
                _buildMicroChip('Sodium', micro['sodium']),
                _buildMicroChip('Fiber', micro['fiber']),
                _buildMicroChip('Vitamins', micro['vitamins']),
                _buildMicroChip('Minerals', micro['minerals']),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMicroChip(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: FoodInsightColors.warmWhite,
        borderRadius: FoodInsightRadius.mdAll,
        border: Border.all(color: FoodInsightColors.outlineGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FoodInsightTypography.caption(size: 11, color: FoodInsightColors.midGray)),
          SizedBox(height: 0.3.h),
          Text(
            value.toString(),
            style: FoodInsightTypography.body(size: 13, weight: FontWeight.w600, color: FoodInsightColors.deepCharcoal),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
