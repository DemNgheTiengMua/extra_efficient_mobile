import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../context/learner_context_provider.dart';
import '../models/placement_models.dart';
import '../providers/placement_providers.dart';

/// Placement Overview & Preflight screen.
/// Displays free first-placement vs paid retake scope options, reusable skill
/// toggles, audio output check, and microphone check before any Credit is spent.
class PlacementOverviewScreen extends ConsumerStatefulWidget {
  const PlacementOverviewScreen({super.key});

  @override
  ConsumerState<PlacementOverviewScreen> createState() =>
      _PlacementOverviewScreenState();
}

class _PlacementOverviewScreenState
    extends ConsumerState<PlacementOverviewScreen> {
  String _selectedScope = 'all_skills';
  bool _reuseValidSkills = false;
  bool _audioChecked = false;
  bool _micChecked = false;
  bool? _micGranted;
  bool _starting = false;
  String? _errorMessage;

  /// The pre-start sheet has no per-sitting sample URL, so this is the explicit
  /// UI-only confirmation. It never touches a path that would 404 and never
  /// blocks the start control on playback.
  void _runAudioCheck() {
    setState(() {
      _audioChecked = true;
      _errorMessage = null;
    });
  }

  Future<void> _runMicCheck() async {
    final audio = ref.read(audioMediaAdapterProvider);
    try {
      final granted = await audio.hasRecordPermission();
      if (granted) {
        await audio.startRecording('preflight_test.m4a');
        await audio.stopRecording();
      }
      if (!mounted) return;
      setState(() {
        _micGranted = granted;
        _micChecked = granted;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _micChecked = false;
        _errorMessage = 'Microphone check failed: $e';
      });
    }
  }

  Future<void> _startPlacement(PlacementCatalog catalog) async {
    final examId = catalog.startableExamId;
    if (examId == null) return;
    setState(() {
      _starting = true;
      _errorMessage = null;
    });
    try {
      final scope = catalog.isRetake ? _selectedScope : 'all_skills';
      final placementId = await ref
          .read(placementRepositoryProvider)
          .startPlacement(
            examId: examId,
            scope: scope,
            reuseValidSkills: _reuseValidSkills,
            idempotencyKey:
                'placement-$examId-${DateTime.now().millisecondsSinceEpoch}',
          );
      ref.invalidate(learnerContextProvider);
      if (!mounted) return;
      // A freshly started sitting must pass the same device gate as a resumed
      // one - the sitting itself answers `preflight_required` until it does.
      context.go('/placement/take/$placementId/preflight');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _starting = false;
      });
    }
  }

  Future<void> _abandonInProgress(int placementId) async {
    await ref.read(placementRepositoryProvider).abandon(placementId);
    ref.invalidate(placementCatalogProvider);
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(placementCatalogProvider);
    final preflightAsync = ref.watch(placementPreflightProvider);

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
                      style: SignageTypography.label(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PLACEMENT PREFLIGHT',
                    style: SignageTypography.title(color: SignageColors.paper)
                        .copyWith(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Container(
        color: SignageColors.wall,
        child: catalogAsync.when(
          loading: () => const Center(child: FCircularProgress()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StateBlock(
                stamp: 'ERROR',
                title: 'UNABLE TO LOAD PLACEMENT',
                description: error.toString(),
                action: PlacardButton(
                  label: 'RETRY',
                  onPress: () => ref.invalidate(placementCatalogProvider),
                ),
              ),
            ],
          ),
          data: (catalog) {
            final preflight = preflightAsync.value;
            final exam = catalog.exams.isEmpty ? null : catalog.exams.first;
            final isFirstPlacement = !catalog.isRetake;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null) ...[
                  PlacardAlert(
                    variant: PlacardAlertVariant.danger,
                    title: 'Could not start placement',
                    subtitle: _errorMessage,
                  ),
                  const SizedBox(height: 16),
                ],
                if (catalog.activePlacementId != null) ...[
                  PlacardPanel(
                    title: 'IN-PROGRESS ATTEMPT',
                    trailing: PlacardBadge.warning('UNFINISHED'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You have an unfinished placement attempt '
                          '(#${catalog.activePlacementId}).',
                          style: SignageTypography.body(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: PlacardButton(
                                key: const Key('resume-placement-btn'),
                                label: 'RESUME',
                                onPress: () => context.go(
                                  '/placement/take/${catalog.activePlacementId}/preflight',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PlacardButton(
                                key: const Key('abandon-placement-btn'),
                                label: 'ABANDON',
                                variant: PlacardButtonVariant.destructive,
                                onPress: () => _abandonInProgress(
                                  catalog.activePlacementId!,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                PlacardPanel(
                  title: catalog.certificateCode.isEmpty
                      ? 'PLACEMENT OVERVIEW'
                      : '${catalog.certificateCode} PLACEMENT',
                  trailing: isFirstPlacement
                      ? const PlacardBadge.success('FREE FIRST PLACEMENT')
                      : const PlacardBadge.warning('PAID RETAKE'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam?.name ?? 'NO PLACEMENT EXAM AVAILABLE',
                        style: SignageTypography.condensedSentence(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFirstPlacement
                            ? '0 CREDITS — First diagnostic placement per certificate is free.'
                            : 'Select a retake scope below.',
                        style: SignageTypography.body(
                          fontSize: 14,
                          color: SignageColors.inkMuted,
                        ),
                      ),
                      if (catalog.currentTotalScore != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'CURRENT BAND ${catalog.currentBandCode ?? '-'}',
                                style: SignageTypography.label(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${catalog.currentTotalScore}',
                              style: SignageTypography.data(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isFirstPlacement) ...[
                  const SizedBox(height: 16),
                  PlacardPanel(
                    title: 'RETAKE SCOPE',
                    child: Column(
                      children: [
                        for (final option in [
                          PlacementScopeOption(
                            scope: 'all_skills',
                            label: 'All 4 Skills',
                            credits: catalog.allSkillsRetakeCredits,
                          ),
                          PlacementScopeOption(
                            scope: 'listening_and_reading',
                            label: 'Listening & Reading',
                            credits: catalog.listeningAndReadingRetakeCredits,
                          ),
                        ]) ...[
                          FTappable(
                            key: Key('scope-option-${option.scope}'),
                            onPress: () =>
                                setState(() => _selectedScope = option.scope),
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _selectedScope == option.scope
                                    ? SignageColors.ink
                                    : SignageColors.paper,
                                border: Border.all(
                                  color: SignageColors.ink,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.label.toUpperCase(),
                                      style: SignageTypography.label(
                                        fontSize: 13,
                                        color: _selectedScope == option.scope
                                            ? SignageColors.paper
                                            : SignageColors.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${option.credits} CREDITS',
                                    style: SignageTypography.data(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _selectedScope == option.scope
                                          ? SignageColors.signGold
                                          : SignageColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (preflight != null &&
                    preflight.reusableSkills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  PlacardPanel(
                    title: 'REUSABLE SKILL MEASUREMENTS',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in preflight.reusableSkills)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.skillName.toUpperCase(),
                                    style: SignageTypography.label(
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                PlacardBadge.info(item.levelCode!),
                              ],
                            ),
                          ),
                        const Divider(
                          height: 20,
                          color: SignageColors.lineSoft,
                        ),
                        FSwitch(
                          key: const Key('reuse-skills-toggle'),
                          label: const Text('Reuse valid skill measurements'),
                          value: _reuseValidSkills,
                          onChange: (value) =>
                              setState(() => _reuseValidSkills = value),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                PlacardPanel(
                  title: 'DEVICE PREFLIGHT CHECKS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'AUDIO OUTPUT',
                              style: SignageTypography.label(fontSize: 13),
                            ),
                          ),
                          PlacardBadge(
                            label: _audioChecked ? 'READY' : 'NOT TESTED',
                            variant: _audioChecked
                                ? PlacardBadgeVariant.success
                                : PlacardBadgeVariant.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      PlacardButton(
                        key: const Key('preflight-audio-check-btn'),
                        label: _audioChecked
                            ? 'CONFIRMED'
                            : 'CONFIRM AUDIO OUTPUT WORKS',
                        variant: PlacardButtonVariant.secondary,
                        onPress: _runAudioCheck,
                      ),
                      if ((preflight?.requiresMicrophone ?? true) &&
                          (isFirstPlacement ||
                              _selectedScope == 'all_skills')) ...[
                        const Divider(
                          height: 24,
                          color: SignageColors.lineSoft,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'MICROPHONE INPUT',
                                style: SignageTypography.label(fontSize: 13),
                              ),
                            ),
                            PlacardBadge(
                              label: _micChecked
                                  ? 'READY'
                                  : (_micGranted == false
                                        ? 'DENIED'
                                        : 'NOT TESTED'),
                              variant: _micChecked
                                  ? PlacardBadgeVariant.success
                                  : (_micGranted == false
                                        ? PlacardBadgeVariant.danger
                                        : PlacardBadgeVariant.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PlacardButton(
                          key: const Key('preflight-mic-check-btn'),
                          label: 'TEST MICROPHONE',
                          variant: PlacardButtonVariant.secondary,
                          onPress: _runMicCheck,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (exam == null) ...[
                  PlacardAlert(
                    variant: PlacardAlertVariant.warning,
                    title: 'NO PLACEMENT EXAM AVAILABLE',
                    subtitle:
                        'No placement exam is currently published for ${catalog.certificateCode.isEmpty ? 'this certificate' : catalog.certificateCode}. Switch certificate in ACCOUNT to take a placement test.',
                  ),
                  const SizedBox(height: 12),
                ],
                PlacardButton(
                  key: const Key('start-placement-btn'),
                  label: isFirstPlacement
                      ? 'START FREE PLACEMENT'
                      : 'START PLACEMENT RETAKE',
                  isLoading: _starting,
                  onPress: exam != null ? () => _startPlacement(catalog) : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
