import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../models/path_models.dart';
import '../providers/path_providers.dart';

class LearningPathScreen extends ConsumerWidget {
  const LearningPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(learningPathProvider);

    return pathAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          PlacardPanel(
            title: 'LOADING LEARNING PATH',
            child: Text('Loading weeks and progress...'),
          ),
        ],
      ),
      error: (error, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StateBlock(
            stamp: 'PATH ERROR',
            title: 'Could not load learning path',
            description: extractApiError(error, fallback: error.toString()),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () => ref.invalidate(learningPathProvider),
            ),
          ),
        ],
      ),
      data: (path) {
        // `hasActivePath` is the server's existence switch. Without a path every
        // figure is a zero and every list is empty, so an empty shell of weeks
        // would be a lie: offer generation instead.
        if (path == null || !path.hasActivePath) {
          return const _NoPathBody();
        }

        return _PathBody(path: path);
      },
    );
  }
}

/// No active path: the honest state is one generation block, and it is only
/// actionable once a target band exists — `POST /learning-path/generate`
/// answers 422 `LEARNING_PATH_BAND_UNKNOWN` without one.
class _NoPathBody extends ConsumerWidget {
  const _NoPathBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAsync = ref.watch(targetBandGoalProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        targetAsync.when(
          loading: () => const PlacardPanel(
            title: 'NO LEARNING PATH',
            child: Text('Checking your target band...'),
          ),
          error: (error, _) => StateBlock(
            stamp: 'NO LEARNING PATH',
            title: 'Could not read your target band',
            description: extractApiError(error, fallback: error.toString()),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () => ref.invalidate(targetBandGoalProvider),
            ),
          ),
          data: (goal) {
            if (goal == null) {
              return const StateBlock(
                stamp: 'NO LEARNING PATH',
                title: 'Sign in to build a learning path',
                description:
                    'A path is built from your measured band and your target band.',
              );
            }
            return _generateBlock(context, ref, goal);
          },
        ),
      ],
    );
  }

  Widget _generateBlock(
    BuildContext context,
    WidgetRef ref,
    TargetBandGoal goal,
  ) {
    final currentBand = goal.currentBandCode;
    if (!goal.hasTargetBand) {
      return StateBlock(
        stamp: 'NO LEARNING PATH',
        title: 'Choose a target band first',
        description:
            'A learning path is a sequence aimed at a target band, so there is '
            'nothing to build until you set one. '
            '${currentBand == null ? 'Your band has not been measured yet either: take the free placement test, or set your band with the goal.' : 'Your measured band is ${_bandLabel(currentBand)}.'}',
        action: PlacardButton(
          key: const Key('set-target-band-btn'),
          label: 'SET YOUR TARGET BAND',
          onPress: () => context.push('/path/goal'),
        ),
      );
    }

    return StateBlock(
      stamp: 'NO LEARNING PATH',
      title: 'Generate your learning path',
      description:
          'Build a week-by-week sequence aimed at ${_bandLabel(goal.targetBandCode!)}'
          '${currentBand == null ? '' : ' from ${_bandLabel(currentBand)}'}.',
      action: PlacardButton(
        key: const Key('generate-learning-path-btn'),
        label: 'GENERATE LEARNING PATH',
        onPress: () => ref.read(learningPathProvider.notifier).generate(),
      ),
    );
  }
}

class _PathBody extends ConsumerStatefulWidget {
  const _PathBody({required this.path});

  final LearningPathOverview path;

  @override
  ConsumerState<_PathBody> createState() => _PathBodyState();
}

class _PathBodyState extends ConsumerState<_PathBody> {
  bool _starting = false;
  String? _error;
  String? _notice;

