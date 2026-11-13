import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../context/learner_context_provider.dart';
import '../models/path_models.dart';
import '../providers/path_providers.dart';

class PathDashboardScreen extends ConsumerWidget {
  const PathDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(learnerContextProvider);
    final dashboardAsync = ref.watch(dashboardProvider);
    final insightAsync = ref.watch(dashboardInsightProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        contextAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PlacardAlert(
              variant: PlacardAlertVariant.danger,
              title: 'Unable to load learner context',
              subtitle: error.toString(),
            ),
          ),
          data: (ctx) {
            if (ctx == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PlacardPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    PlacardBadge.info(ctx.active.code),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ctx.active.name,
                        style: SignageTypography.condensedSentence(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        dashboardAsync.when(
          loading: () => const PlacardPanel(
            title: 'LOADING DASHBOARD',
            child: Text('Loading certificate progress...'),
          ),
          error: (error, _) => StateBlock(
            stamp: 'DASHBOARD UNAVAILABLE',
            title: 'Could not load dashboard summary',
            description: error.toString(),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () => ref.invalidate(dashboardProvider),
            ),
          ),
          data: (dashboard) {
            if (dashboard == null) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dashboard.nextAction != null) ...[
                  _NextActionCard(action: dashboard.nextAction!),
                  const SizedBox(height: 12),
                ],
                _BandSummaryCard(dashboard: dashboard),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PlacardButton(
                        key: const Key('open-goal-calibration-btn'),
                        label: 'GOAL & CALIBRATION',
                        variant: PlacardButtonVariant.secondary,
                        onPress: () => context.push('/path/goal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PlacardButton(
                        key: const Key('open-learning-path-btn'),
                        label: 'LEARNING PATH',
                        variant: PlacardButtonVariant.ink,
                        onPress: () => context.push('/path/learning-path'),
                      ),
                    ),
                  ],
                ),
                if (dashboard.skillMeasurements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SkillMeasurementsCard(skills: dashboard.skillMeasurements),
                ],
                if (dashboard.unfinishedAttempt != null) ...[
                  const SizedBox(height: 12),
                  _UnfinishedAttemptCard(attempt: dashboard.unfinishedAttempt!),
                ],
                if (dashboard.unfinishedPractice != null) ...[
                  const SizedBox(height: 12),
                  _UnfinishedPracticeCard(
                    practice: dashboard.unfinishedPractice!,
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        insightAsync.when(
          loading: () => const PlacardPanel(
            title: 'DASHBOARD INSIGHT',
            child: Text('Generating insight...'),
          ),
          error: (error, _) => PlacardPanel(
            title: 'DASHBOARD INSIGHT',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlacardAlert(
                  variant: PlacardAlertVariant.warning,
                  title: 'Insight unavailable',
                  subtitle: error.toString(),
                ),
                const SizedBox(height: 12),
                PlacardButton(
                  key: const Key('retry-dashboard-insight-btn'),
                  label: 'RETRY INSIGHT',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () =>
                      ref.read(dashboardInsightProvider.notifier).retry(),
                ),
              ],
            ),
          ),
          data: (insight) {
            if (insight == null) return const SizedBox.shrink();
            return PlacardPanel(
              title: 'DASHBOARD INSIGHT',
              trailing: insight.isFailed
                  ? const PlacardBadge.danger('FAILED')
                  : const PlacardBadge.success('READY'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    insight.narrative.isNotEmpty
                        ? insight.narrative
                        : (insight.errorMessage ?? 'No insight available yet.'),
                    style: SignageTypography.body(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  PlacardButton(
                    key: const Key('retry-dashboard-insight-btn'),
                    label: 'RETRY INSIGHT',
                    variant: PlacardButtonVariant.secondary,
                    onPress: () =>
                        ref.read(dashboardInsightProvider.notifier).retry(),
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

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.action});

  final NextActionInfo action;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'NEXT ACTION',
      trailing: PlacardBadge.info(action.type.toUpperCase()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            action.title,
            style: SignageTypography.condensedSentence(fontSize: 18),
          ),
          if (action.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              action.description,
              style: SignageTypography.body(
                fontSize: 14,
                color: SignageColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          PlacardButton(
            key: const Key('next-action-btn'),
            label: action.actionLabel,
            onPress: () {
              if (action.lessonId != null) {
                context.push('/path/lessons/${action.lessonId}');
              } else if (action.type == 'placement') {
                context.go('/exams');
              } else {
                context.push('/path/learning-path');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _BandSummaryCard extends StatelessWidget {
  const _BandSummaryCard({required this.dashboard});

  final LearnerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final targetLabel = dashboard.targetBandCode != null
        ? 'TARGET ${dashboard.targetBandCode!.toUpperCase()}'
        : 'NO TARGET';
    final scoreText = dashboard.scaledScore?.toString() ?? '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScorePlacard(
          totalScore: scoreText,
          caption:
              'CURRENT BAND ${dashboard.currentBandCode.toUpperCase()} • $targetLabel',
          splits: [
            ScoreSplit(
              label: 'CURRENT BAND',
              value: dashboard.currentBandCode.toUpperCase(),
            ),
            ScoreSplit(
              label: 'TARGET BAND',
              value: dashboard.targetBandCode?.toUpperCase() ?? '--',
            ),
          ],
        ),
        const SizedBox(height: 8),
        CefrBandBar(currentBand: dashboard.currentBandCode),
      ],
    );
  }
}

class _SkillMeasurementsCard extends StatelessWidget {
  const _SkillMeasurementsCard({required this.skills});

  final List<SkillMeasurementSummary> skills;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'SKILL MEASUREMENTS',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < skills.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skills[i].skill.toUpperCase(),
                          style: SignageTypography.label(fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'BAND ${skills[i].bandCode?.toUpperCase() ?? '--'} • SCORE ${skills[i].scaledScore?.toString() ?? '--'}',
                          style: SignageTypography.data(
                            fontSize: 12,
                            color: SignageColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(skills[i].status),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    return switch (status.toLowerCase()) {
      'measured' => const PlacardBadge.success('MEASURED'),
      'stale' => const PlacardBadge.warning('STALE'),
      _ => PlacardBadge.muted(status.toUpperCase()),
    };
  }
}

class _UnfinishedAttemptCard extends StatelessWidget {
  const _UnfinishedAttemptCard({required this.attempt});

  final UnfinishedAttemptSummary attempt;

  /// Every door leads to the same device gate. A placement is addressed by
  /// `placementId` — which the dashboard does not carry — so it goes to the
  /// placement sheet, whose RESUME opens the gate with the right id.
  String get _route => attempt.purpose == 'placement'
      ? '/placement'
      : '/exams/attempts/${attempt.attemptId}/preflight';

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'UNFINISHED ATTEMPT',
      trailing: PlacardBadge.warning(attempt.purpose.toUpperCase()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            attempt.title,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          if (attempt.remainingMinutes != null) ...[
            const SizedBox(height: 4),
            Text(
              '${attempt.remainingMinutes} MIN REMAINING',
              style: SignageTypography.data(
                fontSize: 12,
                color: SignageColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          PlacardButton(
            key: const Key('resume-unfinished-attempt-btn'),
            label: 'RESUME ATTEMPT',
            variant: PlacardButtonVariant.secondary,
            onPress: () => context.go(_route),
          ),
        ],
      ),
    );
  }
}

class _UnfinishedPracticeCard extends StatelessWidget {
  const _UnfinishedPracticeCard({required this.practice});

  final UnfinishedPracticeSummary practice;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'UNFINISHED PRACTICE',
      trailing: PlacardBadge.info(
        '${practice.answeredCount}/${practice.totalCount}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            practice.title,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          const SizedBox(height: 10),
          PlacardButton(
            label: 'RESUME PRACTICE',
            variant: PlacardButtonVariant.secondary,
            onPress: () => context.go('/practice'),
          ),
        ],
      ),
    );
  }
}
