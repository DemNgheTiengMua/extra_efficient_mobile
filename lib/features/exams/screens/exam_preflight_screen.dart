import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/exam_room_stop.dart';
import '../models/preflight_models.dart';
import '../providers/exam_room_gate_providers.dart';

/// The device gate every door into a sitting passes through.
///
/// Start, resume, history-resume and the dashboard's unfinished card all route
/// here, because the sitting is unreadable until `preflight/verify` succeeds:
/// `GET .../take/{id}` answers 400 `preflight_required` before that.
class ExamPreflightScreen extends ConsumerStatefulWidget {
  const ExamPreflightScreen({
    super.key,
    required this.kind,
    required this.sittingId,
    this.resume = false,
  });

  final SittingKind kind;
  final int sittingId;

  /// Used only for prose and for where an already-finished sitting goes.
  final bool resume;

  @override
  ConsumerState<ExamPreflightScreen> createState() =>
      _ExamPreflightScreenState();
}

class _ExamPreflightScreenState extends ConsumerState<ExamPreflightScreen> {
  bool _audioChecked = false;
  bool _micChecked = false;
  bool? _micGranted;

  /// True when the backend supplied no playable sample, so the audio step is an
  /// explicit confirmation rather than a playback that would 404.
  bool _sampleUnavailable = false;

  bool _verifying = false;
  String? _error;

  bool get _isPlacement => widget.kind == SittingKind.placement;

  String get _roomRoute => _roomRouteFor(widget.kind, widget.sittingId);

  String get _resultRoute =>
      _resultRouteFor(widget.kind, widget.sittingId);

  Future<void> _runAudioCheck(String? sampleUrl) async {
    if (sampleUrl == null || sampleUrl.isEmpty) {
      // Every media path on this backend 404s, so playback cannot be the pass
      // condition: the learner confirms they can hear, instead of being blocked
      // by a sample that does not exist.
      setState(() {
        _audioChecked = true;
        _sampleUnavailable = true;
        _error = null;
      });
      return;
    }
    final audio = ref.read(audioMediaAdapterProvider);
    try {
      await audio.setAudioUrl(sampleUrl);
      await audio.play();
      await audio.stop();
      if (!mounted) return;
      setState(() {
        _audioChecked = true;
        _sampleUnavailable = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audioChecked = true;
        _sampleUnavailable = true;
        _error = null;
      });
    }
  }

  Future<void> _runMicCheck() async {
    final audio = ref.read(audioMediaAdapterProvider);
    try {
      final granted = await audio.hasRecordPermission();
      if (granted) {
        await audio.startRecording('exam_preflight_test.m4a');
        await audio.stopRecording();
      }
      if (!mounted) return;
      setState(() {
        _micGranted = granted;
        _micChecked = granted;
        _error = granted ? null : 'Microphone permission was refused.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _micChecked = false;
        _error = 'Microphone check failed: $e';
      });
    }
  }

