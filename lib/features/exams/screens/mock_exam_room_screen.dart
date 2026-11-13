import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/placement_models.dart';
import '../providers/mock_exam_controller.dart';
import '../providers/mock_exam_providers.dart';
import '../providers/placement_exam_controller.dart';
import '../widgets/answer_navigator_sheet.dart';

/// Full-screen portrait Exam Room for a timed Mock Attempt.
class MockExamRoomScreen extends ConsumerStatefulWidget {
  const MockExamRoomScreen({
    super.key,
    required this.attemptId,
  });

  final int attemptId;

  @override
  ConsumerState<MockExamRoomScreen> createState() => _MockExamRoomScreenState();
}

class _MockExamRoomScreenState extends ConsumerState<MockExamRoomScreen> {
  late final MockExamController _controller;
  final TextEditingController _writingController = TextEditingController();
  int? _writingQuestionId;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller = MockExamController(
      attemptId: widget.attemptId,
      repository: ref.read(mockExamRepositoryProvider),
      audioAdapter: ref.read(audioMediaAdapterProvider),
      onSubmitted: () {
        if (!mounted) return;
        context.go('/exams/attempts/${widget.attemptId}/result');
      },
    )..addListener(_onControllerChanged);
    unawaited(_controller.init());
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final q = _controller.state.currentQuestion;
    if (q != null && q.skill == 'writing' && _writingQuestionId != q.questionId) {
      _writingQuestionId = q.questionId;
      _writingController.text = q.responseText ?? '';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _writingController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  String _formatClock(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    }
    return '${two(minutes)}:${two(seconds)}';
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  Future<void> _confirmSubmit() async {
    final router = GoRouter.of(context);
    await showFDialog(
      context: context,
      builder: (dialogContext, style, animation) => FDialog(
        style: style,
        animation: animation,
        builder: (context, _) => PlacardPanel(
          title: 'SUBMIT MOCK ATTEMPT',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Are you sure you want to submit this mock attempt? You cannot change answers after submitting.',
                style: SignageTypography.body(fontSize: 14),
              ),
              const SizedBox(height: 16),
              PlacardButton(
                key: const Key('confirm-submit-btn'),
                label: 'CONFIRM SUBMIT',
                onPress: () async {
                  Navigator.of(dialogContext).pop();
                  final ok = await _controller.submit();
                  if (ok && mounted) {
                    router.go('/exams/attempts/${widget.attemptId}/result');
                  }
                },
              ),
              const SizedBox(height: 8),
              PlacardButton(
                label: 'CANCEL',
                variant: PlacardButtonVariant.secondary,
                onPress: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final router = GoRouter.of(context);
    await showFDialog(
      context: context,
      builder: (dialogContext, style, animation) => FDialog(
        style: style,
        animation: animation,
        builder: (context, _) => PlacardPanel(
          title: 'CANCEL ATTEMPT',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cancel this mock attempt and return to the Exams hub?',
                style: SignageTypography.body(fontSize: 14),
              ),
              const SizedBox(height: 16),
              PlacardButton(
                key: const Key('confirm-cancel-btn'),
                label: 'YES, CANCEL ATTEMPT',
                variant: PlacardButtonVariant.destructive,
                onPress: () async {
                  Navigator.of(dialogContext).pop();
                  final ok = await _controller.cancel();
                  if (ok && mounted) {
                    router.go('/exams');
                  }
                },
              ),
              const SizedBox(height: 8),
              PlacardButton(
                label: 'KEEP WORKING',
                variant: PlacardButtonVariant.secondary,
                onPress: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNavigatorSheet() {
    final s = _controller.state;
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (sheetContext) => AnswerNavigatorSheet(
        questions: s.questions,
        currentIndex: s.currentIndex,
        onSelectIndex: (idx) {
          unawaited(_controller.jumpToQuestion(idx));
        },
      ),
    );
  }

  Future<void> _toggleSpeakingRecord(PlacementQuestion q) async {
    final audio = ref.read(audioMediaAdapterProvider);
    if (_isRecording) {
      await audio.stopRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
    } else {
      final granted = await audio.hasRecordPermission();
      if (!granted) return;
      await audio.startRecording('mock_${widget.attemptId}_q${q.questionId}.m4a');
      if (!mounted) return;
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _controller.state;
    final q = s.currentQuestion;
    final autosaveLabel = switch (s.autosaveStatus) {
      AutosaveStatus.idle => 'READY',
      AutosaveStatus.saving => 'SAVING...',
      AutosaveStatus.saved => 'SAVED',
      AutosaveStatus.failed => 'SAVE FAILED',
    };

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
                  key: const Key('cancel-exam-btn'),
                  onPress: _confirmCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SignageColors.paper,
                      border: Border.all(color: SignageColors.ink, width: 2),
                    ),
                    child: Text(
                      'EXIT',
                      style: SignageTypography.label(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatClock(s.remainingSeconds),
                  key: const Key('exam-countdown-clock'),
                  style: SignageTypography.data(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SignageColors.paper,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    autosaveLabel,
                    style: SignageTypography.label(
                      fontSize: 11,
                      color: SignageColors.bandScoreCaption,
                    ),
                  ),
                ),
                FTappable(
                  key: const Key('sync-sitting-btn'),
                  onPress: () => unawaited(_controller.syncNow()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SignageColors.paper,
                      border: Border.all(color: SignageColors.ink, width: 2),
                    ),
                    child: Text(
                      'SYNC',
                      style: SignageTypography.label(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FTappable(
                  key: const Key('open-grid-btn'),
                  onPress: _openNavigatorSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SignageColors.paper,
                      border: Border.all(color: SignageColors.ink, width: 2),
                    ),
                    child: Text(
                      'GRID',
                      style: SignageTypography.label(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FTappable(
                  key: const Key('submit-exam-btn'),
                  onPress: _confirmSubmit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SignageColors.signGold,
                      border: Border.all(color: SignageColors.ink, width: 2),
                    ),
                    child: Text(
                      'SUBMIT',
                      style: SignageTypography.label(
                        fontSize: 11,
                        color: SignageColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: s.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (s.error != null && q == null)
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: StateBlock(
                    stamp: 'ERROR',
                    title: 'UNABLE TO LOAD MOCK SITTING',
                    description: s.error!,
                    action: PlacardButton(
                      label: 'RETRY',
                      onPress: () => unawaited(_controller.init()),
                    ),
                  ),
                )
              : q == null
                  ? const Center(child: Text('No questions in sitting.'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Row(
                                children: [
                                  PlacardBadge.info(
                                    'Q${s.currentIndex + 1}/${s.questions.length}',
                                  ),
                                  const SizedBox(width: 8),
                                  PlacardBadge.muted(q.skill.toUpperCase()),
                                  const Spacer(),
                                  FTappable(
                                    key: const Key('flag-question-btn'),
                                    onPress: _controller.toggleFlag,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: q.isFlagged
                                            ? SignageColors.signGold
                                            : SignageColors.paper,
                                        border: Border.all(
                                          color: SignageColors.ink,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        q.isFlagged ? 'FLAGGED' : 'FLAG',
                                        style: SignageTypography.label(
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (q.audioUrl != null && q.audioUrl!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: PlacardButton(
                                    key: const Key('play-audio-btn'),
                                    label: 'PLAY AUDIO SLICE',
                                    variant: PlacardButtonVariant.secondary,
                                    onPress: () => unawaited(
                                      ref.read(audioMediaAdapterProvider).play(),
                                    ),
                                  ),
                                ),
                              if (q.passageText != null &&
                                  q.passageText!.isNotEmpty) ...[
                                PlacardPanel(
                                  title: 'PASSAGE',
                                  child: Text(
                                    q.passageText!,
                                    style: SignageTypography.body(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              PlacardPanel(
                                title: q.sectionName.isNotEmpty
                                    ? q.sectionName
                                    : 'QUESTION',
                                child: Text(
                                  q.prompt,
                                  style: SignageTypography.body(fontSize: 15),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (q.options.isNotEmpty)
                                for (final opt in q.options)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: FTappable(
                                      key: Key('option-${opt.optionId}'),
                                      onPress: () => _controller
                                          .selectMcqOption(opt.optionId),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: q.selectedOptionId ==
                                                  opt.optionId
                                              ? SignageColors.blueWash
                                              : SignageColors.paper,
                                          border: Border.all(
                                            color: q.selectedOptionId ==
                                                    opt.optionId
                                                ? SignageColors.signBlue
                                                : SignageColors.ink,
                                            width: 2,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Text(
                                                '${opt.label}.',
                                                style: SignageTypography.data(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  opt.text,
                                                  style: SignageTypography.body(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              if (q.skill == 'writing') ...[
                                FTextField.multiline(
                                  key: const Key('writing-draft-input'),
                                  control: FTextFieldControl.managed(
                                    controller: _writingController,
                                    onChange: (value) => _controller
                                        .updateWritingDraft(value.text),
                                  ),
                                  maxLines: 8,
                                  hint: 'Write your response here...',
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'WORDS: ${_wordCount(_writingController.text)}${q.wordFloor != null ? ' / MIN ${q.wordFloor}' : ''}',
                                  style: SignageTypography.data(fontSize: 12),
                                ),
                              ],
                              if (q.skill == 'speaking')
                                PlacardButton(
                                  key: const Key('speaking-record-btn'),
                                  label: _isRecording
                                      ? 'STOP RECORDING'
                                      : 'RECORD RESPONSE',
                                  variant: _isRecording
                                      ? PlacardButtonVariant.destructive
                                      : PlacardButtonVariant.primary,
                                  onPress: () =>
                                      unawaited(_toggleSpeakingRecord(q)),
                                ),
                            ],
                          ),
                        ),
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            color: SignageColors.paper,
                            border: Border(
                              top: BorderSide(
                                color: SignageColors.ink,
                                width: 2,
                              ),
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
                                      label: 'PREVIOUS',
                                      variant: PlacardButtonVariant.secondary,
                                      onPress: s.currentIndex > 0
                                          ? () => unawaited(
                                                _controller.jumpToQuestion(
                                                  s.currentIndex - 1,
                                                ),
                                              )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: PlacardButton(
                                      key: const Key('next-question-btn'),
                                      label: 'NEXT',
                                      onPress: s.currentIndex <
                                              s.questions.length - 1
                                          ? () => unawaited(
                                                _controller.jumpToQuestion(
                                                  s.currentIndex + 1,
                                                ),
                                              )
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
    );
  }
}
