import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../../context/learner_context_provider.dart';
import '../models/path_models.dart';
import '../providers/path_providers.dart';

class PathDashboardScreen extends ConsumerWidget {
  const PathDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(learnerContextProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

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
              subtitle: extractApiError(
                error,
                fallback: 'The learner context could not be loaded.',
              ),
            ),
          ),
          data: (ctx) {
            if (ctx == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PlacardPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    PlacardBadge.info(ctx.active.code),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ctx.active.name,
                        style: SignageTypography.condensedSentence(
                          fontSize: 16,
                        ),
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
            description: extractApiError(
              error,
              fallback: 'The dashboard summary could not be loaded.',
            ),
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
                _DashboardBody(dashboard: dashboard),
                // An insight describes a certificate, so there is nothing to ask
                // for until one has loaded.
                if (dashboard.certificate.code.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _DashboardInsightCard(),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dashboard});

  final LearnerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final goal = dashboard.goal;
    final attempt = dashboard.unfinishedAttempt;
    final resumeUrl = attempt == null ? null : _resumeAttemptUrl(dashboard);

    // Nothing has been measured, so there is no band and no score to print.
    // The honest page is the backend's own first step — a placement test, or
    // the resume of one already open.
    if (goal.hasNoMeasurement) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FirstStepCard(dashboard: dashboard),
          const SizedBox(height: 12),
          // The goal and path surfaces stay reachable: an unmeasured learner can
          // still open them, they simply have nothing measured to show yet.
          const _PathDestinations(),
          if (attempt != null) ...[
            const SizedBox(height: 12),
            _UnfinishedAttemptCard(attempt: attempt, resumeUrl: resumeUrl!),
          ],
          if (dashboard.unfinishedPractice != null) ...[
            const SizedBox(height: 12),
            _UnfinishedPracticeCard(practice: dashboard.unfinishedPractice!),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dashboard.nextAction != null) ...[
          _NextActionCard(action: dashboard.nextAction!),
          const SizedBox(height: 12),
        ],
        _BandSummaryCard(goal: goal),
        const SizedBox(height: 12),
        const _PathDestinations(),
        if (dashboard.skills.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SkillMeasurementsCard(skills: dashboard.skills),
        ],
        if (attempt != null) ...[
          const SizedBox(height: 12),
          _UnfinishedAttemptCard(attempt: attempt, resumeUrl: resumeUrl!),
        ],
        if (dashboard.unfinishedPractice != null) ...[
          const SizedBox(height: 12),
          _UnfinishedPracticeCard(practice: dashboard.unfinishedPractice!),
        ],
      ],
    );
  }

  /// The server decides how a sitting is addressed: a placement by its
  /// placement id, everything else by the attempt id. It expresses that in the
  /// resume action, so that URL is used when the action is the resume one. The
  /// fallback only runs when the server offered no resume action.
  String _resumeAttemptUrl(LearnerDashboard dashboard) {
    final action = dashboard.nextAction;
    if (action != null && action.isResume && action.actionUrl.isNotEmpty) {
      return action.actionUrl;
    }
    final attempt = dashboard.unfinishedAttempt!;
    return attempt.isPlacement
        ? '/placement'
        : '/exams/attempts/${attempt.attemptId}';
  }
}

/// The never-measured state: a sentence about the free placement test and the
/// one action that starts it. No band, no score, no skills ladder.
class _FirstStepCard extends StatelessWidget {
  const _FirstStepCard({required this.dashboard});

  final LearnerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final action = dashboard.nextAction;
    final actionUrl = action != null && action.actionUrl.isNotEmpty
        ? action.actionUrl
        : '/placement';

    return StateBlock(
      stamp: action?.eyebrow.isNotEmpty == true
          ? action!.eyebrow
          : 'START HERE',
      title: action?.title.isNotEmpty == true
          ? action!.title
          : 'Find your level with the free placement test',
      description: action?.description.isNotEmpty == true
          ? action!.description
          : 'A free placement test sets your starting band, and your practice and '
                'learning path are chosen from it. No credit is spent.',
      action: PlacardButton(
        key: const Key('take-placement-test-btn'),
        label: action?.actionLabel.isNotEmpty == true
            ? action!.actionLabel
            : 'Take the free placement test',
        onPress: () => context.push(actionUrl),
      ),
    );
  }
}

/// The two surfaces that are not the backend's next action but still belong on
/// this tab: the goal editor and the learning path.
class _PathDestinations extends StatelessWidget {
  const _PathDestinations();

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.action});

  final NextActionInfo action;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = action.metaLabel?.isNotEmpty == true
        ? action.metaLabel!
        : action.eyebrow;

    return PlacardPanel(
      title: action.eyebrow.isNotEmpty ? action.eyebrow : 'NEXT ACTION',
      trailing: badgeLabel.isNotEmpty
          ? _severityBadge(action.severity, badgeLabel)
          : null,
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
            onPress: action.actionUrl.isEmpty
                ? null
                : () => context.push(action.actionUrl),
          ),
        ],
      ),
    );
  }

  Widget _severityBadge(String severity, String label) {
    return switch (severity.toLowerCase()) {
      'danger' => PlacardBadge.danger(label),
      'warning' => PlacardBadge.warning(label),
      'success' => PlacardBadge.success(label),
      'muted' => PlacardBadge.muted(label),
      _ => PlacardBadge.info(label),
    };
  }
}

