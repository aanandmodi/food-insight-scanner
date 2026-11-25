import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/input_validators.dart';
import '../../services/auth_service.dart';
import '../../services/data_export_service.dart';
import '../../theme/app_design_system.dart';
import '../../widgets/password_strength_meter.dart';

/// Opens a dedicated Forgot Password modal with non-enumerating feedback.
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  String initialEmail = '',
  Future<void> Function(String email)? onSendResetOverride,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(
      initialEmail: initialEmail,
      onSendResetOverride: onSendResetOverride,
    ),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    this.onSendResetOverride,
  });

  final String initialEmail;
  final Future<void> Function(String email)? onSendResetOverride;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _submitting = false;
  bool _sent = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final email = _emailController.text.trim();
    try {
      if (widget.onSendResetOverride != null) {
        await widget.onSendResetOverride!(email);
      } else {
        await AuthService().sendPasswordResetEmail(email);
      }
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      // Never disclose whether an email address is registered.
      if (e.code == 'user-not-found') {
        if (mounted) setState(() => _sent = true);
      } else if (mounted) {
        setState(() => _errorText = e.message);
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = AuthService.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Reset Password'),
      content: _sent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.mark_email_read_rounded,
                  color: FoodInsightColors.scannerGreen,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'If an account exists for ${_emailController.text.trim()}, a password reset link has been sent. Please check your inbox and spam folder.',
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the email address for your account to receive a password reset link.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: InputValidators.validateEmail,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText!,
                      style: FoodInsightTypography.caption(
                        color: FoodInsightColors.healthRed,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(_sent ? 'Done' : 'Cancel'),
        ),
        if (!_sent)
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: FoodInsightColors.scannerGreen,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Send Reset Link'),
          ),
      ],
    );
  }
}

/// Opens an in-app Change Password dialog enforcing current-password reauth and strong rules.
Future<bool> showChangePasswordDialog(
  BuildContext context, {
  Future<void> Function(String currentPassword, String newPassword)?
      onChangePasswordOverride,
  String? emailOverride,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => _ChangePasswordDialog(
          onChangePasswordOverride: onChangePasswordOverride,
          emailOverride: emailOverride,
        ),
      ) ??
      false;
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    this.onChangePasswordOverride,
    this.emailOverride,
  });

  final Future<void> Function(String currentPassword, String newPassword)?
      onChangePasswordOverride;
  final String? emailOverride;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      if (widget.onChangePasswordOverride != null) {
        await widget.onChangePasswordOverride!(
          _currentController.text,
          _newController.text,
        );
      } else {
        await AuthService().changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _errorText = AuthService.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountEmail =
        widget.emailOverride ?? AuthService().currentUser?.email;
    return AlertDialog(
      scrollable: true,
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current Password',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please enter your current password'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: _obscureNew,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'New Password',
                hintText: '8+ chars with upper, lower, digit & symbol',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  icon: Icon(
                    _obscureNew
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              validator: (value) => InputValidators.validateStrongPassword(
                value,
                disallowMatch: _currentController.text,
                email: accountEmail,
              ),
            ),
            const SizedBox(height: 10),
            PasswordStrengthMeter(password: _newController.text),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              validator: (value) => value != _newController.text
                  ? 'Passwords do not match'
                  : null,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: FoodInsightTypography.caption(
                  color: FoodInsightColors.healthRed,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Update Password'),
        ),
      ],
    );
  }
}

/// Opens a GDPR/DPDP portable JSON/CSV export modal for the current user's data.
Future<void> showDataExportDialog(
  BuildContext context, {
  Future<UserExportBundle> Function()? onCollectOverride,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _DataExportDialog(onCollectOverride: onCollectOverride),
  );
}

class _DataExportDialog extends StatefulWidget {
  const _DataExportDialog({this.onCollectOverride});

  final Future<UserExportBundle> Function()? onCollectOverride;

  @override
  State<_DataExportDialog> createState() => _DataExportDialogState();
}

class _DataExportDialogState extends State<_DataExportDialog> {
  ExportFormat _format = ExportFormat.json;
  bool _loading = true;
  bool _saving = false;
  UserExportBundle? _bundle;
  String? _error;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = widget.onCollectOverride != null
          ? await widget.onCollectOverride!()
          : await DataExportService.collectCurrentUserData();
      if (mounted) {
        setState(() {
          _bundle = bundle;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not prepare your export: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    final bundle = _bundle;
    if (bundle == null) return;
    await Clipboard.setData(
      ClipboardData(text: bundle.toFormattedString(_format)),
    );
    if (mounted) {
      setState(() => _statusMessage = 'Export copied to clipboard.');
    }
  }

  Future<void> _saveToFile() async {
    final bundle = _bundle;
    if (bundle == null || _saving) return;
    setState(() => _saving = true);
    try {
      final file = await DataExportService.writeExportFile(
        content: bundle.toFormattedString(_format),
        format: _format,
      );
      if (mounted) {
        setState(() => _statusMessage = 'Saved to ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not save file: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final formatted = bundle?.toFormattedString(_format) ?? '';
    final preview = formatted.length > 600
        ? '${formatted.substring(0, 600)}\n…'
        : formatted;

    return AlertDialog(
      scrollable: true,
      title: const Text('Export Your Data'),
      content: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? Text(_error!)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bundle!.dietEntries.length} meals · ${bundle.scans.length} scans · ${bundle.shoppingItems.length} shopping items',
                      style: FoodInsightTypography.caption(
                        weight: FontWeight.w700,
                        color: FoodInsightColors.deepCharcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Full JSON'),
                          selected: _format == ExportFormat.json,
                          onSelected: (_) => setState(() {
                            _format = ExportFormat.json;
                            _statusMessage = null;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Diet Logs CSV'),
                          selected: _format == ExportFormat.dietCsv,
                          onSelected: (_) => setState(() {
                            _format = ExportFormat.dietCsv;
                            _statusMessage = null;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Scan History CSV'),
                          selected: _format == ExportFormat.scansCsv,
                          onSelected: (_) => setState(() {
                            _format = ExportFormat.scansCsv;
                            _statusMessage = null;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 160),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FoodInsightColors.warmWhite,
                        borderRadius: FoodInsightRadius.smAll,
                        border: Border.all(
                          color: FoodInsightColors.outlineGray,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          preview,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _statusMessage!,
                        style: FoodInsightTypography.caption(
                          size: 12,
                          weight: FontWeight.w600,
                          color: FoodInsightColors.scannerGreenDark,
                        ),
                      ),
                    ],
                  ],
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!_loading && _error == null) ...[
          OutlinedButton.icon(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _saveToFile,
            style: FilledButton.styleFrom(
              backgroundColor: FoodInsightColors.scannerGreen,
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Save File'),
          ),
        ],
      ],
    );
  }
}
