import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/skill_practice_models.dart';
import '../providers/skill_practice_providers.dart';

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
  bool _loading = true;
  String? _error;
  bool _isRecording = false;
  bool _uploadingAudio = false;
  bool _audioUploaded = false;
  bool _submitting = false;
  final TextEditingController _writingController = TextEditingController();
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _writingController.dispose();
    super.dispose();
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
        _loading = false;
        if (res.questions.isNotEmpty) {
          _writingController.text = res.questions.first.responseText ?? '';
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
      final path = await audio.stopRecording();
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
            );
        if (!mounted) return;
        setState(() {
          _uploadingAudio = false;
          _audioUploaded = true;
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
      await audio.startRecording(
        'speaking_${widget.attemptId}_q$questionId.m4a',
      );
      if (!mounted) return;
      setState(() => _isRecording = true);
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
    final q = (_attempt?.questions.isNotEmpty ?? false)
        ? _attempt!.questions.first
        : null;

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
          ? const Center(child: CircularProgressIndicator())
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
                            trailing: _audioUploaded
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
                            child: Text(
                              _isRecording
                                  ? 'Recording in progress...'
                                  : 'Tap Record Answer, speak your response, then tap Stop & Upload.',
                              style: SignageTypography.body(fontSize: 14),
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
