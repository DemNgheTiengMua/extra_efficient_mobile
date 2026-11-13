import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../context/learner_context_provider.dart';
import '../models/mock_exam_models.dart';
import '../providers/mock_exam_providers.dart';

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
  final TextEditingController _authCodeController = TextEditingController();
  bool _resumingCode = false;
  String? _resumeError;

  @override
  void dispose() {
    _authCodeController.dispose();
    super.dispose();
  }

  Future<void> _resumeWithCode() async {
    final code = _authCodeController.text.trim();
    if (code.isEmpty || _resumingCode) return;
    setState(() {
      _resumingCode = true;
      _resumeError = null;
    });
    try {
      final attemptId = await ref
          .read(mockExamRepositoryProvider)
          .resumeByAuthorizationCode(code);
      if (!mounted) return;
      context.push('/exams/attempts/$attemptId');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resumeError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _resumingCode = false);
      }
    }
  }

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
            _ExamSubTab.mockExams => _MockExamsView(
                authCodeController: _authCodeController,
                resumingCode: _resumingCode,
                resumeError: _resumeError,
                onResumeWithCode: _resumeWithCode,
              ),
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
        border: Border(
          bottom: BorderSide(color: SignageColors.ink, width: 2),
        ),
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
  const _MockExamsView({
    required this.authCodeController,
    required this.resumingCode,
    required this.resumeError,
    required this.onResumeWithCode,
  });

  final TextEditingController authCodeController;
  final bool resumingCode;
  final String? resumeError;
  final VoidCallback onResumeWithCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(learnerContextProvider);
    final activeCode = contextAsync.value?.active.code ?? '---';
    final examsAsync = ref.watch(mockExamsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PlacardPanel(
          title: 'PLACEMENT ASSESSMENT',
          trailing: PlacardBadge.info(activeCode),
          footer: PlacardButton(
            key: const Key('open-placement-btn'),
            label: 'OPEN PLACEMENT & PREFLIGHT',
            onPress: () => context.push('/placement'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diagnose your starting Band for $activeCode',
                style: SignageTypography.condensedSentence(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'First placement attempt per certificate is free. Run audio & microphone preflight checks before entering the timed exam room.',
                style: SignageTypography.body(
                  fontSize: 14,
                  color: SignageColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'MOCK EXAM CATALOG',
          trailing: PlacardBadge.info(activeCode),
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
            data: (exams) {
              if (exams.isEmpty) {
                return const StateBlock(
                  stamp: 'EMPTY',
                  title: 'NO MOCK EXAMS AVAILABLE',
                  description:
                      'No mock exams are currently published for this certificate.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < exams.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _MockExamRow(exam: exams[i]),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'RESUME BY AUTHORIZATION CODE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter an authorization code to unlock and resume an interrupted mock attempt.',
                style: SignageTypography.body(
                  fontSize: 13,
                  color: SignageColors.inkMuted,
                ),
              ),
              const SizedBox(height: 10),
              if (resumeError != null) ...[
                PlacardAlert(
                  variant: PlacardAlertVariant.danger,
                  title: 'RESUME FAILED',
                  subtitle: resumeError!,
                ),
                const SizedBox(height: 10),
              ],
              FTextField(
                key: const Key('resume-auth-code-input'),
                control:
                    FTextFieldControl.managed(controller: authCodeController),
                hint: 'Authorization code (e.g. AUTH-901)',
              ),
              const SizedBox(height: 10),
              PlacardButton(
                key: const Key('resume-auth-code-btn'),
                label: resumingCode ? 'RESUMING...' : 'RESUME ATTEMPT',
                onPress: resumingCode ? null : onResumeWithCode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MockExamRow extends StatelessWidget {
  const _MockExamRow({required this.exam});

  final MockExamSummary exam;

  @override
  Widget build(BuildContext context) {
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
                    exam.title,
                    style: SignageTypography.condensedSentence(fontSize: 16),
                  ),
                ),
                PlacardBadge.info('${exam.credits} CREDITS'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${exam.durationMinutes} MIN · ${exam.questionCount} QUESTIONS',
              style: SignageTypography.data(
                fontSize: 12,
                color: SignageColors.inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            if (exam.inProgressAttemptId != null)
              PlacardButton(
                key: Key('resume-mock-exam-${exam.examId}'),
                label: 'RESUME IN-PROGRESS',
                variant: PlacardButtonVariant.secondary,
                onPress: () => context
                    .push('/exams/attempts/${exam.inProgressAttemptId}'),
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
      data: (attempts) {
        if (attempts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: StateBlock(
              stamp: 'EMPTY',
              title: 'NO ATTEMPTS YET',
              description:
                  'Complete a mock attempt to view your score placard and answer review here.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: attempts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = attempts[index];
            return PlacardPanel(
              title: item.examTitle,
              trailing: item.overallBand != null
                  ? PlacardBadge.info(item.overallBand!)
                  : PlacardBadge.muted(item.status),
              footer: Row(
                children: [
                  if (item.isInProgress)
                    Expanded(
                      child: PlacardButton(
                        key: Key('history-resume-${item.attemptId}'),
                        label: 'RESUME',
                        onPress: () =>
                            context.push('/exams/attempts/${item.attemptId}'),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: PlacardButton(
                        key: Key('history-result-${item.attemptId}'),
                        label: 'RESULT',
                        variant: PlacardButtonVariant.secondary,
                        onPress: () => context
                            .push('/exams/attempts/${item.attemptId}/result'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PlacardButton(
                        key: Key('history-review-${item.attemptId}'),
                        label: 'REVIEW',
                        onPress: () => context
                            .push('/exams/attempts/${item.attemptId}/review'),
                      ),
                    ),
                  ],
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.status,
                    style: SignageTypography.label(
                      fontSize: 12,
                      color: SignageColors.inkMuted,
                    ),
                  ),
                  if (item.totalScaledScore != null)
                    Text(
                      '${item.totalScaledScore}',
                      style: SignageTypography.data(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
