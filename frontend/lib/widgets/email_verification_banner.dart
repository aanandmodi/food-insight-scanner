import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_design_system.dart';

/// Prompts unverified password users to verify their email before using AI endpoints.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({
    super.key,
    this.emailOverride,
    this.visibleOverride,
    this.onResendOverride,
    this.onRefreshOverride,
    this.onVerified,
  });

  final String? emailOverride;
  final bool? visibleOverride;
  final Future<void> Function()? onResendOverride;
  final Future<bool> Function()? onRefreshOverride;
  final VoidCallback? onVerified;

  @override
  State<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  final AuthService _authService = AuthService();
  bool _sending = false;
  bool _checking = false;
  int _cooldownSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncCooldown() {
    final remaining = _authService.verificationResendCooldownSeconds();
    if (remaining > 0) {
      _startCooldown(remaining);
    }
  }

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleResend() async {
    if (_sending || _cooldownSeconds > 0) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    try {
      if (widget.onResendOverride != null) {
        await widget.onResendOverride!();
      } else {
        await _authService.sendEmailVerification();
      }
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification email sent to ${widget.emailOverride ?? _authService.currentUser?.email ?? 'your inbox'}.',
          ),
          backgroundColor: FoodInsightColors.scannerGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.getErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleRefresh() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() => _checking = true);
    try {
      final verified = widget.onRefreshOverride != null
          ? await widget.onRefreshOverride!()
          : await _authService.reloadUser();
      if (!mounted) return;
      if (verified) {
        widget.onVerified?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified! AI features are now unlocked.'),
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Still waiting for verification. Click the link in your email, then tap Refresh.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.getErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visibleOverride ?? _authService.needsEmailVerification;
    if (!visible) return const SizedBox.shrink();

    final email = widget.emailOverride ?? _authService.currentUser?.email ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FoodInsightColors.warningAmber.withValues(alpha: 0.1),
        borderRadius: FoodInsightRadius.mdAll,
        border: Border.all(
          color: FoodInsightColors.warningAmber.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mark_email_unread_rounded,
                color: FoodInsightColors.warningAmber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verify your email to unlock AI features',
                  style: FoodInsightTypography.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: FoodInsightColors.deepCharcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            email.isEmpty
                ? 'Barcode scanning works now. Verify your email address to enable AI Assistant and Meal Planning.'
                : 'Sent to $email. Barcode scanning works now; verify your address to enable AI Assistant and Meal Planning.',
            style: FoodInsightTypography.caption(
              size: 12.5,
              color: FoodInsightColors.midGray,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed:
                    (_sending || _cooldownSeconds > 0) ? null : _handleResend,
                icon: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  _cooldownSeconds > 0
                      ? 'Resend (${_cooldownSeconds}s)'
                      : 'Resend email',
                ),
              ),
              FilledButton.icon(
                onPressed: _checking ? null : _handleRefresh,
                style: FilledButton.styleFrom(
                  backgroundColor: FoodInsightColors.scannerGreen,
                ),
                icon: _checking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("I've Verified"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
