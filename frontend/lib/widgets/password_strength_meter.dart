import 'package:flutter/material.dart';

import '../core/utils/input_validators.dart';
import '../theme/app_design_system.dart';

/// Displays live password strength progress and requirement badges.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.darkSurface = false,
  });

  final String password;
  final bool darkSurface;

  @override
  Widget build(BuildContext context) {
    final strength = InputValidators.evaluatePasswordStrength(password);
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final barColor = switch (strength.level) {
      PasswordStrengthLevel.empty => FoodInsightColors.lightGray,
      PasswordStrengthLevel.weak => FoodInsightColors.healthRed,
      PasswordStrengthLevel.fair => FoodInsightColors.warningAmber,
      PasswordStrengthLevel.good => FoodInsightColors.infoBlue,
      PasswordStrengthLevel.strong => FoodInsightColors.scannerGreen,
    };

    final mutedColor =
        darkSurface ? Colors.white70 : FoodInsightColors.midGray;
    final trackColor = darkSurface
        ? Colors.white.withValues(alpha: 0.14)
        : FoodInsightColors.lightGray.withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength.progress,
                  minHeight: 6,
                  backgroundColor: trackColor,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              strength.label,
              style: FoodInsightTypography.caption(
                size: 12,
                weight: FontWeight.w700,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _RuleChip(
              label: '8+ chars',
              met: strength.hasMinLength,
              mutedColor: mutedColor,
            ),
            _RuleChip(
              label: 'A-Z',
              met: strength.hasUppercase,
              mutedColor: mutedColor,
            ),
            _RuleChip(
              label: 'a-z',
              met: strength.hasLowercase,
              mutedColor: mutedColor,
            ),
            _RuleChip(
              label: '0-9',
              met: strength.hasDigit,
              mutedColor: mutedColor,
            ),
            _RuleChip(
              label: 'Symbol',
              met: strength.hasSpecial,
              mutedColor: mutedColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({
    required this.label,
    required this.met,
    required this.mutedColor,
  });

  final String label;
  final bool met;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    const activeColor = FoodInsightColors.scannerGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: met
            ? activeColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: met
              ? activeColor.withValues(alpha: 0.5)
              : mutedColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 12,
            color: met ? activeColor : mutedColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: FoodInsightTypography.caption(
              size: 11,
              weight: FontWeight.w600,
              color: met ? activeColor : mutedColor,
            ),
          ),
        ],
      ),
    );
  }
}