  Future<void> _start(PathStep step) async {
    setState(() {
      _starting = true;
      _error = null;
      _notice = null;
    });
    final repo = ref.read(pathRepositoryProvider);
    try {
      final started = await repo.startStep(step.stepId);
      if (!mounted) return;
      if (started.isSubstituted) {
        setState(
          () => _notice =
              'This step drew from a sibling topic because its own cell had no '
              'items available.',
        );
      }
      ref.invalidate(learningPathProvider);
      if (started.redirectUrl.isEmpty) return;
      // The server decides the surface; the app follows it rather than mapping
      // step types to routes of its own.
      context.push(started.redirectUrl);
    } on PathStepUnavailable catch (e) {
      // Terminal: the step is not on the active path, so retrying cannot help.
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = extractApiError(e, fallback: 'Could not start this step.'));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          PlacardAlert(
            variant: PlacardAlertVariant.danger,
            title: 'Cannot open that step',
            subtitle: _error,
          ),
          const SizedBox(height: 12),
        ],
        if (_notice != null) ...[
          PlacardAlert(
            variant: PlacardAlertVariant.info,
            title: 'A different topic supplied this step',
            subtitle: _notice,
          ),
          const SizedBox(height: 12),
        ],
        _PathOverviewPanel(path: path),
        const SizedBox(height: 12),
        for (final week in path.weeks) ...[
          _PathWeekCard(
            week: week,
            starting: _starting,
            onStart: _start,
          ),
          const SizedBox(height: 12),
        ],
        // Mounted only when a path exists: the insight describes a path, and
        // without one the backend answers 404 LEARNING_PATH_NOT_FOUND.
        const _PathInsightCard(),
      ],
    );
  }
}

class _PathOverviewPanel extends ConsumerWidget {
  const _PathOverviewPanel({required this.path});

  final LearningPathOverview path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = path.currentBandCode;
    final to = path.targetBandCode;
    final caption = [
      if (from != null) 'CURRENT BAND ${_bandLabel(from)}',
      if (to != null) 'TARGET ${_bandLabel(to)}' else 'NO TARGET',
    ].join(' • ');

    return PlacardPanel(
      title: 'LEARNING PATH OVERVIEW',
      trailing: to != null
          ? PlacardBadge.info('TARGET ${_bandLabel(to)}')
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (from != null) ...[
            CefrBandBar(currentBand: _bandLabel(from)),
            const SizedBox(height: 12),
          ],
          Text(
            caption,
            style: SignageTypography.label(fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _figure(
                  '${path.completedSteps}/${path.totalSteps}',
                  'STEPS DONE',
                ),
              ),
              Expanded(
                child: _figure(
                  '${path.remainingMinutes} MIN',
                  'REMAINING',
                ),
              ),
              Expanded(
                child: _figure(
                  '${path.totalEstimatedMinutes} MIN',
                  'PLANNED',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProgressBar(ratio: path.progressRatio),
          const SizedBox(height: 12),
          PlacardButton(
            key: const Key('reset-learning-path-btn'),
            label: 'RESET PATH',
            variant: PlacardButtonVariant.destructive,
            onPress: () => ref.read(learningPathProvider.notifier).reset(),
          ),
        ],
      ),
    );
  }

  Widget _figure(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: SignageTypography.data(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: SignageTypography.label(
            fontSize: 11,
            color: SignageColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// A 2px-framed progress track: the painted signage numeral for what is done.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Path ${(ratio * 100).round()} per cent complete',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SignageColors.paper,
          border: Border.all(color: SignageColors.ink, width: 2),
        ),
        child: SizedBox(
          height: 14,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: const ColoredBox(color: SignageColors.signBlue),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathWeekCard extends StatelessWidget {
  const _PathWeekCard({
    required this.week,
    required this.starting,
    required this.onStart,
  });

  final LearningPathWeek week;
  final bool starting;
  final Future<void> Function(PathStep step) onStart;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'WEEK ${week.weekNumber}',
      trailing: week.isOnTrack
          ? const PlacardBadge.success('ON TRACK')
          : const PlacardBadge.warning('BEHIND'),
      footer: Text(
        '${week.completedSteps}/${week.plannedSteps} STEPS • '
        '${week.completedMinutes}/${week.plannedMinutes} MIN',
        style: SignageTypography.label(fontSize: 11),
      ),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < week.steps.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1),
            _PathStepRow(
              step: week.steps[i],
              starting: starting,
              onStart: onStart,
            ),
          ],
        ],
      ),
    );
  }
}

