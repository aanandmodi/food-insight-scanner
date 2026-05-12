import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_design_system.dart';
import '../../../widgets/skeuomorphic/skeu_card.dart';

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
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Quick Actions',
              style: FoodInsightTypography.heading(
                size: 18,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SkeuActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan\nBarcode',
                  color: FoodInsightColors.scannerGreen,
                  onTap: onScanBarcode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SkeuActionTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Upload\nImage',
                  color: FoodInsightColors.infoBlue,
                  onTap: onUploadImage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SkeuActionTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI\nAssistant',
                  color: FoodInsightColors.purpleAccent,
                  onTap: onChatWithAI,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual skeuomorphic action tile with press animation
class _SkeuActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SkeuActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SkeuActionTile> createState() => _SkeuActionTileState();
}

class _SkeuActionTileState extends State<_SkeuActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
        child: SkeuCard(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          borderRadius: 20,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              widget.color.withValues(alpha: 0.05),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with colored background circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: FoodInsightTypography.caption(
                  size: 11,
                  weight: FontWeight.w700,
                  color: FoodInsightColors.deepCharcoal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
