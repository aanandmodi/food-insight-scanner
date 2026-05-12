import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';

/// Tactile button with physical press animation.
/// Shrinks and deepens shadow on press — feels like pushing a real button.
class SkeuButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final bool isDestructive;
  final double? width;

  const SkeuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.width,
  });

  @override
  State<SkeuButton> createState() => _SkeuButtonState();
}

class _SkeuButtonState extends State<SkeuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _shadowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _shadowAnim = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _bgColor {
    if (widget.isDestructive) return FoodInsightColors.healthRed;
    return widget.backgroundColor ?? FoodInsightColors.scannerGreen;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) async {
        await _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              width: widget.width,
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: FoodInsightRadius.lgAll,
                boxShadow: [
                  BoxShadow(
                    color:
                        _bgColor.withValues(alpha: 0.4 * _shadowAnim.value),
                    blurRadius: 20 * _shadowAnim.value,
                    offset: Offset(0, 8 * _shadowAnim.value),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
                // Glossy top sheen over solid color
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(
                        _bgColor, Colors.white, 0.15)!,
                    _bgColor,
                  ],
                  stops: const [0.0, 0.5],
                ),
              ),
              child: child,
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:
              widget.width == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (widget.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else ...[
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: widget.textColor ?? Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: FoodInsightTypography.body(
                  weight: FontWeight.w700,
                  color: widget.textColor ?? Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
