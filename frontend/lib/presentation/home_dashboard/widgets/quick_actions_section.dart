import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/app_design_system.dart';

class QuickActionsSection extends StatelessWidget {
  final VoidCallback onScanBarcode;
  final VoidCallback onUploadImage;
  final VoidCallback onChatWithAI;

  const QuickActionsSection({
    super.key,
    required this.onScanBarcode,
    required this.onUploadImage,
    required this.onChatWithAI,
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
          // Two side-by-side action items
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
          // Full-width interactive AI card with glowing gradients
          _PremiumActionCard(
            icon: Icons.auto_awesome_rounded,
            title: 'AI Smart Chat',
            subtitle: 'Ask about recipes, safe ingredients, and health advice',
            startColor: FoodInsightColors.purpleAccent,
            endColor: const Color(0xFFBD54E0),
            onTap: onChatWithAI,
            isWide: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
  }
}

class _PremiumActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color startColor;
  final Color endColor;
  final VoidCallback onTap;
  final bool isWide;

  const _PremiumActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.startColor,
    required this.endColor,
    required this.onTap,
    this.isWide = false,
  });

  @override
  State<_PremiumActionCard> createState() => _PremiumActionCardState();
}

class _PremiumActionCardState extends State<_PremiumActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: Container(
          padding: EdgeInsets.all(widget.isWide ? 18 : 20),
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
                color: widget.startColor.withValues(alpha: 0.02),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
          ),
          child: widget.isWide ? _buildWideLayout() : _buildSquareLayout(),
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
          widget.title,
          style: FoodInsightTypography.heading(
            size: 15,
            weight: FontWeight.w800,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
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

  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildIconContainer(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: FoodInsightTypography.heading(
                  size: 15,
                  weight: FontWeight.w800,
                  color: FoodInsightColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: FoodInsightTypography.caption(
                  size: 12,
                  weight: FontWeight.w600,
                  color: FoodInsightColors.midGray,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: FoodInsightColors.midGray.withValues(alpha: 0.6),
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
            widget.startColor,
            widget.endColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.startColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
