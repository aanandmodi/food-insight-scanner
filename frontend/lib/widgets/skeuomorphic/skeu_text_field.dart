import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';

/// Sunken inset text field — looks carved into the surface.
class SkeuTextField extends StatefulWidget {
  final String hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const SkeuTextField({
    super.key,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  State<SkeuTextField> createState() => _SkeuTextFieldState();
}

class _SkeuTextFieldState extends State<SkeuTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: FoodInsightAnimations.fast,
      curve: FoodInsightAnimations.spring,
      decoration: BoxDecoration(
        color: _focused ? Colors.white : const Color(0xFFEEEAE2),
        borderRadius: FoodInsightRadius.lgAll,
        boxShadow:
            _focused ? FoodInsightShadows.raisedCard : FoodInsightShadows.inset,
        border: Border.all(
          color: _focused
              ? FoodInsightColors.scannerGreen
              : FoodInsightColors.embossedShadow,
          width: _focused ? 1.5 : 1.0,
        ),
      ),
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: TextField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          focusNode: widget.focusNode,
          style: FoodInsightTypography.body(),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                FoodInsightTypography.body(color: FoodInsightColors.midGray),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon,
                    color: FoodInsightColors.midGray, size: 20)
                : null,
            suffixIcon: widget.suffixIcon != null
                ? GestureDetector(
                    onTap: widget.onSuffixTap,
                    child: Icon(widget.suffixIcon,
                        color: FoodInsightColors.midGray, size: 20),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }
}
