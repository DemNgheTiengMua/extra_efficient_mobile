import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../providers/mock_exam_providers.dart';

/// Audio & Microphone Preflight Check for a started Mock Attempt.
class MockPreflightScreen extends ConsumerStatefulWidget {
  const MockPreflightScreen({super.key, required this.attemptId});

  final int attemptId;

  @override
  ConsumerState<MockPreflightScreen> createState() =>
      _MockPreflightScreenState();
}

class _MockPreflightScreenState extends ConsumerState<MockPreflightScreen> {
  bool _audioChecked = false;
  bool _micChecked = false;
  bool? _micGranted;
  bool _verifying = false;
  String? _error;

  Future<void> _runAudioCheck(String sampleUrl) async {
    final audio = ref.read(audioMediaAdapterProvider);
    final url = sampleUrl.isNotEmpty
        ? sampleUrl
        : 'https://example.com/audio/preflight.mp3';
    await audio.setAudioUrl(url);
    await audio.play();
    await audio.stop();
    if (!mounted) return;
    setState(() => _audioChecked = true);
  }

  Future<void> _runMicCheck() async {
    final audio = ref.read(audioMediaAdapterProvider);
    final granted = await audio.hasRecordPermission();
    if (granted) {
      await audio.startRecording('mock_preflight_test.m4a');
      await audio.stopRecording();
    }
    if (!mounted) return;
    setState(() {
      _micGranted = granted;
      _micChecked = granted;
    });
  }

  Future<void> _verifyAndEnter() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref
          .read(mockExamRepositoryProvider)
          .verifyPreflight(widget.attemptId);
      if (!mounted) return;
      context.go('/exams/attempts/${widget.attemptId}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preflightAsync = ref.watch(mockPreflightProvider(widget.attemptId));

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
                    'MOCK ATTEMPT PREFLIGHT',
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
      child: preflightAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: StateBlock(
            stamp: 'ERROR',
            title: 'UNABLE TO LOAD PREFLIGHT',
            description: err.toString(),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () =>
                  ref.invalidate(mockPreflightProvider(widget.attemptId)),
            ),
          ),
        ),
        data: (preflight) {
          final canEnter = _audioChecked &&
              (!preflight.requiresMicrophone || _micChecked);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                PlacardAlert(
                  variant: PlacardAlertVariant.danger,
                  title: 'PREFLIGHT ERROR',
                  subtitle: _error!,
                ),
                const SizedBox(height: 12),
              ],
              PlacardPanel(
                title: '1. AUDIO OUTPUT CHECK',
                trailing: _audioChecked
                    ? PlacardBadge.success('PASSED')
                    : PlacardBadge.muted('REQUIRED'),
                footer: PlacardButton(
                  key: const Key('preflight-audio-check-btn'),
                  label: _audioChecked ? 'REPLAY TEST AUDIO' : 'TEST AUDIO',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () => _runAudioCheck(preflight.audioSampleUrl),
                ),
                child: Text(
                  'Verify your speakers or headphones before starting the listening section.',
                  style: SignageTypography.body(fontSize: 14),
                ),
              ),
              if (preflight.requiresMicrophone) ...[
                const SizedBox(height: 16),
                PlacardPanel(
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
                    'Verify microphone permission for speaking tasks.',
                    style: SignageTypography.body(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PlacardButton(
                key: const Key('enter-mock-room-btn'),
                label: _verifying ? 'VERIFYING...' : 'ENTER MOCK EXAM ROOM',
                onPress: canEnter && !_verifying ? _verifyAndEnter : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
