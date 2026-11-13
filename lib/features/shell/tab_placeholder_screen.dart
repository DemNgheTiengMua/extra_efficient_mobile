import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/signage_theme.dart';
import '../../widgets/signage_primitives.dart';
import '../context/learner_context_provider.dart';

/// Certificate-scoped tab landing screen for `PATH`, `PRACTICE`, `EXAMS`, and `WALLET`.
class TabPlaceholderScreen extends ConsumerWidget {
  const TabPlaceholderScreen({
    super.key,
    required this.tabName,
    required this.description,
  });

  final String tabName;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(learnerContextProvider);
    final scopeVersion = ref.watch(certificateScopeVersionProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        contextAsync.when(
          loading: () => const PlacardPanel(
            title: 'LOADING CONTEXT',
            child: Text('Loading active certificate context...'),
          ),
          error: (error, _) => PlacardAlert(
            variant: PlacardAlertVariant.danger,
            title: 'Unable to load learner context',
            subtitle: error.toString(),
          ),
          data: (ctx) {
            final certName = ctx == null
                ? 'Not loaded'
                : '${ctx.active.code} — ${ctx.active.name}';
            return PlacardPanel(
              title: '$tabName WORKSPACE',
              footer: Text(
                'SCOPE VERSION: $scopeVersion',
                style: SignageTypography.data(
                  fontSize: 12,
                  color: SignageColors.inkMuted,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlacardBadge.info(ctx?.active.code ?? 'NONE'),
                  const SizedBox(height: 10),
                  Text(
                    certName,
                    style: SignageTypography.condensedSentence(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: SignageTypography.body(
                      fontSize: 15,
                      color: SignageColors.inkMuted,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
