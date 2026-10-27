import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/apple_motion.dart';
import '../../../theme/app_design_system.dart';

class QuickActionsSection extends StatelessWidget {
  final VoidCallback onScanBarcode;
  final VoidCallback onUploadImage;
  final VoidCallback onChatWithAI;
  final VoidCallback onShoppingList;
  final bool aiChatEnabled;

  const QuickActionsSection({
    super.key,
    required this.onScanBarcode,
    required this.onUploadImage,
    required this.onChatWithAI,
    required this.onShoppingList,
    required this.aiChatEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: FoodInsightColors.scannerGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'QUICK ACTIONS',
                style: FoodInsightTypography.smallCaps(
                  size: 11,
                  weight: FontWeight.w900,
                  color: FoodInsightColors.deepCharcoal.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // First row of action items
          Row(
            children: [
              Expanded(
                child: _PremiumActionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scan Barcode',
                  subtitle: 'Scan food package',
                  startColor: FoodInsightColors.scannerGreen,
                  endColor: const Color(0xFF2EBD59),
                  onTap: onScanBarcode,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _PremiumActionCard(
                  icon: Icons.edit_calendar_rounded,
                  title: 'Log Meal',
                  subtitle: 'Manual meal logging',
                  startColor: FoodInsightColors.infoBlue,
                  endColor: const Color(0xFF2993FF),
                  onTap: onUploadImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Second row of action items
          Row(
            children: [
              Expanded(
                child: _PremiumActionCard(
                  icon: Icons.shopping_cart_rounded,
                  title: 'Shopping List',
                  subtitle: 'Manage groceries',
                  startColor: FoodInsightColors.warningAmber,
                  endColor: const Color(0xFFF09819),
                  onTap: onShoppingList,
                ),
              ),
              if (aiChatEnabled) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: _PremiumActionCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Smart Chat',
                    subtitle: 'Ask about nutrition',
                    startColor: FoodInsightColors.scannerGreen,
                    endColor: FoodInsightColors.scannerGreenDark,
                    onTap: onChatWithAI,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

class _PremiumActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color startColor;
  final Color endColor;
  final VoidCallback onTap;

  const _PremiumActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.startColor,
    required this.endColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: PressScale(
        onTap: onTap,
        scaleFactor: AppleMotion.pressScaleCard,
        pressSpring: AppleMotion.snappy,
        releaseSpring: AppleMotion.smooth,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: -2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: startColor.withValues(alpha: 0.02),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
          ),
          child: _buildSquareLayout(),
        ),
      ),
    );
  }

  Widget _buildSquareLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconContainer(),
        const SizedBox(height: 16),
        Text(
          title,
          style: FoodInsightTypography.heading(
            size: 15,
            weight: FontWeight.w800,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: FoodInsightTypography.caption(
            size: 12,
            weight: FontWeight.w600,
            color: FoodInsightColors.midGray,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildIconContainer() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            startColor,
            endColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: startColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

