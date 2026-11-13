import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/mock_exam_models.dart';
import '../providers/mock_exam_providers.dart';

enum _ReviewFilter { all, wrong, flagged }

/// Full Answer Review screen with All/Wrong/Flagged filters, wrong-answer
/// rationale, transcript, single-question audio slice replay, and Save Question.
class MockReviewScreen extends ConsumerStatefulWidget {
  const MockReviewScreen({super.key, required this.attemptId});

  final int attemptId;

  @override
  ConsumerState<MockReviewScreen> createState() => _MockReviewScreenState();
}

class _MockReviewScreenState extends ConsumerState<MockReviewScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;
  final Set<int> _savedQuestionIds = {};

  Future<void> _playSlice(MockReviewQuestion q) async {
    if (q.audioUrl == null || q.audioUrl!.isEmpty) return;
    final audio = ref.read(audioMediaAdapterProvider);
    await audio.setAudioUrl(
      q.audioUrl!,
      clipStart:
          q.audioStartMs != null ? Duration(milliseconds: q.audioStartMs!) : null,
      clipEnd:
          q.audioEndMs != null ? Duration(milliseconds: q.audioEndMs!) : null,
    );
    await audio.play();
  }

  Future<void> _saveQuestion(int questionId) async {
    await ref.read(mockExamRepositoryProvider).saveQuestion(questionId);
    if (!mounted) return;
    setState(() {
      _savedQuestionIds.add(questionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync = ref.watch(mockReviewProvider(widget.attemptId));

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
                    'ANSWER REVIEW',
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
      child: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: StateBlock(
            stamp: 'ERROR',
            title: 'UNABLE TO LOAD REVIEW',
            description: err.toString(),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () =>
                  ref.invalidate(mockReviewProvider(widget.attemptId)),
            ),
          ),
        ),
        data: (review) {
          final filtered = review.questions.where((q) {
            return switch (_filter) {
              _ReviewFilter.all => true,
              _ReviewFilter.wrong => !q.isCorrect,
              _ReviewFilter.flagged => q.isFlagged,
            };
          }).toList();

          return Column(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: SignageColors.paper,
                  border: Border(
                    bottom: BorderSide(color: SignageColors.ink, width: 2),
                  ),
                ),
                child: Row(
                  children: [
                    _filterTab(_ReviewFilter.all, 'ALL', 'review-filter-all'),
                    _filterTab(
                      _ReviewFilter.wrong,
                      'WRONG',
                      'review-filter-wrong',
                    ),
                    _filterTab(
                      _ReviewFilter.flagged,
                      'FLAGGED',
                      'review-filter-flagged',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: StateBlock(
                          stamp: 'EMPTY',
                          title: 'NO MATCHING QUESTIONS',
                          description:
                              'No questions match the selected filter.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final q = filtered[index];
                          final isSaved =
                              _savedQuestionIds.contains(q.questionId);
                          return PlacardPanel(
                            title: 'Q${q.index + 1} · ${q.skill}',
                            trailing: q.isCorrect
                                ? const PlacardBadge.success('CORRECT')
                                : const PlacardBadge.danger('WRONG'),
                            footer: Row(
                              children: [
                                if (q.audioUrl != null &&
                                    q.audioUrl!.isNotEmpty) ...[
                                  Expanded(
                                    child: PlacardButton(
                                      key: Key(
                                        'review-play-audio-${q.questionId}',
                                      ),
                                      label: 'REPLAY SLICE',
                                      variant: PlacardButtonVariant.secondary,
                                      onPress: () => unawaited(_playSlice(q)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: PlacardButton(
                                    key: Key(
                                      'review-save-question-${q.questionId}',
                                    ),
                                    label: isSaved ? 'SAVED' : 'SAVE QUESTION',
                                    onPress: isSaved
                                        ? null
                                        : () => unawaited(
                                              _saveQuestion(q.questionId),
                                            ),
                                  ),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q.prompt,
                                  style: SignageTypography.body(fontSize: 15),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'YOURS: ${q.selectedOptionLabel ?? '-'} · CORRECT: ${q.correctOptionLabel ?? '-'}',
                                  style: SignageTypography.data(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (q.wrongOptionRationale != null &&
                                    q.wrongOptionRationale!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  PlacardAlert(
                                    variant: PlacardAlertVariant.danger,
                                    title: 'WHY YOUR OPTION WAS WRONG',
                                    subtitle: q.wrongOptionRationale!,
                                  ),
                                ],
                                if (q.explanation != null &&
                                    q.explanation!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    q.explanation!,
                                    style: SignageTypography.body(fontSize: 14),
                                  ),
                                ],
                                if (q.transcript != null &&
                                    q.transcript!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    q.transcript!,
                                    style: SignageTypography.body(
                                      fontSize: 13,
                                      color: SignageColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterTab(_ReviewFilter value, String label, String keyName) {
    final selected = _filter == value;
    return Expanded(
      child: FTappable(
        key: Key(keyName),
        onPress: () => setState(() => _filter = value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? SignageColors.ink : SignageColors.paper,
            border: const Border(
              right: BorderSide(color: SignageColors.lineSoft, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
