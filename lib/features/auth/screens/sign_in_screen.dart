import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../auth_provider.dart';
import 'auth_page_frame.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            email: email,
            password: password,
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = extractApiError(e, fallback: 'Sign in failed');
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
      screenTitle: 'SIGN IN',
      panelTitle: 'LEARNER SIGN IN',
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
          FTextField.email(
            key: const Key('sign-in-email-field'),
            control: FTextFieldControl.managed(controller: _emailController),
            label: Text(
              'EMAIL',
              style: SignageTypography.label(),
            ),
            hint: 'learner@demo.local',
          ),
          const SizedBox(height: 12),
          FTextField.password(
            key: const Key('sign-in-password-field'),
            control: FTextFieldControl.managed(controller: _passwordController),
            label: Text(
              'PASSWORD',
              style: SignageTypography.label(),
            ),
            hint: 'Enter your password',
          ),
          const SizedBox(height: 16),
          PlacardButton(
            key: const Key('sign-in-submit-button'),
            label: 'SIGN IN',
            isLoading: _isSubmitting,
            onPress: _submit,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: SignageColors.lineSoft),
          const SizedBox(height: 12),
          PlacardButton(
            key: const Key('go-register-button'),
            label: 'CREATE ACCOUNT',
            variant: PlacardButtonVariant.secondary,
            onPress: () => context.go('/register'),
          ),
          const SizedBox(height: 8),
          PlacardButton(
            key: const Key('go-verify-email-button'),
            label: 'VERIFY EMAIL',
            variant: PlacardButtonVariant.secondary,
            onPress: () => context.go('/verify-email'),
          ),
          const SizedBox(height: 8),
          PlacardButton(
            key: const Key('go-forgot-password-button'),
            label: 'FORGOT PASSWORD',
            variant: PlacardButtonVariant.secondary,
            onPress: () => context.go('/forgot-password'),
          ),
        ],
      ),
    );
  }
}
