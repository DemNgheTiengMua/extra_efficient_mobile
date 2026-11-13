import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../theme/signage_theme.dart';
import '../../widgets/signage_primitives.dart';
import '../auth/auth_provider.dart';
import '../context/learner_context_provider.dart';

/// Account tab with signed-in learner details, active Certificate switcher,
/// and Sign Out action.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isSwitching = false;
  String? _errorMessage;

  Future<void> _switchCertificate(String code) async {
    setState(() {
      _isSwitching = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(learnerContextProvider.notifier)
          .switchActiveCertificate(code);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = extractApiError(
            e,
            fallback: 'Could not switch certificate',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final contextAsync = ref.watch(learnerContextProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_errorMessage != null) ...[
          PlacardAlert(
            variant: PlacardAlertVariant.danger,
            title: _errorMessage!,
          ),
          const SizedBox(height: 12),
        ],
        PlacardPanel(
          title: 'LEARNER PROFILE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.fullName ?? 'Learner',
                style: SignageTypography.condensedSentence(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: SignageTypography.data(
                  fontSize: 13,
                  color: SignageColors.inkMuted,
                ),
              ),
              const SizedBox(height: 10),
              PlacardBadge(
                label: (user?.emailVerified ?? false)
                    ? 'EMAIL VERIFIED'
                    : 'UNVERIFIED',
                variant: (user?.emailVerified ?? false)
                    ? PlacardBadgeVariant.success
                    : PlacardBadgeVariant.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'ACTIVE CERTIFICATE',
          trailing: PlacardButton(
            key: const Key('refresh-context-button'),
            label: 'REFRESH',
            variant: PlacardButtonVariant.secondary,
            expand: false,
            onPress: _isSwitching
                ? null
                : () => ref
                    .read(learnerContextProvider.notifier)
                    .refreshContext(),
          ),
          child: contextAsync.when(
            loading: () => const Text('Loading certificates...'),
            error: (err, _) => PlacardAlert(
              variant: PlacardAlertVariant.danger,
              title: extractApiError(err, fallback: 'Failed to load context'),
            ),
            data: (ctx) {
              if (ctx == null) {
                return const Text('No active context.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < ctx.certificates.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _CertificateTile(
                      key: Key('cert-option-${ctx.certificates[i].code}'),
                      code: ctx.certificates[i].code,
                      name: ctx.certificates[i].name,
                      sectionNoun: ctx.certificates[i].sectionNoun,
                      selected: ctx.certificates[i].code == ctx.active.code,
                      enabled: !_isSwitching,
                      onTap: () => _switchCertificate(ctx.certificates[i].code),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        PlacardButton(
          key: const Key('sign-out-button'),
          label: 'SIGN OUT',
          variant: PlacardButtonVariant.destructive,
          onPress: () async {
            await ref.read(authNotifierProvider.notifier).signOut();
          },
        ),
      ],
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({
    super.key,
    required this.code,
    required this.name,
    required this.sectionNoun,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String code;
  final String name;
  final String sectionNoun;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? SignageColors.ink : SignageColors.paper;
    final fg = selected ? SignageColors.paper : SignageColors.ink;
    final subFg =
        selected ? SignageColors.bandInkMuted : SignageColors.inkMuted;

    return FTappable(
      onPress: enabled && !selected ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: SignageColors.ink, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: SignageTypography.label(fontSize: 13, color: fg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: SignageTypography.body(fontSize: 14, color: subFg),
                    ),
                  ],
                ),
              ),
              if (selected)
                const PlacardBadge.info('ACTIVE')
              else
                PlacardBadge.muted(sectionNoun),
            ],
          ),
        ),
      ),
    );
  }
}