class _PathStepRow extends StatelessWidget {
  const _PathStepRow({
    required this.step,
    required this.starting,
    required this.onStart,
  });

  final PathStep step;
  final bool starting;
  final Future<void> Function(PathStep step) onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _statusBadge(step),
                    PlacardBadge.muted(step.typeLabel),
                    if (step.targetCefr.isNotEmpty)
                      PlacardBadge.muted(step.targetCefr),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  step.title,
                  style: SignageTypography.condensedSentence(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  _detailLine(step),
                  style: SignageTypography.data(
                    fontSize: 12,
                    color: SignageColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PlacardButton(
            key: Key('start-step-${step.stepId}'),
            label: _actionLabel(step),
            variant: step.isLocked
                ? PlacardButtonVariant.secondary
                : PlacardButtonVariant.primary,
            isLoading: starting,
            expand: false,
            onPress: step.isLocked ? null : () => onStart(step),
          ),
        ],
      ),
    );
  }

  /// A locked step stays visible as an unavailable line rather than being
  /// hidden, so the sequence is legible.
  String _actionLabel(PathStep step) {
    if (step.isDone) return 'OPEN';
    return step.isLocked ? 'LOCKED' : 'START';
  }

  String _detailLine(PathStep step) {
    final parts = <String>[
      if (step.skillName.isNotEmpty) step.skillName.toUpperCase(),
      if (step.plannedItemCount != null) '${step.plannedItemCount} ITEMS',
      if (step.estimatedMinutes != null) '${step.estimatedMinutes} MIN',
    ];
    return parts.join(' • ');
  }

  Widget _statusBadge(PathStep step) {
    return switch (step.status.toLowerCase()) {
      'done' => const PlacardBadge.success('DONE'),
      'in_progress' => const PlacardBadge.info('IN PROGRESS'),
      'available' => const PlacardBadge.warning('AVAILABLE'),
      _ => const PlacardBadge.muted('LOCKED'),
    };
  }
}

class _PathInsightCard extends ConsumerWidget {
  const _PathInsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(pathInsightProvider)
        .when(
          loading: () => const PlacardPanel(
            title: 'PATH INSIGHT',
            child: Text('Generating path insight...'),
          ),
          error: (error, _) => PlacardPanel(
            title: 'PATH INSIGHT',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlacardAlert(
                  variant: PlacardAlertVariant.warning,
                  title: 'Path insight unavailable',
                  subtitle: extractApiError(error, fallback: error.toString()),
                ),
                const SizedBox(height: 12),
                PlacardButton(
                  key: const Key('reload-path-insight-btn'),
                  label: 'RELOAD INSIGHT',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () => ref.invalidate(pathInsightProvider),
                ),
              ],
            ),
          ),
          data: (insight) {
            if (insight == null) return const SizedBox.shrink();
            final body = insight.body;
            return PlacardPanel(
              title: 'PATH INSIGHT',
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
                                  'The path insight could not be generated.')
                            : 'Generating path insight...'),
                    style: SignageTypography.body(fontSize: 15),
                  ),
                  // The backend rejects a retry unless the insight failed.
                  if (insight.isFailed) ...[
                    const SizedBox(height: 12),
                    PlacardButton(
                      key: const Key('retry-path-insight-btn'),
                      label: 'RETRY INSIGHT',
                      variant: PlacardButtonVariant.secondary,
                      onPress: () =>
                          ref.read(pathInsightProvider.notifier).retry(),
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
