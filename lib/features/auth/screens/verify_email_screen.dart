import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../auth_provider.dart';
import 'auth_page_frame.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _tokenController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final msg = await ref
          .read(authNotifierProvider.notifier)
          .verifyEmail(token: _tokenController.text);
      if (mounted) {
        setState(() => _successMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = extractApiError(e, fallback: 'Verification failed');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final msg =
          await ref.read(authNotifierProvider.notifier).resendActivation();
      if (mounted) {
        setState(() => _successMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = extractApiError(e, fallback: 'Resend failed');
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
      screenTitle: 'VERIFY EMAIL',
      panelTitle: 'EMAIL ACTIVATION',
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
          FTextField(
            control: FTextFieldControl.managed(controller: _tokenController),
            label: Text('ACTIVATION TOKEN', style: SignageTypography.label()),
            hint: 'Paste activation token',
          ),
          const SizedBox(height: 16),
          PlacardButton(
            key: const Key('verify-email-submit-button'),
            label: 'VERIFY EMAIL',
            isLoading: _isSubmitting,
            onPress: _verify,
          ),
          const SizedBox(height: 10),
          PlacardButton(
            key: const Key('resend-activation-button'),
            label: 'RESEND ACTIVATION',
            variant: PlacardButtonVariant.secondary,
            isLoading: _isSubmitting,
            onPress: _resend,
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
