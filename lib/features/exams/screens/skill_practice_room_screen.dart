import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/placement_models.dart';
import '../models/skill_practice_models.dart';
import '../providers/skill_practice_providers.dart';
import '../widgets/exam_room_helpers.dart';

/// Room for paid Speaking (microphone + multipart upload) or Writing (essay
/// draft autosave) Skill Practice Attempt.
class SkillPracticeRoomScreen extends ConsumerStatefulWidget {
  const SkillPracticeRoomScreen({
    super.key,
    required this.skill,
    required this.attemptId,
  });

  final String skill;
  final int attemptId;

  @override
  ConsumerState<SkillPracticeRoomScreen> createState() =>
      _SkillPracticeRoomScreenState();
}

class _SkillPracticeRoomScreenState
    extends ConsumerState<SkillPracticeRoomScreen> {
  SkillPracticeAttempt? _attempt;
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;
  bool _isRecording = false;
  DateTime? _recordingStartedAt;
  bool _uploadingAudio = false;
  final Set<int> _uploadedQuestionIds = <int>{};
  bool _submitting = false;
  int _prepRemaining = 0;
  int _responseRemaining = 0;
  Timer? _countdownTimer;
  final TextEditingController _writingController = TextEditingController();
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _draftTimer?.cancel();
    _writingController.dispose();
    super.dispose();
  }

  void _syncQuestionState(PlacementQuestion q) {
    _countdownTimer?.cancel();
    _writingController.text = q.responseText ?? '';
    _prepRemaining = q.prepSeconds ?? 0;
    _responseRemaining = q.responseSeconds ?? 45;
    if (widget.skill == 'speaking' && _prepRemaining > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_prepRemaining > 1) {
          setState(() => _prepRemaining -= 1);
        } else {
          timer.cancel();
          setState(() => _prepRemaining = 0);
        }
      });
    }
  }

  void _goToQuestion(int index) {
    final questions = _attempt?.questions ?? const <PlacementQuestion>[];
    if (index < 0 || index >= questions.length || _isRecording) return;
    _draftTimer?.cancel();
    setState(() {
      _currentIndex = index;
      _error = null;
      _syncQuestionState(questions[index]);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(skillPracticeRepositoryProvider)
          .fetchAttempt(widget.skill, widget.attemptId);
      if (!mounted) return;
      setState(() {
        _attempt = res;
        _currentIndex = 0;
        _loading = false;
        if (res.questions.isNotEmpty) {
          _syncQuestionState(res.questions.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleRecord(int questionId) async {
    final audio = ref.read(audioMediaAdapterProvider);
    if (_isRecording) {
      _countdownTimer?.cancel();
      final path = await audio.stopRecording();
      final durationMs = _recordingStartedAt != null
          ? DateTime.now().difference(_recordingStartedAt!).inMilliseconds
          : 0;
      _recordingStartedAt = null;
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _uploadingAudio = true;
      });
      try {
        await ref.read(skillPracticeRepositoryProvider).uploadSpeakingAudio(
              widget.attemptId,
              questionId,
              path ?? 'speaking_${widget.attemptId}_q$questionId.m4a',
              durationMs: durationMs,
            );
        if (!mounted) return;
        setState(() {
          _uploadingAudio = false;
          _uploadedQuestionIds.add(questionId);
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _uploadingAudio = false;
          _error = e.toString();
        });
      }
    } else {
      final granted = await audio.hasRecordPermission();
      if (!granted) return;
      _countdownTimer?.cancel();
      await audio.startRecording(
        'speaking_${widget.attemptId}_q$questionId.m4a',
      );
      if (!mounted) return;
      _recordingStartedAt = DateTime.now();
      setState(() {
        _prepRemaining = 0;
        _isRecording = true;
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }
        if (_responseRemaining > 1) {
          setState(() => _responseRemaining -= 1);
        } else {
          timer.cancel();
          setState(() => _responseRemaining = 0);
          unawaited(_toggleRecord(questionId));
        }
      });
    }
  }

  void _onWritingChanged(int questionId, String text) {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        await ref.read(skillPracticeRepositoryProvider).saveWritingDraft(
              widget.attemptId,
              questionId: questionId,
              responseText: text,
            );
      } catch (_) {}
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _draftTimer?.cancel();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(skillPracticeRepositoryProvider)
          .submitAttempt(widget.skill, widget.attemptId);
      if (!mounted) return;
      context.go(
        '/practice/skill-practice/${widget.skill}/attempts/${widget.attemptId}/result',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _attempt?.questions ?? const <PlacementQuestion>[];
    final q = (_currentIndex >= 0 && _currentIndex < questions.length)
        ? questions[_currentIndex]
        : null;
    final isUploaded = q != null && _uploadedQuestionIds.contains(q.questionId);

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
                Expanded(
                  child: Text(
                    '${widget.skill.toUpperCase()} PRACTICE',
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
      child: _loading
          ? const Center(child: FCircularProgress())
          : (_error != null && q == null)
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: StateBlock(
                    stamp: 'ERROR',
                    title: 'UNABLE TO LOAD ATTEMPT',
                    description: _error!,
                    action: PlacardButton(label: 'RETRY', onPress: _load),
                  ),
                )
              : q == null
                  ? const Center(child: Text('No prompt found.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_error != null) ...[
                          PlacardAlert(
                            variant: PlacardAlertVariant.danger,
                            title: 'ERROR',
                            subtitle: _error!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            PlacardBadge.info(
                              'Q${_currentIndex + 1}/${questions.length}',
                            ),
                            const SizedBox(width: 8),
                            PlacardBadge.muted(widget.skill.toUpperCase()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        PlacardPanel(
                          title: _attempt?.examTitle ?? 'TASK PROMPT',
                          child: Text(
                            q.prompt,
                            style: SignageTypography.body(fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.skill == 'speaking')
                          PlacardPanel(
                            title: 'SPEAKING RECORDING',
                            trailing: isUploaded
                                ? const PlacardBadge.success('UPLOADED')
                                : const PlacardBadge.muted('READY'),
                            footer: PlacardButton(
                              key: const Key('skill-record-btn'),
                              label: _uploadingAudio
                                  ? 'UPLOADING...'
                                  : (_isRecording
                                      ? 'STOP & UPLOAD'
                                      : 'RECORD ANSWER'),
                              variant: _isRecording
                                  ? PlacardButtonVariant.destructive
                                  : PlacardButtonVariant.primary,
                              onPress: _uploadingAudio
                                  ? null
                                  : () => unawaited(_toggleRecord(q.questionId)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (q.prepSeconds != null &&
                                        q.prepSeconds! > 0) ...[
                                      Text(
                                        'PREP ',
                                        style: SignageTypography.label(
                                          fontSize: 11,
                                          color: SignageColors.inkMuted,
                                        ),
                                      ),
                                      Text(
                                        formatClock(_prepRemaining),
                                        key: const Key('skill-prep-timer'),
                                        style: SignageTypography.data(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                    ],
                                    Text(
                                      'RESPONSE ',
                                      style: SignageTypography.label(
                                        fontSize: 11,
                                        color: SignageColors.inkMuted,
                                      ),
                                    ),
                                    Text(
                                      formatClock(_responseRemaining),
                                      key: const Key('skill-response-timer'),
                                      style: SignageTypography.data(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _isRecording
                                            ? SignageColors.signRed
                                            : SignageColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _isRecording
                                      ? 'Recording in progress...'
                                      : 'Tap Record Answer, speak your response, then tap Stop & Upload.',
                                  style: SignageTypography.body(fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        else
                          FTextField.multiline(
                            key: const Key('skill-writing-input'),
                            control: FTextFieldControl.managed(
                              controller: _writingController,
                              onChange: (value) =>
                                  _onWritingChanged(q.questionId, value.text),
                            ),
                            maxLines: 10,
                            hint: 'Draft your essay response...',
                          ),
                        if (questions.length > 1) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: PlacardButton(
                                  key: const Key('skill-prev-btn'),
                                  label: 'PREVIOUS',
                                  variant: PlacardButtonVariant.secondary,
                                  onPress: _currentIndex > 0 && !_isRecording
                                      ? () => _goToQuestion(_currentIndex - 1)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PlacardButton(
                                  key: const Key('skill-next-btn'),
                                  label: 'NEXT',
                                  variant: PlacardButtonVariant.secondary,
                                  onPress: _currentIndex < questions.length - 1 &&
                                          !_isRecording
                                      ? () => _goToQuestion(_currentIndex + 1)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        PlacardButton(
                          key: const Key('skill-submit-btn'),
                          label:
                              _submitting ? 'SUBMITTING...' : 'SUBMIT FOR GRADING',
                          onPress: _submitting ? null : _submit,
                        ),
                      ],
                    ),
    );
  }
}
