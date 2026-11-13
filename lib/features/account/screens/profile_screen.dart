import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../account_models.dart';
import '../account_provider.dart';

/// Learner personal profile editor and password change screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _timeZoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _hydrated = false;

  bool _isSavingProfile = false;
  String? _profileError;
  String? _profileSuccess;
  String? _fullNameFieldError;
  String? _timeZoneFieldError;

  bool _isChangingPassword = false;
  String? _passwordError;
  String? _passwordSuccess;
  String? _currentPasswordFieldError;
  String? _newPasswordFieldError;
  String? _confirmPasswordFieldError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _timeZoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _hydrateFromProfile(LearnerProfile profile) {
    if (_hydrated) return;
    _hydrated = true;
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phone ?? '';
    _timeZoneController.text = profile.timeZoneId;
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final timeZoneId = _timeZoneController.text.trim();

    setState(() {
      _fullNameFieldError =
          fullName.isEmpty ? 'Full name is required.' : null;
      _timeZoneFieldError =
          timeZoneId.isEmpty ? 'Time zone ID is required.' : null;
      _profileError = null;
      _profileSuccess = null;
    });

    if (_fullNameFieldError != null || _timeZoneFieldError != null) {
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      final updated = await ref.read(profileProvider.notifier).updateProfile(
            fullName: fullName,
            phone: _phoneController.text,
            timeZoneId: timeZoneId,
          );
      if (mounted) {
        _fullNameController.text = updated.fullName;
        _phoneController.text = updated.phone ?? '';
        _timeZoneController.text = updated.timeZoneId;
        setState(() {
          _profileSuccess = 'Profile updated.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profileError = extractApiError(
            e,
            fallback: 'Could not update profile.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _currentPasswordFieldError =
          currentPassword.isEmpty ? 'Current password is required.' : null;
      _newPasswordFieldError = newPassword.length < 8
          ? 'New password must be at least 8 characters.'
          : null;
      _confirmPasswordFieldError =
          confirmPassword != newPassword ? 'Passwords do not match.' : null;
      _passwordError = null;
      _passwordSuccess = null;
    });

    if (_currentPasswordFieldError != null ||
        _newPasswordFieldError != null ||
        _confirmPasswordFieldError != null) {
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      await ref.read(profileProvider.notifier).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _passwordSuccess = 'Password changed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _passwordError = extractApiError(
            e,
            fallback: 'Could not change password.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            PlacardButton(
              key: const Key('profile-back-button'),
              label: 'BACK',
              variant: PlacardButtonVariant.secondary,
              expand: false,
              onPress: () => context.go('/account'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'PROFILE & PASSWORD',
                style: SignageTypography.title(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'PERSONAL DETAILS',
          child: profileAsync.when(
            loading: () => const Text('Loading profile...'),
            error: (err, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlacardAlert(
                  variant: PlacardAlertVariant.danger,
                  title: extractApiError(err, fallback: 'Failed to load profile'),
                ),
                const SizedBox(height: 12),
                PlacardButton(
                  label: 'RETRY',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () =>
                      ref.read(profileProvider.notifier).refreshProfile(),
                ),
              ],
            ),
            data: (profile) {
              if (profile != null) {
                _hydrateFromProfile(profile);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_profileError != null) ...[
                    PlacardAlert(
                      variant: PlacardAlertVariant.danger,
                      title: _profileError!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_profileSuccess != null) ...[
                    PlacardAlert(
                      variant: PlacardAlertVariant.success,
                      title: _profileSuccess!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  FTextField(
                    key: const Key('profile-full-name-field'),
                    control: FTextFieldControl.managed(
                      controller: _fullNameController,
                    ),
                    label: Text('FULL NAME', style: SignageTypography.label()),
                    hint: 'Nguyen Van A',
                    error: _fullNameFieldError != null
                        ? Text(_fullNameFieldError!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  FTextField(
                    key: const Key('profile-phone-field'),
                    control: FTextFieldControl.managed(
                      controller: _phoneController,
                    ),
                    label: Text('PHONE', style: SignageTypography.label()),
                    hint: '+84901234567',
                  ),
                  const SizedBox(height: 12),
                  FTextField(
                    key: const Key('profile-timezone-field'),
                    control: FTextFieldControl.managed(
                      controller: _timeZoneController,
                    ),
                    label: Text('TIME ZONE ID', style: SignageTypography.label()),
                    hint: 'Asia/Ho_Chi_Minh',
                    error: _timeZoneFieldError != null
                        ? Text(_timeZoneFieldError!)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PlacardButton(
                    key: const Key('save-profile-button'),
                    label: 'SAVE PROFILE',
                    isLoading: _isSavingProfile,
                    onPress: _saveProfile,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'CHANGE PASSWORD',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_passwordError != null) ...[
                PlacardAlert(
                  variant: PlacardAlertVariant.danger,
                  title: _passwordError!,
                ),
                const SizedBox(height: 12),
              ],
              if (_passwordSuccess != null) ...[
                PlacardAlert(
                  variant: PlacardAlertVariant.success,
                  title: _passwordSuccess!,
                ),
                const SizedBox(height: 12),
              ],
              FTextField.password(
                key: const Key('current-password-field'),
                control: FTextFieldControl.managed(
                  controller: _currentPasswordController,
                ),
                label: Text('CURRENT PASSWORD', style: SignageTypography.label()),
                hint: 'Enter current password',
                error: _currentPasswordFieldError != null
                    ? Text(_currentPasswordFieldError!)
                    : null,
              ),
              const SizedBox(height: 12),
              FTextField.password(
                key: const Key('new-password-field'),
                control: FTextFieldControl.managed(
                  controller: _newPasswordController,
                ),
                label: Text('NEW PASSWORD', style: SignageTypography.label()),
                hint: 'At least 8 characters',
                error: _newPasswordFieldError != null
                    ? Text(_newPasswordFieldError!)
                    : null,
              ),
              const SizedBox(height: 12),
              FTextField.password(
                key: const Key('confirm-password-field'),
                control: FTextFieldControl.managed(
                  controller: _confirmPasswordController,
                ),
                label:
                    Text('CONFIRM NEW PASSWORD', style: SignageTypography.label()),
                hint: 'Re-enter new password',
                error: _confirmPasswordFieldError != null
                    ? Text(_confirmPasswordFieldError!)
                    : null,
              ),
              const SizedBox(height: 16),
              PlacardButton(
                key: const Key('change-password-button'),
                label: 'CHANGE PASSWORD',
                isLoading: _isChangingPassword,
                onPress: _changePassword,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
