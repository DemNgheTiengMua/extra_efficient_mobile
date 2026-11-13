import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../context/learner_context_provider.dart';
import '../providers/mock_exam_providers.dart';

/// Displays Mock Exam instructions, section breakdown, and credit cost
/// before calling `POST /api/learner/exams/{examId}/start`.
class MockInstructionsScreen extends ConsumerStatefulWidget {
  const MockInstructionsScreen({super.key, required this.examId});

  final int examId;

  @override
  ConsumerState<MockInstructionsScreen> createState() =>
      _MockInstructionsScreenState();
}

class _MockInstructionsScreenState
    extends ConsumerState<MockInstructionsScreen> {
  bool _starting = false;
  String? _error;

  Future<void> _startAttempt() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final attemptId = await ref
          .read(mockExamRepositoryProvider)
          .startAttempt(widget.examId);
      ref.invalidate(learnerContextProvider);
      if (!mounted) return;
      context.go('/exams/attempts/$attemptId/preflight');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _starting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final instructionsAsync = ref.watch(
      mockInstructionsProvider(widget.examId),
    );

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
                  onPress: () => context.pop(),
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
                      'BACK',
                      style: SignageTypography.label(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'MOCK EXAM INSTRUCTIONS',
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
      child: instructionsAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: StateBlock(
            stamp: 'ERROR',
            title: 'UNABLE TO LOAD INSTRUCTIONS',
            description: err.toString(),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () =>
                  ref.invalidate(mockInstructionsProvider(widget.examId)),
            ),
          ),
        ),
        data: (info) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              PlacardAlert(
                variant: PlacardAlertVariant.danger,
                title: 'START FAILED',
                subtitle: _error!,
              ),
              const SizedBox(height: 12),
            ],
            PlacardPanel(
              title: info.examName,
              trailing: PlacardBadge.info('${info.creditCost} CREDITS'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      '${info.durationMinutes} MIN',
                      if (info.questionCount != null)
                        '${info.questionCount} QUESTIONS',
                    ].join(' · '),
                    style: SignageTypography.data(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (info.description != null &&
                      info.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      info.description!,
                      style: SignageTypography.body(fontSize: 14),
                    ),
                  ],
                  if (info.sections.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final s in info.sections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.name,
                              style: SignageTypography.body(fontSize: 14),
                            ),
                            Text(
                              '${s.questionCount} Q',
                              style: SignageTypography.data(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            PlacardPanel(
              title: 'BEFORE YOU START',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starting charges ${info.creditCost} credits from your '
                    'balance of ${info.creditBalance}. The clock begins when '
                    'you enter the room.',
                    style: SignageTypography.body(fontSize: 14),
                  ),
                  if (info.hasActiveAttempt) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Attempt ${info.activeAttemptId} on this exam is still in progress.',
                      style: SignageTypography.body(
                        fontSize: 14,
                        color: SignageColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            PlacardButton(
              key: const Key('start-mock-attempt-btn'),
              label: _starting
                  ? 'STARTING...'
                  : 'START MOCK ATTEMPT (${info.creditCost} CREDITS)',
              onPress: _starting ? null : _startAttempt,
            ),
          ],
        ),
      ),
    );
  }
}
