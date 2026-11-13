import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../auth_provider.dart';
import 'auth_page_frame.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_termsAccepted) {
      setState(() => _errorMessage = 'You must accept the terms to register.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final msg = await ref.read(authNotifierProvider.notifier).register(
            fullName: _fullNameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            password: _passwordController.text,
            termsAccepted: _termsAccepted,
          );
      if (mounted) {
        setState(() => _successMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = extractApiError(e, fallback: 'Registration failed');
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
      screenTitle: 'REGISTER',
      panelTitle: 'NEW LEARNER REGISTRATION',
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
              subtitle: 'Check your email for the activation token.',
            ),
            const SizedBox(height: 12),
          ],
          FTextField(
            control: FTextFieldControl.managed(controller: _fullNameController),
            label: Text('FULL NAME', style: SignageTypography.label()),
            hint: 'Nguyen Van A',
          ),
          const SizedBox(height: 12),
          FTextField.email(
            control: FTextFieldControl.managed(controller: _emailController),
            label: Text('EMAIL', style: SignageTypography.label()),
            hint: 'name@example.com',
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: _phoneController),
            label: Text('PHONE', style: SignageTypography.label()),
            hint: '0901234567',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          FTextField.password(
            control: FTextFieldControl.managed(controller: _passwordController),
            label: Text('PASSWORD', style: SignageTypography.label()),
            hint: 'At least 8 characters',
          ),
          const SizedBox(height: 12),
          FTappable(
            key: const Key('register-terms-checkbox'),
            onPress: () => setState(() => _termsAccepted = !_termsAccepted),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _termsAccepted ? SignageColors.blueWash : SignageColors.paper,
                border: Border.all(color: SignageColors.ink, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _termsAccepted
                            ? SignageColors.ink
                            : SignageColors.paper,
                        border: Border.all(color: SignageColors.ink, width: 2),
                      ),
                      child: _termsAccepted
                          ? const Center(
                              child: Text(
                                'X',
                                style: TextStyle(
                                  color: SignageColors.paper,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I accept the learner terms and privacy policy.',
                        style: SignageTypography.body(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PlacardButton(
            key: const Key('register-submit-button'),
            label: 'REGISTER',
            isLoading: _isSubmitting,
            onPress: _submit,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PlacardButton(
                key: const Key('go-verify-email-button'),
                label: 'VERIFY EMAIL',
                variant: PlacardButtonVariant.secondary,
                expand: false,
                onPress: () => context.go('/verify-email'),
              ),
              const SizedBox(width: 8),
              PlacardButton(
                key: const Key('back-to-sign-in-button'),
                label: 'BACK TO SIGN IN',
                variant: PlacardButtonVariant.secondary,
                expand: false,
                onPress: () => context.go('/sign-in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
