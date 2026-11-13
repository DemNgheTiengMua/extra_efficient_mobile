import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../models/practice_models.dart';
import '../providers/practice_providers.dart';

class WeaknessAnalysisView extends ConsumerStatefulWidget {
  const WeaknessAnalysisView({super.key});

  @override
  ConsumerState<WeaknessAnalysisView> createState() =>
      _WeaknessAnalysisViewState();
}

class _WeaknessAnalysisViewState extends ConsumerState<WeaknessAnalysisView> {
  final Set<int> _resolvedIds = {};
  int? _resolvingRecId;
  String? _resolveFailure;
  int? _failedRecId;

  Future<void> _resolve(int recId) async {
    setState(() {
      _resolvingRecId = recId;
      _resolveFailure = null;
      _failedRecId = null;
    });
    try {
      final resolved =
          await ref.read(practiceRepositoryProvider).resolveRecommendation(recId);
      if (!mounted) return;
      if (!resolved) {
        setState(() {
          _failedRecId = recId;
          _resolveFailure = 'Recommendation was not resolved.';
        });
        return;
      }
      // The panel changes in place; the server holds the durable state, so re-opening the tab
      // (which refetches) keeps it resolved.
      setState(() => _resolvedIds.add(recId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failedRecId = recId;
        _resolveFailure =
            extractApiError(e, fallback: 'Could not resolve recommendation');
      });
    } finally {
      if (mounted) setState(() => _resolvingRecId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weaknessAsync = ref.watch(weaknessAnalysisProvider);

    return weaknessAsync.when(
      loading: () => const Center(child: FCircularProgress()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: StateBlock(
          stamp: 'ERROR',
          title: 'Could not load weakness analysis',
          description: extractApiError(err, fallback: '$err'),
          action: PlacardButton(
            label: 'RETRY',
            onPress: () => ref.invalidate(weaknessAnalysisProvider),
          ),
        ),
      ),
      data: (data) {
        if (!data.hasData && data.recommendations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: StateBlock(
              stamp: 'EMPTY',
              title: 'No practice history yet',
              description:
                  'Complete a practice session or a mock attempt to see your accuracy breakdown and recommendations.',
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (data.sections.isNotEmpty) ...[
              _SectionTable(title: '${data.sectionNoun.toUpperCase()} ACCURACY', rows: data.sections),
              const SizedBox(height: 16),
            ],
            // `frequentlyMissedTopics` is the same cell list as `topics`, only reordered, so one
            // table carries the topic axis rather than two identical ones.
            if (data.topics.isNotEmpty) ...[
              _TopicTable(rows: data.topics),
              const SizedBox(height: 16),
            ],
            if (data.recommendations.isNotEmpty) ...[
              Text(
                'RECOMMENDATIONS',
                style: SignageTypography.title().copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (final rec in data.recommendations) ...[
                _RecommendationTile(
                  rec: rec,
                  resolved: _resolvedIds.contains(rec.recId),
                  isResolving: _resolvingRecId == rec.recId,
                  failure: _failedRecId == rec.recId ? _resolveFailure : null,
                  onResolve: () => _resolve(rec.recId),
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

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.rec,
    required this.resolved,
    required this.isResolving,
    required this.failure,
    required this.onResolve,
  });

  final WeaknessRecommendation rec;
  final bool resolved;
  final bool isResolving;
  final String? failure;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'RECOMMENDATION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rec.text,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (rec.severity.isNotEmpty) _SeverityBadge(severity: rec.severity),
              if (rec.skillName != null && rec.skillName!.isNotEmpty)
                PlacardBadge.muted(rec.skillName!),
              if (rec.targetBandCode != null && rec.targetBandCode!.isNotEmpty)
                PlacardBadge.info('TARGET ${rec.targetBandCode!}'),
              if (resolved) const PlacardBadge.success('RESOLVED'),
            ],
          ),
          if (failure != null) ...[
            const SizedBox(height: 12),
            PlacardAlert(
              key: const Key('resolve-error'),
              title: failure!,
              variant: PlacardAlertVariant.danger,
            ),
          ],
          if (!resolved) ...[
            const SizedBox(height: 12),
            PlacardButton(
              key: Key('resolve-rec-${rec.recId}'),
              label: 'RESOLVE',
              variant: PlacardButtonVariant.secondary,
              isLoading: isResolving,
              onPress: onResolve,
            ),
          ],
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final label = severity.toUpperCase();
    return switch (severity.toLowerCase()) {
      'major' => PlacardBadge.danger(label),
      'minor' => PlacardBadge.warning(label),
      _ => PlacardBadge.info(label),
    };
  }
}

class _SectionTable extends StatelessWidget {
  const _SectionTable({required this.title, required this.rows});

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
            _AccuracyRowTile(
              name: rows[i].name,
              answered: rows[i].answered,
              accuracyPercent: rows[i].accuracyPercentage,
              isWeakest: rows[i].isWeakest,
              isStrongest: rows[i].isStrongest,
              showDivider: i < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TopicTable extends StatelessWidget {
  const _TopicTable({required this.rows});

  final List<WeaknessTopicRow> rows;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'TOPIC ACCURACY',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            _AccuracyRowTile(
              name: rows[i].topicName,
              levelCode: rows[i].levelCode,
              answered: rows[i].answered,
              accuracyPercent: rows[i].accuracyPercent,
              isWeakest: rows[i].isWeakest,
              isStrongest: false,
              // Below n_min the cell is listed but not yet ranked, and says so.
              footer: rows[i].isRankable
                  ? null
                  : '${rows[i].answered} of ${rows[i].observationFloor} answers needed to rank',
              showDivider: i < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _AccuracyRowTile extends StatelessWidget {
  const _AccuracyRowTile({
    required this.name,
    required this.answered,
    required this.accuracyPercent,
    required this.isWeakest,
    required this.isStrongest,
    required this.showDivider,
    this.levelCode,
    this.footer,
  });

  final String name;
  final String? levelCode;
  final int answered;
  final int accuracyPercent;
  final bool isWeakest;
  final bool isStrongest;
  final bool showDivider;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    if (isWeakest) {
      barColor = SignageColors.signGold;
    } else if (isStrongest) {
      barColor = SignageColors.signGreen;
    } else {
      barColor = SignageColors.signBlue;
    }

    final fraction = (accuracyPercent.clamp(0, 100)) / 100.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isWeakest
            ? SignageColors.goldWash
            : (isStrongest ? SignageColors.greenWash : SignageColors.paper),
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name,
                        style: SignageTypography.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (levelCode != null && levelCode!.isNotEmpty)
                        PlacardBadge.muted(levelCode!),
                    ],
                  ),
                ),
                if (isWeakest) ...[
                  const PlacardBadge.warning('WEAKEST'),
                  const SizedBox(width: 8),
                ] else if (isStrongest) ...[
                  const PlacardBadge.success('STRONGEST'),
                  const SizedBox(width: 8),
                ],
                Text(
                  '$accuracyPercent%',
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
              '$answered ANSWERED',
              style: SignageTypography.data(
                fontSize: 11,
                color: SignageColors.inkMuted,
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 2),
              Text(
                footer!,
                style: SignageTypography.data(
                  fontSize: 11,
                  color: SignageColors.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