class _BandSummaryCard extends StatelessWidget {
  const _BandSummaryCard({required this.goal});

  final GoalStanding goal;

  @override
  Widget build(BuildContext context) {
    final currentBand = goal.currentBandCode;
    final targetBand = goal.targetBandCode;
    final caption = [
      if (currentBand != null) 'CURRENT BAND ${_bandLabel(currentBand)}',
      if (targetBand != null)
        'TARGET ${_bandLabel(targetBand)}'
      else
        'NO TARGET',
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScorePlacard(
          totalScore: goal.currentScoreText ?? '--',
          caption: caption,
          splits: [
            ScoreSplit(
              label: 'CURRENT BAND',
              value: currentBand == null ? '--' : _bandLabel(currentBand),
            ),
            ScoreSplit(
              label: 'TARGET BAND',
              value: targetBand == null ? '--' : _bandLabel(targetBand),
            ),
            ScoreSplit(
              label: 'PATH STEPS',
              value: '${goal.completedPathSteps}/${goal.totalPathSteps}',
            ),
          ],
        ),
        if (currentBand != null) ...[
          const SizedBox(height: 8),
          CefrBandBar(currentBand: _bandLabel(currentBand)),
        ],
      ],
    );
  }
}

class _SkillMeasurementsCard extends StatelessWidget {
  const _SkillMeasurementsCard({required this.skills});

  final List<SkillMeasurement> skills;

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
                          skills[i].name.toUpperCase(),
                          style: SignageTypography.label(fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _detailLine(skills[i]),
                          style: SignageTypography.data(
                            fontSize: 12,
                            color: SignageColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(skills[i]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A skill nothing measured has a null level, and null is printed as such
  /// rather than defaulted to the bottom band.
  String _detailLine(SkillMeasurement skill) {
    if (!skill.isMeasured) return 'NO MEASUREMENT YET';
    final band = skill.levelCode!.toUpperCase();
    final score = skill.scoreText;
    if (score == null) return 'BAND $band';
    final max = skill.maxScoreText;
    return max == null
        ? 'BAND $band • SCORE $score'
        : 'BAND $band • $score/$max';
  }

  Widget _statusBadge(SkillMeasurement skill) {
    if (!skill.isMeasured) return PlacardBadge.muted('NOT MEASURED');
    return skill.isStale
        ? const PlacardBadge.warning('STALE')
        : const PlacardBadge.success('MEASURED');
  }
}

class _UnfinishedAttemptCard extends StatelessWidget {
  const _UnfinishedAttemptCard({
    required this.attempt,
    required this.resumeUrl,
  });

  final UnfinishedAttemptSummary attempt;
  final String resumeUrl;
  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'UNFINISHED ATTEMPT',
      trailing: PlacardBadge.warning(attempt.purpose),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            attempt.examName,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          const SizedBox(height: 10),
          PlacardButton(
            key: const Key('resume-attempt-btn'),
            label: 'RESUME ATTEMPT',
            variant: PlacardButtonVariant.secondary,
            onPress: () => context.push(resumeUrl),
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
        '${practice.correctCount}/${practice.questionCount}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            practice.sectionName,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          const SizedBox(height: 10),
          PlacardButton(
            key: const Key('resume-practice-btn'),
            label: 'RESUME PRACTICE',
            variant: PlacardButtonVariant.secondary,
            onPress: () =>
                context.push('/practice/sessions/${practice.sessionId}'),
          ),
        ],
      ),
    );
  }
}

/// The dashboard insight, with RETRY only where the backend would accept it:
/// an insight that reports `failed`. Pending is a normal state, not a failure.
class _DashboardInsightCard extends ConsumerWidget {
  const _DashboardInsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(dashboardInsightProvider)
        .when(
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
                  subtitle: extractApiError(error, fallback: error.toString()),
                ),
                const SizedBox(height: 12),
                PlacardButton(
                  key: const Key('reload-dashboard-insight-btn'),
                  label: 'RELOAD INSIGHT',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () => ref.invalidate(dashboardInsightProvider),
                ),
              ],
            ),
          ),
          data: (insight) {
            if (insight == null) return const SizedBox.shrink();
            final body = insight.body;
            return PlacardPanel(
              title: 'DASHBOARD INSIGHT',
              trailing: insight.isFailed
                  ? const PlacardBadge.danger('FAILED')
                  : insight.isPending
                  ? const PlacardBadge.muted('PENDING')
                  : const PlacardBadge.success('READY'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    body ??
                        (insight.isFailed
                            ? (insight.failureReason ??
                                  'The insight could not be generated.')
                            : 'Generating insight...'),
                    style: SignageTypography.body(fontSize: 15),
                  ),
                  if (insight.isFailed) ...[
                    const SizedBox(height: 12),
                    PlacardButton(
                      key: const Key('retry-dashboard-insight-btn'),
                      label: 'RETRY INSIGHT',
                      variant: PlacardButtonVariant.secondary,
                      onPress: () =>
                          ref.read(dashboardInsightProvider.notifier).retry(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
  }
}

/// `below_A1` is the server's code for the band the signage bar paints `<A1`.
String _bandLabel(String code) {
  final lower = code.toLowerCase();
  if (lower == 'below_a1' || lower == '<a1') return '<A1';
  return code.toUpperCase();
}
