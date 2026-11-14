import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
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
  PracticeSessionTake? _take;
  int _currentIndex = 0;

  final Map<int, int> _selectedOptions = {};
  final Map<int, String> _writingResponses = {};
  final Map<int, TextEditingController> _writingControllers = {};

  /// address → savedQuestionId. Seeded from the take payload so a question that
  /// arrived already saved can be un-saved rather than re-saved.
  final Map<int, int?> _savedQuestionIds = {};

  final Map<int, String> _hints = {};
  final Map<int, PracticeAnswerResult> _results = {};

  bool _submitting = false;
  bool _requestingHint = false;
  bool _isPlayingAudio = false;

  /// The backend's own refusal for the last write, kept per action so a failed
  /// submit and a failed hint each report their own sentence.
  String? _writeError;

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

  TextEditingController _controllerFor(int address) {
    return _writingControllers.putIfAbsent(
      address,
      () => TextEditingController(text: _writingResponses[address] ?? ''),
    );
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  List<PracticeQuestion> get _questions => _take?.questions ?? const [];

  PracticeQuestion? get _question =>
      _currentIndex < _questions.length ? _questions[_currentIndex] : null;

  bool _isSaved(PracticeQuestion q) =>
      _savedQuestionIds.containsKey(q.address)
          ? _savedQuestionIds[q.address] != null
          : q.isSaved;

  Future<void> _toggleBookmark(PracticeQuestion q) async {
    final address = q.address;
    final savedId = _savedQuestionIds.containsKey(address)
        ? _savedQuestionIds[address]
        : q.savedQuestionId;
    final repo = ref.read(practiceRepositoryProvider);
    try {
      if (savedId != null) {
        await repo.deleteSavedQuestion(savedId);
        if (!mounted) return;
        setState(() => _savedQuestionIds[address] = null);
      } else {
        // Save by whichever handle the question holds: a pool item has no row
        // id, and filing its 0 against the questions route saves nothing.
        final result = await repo.saveQuestionAddress(
          questionId: q.questionId,
          itemVersionId: q.itemVersionId,
        );
        if (!mounted) return;
        setState(
          () => _savedQuestionIds[address] =
              result.isSaved ? result.savedQuestionId : null,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _writeError = extractApiError(
          e,
          fallback: 'Could not update saved question',
        );
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
        _take = take;
        // Open on the question the server names as current, so a resumed
        // session continues where it was left rather than restarting at Q1.
        final opening = take.openingQuestion;
        _currentIndex = opening == null
            ? 0
            : take.questions.indexWhere((q) => q.address == opening.address);
        if (_currentIndex < 0) _currentIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractApiError(
          e,
          fallback: 'The session could not be loaded.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _playAudio(PracticeQuestion q) async {
    final path = q.audioPath;
    if (path == null || path.isEmpty) return;
    final audio = ref.read(audioMediaAdapterProvider);
    try {
      await audio.setAudioUrl(
        path,
        clipStart: q.audioStartMs != null
            ? Duration(milliseconds: q.audioStartMs!)
            : null,
        clipEnd:
            q.audioEndMs != null ? Duration(milliseconds: q.audioEndMs!) : null,
      );
      await audio.play();
      if (!mounted) return;
      setState(() => _isPlayingAudio = true);
    } catch (e) {
      // A path the backend cannot serve must not crash the room, and must not
      // look like a working player either.
      if (!mounted) return;
      setState(() {
        _writeError = extractApiError(e, fallback: 'The audio could not play.');
      });
    }
  }

  Future<void> _stopAudio() async {
    await ref.read(audioMediaAdapterProvider).stop();
    if (!mounted) return;
    setState(() => _isPlayingAudio = false);
  }

  Future<void> _requestHint(PracticeQuestion q) async {
    if (_requestingHint) return;
    setState(() {
      _requestingHint = true;
      _writeError = null;
    });
    try {
      final hint = await ref
          .read(practiceRepositoryProvider)
          .requestHint(widget.sessionId, q.address);
      if (!mounted) return;
      setState(() => _hints[q.address] = hint);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _writeError = extractApiError(
          e,
          fallback: 'The hint could not be revealed.',
        );
      });
    } finally {
      if (mounted) setState(() => _requestingHint = false);
    }
  }

  Future<void> _submitAnswer(PracticeQuestion q) async {
    if (_submitting) return;
    final address = q.address;
    final text = (_writingResponses[address] ?? '').trim();
    final selectedId = _selectedOptions[address];
    if (q.isWriting ? text.isEmpty : selectedId == null) return;

    setState(() {
      _submitting = true;
      _writeError = null;
    });
    try {
      final result = await ref.read(practiceRepositoryProvider).submitAnswer(
            widget.sessionId,
            address,
            selectedOptionId: q.isWriting ? null : selectedId,
            responseText: q.isWriting ? text : null,
          );
      if (!mounted) return;
      setState(() {
        _results[address] = result;
        // The backend answers a saved question with its bookmark row id.
        if (result.isSaved && result.savedQuestionId != null) {
          _savedQuestionIds[address] = result.savedQuestionId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _writeError = extractApiError(
          e,
          fallback: 'The answer could not be submitted.',
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(practiceRepositoryProvider);
    try {
      final summary = await repo.fetchSummary(widget.sessionId);
      PracticeInsight? insight;
      try {
        insight = await repo.fetchInsight(widget.sessionId);
      } catch (_) {
        // The insight is a bonus; its absence must not hide the score.
      }
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
        _error = extractApiError(
          e,
          fallback: 'The summary could not be loaded.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _retryInsight() async {
    try {
      final updated = await ref
          .read(practiceRepositoryProvider)
          .retryInsight(widget.sessionId);
      if (!mounted) return;
      setState(() => _insight = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _insight = PracticeInsight(
          status: 'failed',
          errorMessage: extractApiError(
            e,
            fallback: 'The insight could not be generated.',
          ),
        );
      });
    }
  }

  void _goToNext(PracticeAnswerResult result) {
    // The backend names the next display order; fall back to the next row.
    final next = result.nextQuestionDisplayOrder;
    final index = next == null
        ? _currentIndex + 1
        : _questions.indexWhere((q) => q.displayOrder == next);
    setState(() {
      _currentIndex = index >= 0 && index < _questions.length
          ? index
          : _currentIndex + 1;
      _isPlayingAudio = false;
      _writeError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _take?.session;
    final title = session == null || session.sectionName.isEmpty
        ? 'PRACTICE SESSION #${widget.sessionId}'
        : '${session.sectionCode} · ${session.sectionName}';

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
    final q = _question;
    if (q == null) {
      return const Center(
        child: StateBlock(
          stamp: 'SESSION',
          title: 'No questions in this session',
          description:
              'This drill arrived without a question. Go back and start another.',
        ),
      );
    }

    final address = q.address;
    final selectedId = _selectedOptions[address];
    final writingText = _writingResponses[address] ?? '';
    final wordCount = _countWords(writingText);
    final result = _results[address];
    final hint = _hints[address] ?? q.hint;
    final hintRequested = _hints.containsKey(address) || q.hintUsed;
    final isLast = _currentIndex == _questions.length - 1;
    final isSaved = _isSaved(q);
    final canSubmit = q.isWriting
        ? writingText.trim().isNotEmpty
        : selectedId != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            PlacardBadge.info('Q${q.displayOrder}/${q.totalQuestions}'),
            const SizedBox(width: 8),
            if (q.cefrLevelCode != null)
              PlacardBadge.muted(q.cefrLevelCode!),
            const Spacer(),
            PlacardButton(
              key: Key('bookmark-question-$address'),
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
        if (_writeError != null) ...[
          PlacardAlert(
            key: const Key('practice-write-error'),
            title: 'Action failed',
            subtitle: _writeError,
            variant: PlacardAlertVariant.danger,
          ),
          const SizedBox(height: 12),
        ],
        if (q.audioPath != null && q.audioPath!.isNotEmpty) ...[
          PlacardPanel(
            title: 'AUDIO TRACK',
            child: PlacardButton(
              key: const Key('practice-play-audio'),
              label: _isPlayingAudio ? 'STOP AUDIO' : 'PLAY AUDIO',
              variant: _isPlayingAudio
                  ? PlacardButtonVariant.ink
                  : PlacardButtonVariant.primary,
              onPress: () => _isPlayingAudio ? _stopAudio() : _playAudio(q),
            ),
          ),
          const SizedBox(height: 12),
        ],
        PlacardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // P1/P2 photographs and similar items carry an image the learner
              // must look at. It was parsed but never rendered, so a photo
              // question showed only its stem.
              if (q.imagePath != null && q.imagePath!.isNotEmpty) ...[
                _QuestionImage(path: q.imagePath!, altText: q.imageAlt),
                const SizedBox(height: 12),
                const Divider(color: SignageColors.lineSoft, height: 1),
                const SizedBox(height: 12),
              ],
              if (q.passage != null && q.passage!.isNotEmpty) ...[
                Text(q.passage!, style: SignageTypography.body()),
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
                    if (q.minWords != null)
                      PlacardBadge.info('MIN ${q.minWords} WORDS'),
                    if (q.maxWords != null)
                      PlacardBadge.muted('MAX ${q.maxWords} WORDS'),
                    PlacardBadge(
                      label: '$wordCount WORDS',
                      variant:
                          q.minWords == null || wordCount >= q.minWords!
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
                    controller: _controllerFor(address),
                    onChange: (value) {
                      setState(() => _writingResponses[address] = value.text);
                    },
                  ),
                  hint: 'Write your response here...',
                  minLines: 4,
                  maxLines: 8,
                  enabled: result == null,
                ),
              ] else ...[
                for (final opt in q.options) ...[
                  _OptionTile(
                    option: opt,
                    selected: selectedId == opt.optionId,
                    isCorrectOption: result?.correctOptionId == opt.optionId,
                    isWrongSelected: result != null &&
                        result.isCorrect == false &&
                        selectedId == opt.optionId,
                    onTap: result != null
                        ? null
                        : () {
                            setState(() {
                              _selectedOptions[address] = opt.optionId;
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
            key: const Key('practice-hint'),
            title: 'HINT',
            subtitle: hint,
            variant: PlacardAlertVariant.warning,
          ),
          const SizedBox(height: 12),
        ] else if (hintRequested) ...[
          // `hintUsed` can be true beside a null `hint`: the item has none.
          const PlacardAlert(
            key: Key('practice-hint-empty'),
            title: 'No hint for this question',
            variant: PlacardAlertVariant.info,
          ),
          const SizedBox(height: 12),
        ] else ...[
          PlacardButton(
            key: const Key('practice-request-hint'),
            label: 'REQUEST HINT',
            variant: PlacardButtonVariant.secondary,
            isLoading: _requestingHint,
            onPress: result != null ? null : () => _requestHint(q),
          ),
          const SizedBox(height: 12),
        ],
        if (result == null)
          PlacardButton(
            label: 'CHECK ANSWER',
            isLoading: _submitting,
            onPress: !canSubmit ? null : () => _submitAnswer(q),
          )
        else ...[
          PlacardAlert(
            key: const Key('practice-result'),
            title: switch (result.isCorrect) {
              true => 'CORRECT',
              false => 'INCORRECT',
              // A productive answer is recorded but not graded: saying "wrong"
              // would be a claim the backend did not make.
              null => 'ANSWER RECORDED',
            },
            subtitle: result.explanation,
            variant: switch (result.isCorrect) {
              true => PlacardAlertVariant.success,
              false => PlacardAlertVariant.danger,
              null => PlacardAlertVariant.info,
            },
          ),
          if (result.correctOptionId != null) ...[
            const SizedBox(height: 8),
            PlacardPanel(
              title: 'CORRECT ANSWER',
              child: Text(
                _optionLabelFor(q, result.correctOptionId!),
                style: SignageTypography.body(fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 12),
          PlacardButton(
            label: result.isSessionFinished || isLast
                ? 'VIEW SUMMARY'
                : 'NEXT QUESTION',
            variant: PlacardButtonVariant.ink,
            onPress: result.isSessionFinished || isLast
                ? _openSummary
                : () => _goToNext(result),
          ),
        ],
      ],
    );
  }

  /// The correct option as the learner saw it, e.g. `B. On the table.`
  String _optionLabelFor(PracticeQuestion q, int optionId) {
    for (final opt in q.options) {
      if (opt.optionId == optionId) {
        return opt.text.isEmpty ? opt.label : '${opt.label}. ${opt.text}';
      }
    }
    return 'Option $optionId';
  }
}

class _QuestionImage extends ConsumerWidget {
  const _QuestionImage({required this.path, this.altText});

  /// The server's `imagePath`. It is either absolute or root-relative; the
  /// latter is resolved against the API base so the emulator's tunnel works.
  final String path;
  final String? altText;

  String get _url {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignageColors.paper,
        border: Border.all(color: SignageColors.ink, width: 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: Image.network(
          _url,
          key: const Key('practice-question-image'),
          fit: BoxFit.contain,
          semanticLabel: altText,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 120,
                  child: Center(child: FCircularProgress()),
                ),
          // A missing image must not break the drill: say so and keep the
          // question answerable.
          errorBuilder: (context, error, stack) => Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              altText == null || altText!.isEmpty
                  ? 'The image for this question could not be loaded.'
                  : 'Image unavailable — $altText',
              style: SignageTypography.body(
                fontSize: 13,
                color: SignageColors.inkMuted,
              ),
            ),
          ),
        ),
      ),
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
                '${summary.accuracyPercentage}%',
                style: SignageTypography.displayScore(),
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.correctCount}/${summary.totalQuestions} CORRECT',
                style: SignageTypography.label(
                  fontSize: 13,
                  color: SignageColors.bandScoreCaption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PlacardPanel(
          child: Row(
            children: [
              _SummaryStat(
                label: 'ANSWERED',
                value: '${summary.answeredCount}',
              ),
              _SummaryStat(
                label: 'SKIPPED',
                value: '${summary.skippedCount}',
              ),
              _SummaryStat(
                label: 'HINTS',
                value: '${summary.hintUsedCount}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (insight != null) ...[
          PlacardPanel(
            title: 'AI PRACTICE INSIGHT',
            trailing: insight!.isFailed
                ? const PlacardBadge.danger('FAILED')
                : (insight!.narrative != null
                      ? const PlacardBadge.success('READY')
                      : const PlacardBadge.warning('PENDING')),
            // AiInsightStatusDto is pending|done|failed. A `done` insight with
            // prose is the success path; only a failed one may be retried - the
            // backend rejects a retry of anything else with 400.
            child: insight!.narrative != null
                ? Text(insight!.narrative!, style: SignageTypography.body())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlacardAlert(
                        title: insight!.isFailed
                            ? 'Insight unavailable'
                            : 'Insight still generating',
                        subtitle: insight!.errorMessage ??
                            (insight!.isFailed
                                ? 'Could not generate.'
                                : 'Your insight appears here once it is ready.'),
                        variant: insight!.isFailed
                            ? PlacardAlertVariant.warning
                            : PlacardAlertVariant.info,
                      ),
                      if (insight!.isFailed) ...[
                        const SizedBox(height: 12),
                        PlacardButton(
                          label: 'RETRY INSIGHT',
                          variant: PlacardButtonVariant.secondary,
                          onPress: onRetryInsight,
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
        ],
        PlacardPanel(
          title: 'QUESTION BREAKDOWN',
          child: Column(
            children: [
              for (final item in summary.questions) ...[
                _SummaryRow(item: item),
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

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SignageTypography.label(
              fontSize: 11,
              color: SignageColors.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: SignageTypography.data(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.item});

  final PracticeSummaryItem item;

  @override
  Widget build(BuildContext context) {
    // The key and explanation ship even for a question the learner skipped, so
    // a null `isCorrect` is "not answered" and must not be painted as wrong.
    final badge = switch (item.isCorrect) {
      true => const PlacardBadge.success('CORRECT'),
      false => const PlacardBadge.danger('WRONG'),
      null => const PlacardBadge.muted('NOT ANSWERED'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            badge,
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${item.displayOrder}. ${item.stem}',
                style: SignageTypography.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (item.correctOptionLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            'Answer: ${item.correctOptionLabel}. ${item.correctOptionText ?? ''}'
                .trim(),
            style: SignageTypography.body(
              fontSize: 13,
              color: SignageColors.greenInk,
            ),
          ),
        ],
        if (item.explanation != null && item.explanation!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.explanation!,
            style: SignageTypography.body(
              fontSize: 13,
              color: SignageColors.inkMuted,
            ),
          ),
        ],
      ],
    );
  }
}


