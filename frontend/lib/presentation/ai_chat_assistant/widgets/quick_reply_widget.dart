import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_design_system.dart';

class QuickReplyWidget extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionTap;

  const QuickReplyWidget({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return suggestions.isNotEmpty
        ? Container(
            height: 5.6.h,
            margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => SizedBox(width: 2.w),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => onSuggestionTap(suggestions[index]),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: FoodInsightShadows.subtleCard,
                    ),
                    child: Center(
                      child: Text(
                        suggestions[index],
                        style: FoodInsightTypography.caption(
                          size: 12,
                          weight: FontWeight.w700,
                          color: FoodInsightColors.scannerGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        : const SizedBox.shrink();
  }
}
