import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/consent_service.dart';
import '../../theme/app_design_system.dart';
import '../../widgets/legal_consent_card.dart';
import '../settings/legal_information_screen.dart';

/// Mandatory consent gate shown when a signed-in user has not accepted
/// the current Terms of Use, Privacy Policy, or Health Data Notice.
class LegalConsentGateScreen extends StatefulWidget {
  const LegalConsentGateScreen({
    super.key,
    this.isVersionUpdate = false,
    this.onAcceptOverride,
    this.onSignOutOverride,
  });

  final bool isVersionUpdate;
  final Future<void> Function()? onAcceptOverride;
  final Future<void> Function()? onSignOutOverride;

  @override
  State<LegalConsentGateScreen> createState() => _LegalConsentGateScreenState();
}

class _LegalConsentGateScreenState extends State<LegalConsentGateScreen> {
  bool _accepted = false;
  bool _showError = false;
  bool _isSubmitting = false;

  Future<void> _handleContinue() async {
    if (_isSubmitting) return;
    if (!_accepted) {
      HapticFeedback.selectionClick();
      setState(() => _showError = true);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isSubmitting = true;
      _showError = false;
    });

    try {
      if (widget.onAcceptOverride != null) {
        await widget.onAcceptOverride!();
      } else {
        await ConsentService.instance.acceptForCurrentUser();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your consent yet. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSignOut() async {
    if (_isSubmitting) return;
    if (widget.onSignOutOverride != null) {
      await widget.onSignOutOverride!();
      return;
    }
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final consent = ConsentService.instance;
    final hasPriorConsent =
        widget.isVersionUpdate || consent.currentConsent != null;

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      body: Container(
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: FoodInsightColors.healthyGradient,
                              borderRadius: FoodInsightRadius.lgAll,
                              boxShadow: FoodInsightShadows.scannerGlow(
                                FoodInsightColors.scannerGreen,
                              ),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            hasPriorConsent
                                ? 'Updated Policies & Terms'
                                : 'Review Privacy & Terms',
                            style: FoodInsightTypography.display(
                              size: 28,
                              weight: FontWeight.w800,
                              color: FoodInsightColors.deepCharcoal,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasPriorConsent
                                ? 'We updated our Privacy Policy or Terms of Use (Terms ${consent.requiredTermsVersion}, Privacy ${consent.requiredPrivacyVersion}). Please review and confirm below to continue.'
                                : 'Before personalizing your food safety and nutrition insights, please review and accept how Food Insight handles your account and optional health data.',
                            style: FoodInsightTypography.body(
                              size: 14.5,
                              color: FoodInsightColors.midGray,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _HighlightRow(
                            icon: Icons.health_and_safety_rounded,
                            title: 'Allergies, Goals & Nutrition Logs',
                            subtitle:
                                'Used only to calculate Food Fit scores and allergen alerts for your account.',
                          ),
                          const SizedBox(height: 12),
                          const _HighlightRow(
                            icon: Icons.smart_toy_rounded,
                            title: 'Authenticated AI & Barcode Lookup',
                            subtitle:
                                'Barcodes query Open Food Facts; AI queries use bounded profile context through our backend.',
                          ),
                          const SizedBox(height: 12),
                          const _HighlightRow(
                            icon: Icons.warning_amber_rounded,
                            title: 'Not Medical Advice',
                            subtitle:
                                'Product labels can be incomplete. Always verify physical packaging for severe allergies.',
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const LegalInformationScreen(
                                        page: LegalPage.privacy,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.privacy_tip_outlined,
                                      size: 18),
                                  label: const Text('Read Privacy'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const LegalInformationScreen(
                                        page: LegalPage.terms,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.description_outlined,
                                      size: 18),
                                  label: const Text('Read Terms'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LegalConsentCard(
                            accepted: _accepted,
                            showError: _showError,
                            onChanged: (value) => setState(() {
                              _accepted = value;
                              if (value) _showError = false;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _handleContinue,
                              style: FilledButton.styleFrom(
                                backgroundColor: FoodInsightColors.scannerGreen,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: FoodInsightRadius.mdAll,
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Agree & Continue',
                                      style: FoodInsightTypography.body(
                                        size: 16,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isSubmitting ? null : _handleSignOut,
                            child: Text(
                              'Decline & Sign Out',
                              style: FoodInsightTypography.caption(
                                size: 13.5,
                                weight: FontWeight.w600,
                                color: FoodInsightColors.midGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: FoodInsightColors.scannerGreen.withValues(alpha: 0.12),
            borderRadius: FoodInsightRadius.smAll,
          ),
          child: Icon(icon, color: FoodInsightColors.scannerGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FoodInsightTypography.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: FoodInsightColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: FoodInsightTypography.caption(
                  size: 12.5,
                  color: FoodInsightColors.midGray,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
