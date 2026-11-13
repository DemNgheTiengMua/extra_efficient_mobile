import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/practice_models.dart';
import '../providers/practice_providers.dart';

class WeaknessAnalysisView extends ConsumerWidget {
  const WeaknessAnalysisView({super.key});

  Future<void> _resolve(WidgetRef ref, int recId) async {
    await ref.read(practiceRepositoryProvider).resolveRecommendation(recId);
    ref.invalidate(weaknessAnalysisProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weaknessAsync = ref.watch(weaknessAnalysisProvider);

    return weaknessAsync.when(
      loading: () => const Center(child: FCircularProgress()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: StateBlock(
          stamp: 'ERROR',
          title: 'Could not load weakness analysis',
          description: '$err',
          action: PlacardButton(
            label: 'RETRY',
            onPress: () => ref.invalidate(weaknessAnalysisProvider),
          ),
        ),
      ),
      data: (data) {
        if (data.sections.isEmpty &&
            data.categories.isEmpty &&
            data.recommendations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: StateBlock(
              stamp: 'EMPTY',
              title: 'No weakness data yet',
              description:
                  'Complete practice sessions or mock attempts to see accuracy breakdowns.',
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (data.sections.isNotEmpty) ...[
              _BreakdownTable(
                title: 'SECTION ACCURACY',
                rows: data.sections,
              ),
              const SizedBox(height: 16),
            ],
            if (data.categories.isNotEmpty) ...[
              _BreakdownTable(
                title: 'CATEGORY ACCURACY',
                rows: data.categories,
              ),
              const SizedBox(height: 16),
            ],
            if (data.recommendations.isNotEmpty) ...[
              Text(
                'RECOMMENDATIONS',
                style: SignageTypography.title().copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (final rec in data.recommendations) ...[
                PlacardPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rec.title,
                              style: SignageTypography.condensedSentence(
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (rec.resolved)
                            const PlacardBadge.success('RESOLVED'),
                        ],
                      ),
                      if (rec.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          rec.description!,
                          style: SignageTypography.body(
                            fontSize: 14,
                            color: SignageColors.inkMuted,
                          ),
                        ),
                      ],
                      if (!rec.resolved) ...[
                        const SizedBox(height: 12),
                        PlacardButton(
                          key: Key('resolve-rec-${rec.recId}'),
                          label: 'RESOLVE',
                          variant: PlacardButtonVariant.secondary,
                          onPress: () => _resolve(ref, rec.recId),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({required this.title, required this.rows});

  final String title;
  final List<WeaknessBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: title,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            _BreakdownRowTile(
              row: rows[i],
              showDivider: i < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _BreakdownRowTile extends StatelessWidget {
  const _BreakdownRowTile({
    required this.row,
    required this.showDivider,
  });

  final WeaknessBreakdownRow row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    if (row.isWeakest) {
      barColor = SignageColors.signGold;
    } else if (row.isStrongest) {
      barColor = SignageColors.signGreen;
    } else {
      barColor = SignageColors.signBlue;
    }

    final fraction = (row.accuracyPercent.clamp(0, 100)) / 100.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: row.isWeakest
            ? SignageColors.goldWash
            : (row.isStrongest ? SignageColors.greenWash : SignageColors.paper),
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: SignageColors.lineSoft, width: 1),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    style: SignageTypography.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (row.isWeakest) ...[
                  const PlacardBadge.warning('WEAKEST'),
                  const SizedBox(width: 8),
                ] else if (row.isStrongest) ...[
                  const PlacardBadge.success('STRONGEST'),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${row.accuracyPercent}%',
                  style: SignageTypography.data(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SignageColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SignageColors.track,
                  border: Border.all(color: SignageColors.ink, width: 1),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: barColor),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${row.answeredCount} ITEMS ANSWERED',
              style: SignageTypography.data(
                fontSize: 11,
                color: SignageColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
