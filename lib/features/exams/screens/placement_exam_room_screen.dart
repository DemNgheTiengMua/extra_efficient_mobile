import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/exam_room_stop.dart';
import '../models/placement_models.dart';
import '../providers/placement_exam_controller.dart';
import '../providers/placement_providers.dart';
import '../widgets/answer_navigator_sheet.dart';
import '../widgets/exam_room_helpers.dart';
import '../widgets/exam_room_states.dart';

/// Full-screen portrait Exam Room for a Placement attempt.
/// Hides bottom navigation and displays server-authoritative countdown,
/// ~400ms debounced autosave status, GRID navigator trigger, and SUBMIT.
class PlacementExamRoomScreen extends ConsumerStatefulWidget {
  const PlacementExamRoomScreen({super.key, required this.placementId});

  final int placementId;

  @override
  ConsumerState<PlacementExamRoomScreen> createState() =>
      _PlacementExamRoomScreenState();
}

class _PlacementExamRoomScreenState
    extends ConsumerState<PlacementExamRoomScreen> {
  late final PlacementExamController _controller;
  final TextEditingController _writingController = TextEditingController();
  int? _writingQuestionId;

  // Speaking local timer state
  bool _isRecording = false;
  DateTime? _recordingStartedAt;
  int _speakingElapsedSeconds = 0;
  Timer? _speakingTimer;

  @override
  void initState() {
    super.initState();
    _controller = PlacementExamController(
      placementId: widget.placementId,
      repository: ref.read(placementRepositoryProvider),
      audioAdapter: ref.read(audioMediaAdapterProvider),
      onSubmitted: () {
        if (!mounted) return;
        context.go('/placement/result/${widget.placementId}');
      },
    )..addListener(_onControllerChanged);
    unawaited(_controller.init());
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final state = _controller.state;
    if (state.needsPreflight) {
      // This door cannot open the sitting: the shared device gate owns entry.
      // `go` keeps it single-entry, so no back-stack loop can form.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/placement/take/${widget.placementId}/preflight');
      });
    }
    final q = state.currentQuestion;
    if (q != null && q.skill == 'writing' && _writingQuestionId != q.questionId) {
      _writingQuestionId = q.questionId;
      _writingController.text = q.responseText ?? '';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _speakingTimer?.cancel();
    _writingController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmSubmit() async {
    final router = GoRouter.of(context);
    final confirmed = await showExamConfirmDialog(
      context: context,
      title: 'SUBMIT PLACEMENT',
      message:
          'Are you sure you want to submit this placement attempt? You cannot change answers after submitting.',
      confirmLabel: 'CONFIRM SUBMIT',
      confirmKey: const Key('confirm-submit-btn'),
    );
    if (confirmed && mounted) {
      final ok = await _controller.submit(isAutoSubmit: false);
      if (ok && mounted) {
        router.go('/placement/result/${widget.placementId}');
      }
    }
  }

  Future<void> _confirmAbandon() async {
    final confirmed = await showExamConfirmDialog(
      context: context,
      title: 'ABANDON ATTEMPT',
      message: 'Abandoning will end your current placement attempt.',
      confirmLabel: 'ABANDON',
      confirmKey: const Key('confirm-abandon-btn'),
      confirmVariant: PlacardButtonVariant.destructive,
      cancelLabel: 'KEEP WORKING',
    );
    if (!confirmed || !mounted) return;
    final router = GoRouter.of(context);
    final ok = await _controller.abandon();
    if (!mounted) return;
    if (ok) {
      router.go('/exams');
    } else {
      // The cancel was refused (already graded or expired). The learner still
      // gets out; only the fact that the sitting is not cancelled is reported.
      setState(() {});
    }
  }

  /// Leaving. Deliberately unconditional: it awaits nothing and navigates, so a
  /// sitting the backend refuses to cancel cannot trap the learner.
  void _leaveRoom() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/exams');
    }
  }

  Future<void> _startSpeakingRecording(PlacementQuestion q) async {
    final audio = ref.read(audioMediaAdapterProvider);
    final granted = await audio.hasRecordPermission();
    if (!granted) return;
    await audio.startRecording('placement_${widget.placementId}_q${q.questionId}.m4a');
    _speakingTimer?.cancel();
    _recordingStartedAt = DateTime.now();
    setState(() {
      _isRecording = true;
      _speakingElapsedSeconds = 0;
    });
    _speakingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _speakingElapsedSeconds += 1);
    });
  }

  Future<void> _stopSpeakingRecording(PlacementQuestion q) async {
    _speakingTimer?.cancel();
    final audio = ref.read(audioMediaAdapterProvider);
    final path = await audio.stopRecording();
    final durationMs = _recordingStartedAt != null
        ? DateTime.now().difference(_recordingStartedAt!).inMilliseconds
        : _speakingElapsedSeconds * 1000;
    _recordingStartedAt = null;
    if (!mounted) return;
    setState(() => _isRecording = false);
    await _controller.saveSpeakingRecording(
      q.questionId,
      path ?? 'placement_${widget.placementId}_q${q.questionId}.m4a',
      durationMs,
    );
  }

  Widget _buildAutosaveBadge(AutosaveStatus status) {
    return switch (status) {
      AutosaveStatus.idle => const PlacardBadge.muted('READY'),
      AutosaveStatus.saving => const PlacardBadge.warning('SAVING'),
      AutosaveStatus.saved => const PlacardBadge.success('SAVED'),
      AutosaveStatus.failed => const PlacardBadge.danger('SAVE FAILED'),
    };
  }

  Widget _buildHeader(PlacementExamState state) {
    final isCritical = state.remainingSeconds <= 60;
    final isWarning = state.remainingSeconds <= 300 && !isCritical;
    final clockBg = isCritical
        ? SignageColors.signRed
        : (isWarning ? SignageColors.signGold : SignageColors.ink);
    final clockFg = isWarning ? SignageColors.ink : SignageColors.paper;

    return DecoratedBox(
      key: const Key('exam-room-header'),
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
              Container(
                key: const Key('exam-countdown-clock'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: clockBg,
                  border: Border.all(color: SignageColors.paper, width: 1),
                ),
                child: Text(
                  formatClock(state.remainingSeconds),
                  style: SignageTypography.data(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: clockFg,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildAutosaveBadge(state.autosaveStatus),
              const Spacer(),
              ExamRoomExitButton(onLeave: _leaveRoom),
              const SizedBox(width: 6),
              FTappable(
                key: const Key('exam-abandon-btn'),
                onPress: _confirmAbandon,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: SignageColors.signRed,
                    border: Border.all(color: SignageColors.ink, width: 2),
                  ),
                  child: Text(
                    'CANCEL',
                    style: SignageTypography.label(
                      fontSize: 11,
                      color: SignageColors.paper,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FTappable(
                key: const Key('exam-grid-btn'),
                onPress: () {
                  showFSheet<void>(
                    context: context,
                    side: FLayout.btt,
                    builder: (_) => AnswerNavigatorSheet(
                      questions: state.questions,
                      currentIndex: state.currentIndex,
                      onSelectIndex: (idx) =>
                          unawaited(_controller.jumpToQuestion(idx)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: SignageColors.paper,
                    border: Border.all(color: SignageColors.ink, width: 2),
                  ),
                  child: Text(
                    'GRID',
                    style: SignageTypography.label(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FTappable(
                key: const Key('exam-submit-btn'),
                onPress: _confirmSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: SignageColors.ink,
                    border: Border.all(color: SignageColors.paper, width: 1),
                  ),
                  child: Text(
                    'SUBMIT',
                    style: SignageTypography.label(
                      fontSize: 12,
                      color: SignageColors.paper,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayerBar(PlacementQuestion q) {
    final audio = ref.read(audioMediaAdapterProvider);
    final hasSlice = q.audioStartMs != null || q.audioEndMs != null;
    final sliceText = hasSlice
        ? '${((q.audioStartMs ?? 0) / 1000).toStringAsFixed(1)}s – ${q.audioEndMs != null ? (q.audioEndMs! / 1000).toStringAsFixed(1) : 'END'}s'
        : 'FULL TRACK';

    return PlacardPanel(
      title: 'LISTENING AUDIO',
      trailing: PlacardBadge.info(sliceText),
      child: StreamBuilder<bool>(
        stream: audio.playingStream,
        initialData: false,
        builder: (context, playingSnap) {
          final isPlaying = playingSnap.data ?? false;
          return Row(
            children: [
              Expanded(
                child: PlacardButton(
                  key: const Key('audio-play-pause-btn'),
                  label: isPlaying ? 'PAUSE AUDIO' : 'PLAY AUDIO',
                  onPress: () => isPlaying ? audio.pause() : audio.play(),
                ),
              ),
              const SizedBox(width: 8),
              PlacardButton(
                label: 'STOP',
                expand: false,
                variant: PlacardButtonVariant.secondary,
                onPress: () => audio.stop(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMcqOptions(PlacementQuestion q) {
    return Column(
      children: [
        for (final option in q.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FTappable(
              key: Key('mcq-option-${option.optionId}'),
              onPress: () => _controller.selectMcqOption(option.optionId),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: q.selectedOptionId == option.optionId
                      ? SignageColors.ink
                      : SignageColors.paper,
                  border: Border.all(color: SignageColors.ink, width: 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${option.label}.',
                      style: SignageTypography.data(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: q.selectedOptionId == option.optionId
                            ? SignageColors.signGold
                            : SignageColors.ink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option.text,
                        style: SignageTypography.body(
                          fontSize: 15,
                          color: q.selectedOptionId == option.optionId
                              ? SignageColors.paper
                              : SignageColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWritingArea(PlacementQuestion q) {
    final text = _writingController.text;
    final words = countWords(text);

    return PlacardPanel(
      title: 'WRITING RESPONSE',
      trailing: PlacardBadge.info('$words WORDS'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q.wordFloor != null) ...[
            Text(
              'TARGET WORD FLOOR: ${q.wordFloor} WORDS',
              style: SignageTypography.data(
                fontSize: 12,
                color: SignageColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
          ],
          FTextField.multiline(
            key: const Key('writing-draft-input'),
            control: FTextFieldControl.managed(
              controller: _writingController,
              onChange: (value) => _controller.updateWritingDraft(value.text),
            ),
            maxLines: 8,
            hint: 'Write your response here...',
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakingArea(PlacementQuestion q) {
    return PlacardPanel(
      title: 'SPEAKING CAPTURE',
      trailing: PlacardBadge(
        label: _isRecording ? 'RECORDING' : 'STANDBY',
        variant: _isRecording
            ? PlacardBadgeVariant.danger
            : PlacardBadgeVariant.muted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (q.prepSeconds != null)
                Text(
                  'PREP: ${q.prepSeconds}s  ',
                  style: SignageTypography.data(fontSize: 13),
                ),
              if (q.responseSeconds != null)
                Text(
                  'LIMIT: ${q.responseSeconds}s  ',
                  style: SignageTypography.data(fontSize: 13),
                ),
              Text(
                'CAPTURED: ${formatClock(_speakingElapsedSeconds)}',
                style: SignageTypography.data(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PlacardButton(
                  key: const Key('speaking-record-btn'),
                  label: 'START RECORDING',
                  onPress:
                      _isRecording ? null : () => _startSpeakingRecording(q),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PlacardButton(
                  key: const Key('speaking-stop-btn'),
                  label: 'STOP RECORDING',
                  variant: PlacardButtonVariant.destructive,
                  onPress:
                      _isRecording ? () => _stopSpeakingRecording(q) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final question = state.currentQuestion;

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: SignageColors.wall,
        child: Column(
          children: [
            _buildHeader(state),
            Expanded(
              child: state.isLoading
                  ? const Center(child: FCircularProgress())
                  : state.stop != null
                      ? ExamRoomTerminalView(
                          stop: state.stop!,
                          onLeave: _leaveRoom,
                        )
                      : state.error != null
                          ? ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                PlacardAlert(
                                  variant: PlacardAlertVariant.danger,
                                  title: 'Exam room error',
                                  subtitle: state.error,
                                ),
                                const SizedBox(height: 12),
                                PlacardButton(
                                  key: const Key('exam-retry-btn'),
                                  label: 'RETRY',
                                  onPress: () => unawaited(_controller.init()),
                                ),
                                const SizedBox(height: 8),
                                PlacardButton(
                                  key: const Key('exam-terminal-leave-btn'),
                                  label: 'LEAVE ROOM',
                                  variant: PlacardButtonVariant.secondary,
                                  onPress: _leaveRoom,
                                ),
                              ],
                            )
                      : question == null
                          ? ExamRoomTerminalView(
                              stop: const ExamRoomStop(
                                stamp: 'EMPTY',
                                title: 'This sitting has no questions',
                                description: 'The paper came back empty, so '
                                    'there is nothing to answer.',
                                actionLabel: 'BACK TO EXAMS',
                                actionRoute: '/exams',
                              ),
                              onLeave: _leaveRoom,
                            )
                          : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Row(
                                children: [
                                  PlacardBadge.info(
                                    'Q${state.currentIndex + 1}/${state.questions.length}',
                                  ),
                                  const SizedBox(width: 8),
                                  PlacardBadge.muted(
                                    question.sectionName.isNotEmpty
                                        ? question.sectionName
                                        : question.skill.toUpperCase(),
                                  ),
                                  const Spacer(),
                                  FTappable(
                                    key: const Key('exam-flag-btn'),
                                    onPress: _controller.toggleFlag,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: question.isFlagged
                                            ? SignageColors.signGold
                                            : SignageColors.paper,
                                        border: Border.all(
                                          color: SignageColors.ink,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        question.isFlagged ? 'FLAGGED' : 'FLAG',
                                        style: SignageTypography.label(
                                          fontSize: 12,
                                          color: SignageColors.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (state.answeredCount > 0) ...[
                                const SizedBox(height: 10),
                                PlacardAlert(
                                  key: const Key('resume-answered-banner'),
                                  variant: PlacardAlertVariant.info,
                                  title: 'RESUMING',
                                  subtitle: '${state.answeredCount} of '
                                      '${state.questions.length} questions '
                                      'already answered. Your answers are kept.',
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (question.audioPath != null &&
                                  question.audioPath!.isNotEmpty) ...[
                                _buildAudioPlayerBar(question),
                                const SizedBox(height: 12),
                              ],
                              if (question.passageText != null &&
                                  question.passageText!.isNotEmpty) ...[
                                Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: SignageColors.paper,
                                    border: Border.all(
                                      color: SignageColors.ink,
                                      width: 2,
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      question.passageText!,
                                      style:
                                          SignageTypography.body(fontSize: 15),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              PlacardPanel(
                                child: Text(
                                  question.prompt,
                                  style: SignageTypography.body(fontSize: 17),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (question.skill == 'writing')
                                _buildWritingArea(question)
                              else if (question.skill == 'speaking')
                                _buildSpeakingArea(question)
                              else
                                _buildMcqOptions(question),
                            ],
                          ),
          ),
          if (state.questions.isNotEmpty)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: SignageColors.paper,
                border: Border(
                  top: BorderSide(color: SignageColors.ink, width: 2),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: PlacardButton(
                          key: const Key('prev-question-btn'),
                          label: 'PREV',
                          variant: PlacardButtonVariant.secondary,
                          onPress: state.currentIndex > 0
                              ? () => _controller
                                  .jumpToQuestion(state.currentIndex - 1)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PlacardButton(
                          key: const Key('next-question-btn'),
                          label: 'NEXT',
                          onPress: state.currentIndex <
                                  state.questions.length - 1
                              ? () => _controller
                                  .jumpToQuestion(state.currentIndex + 1)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
