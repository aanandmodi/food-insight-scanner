import '../../../widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/app_design_system.dart';

class GreetingHeader extends StatelessWidget {
  final String userName;
  final String currentDate;
  final String? photoUrl;
  final String? email;

  const GreetingHeader({
    super.key,
    required this.userName,
    required this.currentDate,
    this.photoUrl,
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    final userInitial = (email != null && email!.isNotEmpty)
        ? email![0].toUpperCase()
        : (userName.isNotEmpty ? userName[0].toUpperCase() : 'W');

    return Container(
      padding: EdgeInsets.fromLTRB(6.w, 3.h, 6.w, 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: User Avatar (Premium Skeuomorphic Ring) ──
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/settings');
            },
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color(0xFFE2E8F0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.9),
                    blurRadius: 4,
                    offset: const Offset(-2, -2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: photoUrl != null
                    ? CustomImageWidget(
                        imageUrl: photoUrl,
                        width: 54,
                        height: 54,
                        errorWidget: _buildAvatarFallback(userInitial))
                    : _buildAvatarFallback(userInitial),
              ),
            ),
          ).animate().scale(
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(width: 14),

          // ── Center: Greeting and Name ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_getGreeting()},',
                  style: FoodInsightTypography.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: FoodInsightColors.midGray,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: -0.1, end: 0),
                const SizedBox(height: 2),
                Text(
                  userName.isNotEmpty ? userName : 'Welcome',
                  style: FoodInsightTypography.display(
                    size: 24,
                    weight: FontWeight.w800,
                    color: FoodInsightColors.deepCharcoal,
                    letterSpacing: -0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideX(begin: -0.05, end: 0),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Settings stays available without implying nonexistent notifications.
          _buildSettingsButton(context).animate().scale(
                duration: 400.ms,
                delay: 200.ms,
                curve: Curves.easeOutBack,
              ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String initial) {
    return Container(
      color: FoodInsightColors.scannerGreen.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initial,
          style: FoodInsightTypography.heading(
            size: 20,
            weight: FontWeight.w800,
            color: FoodInsightColors.scannerGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) => IconButton(
    tooltip: 'Settings',
    onPressed: () => Navigator.pushNamed(context, '/settings'),
    icon: const Icon(Icons.settings_outlined, color: FoodInsightColors.deepCharcoal),
  );

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }
}
