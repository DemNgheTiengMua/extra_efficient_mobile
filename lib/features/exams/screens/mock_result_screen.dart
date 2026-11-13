import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/mock_exam_models.dart';
import '../providers/mock_exam_providers.dart';

/// Displays Mock Attempt ScorePlacard, CefrBandBar, per-skill Raw/Scaled
/// scores, score delta, and AI Insight with free retry.
class MockResultScreen extends ConsumerStatefulWidget {
  const MockResultScreen({super.key, required this.attemptId});

  final int attemptId;

  @override
  ConsumerState<MockResultScreen> createState() => _MockResultScreenState();
}

class _MockResultScreenState extends ConsumerState<MockResultScreen> {
  ExamAiInsight? _insightOverride;
  bool _retryingInsight = false;

  Future<void> _retryInsight() async {
    if (_retryingInsight) return;
    setState(() => _retryingInsight = true);
    try {
      final res = await ref
          .read(mockExamRepositoryProvider)
          .retryExamInsight(widget.attemptId);
      if (!mounted) return;
      setState(() {
        _insightOverride = res;
        _retryingInsight = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _retryingInsight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(mockResultProvider(widget.attemptId));
    final insightAsync = ref.watch(examInsightProvider(widget.attemptId));

    return FScaffold(
      childPad: false,
      header: DecoratedBox(
        decoration: const BoxDecoration(
          color: SignageColors.signBlue,
          border: Border(
            bottom: BorderSide(color: SignageColors.ink, width: 2),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                FTappable(
                  onPress: () => context.go('/exams'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: SignageColors.paper,
                      border: Border.all(color: SignageColors.ink, width: 2),
                    ),
                    child: Text(
                      'EXAMS',
                      style: SignageTypography.label(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'MOCK ATTEMPT RESULT',
                    style: SignageTypography.label(
                      fontSize: 13,
                      color: SignageColors.paper,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: resultAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: StateBlock(
            stamp: 'ERROR',
            title: 'UNABLE TO LOAD RESULT',
            description: err.toString(),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () =>
                  ref.invalidate(mockResultProvider(widget.attemptId)),
            ),
          ),
        ),
        data: (result) {
          final delta = result.scoreDelta;
          final deltaStr = delta == null
              ? null
              : (delta >= 0 ? '+$delta' : '$delta');
          final splits = [
            for (final s in result.skillBreakdowns)
              ScoreSplit(
                label: s.skill,
                value: '${s.scaledScore}',
              ),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ScorePlacard(
                totalScore: '${result.totalScaledScore}',
                caption: deltaStr != null
                    ? '${result.examTitle} · BAND ${result.overallBand}'
                    : '${result.examTitle} · BAND ${result.overallBand}',
                splits: splits,
              ),
              if (deltaStr != null) ...[
                const SizedBox(height: 12),
                PlacardPanel(
                  title: 'SCORE DELTA VS PREVIOUS',
                  trailing: delta! >= 0
                      ? PlacardBadge.success(deltaStr)
                      : PlacardBadge.danger(deltaStr),
                  child: Text(
                    'Change from previous attempt: $deltaStr points',
                    style: SignageTypography.body(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              CefrBandBar(currentBand: result.cefrBand),
              const SizedBox(height: 16),
              PlacardPanel(
                title: 'SKILL BREAKDOWN',
                child: Column(
                  children: [
                    for (final s in result.skillBreakdowns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.skill.toUpperCase(),
                              style: SignageTypography.label(fontSize: 12),
                            ),
                            Text(
                              '${s.rawScore}/${s.maxRawScore} RAW',
                              style: SignageTypography.data(
                                fontSize: 13,
                                color: SignageColors.inkMuted,
                              ),
                            ),
                            Text(
                              '${s.scaledScore} SCALED',
                              style: SignageTypography.data(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PlacardPanel(
                title: 'AI EXAM INSIGHT',
                child: insightAsync.when(
                  loading: () => const Center(child: FCircularProgress()),
                  error: (err, _) => StateBlock(
                    stamp: 'ERROR',
                    title: 'INSIGHT UNAVAILABLE',
                    description: err.toString(),
                    action: PlacardButton(
                      key: const Key('retry-exam-insight-btn'),
                      label: _retryingInsight ? 'RETRYING...' : 'RETRY INSIGHT',
                      onPress: _retryingInsight ? null : _retryInsight,
                    ),
                  ),
                  data: (fetched) {
                    final insight = _insightOverride ?? fetched;
                    if (insight.isFailed) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PlacardAlert(
                            variant: PlacardAlertVariant.warning,
                            title: 'INSIGHT GENERATION FAILED',
                            subtitle: insight.errorMessage ??
                                'Please retry generating your insight.',
                          ),
                          const SizedBox(height: 10),
                          PlacardButton(
                            key: const Key('retry-exam-insight-btn'),
                            label: _retryingInsight
                                ? 'RETRYING...'
                                : 'RETRY INSIGHT (FREE)',
                            onPress: _retryingInsight ? null : _retryInsight,
                          ),
                        ],
                      );
                    }
                    return Text(
                      insight.narrative ?? 'No insight available yet.',
                      style: SignageTypography.body(fontSize: 14),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              PlacardButton(
                key: const Key('open-answer-review-btn'),
                label: 'OPEN ANSWER REVIEW',
                onPress: () =>
                    context.push('/exams/attempts/${widget.attemptId}/review'),
              ),
            ],
          );
        },
      ),
    );
  }
}
