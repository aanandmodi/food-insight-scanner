import 'package:flutter/material.dart';

import '../presentation/settings/legal_information_screen.dart';
import '../theme/app_design_system.dart';

/// Explicit unchecked-by-default checkbox and policy links required before onboarding/auth.
class LegalConsentCard extends StatelessWidget {
  const LegalConsentCard({
    super.key,
    required this.accepted,
    required this.onChanged,
    this.showError = false,
    this.onOpenPrivacy,
    this.onOpenTerms,
    this.darkSurface = false,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final bool showError;
  final VoidCallback? onOpenPrivacy;
  final VoidCallback? onOpenTerms;
  final bool darkSurface;

  void _openPage(BuildContext context, LegalPage page) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LegalInformationScreen(page: page),
      ),
    );
  }

  void _showHealthNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Health & Nutrition Data Notice'),
        content: const SingleChildScrollView(
          child: Text(
            'Optional profile details you provide (allergies, dietary preferences, medical conditions, body metrics, and meal logs) are used solely to personalize nutrition insights and Food Fit indicators.\n\n'
            'Food Insight is not a medical device and does not replace professional medical advice. Always verify physical product packaging before eating, especially if you have a serious allergy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = showError
        ? FoodInsightColors.healthRed
        : (accepted
            ? FoodInsightColors.scannerGreen.withValues(alpha: 0.6)
            : (darkSurface
                ? Colors.white.withValues(alpha: 0.2)
                : FoodInsightColors.lightGray.withValues(alpha: 0.6)));
    final cardColor = darkSurface
        ? Colors.white.withValues(alpha: 0.08)
        : (showError
            ? FoodInsightColors.healthRed.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.85));
    final textColor =
        darkSurface ? Colors.white : FoodInsightColors.deepCharcoal;
    final subTextColor =
        darkSurface ? Colors.white70 : FoodInsightColors.midGray;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: FoodInsightRadius.mdAll,
        border: Border.all(
          color: borderColor,
          width: showError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => onChanged(!accepted),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: accepted,
                    activeColor: FoodInsightColors.scannerGreen,
                    onChanged: (val) => onChanged(val ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'I have read and agree to the Terms of Use, Privacy Policy, and processing of my optional dietary & health profile data for food insights.',
                    style: FoodInsightTypography.caption(
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _LinkChip(
                label: 'Terms of Use',
                onTap: onOpenTerms ?? () => _openPage(context, LegalPage.terms),
              ),
              _LinkChip(
                label: 'Privacy Policy',
                onTap: onOpenPrivacy ??
                    () => _openPage(context, LegalPage.privacy),
              ),
              _LinkChip(
                label: 'Health Data Notice',
                onTap: () => _showHealthNotice(context),
              ),
            ],
          ),
          if (showError) ...[
            const SizedBox(height: 6),
            Text(
              'Please check the box above to review and accept our policies before continuing.',
              style: FoodInsightTypography.caption(
                size: 12,
                weight: FontWeight.w600,
                color: FoodInsightColors.healthRed,
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Not medical advice. Always verify physical labels for severe allergies.',
              style: FoodInsightTypography.caption(
                size: 11,
                color: subTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: FoodInsightTypography.caption(
            size: 12.5,
            weight: FontWeight.w700,
            color: FoodInsightColors.infoBlue,
          ).copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}
