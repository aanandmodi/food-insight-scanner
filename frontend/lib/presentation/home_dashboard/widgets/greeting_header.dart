import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_design_system.dart';

class GreetingHeader extends StatelessWidget {
  final String userName;
  final String currentDate;

  const GreetingHeader({
    super.key,
    required this.userName,
    required this.currentDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: FoodInsightTypography.caption(
                    size: 14,
                    weight: FontWeight.w500,
                    color: FoodInsightColors.midGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName.isNotEmpty ? userName : 'Welcome',
                  style: FoodInsightTypography.display(
                    size: 28,
                    weight: FontWeight.w800,
                    color: FoodInsightColors.deepCharcoal,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: FoodInsightColors.scannerGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                FoodInsightColors.scannerGreen.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentDate,
                      style: FoodInsightTypography.caption(
                        size: 12,
                        color: FoodInsightColors.midGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Premium avatar ring
          _buildAvatarRing(),
        ],
      ),
    );
  }

  Widget _buildAvatarRing() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5F0E8),
            Color(0xFFE8E2D8),
          ],
        ),
        border: Border.all(
          color: FoodInsightColors.scannerGreen.withValues(alpha: 0.4),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: FoodInsightColors.scannerGreen.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: FoodInsightTypography.heading(
            size: 20,
            weight: FontWeight.w800,
            color: FoodInsightColors.scannerGreen,
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning ☀️';
    } else if (hour < 17) {
      return 'Good Afternoon 🌤️';
    } else {
      return 'Good Evening 🌙';
    }
  }
}