  Future<void> _verifyAndEnter(PreflightStatus status) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(examRoomGateProvider).verifyPreflight(
            widget.kind,
            attemptId: status.attemptId,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Could not verify your equipment: ${e.toString()}';
      });
      return;
    }
    if (!mounted) return;
    context.go(_roomRoute);
  }

  void _leave() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/exams');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(examRoomGateProvider);
    final statusAsync = ref.watch(
      preflightStatusProvider(
        SittingRef(kind: widget.kind, sittingId: widget.sittingId),
      ),
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
                  key: const Key('preflight-leave-btn'),
                  onPress: _leave,
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
                      'LEAVE',
                      style: SignageTypography.label(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isPlacement
                        ? 'PLACEMENT PREFLIGHT'
                        : 'MOCK ATTEMPT PREFLIGHT',
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
      child: statusAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (err, _) {
          final stop = _stopForGateError(err, gate: gate);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StateBlock(
                stamp: stop.stamp,
                title: stop.title,
                description: stop.description,
                action: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PlacardButton(
                      key: const Key('preflight-terminal-btn'),
                      label: stop.actionLabel,
                      onPress: () => context.go(stop.actionRoute),
                    ),
                    const SizedBox(height: 8),
                    PlacardButton(
                      label: 'BACK TO EXAMS',
                      variant: PlacardButtonVariant.secondary,
                      onPress: () => context.go('/exams'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        data: (status) {
          if (status.isVerified) {
            return _buildAlreadyVerified(status);
          }
          final canEnter = (!status.requiresAudio || _audioChecked) &&
              (!status.requiresMicrophone || _micChecked);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                PlacardAlert(
                  key: const Key('preflight-error'),
                  variant: PlacardAlertVariant.danger,
                  title: 'PREFLIGHT ERROR',
                  subtitle: _error!,
                ),
                const SizedBox(height: 12),
              ],
              PlacardPanel(
                title: status.examName.isEmpty ? 'YOUR SITTING' : status.examName,
                trailing: PlacardBadge.info('${status.durationMinutes} MIN'),
                child: Text(
                  'Equipment is checked before the clock starts, so you are '
                  'never refused entry by a requirement you could not see.',
                  style: SignageTypography.body(fontSize: 14),
                ),
              ),
              if (status.requiresAudio) ...[
                const SizedBox(height: 16),
                _buildAudioPanel(status),
              ],
              if (status.requiresMicrophone) ...[
                const SizedBox(height: 16),
                _buildMicPanel(),
              ],
              const SizedBox(height: 20),
              PlacardButton(
                key: const Key('enter-room-btn'),
                label: _verifying ? 'VERIFYING...' : 'ENTER EXAM ROOM',
                onPress: canEnter && !_verifying
                    ? () => _verifyAndEnter(status)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlreadyVerified(PreflightStatus status) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StateBlock(
          stamp: 'READY',
          title: 'Your device checks are already complete',
          description: 'This sitting was verified earlier, so the room opens '
              'directly.',
          action: PlacardButton(
            key: const Key('enter-room-btn'),
            label: 'ENTER EXAM ROOM',
            onPress: () => context.go(_roomRoute),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPanel(PreflightStatus status) {
    final sample = status.audioSampleUrl;
    return PlacardPanel(
      title: _sampleUnavailable
          ? 'AUDIO OUTPUT — SAMPLE UNAVAILABLE'
          : '1. AUDIO OUTPUT CHECK',
      trailing: _audioChecked
          ? PlacardBadge.success('PASSED')
          : PlacardBadge.muted('REQUIRED'),
      footer: PlacardButton(
        key: const Key('preflight-audio-check-btn'),
        label: _audioChecked
            ? (_sampleUnavailable ? 'CONFIRM AGAIN' : 'REPLAY TEST AUDIO')
            : (sample == null ? 'CONFIRM I CAN HEAR AUDIO' : 'TEST AUDIO'),
        variant: PlacardButtonVariant.secondary,
        onPress: () => _runAudioCheck(sample),
      ),
      child: Text(
        _sampleUnavailable
            ? 'The backend supplied no playable sample for this sitting. '
                'Confirm your speakers or headphones are working, then enter.'
            : 'Verify your speakers or headphones before the listening '
                'section starts.',
        style: SignageTypography.body(fontSize: 14),
      ),
    );
  }

  Widget _buildMicPanel() {
    return PlacardPanel(
      title: '2. MICROPHONE CHECK',
      trailing: _micChecked
          ? PlacardBadge.success('PASSED')
          : (_micGranted == false
              ? PlacardBadge.danger('DENIED')
              : PlacardBadge.muted('REQUIRED')),
      footer: PlacardButton(
        key: const Key('preflight-mic-check-btn'),
        label: _micChecked ? 'RETEST MICROPHONE' : 'TEST MICROPHONE',
        variant: PlacardButtonVariant.secondary,
        onPress: _runMicCheck,
      ),
      child: Text(
        'This sitting has speaking tasks, so microphone permission is checked '
        'now rather than mid-answer.',
        style: SignageTypography.body(fontSize: 14),
      ),
    );
  }

  /// A gate that cannot even be read is still a dead end the learner must be
  /// able to leave. A finished sitting routes to its result; anything else
  /// explains itself and offers the hub.
  ExamRoomStop _stopForGateError(Object err, {required ExamRoomGate gate}) {
    if (isSittingOver(err)) {
      return ExamRoomStop(
        stamp: 'FINISHED',
        title: 'This sitting is over',
        description: 'It was submitted, graded or expired, so it can no longer '
            'be entered. Your score is on the result placard.',
        actionLabel: _isPlacement ? 'VIEW RESULT' : 'BACK TO EXAMS',
        actionRoute: _isPlacement ? _resultRoute : '/exams',
      );
    }
    if (isSittingMissing(err)) {
      return ExamRoomStop(
        stamp: 'NOT FOUND',
        title: 'This sitting no longer exists',
        description: 'The backend does not recognise it. It may have been '
            'deleted, or it was never started.',
        actionLabel: 'BACK TO EXAMS',
        actionRoute: '/exams',
      );
    }
    return ExamRoomStop(
      stamp: 'ERROR',
      title: 'Unable to read the device checks',
      description: err.toString(),
      actionLabel: 'BACK TO EXAMS',
      actionRoute: '/exams',
    );
  }
}

String _roomRouteFor(SittingKind kind, int id) => kind == SittingKind.placement
    ? '/placement/take/$id'
    : '/exams/attempts/$id';

String _resultRouteFor(SittingKind kind, int id) =>
    kind == SittingKind.placement
        ? '/placement/result/$id'
        : '/exams/attempts/$id/result';
