import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../auth_provider.dart';
import 'auth_page_frame.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final msg = await ref
          .read(authNotifierProvider.notifier)
          .forgotPassword(email: _emailController.text);
      if (mounted) {
        setState(() => _successMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = extractApiError(e, fallback: 'Request failed');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final msg = await ref.read(authNotifierProvider.notifier).resetPassword(
            token: _tokenController.text,
            newPassword: _newPasswordController.text,
          );
      if (mounted) {
        setState(() => _successMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = extractApiError(e, fallback: 'Reset failed');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      screenTitle: 'PASSWORD RECOVERY',
      panelTitle: 'FORGOT & RESET PASSWORD',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            PlacardAlert(
              variant: PlacardAlertVariant.danger,
              title: _errorMessage!,
            ),
            const SizedBox(height: 12),
          ],
          if (_successMessage != null) ...[
            PlacardAlert(
              variant: PlacardAlertVariant.success,
              title: _successMessage!,
            ),
            const SizedBox(height: 12),
          ],
          FTextField.email(
            control: FTextFieldControl.managed(controller: _emailController),
            label: Text('ACCOUNT EMAIL', style: SignageTypography.label()),
            hint: 'learner@demo.local',
          ),
          const SizedBox(height: 12),
          PlacardButton(
            key: const Key('forgot-password-submit-button'),
            label: 'SEND RESET TOKEN',
            isLoading: _isSubmitting,
            onPress: _sendReset,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: SignageColors.lineSoft),
          const SizedBox(height: 16),
          FTextField(
            control: FTextFieldControl.managed(controller: _tokenController),
            label: Text('RESET TOKEN', style: SignageTypography.label()),
            hint: 'Paste reset token',
          ),
          const SizedBox(height: 12),
          FTextField.password(
            control:
                FTextFieldControl.managed(controller: _newPasswordController),
            label: Text('NEW PASSWORD', style: SignageTypography.label()),
            hint: 'Enter new password',
          ),
          const SizedBox(height: 16),
          PlacardButton(
            key: const Key('reset-password-submit-button'),
            label: 'RESET PASSWORD',
            variant: PlacardButtonVariant.ink,
            isLoading: _isSubmitting,
            onPress: _resetPassword,
          ),
          const SizedBox(height: 12),
          PlacardButton(
            key: const Key('back-to-sign-in-button'),
            label: 'BACK TO SIGN IN',
            variant: PlacardButtonVariant.secondary,
            onPress: () => context.go('/sign-in'),
          ),
        ],
      ),
    );
  }
}
