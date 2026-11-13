import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../models/practice_models.dart';
import '../providers/practice_providers.dart';

class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<PracticeSessionScreen> createState() =>
      _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends ConsumerState<PracticeSessionScreen> {
  bool _loading = true;
  String? _error;
  PracticeSessionTake? _session;
  int _currentIndex = 0;

  final Map<int, int> _selectedOptions = {};
  final Map<int, String> _writingResponses = {};
  final Map<int, TextEditingController> _writingControllers = {};
  final Map<int, int?> _savedQuestionIds = {};
  final Map<int, String> _hints = {};
  final Map<int, PracticeAnswerResult> _results = {};
  bool _submitting = false;
  bool _isPlayingAudio = false;
  String? _bookmarkError;

  bool _showingSummary = false;
  PracticeSummary? _summary;
  PracticeInsight? _insight;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    for (final c in _writingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int questionId) {
    return _writingControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: _writingResponses[questionId] ?? ''),
    );
  }

  /// The address the backend gave this question: its row id, else the pinned
  /// item version. A pool item has no row id, and `0` would 404.
  int _addressOf(PracticeQuestion q) => q.address ?? q.displayOrder;

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  Future<void> _toggleBookmark(PracticeQuestion q) async {
    final key = _addressOf(q);
    final currentSavedId = _savedQuestionIds[key] ?? q.savedQuestionId;
    final repo = ref.read(practiceRepositoryProvider);
    try {
      if (currentSavedId != null && currentSavedId > 0) {
        await repo.deleteSavedQuestion(currentSavedId);
        if (!mounted) return;
        setState(() => _savedQuestionIds[key] = null);
      } else {
        // Save by the address the question actually holds: POSTing a pool
        // item's 0 to the questions route files nothing.
        final result = await repo.saveQuestionAddress(
          questionId: q.questionId,
          itemVersionId: q.itemVersionId,
        );
        if (!mounted) return;
        setState(() => _savedQuestionIds[key] = result.savedQuestionId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookmarkError =
            extractApiError(e, fallback: 'Could not update saved question');
      });
    }
  }

  Future<void> _loadSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final take = await ref
          .read(practiceRepositoryProvider)
          .fetchSessionTake(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = take;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _playAudio(PracticeQuestion q) async {
    final url = q.audioUrl;
    if (url == null || url.isEmpty) return;
    final audio = ref.read(audioMediaAdapterProvider);
    await audio.setAudioUrl(
      url,
      clipStart: q.clipStartMs != null
          ? Duration(milliseconds: q.clipStartMs!)
          : null,
      clipEnd:
          q.clipEndMs != null ? Duration(milliseconds: q.clipEndMs!) : null,
    );
    await audio.play();
    if (mounted) {
      setState(() => _isPlayingAudio = true);
    }
  }

  Future<void> _stopAudio() async {
    await ref.read(audioMediaAdapterProvider).stop();
    if (mounted) {
      setState(() => _isPlayingAudio = false);
    }
  }

  Future<void> _requestHint(PracticeQuestion q) async {
    final hint = await ref
        .read(practiceRepositoryProvider)
        .requestHint(widget.sessionId, _addressOf(q));
    if (!mounted) return;
    setState(() {
      _hints[_addressOf(q)] = hint;
    });
  }

  Future<void> _submitAnswer(PracticeQuestion q) async {
    if (_submitting) return;
    if (q.isWriting) {
      final text = (_writingResponses[_addressOf(q)] ?? '').trim();
      if (text.isEmpty) return;
      setState(() => _submitting = true);
      try {
        final result = await ref.read(practiceRepositoryProvider).submitAnswer(
              widget.sessionId,
              _addressOf(q),
              selectedOptionId: null,
              responseText: text,
            );
        if (!mounted) return;
        setState(() {
          _results[_addressOf(q)] = result;
        });
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    final selectedId = _selectedOptions[_addressOf(q)];
    if (selectedId == null) return;
    setState(() => _submitting = true);
    try {
      final result = await ref.read(practiceRepositoryProvider).submitAnswer(
            widget.sessionId,
            _addressOf(q),
            selectedOptionId: selectedId,
          );
      if (!mounted) return;
      setState(() {
        _results[_addressOf(q)] = result;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openSummary() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(practiceRepositoryProvider);
      final summary = await repo.fetchSummary(widget.sessionId);
      PracticeInsight? insight;
      try {
        insight = await repo.fetchInsight(widget.sessionId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _insight = insight;
        _showingSummary = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _retryInsight() async {
    final updated = await ref
        .read(practiceRepositoryProvider)
        .retryInsight(widget.sessionId);
    if (!mounted) return;
    setState(() => _insight = updated);
  }

  @override
  Widget build(BuildContext context) {
    final title = _session?.title ?? 'PRACTICE SESSION #${widget.sessionId}';

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(
          title,
          style: SignageTypography.title().copyWith(fontSize: 18),
        ),
        prefixes: [
          FHeaderAction.back(
            key: const Key('session-back-button'),
            onPress: () => context.pop(),
          ),
        ],
      ),
      child: Container(
        color: SignageColors.wall,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: FCircularProgress());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: StateBlock(
          stamp: 'ERROR',
          title: 'Could not load session',
          description: _error!,
          action: PlacardButton(label: 'RETRY', onPress: _loadSession),
        ),
      );
    }
    if (_showingSummary && _summary != null) {
      return _SummaryView(
        summary: _summary!,
        insight: _insight,
        onRetryInsight: _retryInsight,
        onDone: () => context.pop(),
      );
    }
    final session = _session;
    if (session == null || session.questions.isEmpty) {
      return const Center(
        child: StateBlock(
          stamp: 'SESSION',
          title: 'Practice Session Ready',
          description: 'No questions loaded in this session.',
        ),
      );
    }

    final q = session.questions[_currentIndex];
    final selectedId = _selectedOptions[_addressOf(q)];
    final writingText = _writingResponses[_addressOf(q)] ?? '';
    final wordCount = _countWords(writingText);
    final isSaved =
        (_savedQuestionIds[_addressOf(q)] ?? q.savedQuestionId ?? 0) > 0;
    final result = _results[_addressOf(q)];
    final hint = _hints[_addressOf(q)];
    final isLast = _currentIndex == session.questions.length - 1;
    final isImmediate = session.feedbackMode == PracticeFeedbackMode.immediate;
    final canSubmit = q.isWriting
        ? writingText.trim().isNotEmpty
        : selectedId != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            PlacardBadge.info(
              'Q${_currentIndex + 1}/${session.questions.length}',
            ),
            const SizedBox(width: 8),
            PlacardBadge.muted(session.feedbackMode.label),
            const Spacer(),
            PlacardButton(
              key: Key('bookmark-question-${_addressOf(q)}'),
              label: isSaved ? 'SAVED' : 'SAVE QUESTION',
              variant: isSaved
                  ? PlacardButtonVariant.ink
                  : PlacardButtonVariant.secondary,
              expand: false,
              onPress: () => _toggleBookmark(q),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_bookmarkError != null) ...[
          PlacardAlert(
            key: const Key('bookmark-error'),
            title: _bookmarkError!,
            variant: PlacardAlertVariant.danger,
          ),
          const SizedBox(height: 12),
        ],
        if (q.audioUrl != null && q.audioUrl!.isNotEmpty) ...[
          PlacardPanel(
            title: 'AUDIO TRACK',
            child: Row(
              children: [
                Expanded(
                  child: PlacardButton(
                    key: const Key('practice-play-audio'),
                    label: _isPlayingAudio ? 'STOP AUDIO' : 'PLAY AUDIO',
                    variant: _isPlayingAudio
                        ? PlacardButtonVariant.ink
                        : PlacardButtonVariant.primary,
                    onPress: () =>
                        _isPlayingAudio ? _stopAudio() : _playAudio(q),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        PlacardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (q.passageText != null && q.passageText!.isNotEmpty) ...[
                Text(q.passageText!, style: SignageTypography.body()),
                const SizedBox(height: 12),
                const Divider(color: SignageColors.lineSoft, height: 1),
                const SizedBox(height: 12),
              ],
              Text(
                q.stem,
                style: SignageTypography.body(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (q.isWriting) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (q.wordFloor != null)
                      PlacardBadge.info('MIN ${q.wordFloor} WORDS'),
                    PlacardBadge(
                      label: '$wordCount WORDS',
                      variant: q.wordFloor == null || wordCount >= q.wordFloor!
                          ? PlacardBadgeVariant.success
                          : PlacardBadgeVariant.warning,
                    ),
                  ],
                ),
                if (q.requiredKeywords.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('REQUIRED KEYWORDS', style: SignageTypography.label()),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final kw in q.requiredKeywords)
                        PlacardBadge(
                          label: kw,
                          variant: writingText
                                  .toLowerCase()
                                  .contains(kw.toLowerCase())
                              ? PlacardBadgeVariant.success
                              : PlacardBadgeVariant.muted,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                FTextField.multiline(
                  key: const Key('writing-response-input'),
                  control: FTextFieldControl.managed(
                    controller: _controllerFor(_addressOf(q)),
                    onChange: (value) {
                      setState(() {
                        _writingResponses[_addressOf(q)] = value.text;
                      });
                    },
                  ),
                  hint: 'Write your response here...',
                  minLines: 4,
                  maxLines: 8,
                  enabled: !(result != null && isImmediate),
                ),
              ] else ...[
                for (final opt in q.options) ...[
                  _OptionTile(
                    option: opt,
                    selected: selectedId == opt.optionId,
                    isCorrectOption:
                        isImmediate && result?.correctOptionId == opt.optionId,
                    isWrongSelected: isImmediate &&
                        result != null &&
                        !result.isCorrect &&
                        selectedId == opt.optionId,
                    onTap: result != null && isImmediate
                        ? null
                        : () {
                            setState(() {
                              _selectedOptions[_addressOf(q)] = opt.optionId;
                            });
                          },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (hint != null && hint.isNotEmpty) ...[
          PlacardAlert(
            title: 'HINT',
            subtitle: hint,
            variant: PlacardAlertVariant.warning,
          ),
          const SizedBox(height: 12),
        ] else ...[
          PlacardButton(
            label: 'REQUEST HINT',
            variant: PlacardButtonVariant.secondary,
            onPress: () => _requestHint(q),
          ),
          const SizedBox(height: 12),
        ],
        if (result == null)
          PlacardButton(
            label: isImmediate ? 'CHECK ANSWER' : 'SUBMIT ANSWER',
            isLoading: _submitting,
            onPress: !canSubmit ? null : () => _submitAnswer(q),
          ),
        if (result != null && isImmediate) ...[
          PlacardAlert(
            title: result.isCorrect ? 'CORRECT' : 'INCORRECT',
            subtitle: result.generalExplanation,
            variant: result.isCorrect
                ? PlacardAlertVariant.success
                : PlacardAlertVariant.danger,
          ),
          if (result.selectedOptionRationale != null) ...[
            const SizedBox(height: 8),
            PlacardPanel(
              title: 'OPTION RATIONALE',
              child: Text(
                result.selectedOptionRationale!,
                style: SignageTypography.body(fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (result != null)
          PlacardButton(
            label: isLast ? 'VIEW SUMMARY' : 'NEXT QUESTION',
            variant: PlacardButtonVariant.ink,
            onPress: isLast
                ? _openSummary
                : () {
                    setState(() {
                      _currentIndex++;
                      _isPlayingAudio = false;
                    });
                  },
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.isCorrectOption,
    required this.isWrongSelected,
    this.onTap,
  });

  final PracticeOption option;
  final bool selected;
  final bool isCorrectOption;
  final bool isWrongSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = SignageColors.paper;
    Color fg = SignageColors.ink;
    Color border = SignageColors.ink;

    if (isCorrectOption) {
      bg = SignageColors.greenWash;
      border = SignageColors.signGreen;
    } else if (isWrongSelected) {
      bg = SignageColors.redWash;
      border = SignageColors.signRed;
    } else if (selected) {
      bg = SignageColors.ink;
      fg = SignageColors.paper;
    }

    return FTappable(
      onPress: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            '${option.label}. ${option.text}',
            style: SignageTypography.body(fontSize: 15, color: fg),
          ),
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.summary,
    required this.insight,
    required this.onRetryInsight,
    required this.onDone,
  });

  final PracticeSummary summary;
  final PracticeInsight? insight;
  final VoidCallback onRetryInsight;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PlacardPanel(
          backgroundColor: SignageColors.signBlue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary.accuracyPercent}%',
                style: SignageTypography.displayScore(),
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.correctCount}/${summary.totalCount} CORRECT',
                style: SignageTypography.label(
                  fontSize: 13,
                  color: SignageColors.bandScoreCaption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (insight != null) ...[
          PlacardPanel(
            title: 'AI PRACTICE INSIGHT',
            child: insight!.status == 'ready' && insight!.narrative != null
                ? Text(insight!.narrative!, style: SignageTypography.body())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlacardAlert(
                        title: 'Insight unavailable',
                        subtitle: insight!.errorMessage ?? 'Could not generate.',
                        variant: PlacardAlertVariant.warning,
                      ),
                      const SizedBox(height: 12),
                      PlacardButton(
                        label: 'RETRY INSIGHT',
                        variant: PlacardButtonVariant.secondary,
                        onPress: onRetryInsight,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
        ],
        PlacardPanel(
          title: 'QUESTION BREAKDOWN',
          child: Column(
            children: [
              for (final item in summary.items) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    item.isCorrect
                        ? const PlacardBadge.success('CORRECT')
                        : const PlacardBadge.danger('WRONG'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.stem,
                            style: SignageTypography.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.generalExplanation != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.generalExplanation!,
                              style: SignageTypography.body(
                                fontSize: 13,
                                color: SignageColors.inkMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PlacardButton(label: 'DONE', onPress: onDone),
      ],
    );
  }
}
