import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../context/learner_context_provider.dart';
import '../models/mock_exam_models.dart';
import '../models/placement_models.dart';
import '../providers/mock_exam_providers.dart';
import '../providers/placement_providers.dart';

enum _ExamSubTab { mockExams, history }

/// EXAMS tab hub presenting Mock Exams, Placement Assessment, Resume by Code,
/// and Attempt History & Review.
class ExamHubScreen extends ConsumerStatefulWidget {
  const ExamHubScreen({super.key});

  @override
  ConsumerState<ExamHubScreen> createState() => _ExamHubScreenState();
}

class _ExamHubScreenState extends ConsumerState<ExamHubScreen> {
  _ExamSubTab _subTab = _ExamSubTab.mockExams;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExamSubTabBar(
          current: _subTab,
          onSelect: (tab) => setState(() => _subTab = tab),
        ),
        Expanded(
          child: switch (_subTab) {
            _ExamSubTab.mockExams => const _MockExamsView(),
            _ExamSubTab.history => const _HistoryReviewView(),
          },
        ),
      ],
    );
  }
}

class _ExamSubTabBar extends StatelessWidget {
  const _ExamSubTabBar({required this.current, required this.onSelect});

  final _ExamSubTab current;
  final ValueChanged<_ExamSubTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SignageColors.paper,
        border: Border(bottom: BorderSide(color: SignageColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          _tabItem(_ExamSubTab.mockExams, 'MOCK EXAMS'),
          _tabItem(_ExamSubTab.history, 'HISTORY & REVIEW'),
        ],
      ),
    );
  }

  Widget _tabItem(_ExamSubTab tab, String label) {
    final selected = current == tab;
    return Expanded(
      child: FTappable(
        onPress: () => onSelect(tab),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? SignageColors.ink : SignageColors.paper,
            border: const Border(
              right: BorderSide(color: SignageColors.lineSoft, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: SignageTypography.label(
                  fontSize: 12,
                  color: selected ? SignageColors.paper : SignageColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockExamsView extends ConsumerWidget {
  const _MockExamsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(learnerContextProvider);
    final activeCode = contextAsync.value?.active.code ?? '---';
    final examsAsync = ref.watch(mockExamsProvider);
    final catalogAsync = ref.watch(placementCatalogProvider);
    final catalog = catalogAsync.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PlacementPlacard(
          activeCode: activeCode,
          catalog: catalog,
          error: catalogAsync.error,
          onRetry: () => ref.invalidate(placementCatalogProvider),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'MOCK EXAM CATALOG',
          trailing: examsAsync.value != null
              ? PlacardBadge.info('${examsAsync.value!.creditBalance} CREDITS')
              : PlacardBadge.info(activeCode),
          child: examsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: FCircularProgress()),
            ),
            error: (err, _) => StateBlock(
              stamp: 'ERROR',
              title: 'UNABLE TO LOAD MOCK EXAMS',
              description: err.toString(),
              action: PlacardButton(
                label: 'RETRY',
                onPress: () => ref.invalidate(mockExamsProvider),
              ),
            ),
            data: (catalogue) {
              if (catalogue.exams.isEmpty) {
                return const StateBlock(
                  stamp: 'EMPTY',
                  title: 'NO MOCK EXAMS AVAILABLE',
                  description: 'No mock exams are currently published for this certificate.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < catalogue.exams.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _MockExamRow(exam: catalogue.exams[i]),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'RESUME AN ATTEMPT',
          child: Text(
            'A sitting you have not finished appears in the catalogue above with its '
            'RESUME control. Interrupted sittings are listed under HISTORY & REVIEW.',
            style: SignageTypography.body(
              fontSize: 13,
              color: SignageColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// The placement placard: offers the way back into an unfinished sitting and
/// the way into a new one, both read from the catalogue envelope.
class _PlacementPlacard extends StatelessWidget {
  const _PlacementPlacard({
    required this.activeCode,
    required this.catalog,
    required this.error,
    required this.onRetry,
  });

  final String activeCode;
  final PlacementCatalog? catalog;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final catalog = this.catalog;
    if (catalog == null) {
      return PlacardPanel(
        title: 'PLACEMENT ASSESSMENT',
        trailing: PlacardBadge.info(activeCode),
        child: error != null
            ? StateBlock(
                stamp: 'ERROR',
                title: 'UNABLE TO LOAD PLACEMENT',
                description: error.toString(),
                action: PlacardButton(label: 'RETRY', onPress: onRetry),
              )
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: FCircularProgress()),
              ),
      );
    }

    final exam = catalog.exams.isEmpty ? null : catalog.exams.first;
    final activePlacementId = catalog.activePlacementId;

    return PlacardPanel(
      title: 'PLACEMENT ASSESSMENT',
      trailing: catalog.isRetake
          ? const PlacardBadge.warning('PAID RETAKE')
          : const PlacardBadge.success('FREE FIRST PLACEMENT'),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activePlacementId != null) ...[
            PlacardButton(
              key: const Key('resume-placement-btn'),
              label: 'RESUME PLACEMENT',
              onPress: () =>
                  context.push('/placement/take/$activePlacementId/preflight'),
            ),
            const SizedBox(height: 8),
          ],
          if (exam != null)
            PlacardButton(
              key: const Key('start-placement-hub-btn'),
              label: catalog.isRetake
                  ? 'PLACEMENT RETAKE'
                  : 'START FREE PLACEMENT',
              variant: activePlacementId != null
                  ? PlacardButtonVariant.secondary
                  : PlacardButtonVariant.primary,
              onPress: () => context.push('/placement'),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activePlacementId != null) ...[
            Text(
              'ATTEMPT $activePlacementId IS UNFINISHED',
              style: SignageTypography.label(fontSize: 12),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            exam?.name ?? 'NO PLACEMENT EXAM AVAILABLE',
            style: SignageTypography.condensedSentence(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            exam == null
                ? 'No placement exam is published for $activeCode. Switch certificate in ACCOUNT to take a placement test.'
                : '${exam.durationMinutes} MIN · ${exam.questionCount} QUESTIONS · Diagnose your starting Band for $activeCode',
            style: SignageTypography.body(
              fontSize: 14,
              color: SignageColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockExamRow extends StatelessWidget {
  const _MockExamRow({required this.exam});

  final MockExamSummary exam;

  @override
  Widget build(BuildContext context) {
    final title = exam.name.isEmpty ? 'Mock Exam ${exam.examId}' : exam.name;
    final facts = [
      '${exam.durationMinutes} MIN',
      if (exam.questionCount != null) '${exam.questionCount} QUESTIONS',
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignageColors.paper,
        border: Border.all(color: SignageColors.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: SignageTypography.condensedSentence(fontSize: 16),
                  ),
                ),
                PlacardBadge.info('${exam.creditCost} CREDITS'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              facts,
              style: SignageTypography.data(
                fontSize: 12,
                color: SignageColors.inkMuted,
              ),
            ),
            if (exam.completedAttemptScore != null) ...[
              const SizedBox(height: 6),
              Text(
                'LAST: ${exam.completedAttemptScore} · '
                'BAND ${exam.completedAttemptBand ?? '-'}',
                style: SignageTypography.data(
                  fontSize: 12,
                  color: SignageColors.inkMuted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (exam.activeAttemptId != null)
              PlacardButton(
                key: Key('resume-mock-exam-${exam.examId}'),
                label: 'RESUME IN-PROGRESS',
                variant: PlacardButtonVariant.secondary,
                onPress: () =>
                    context.push('/exams/attempts/${exam.activeAttemptId}/preflight'),
              )
            else
              PlacardButton(
                key: Key('open-mock-exam-${exam.examId}'),
                label: 'INSTRUCTIONS & START',
                onPress: () =>
                    context.push('/exams/${exam.examId}/instructions'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryReviewView extends ConsumerWidget {
  const _HistoryReviewView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(examHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: FCircularProgress()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: StateBlock(
          stamp: 'ERROR',
          title: 'UNABLE TO LOAD HISTORY',
          description: err.toString(),
          action: PlacardButton(
            label: 'RETRY',
            onPress: () => ref.invalidate(examHistoryProvider),
          ),
        ),
      ),
      data: (history) {
        final attempts = history.attempts;
        if (attempts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: StateBlock(
              stamp: 'EMPTY',
              title: 'NO ATTEMPTS YET',
              description: 'Complete a mock attempt to view your score placard and answer review here.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (history.bestScore != null)
              PlacardPanel(
                title: 'RECORD',
                trailing: history.bestBandCode == null
                    ? PlacardBadge.muted('NOT BANDED')
                    : PlacardBadge.info(history.bestBandCode!),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${history.totalAttempts} ATTEMPTS',
                      style: SignageTypography.label(fontSize: 12),
                    ),
                    Text(
                      'BEST ${history.bestScore} · AVG ${history.averageScore ?? '-'}',
                      style: SignageTypography.data(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (history.bestScore != null) const SizedBox(height: 12),
            for (var i = 0; i < attempts.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _HistoryRow(item: attempts[i]),
            ],
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final ExamHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final title = item.examName.isEmpty
        ? 'Attempt ${item.attemptId}'
        : item.examName;

    final bandText = item.status.isUnfinished
        ? 'AWAITING SUBMISSION'
        : item.bandLabel;

    return PlacardPanel(
      title: title,
      trailing: item.status.isUnfinished
          ? PlacardBadge.warning(item.status.label)
          : PlacardBadge.info(item.bandLabel),
      footer: Row(
        children: [
          if (item.status.isUnfinished)
            Expanded(
              child: PlacardButton(
                key: Key('history-resume-${item.attemptId}'),
                label: 'RESUME',
                onPress: () =>
                    context.push('/exams/attempts/${item.attemptId}/preflight'),
              ),
            )
          else ...[
            Expanded(
              child: PlacardButton(
                key: Key('history-result-${item.attemptId}'),
                label: 'RESULT',
                variant: PlacardButtonVariant.secondary,
                onPress: () =>
                    context.push('/exams/attempts/${item.attemptId}/result'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PlacardButton(
                key: Key('history-review-${item.attemptId}'),
                label: 'REVIEW',
                onPress: () =>
                    context.push('/exams/attempts/${item.attemptId}/review'),
              ),
            ),
          ],
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              bandText,
              overflow: TextOverflow.ellipsis,
              style: SignageTypography.label(
                fontSize: 12,
                color: SignageColors.inkMuted,
              ),
            ),
          ),
          if (!item.status.isUnfinished)
            Text(
              '${item.totalScore}',
              style: SignageTypography.data(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
