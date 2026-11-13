import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../../context/learner_context_provider.dart';
import '../models/skill_practice_models.dart';
import '../providers/skill_practice_providers.dart';

/// Paid Speaking & Writing Skill Practice catalog launched from PRACTICE tab.
class SkillPracticeCatalogScreen extends ConsumerStatefulWidget {
  const SkillPracticeCatalogScreen({super.key});

  @override
  ConsumerState<SkillPracticeCatalogScreen> createState() =>
      _SkillPracticeCatalogScreenState();
}

class _SkillPracticeCatalogScreenState
    extends ConsumerState<SkillPracticeCatalogScreen> {
  bool _starting = false;
  String? _error;

  Future<void> _openPreStartDialog(
    String skill,
    SkillPracticeExamSummary summary,
  ) async {
    if (_starting) return;
    setState(() => _error = null);
    Map<String, dynamic> instructions;
    try {
      instructions = await ref
          .read(skillPracticeRepositoryProvider)
          .fetchInstructions(skill, summary.examId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = extractApiError(e, fallback: 'Could not start this skill practice.'));
      return;
    }
    if (!mounted) return;

    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (dialogContext, style, animation) => FDialog(
        style: style,
        animation: animation,
        builder: (context, _) => _SkillPreStartDialog(
          skill: skill,
          summary: summary,
          instructions: instructions,
          audioAdapter: ref.read(audioMediaAdapterProvider),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _startSkillAttempt(skill, summary.examId);
    }
  }

  Future<void> _startSkillAttempt(String skill, int examId) async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final attemptId = await ref
          .read(skillPracticeRepositoryProvider)
          .startAttempt(skill, examId);
      ref.invalidate(learnerContextProvider);
      if (!mounted) return;
      context.push('/practice/skill-practice/$skill/attempts/$attemptId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = extractApiError(e, fallback: 'Could not start this skill practice.'));
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final speakingAsync = ref.watch(speakingCatalogProvider);
    final writingAsync = ref.watch(writingCatalogProvider);

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
                    'PAID SKILL PRACTICE',
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            PlacardAlert(
              variant: PlacardAlertVariant.danger,
              title: 'UNABLE TO START',
              subtitle: _error!,
            ),
            const SizedBox(height: 12),
          ],
          PlacardPanel(
            title: 'SPEAKING SKILL PRACTICE',
            child: _CatalogSection(
              asyncItems: speakingAsync,
              skill: 'speaking',
              starting: _starting,
              onStart: (item) => _openPreStartDialog('speaking', item),
              onRetry: () => ref.invalidate(speakingCatalogProvider),
            ),
          ),
          const SizedBox(height: 16),
          PlacardPanel(
            title: 'WRITING SKILL PRACTICE',
            child: _CatalogSection(
              asyncItems: writingAsync,
              skill: 'writing',
              starting: _starting,
              onStart: (item) => _openPreStartDialog('writing', item),
              onRetry: () => ref.invalidate(writingCatalogProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSection extends StatelessWidget {
  const _CatalogSection({
    required this.asyncItems,
    required this.skill,
    required this.starting,
    required this.onStart,
    required this.onRetry,
  });

  final AsyncValue<List<SkillPracticeExamSummary>> asyncItems;
  final String skill;
  final bool starting;
  final ValueChanged<SkillPracticeExamSummary> onStart;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return asyncItems.when(
      loading: () => const Center(child: FCircularProgress()),
      error: (err, _) => StateBlock(
        stamp: 'ERROR',
        title: 'UNABLE TO LOAD',
        description: extractApiError(
          err,
          fallback: 'The skill practice catalogue could not be loaded.',
        ),
        action: PlacardButton(label: 'RETRY', onPress: onRetry),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const StateBlock(
            stamp: 'EMPTY',
            title: 'NONE AVAILABLE',
            description: 'No skill practice tasks published for this skill.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: SignageColors.paper,
                  border: Border.all(color: SignageColors.ink, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i].title,
                              style: SignageTypography.condensedSentence(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${items[i].credits} CREDIT · ${items[i].questionCount} TASK',
                              style: SignageTypography.data(
                                fontSize: 12,
                                color: SignageColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PlacardButton(
                        key: Key('start-$skill-${items[i].examId}'),
                        label: 'START',
                        expand: false,
                        onPress:
                            starting ? null : () => onStart(items[i]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SkillPreStartDialog extends StatefulWidget {
  const _SkillPreStartDialog({
    required this.skill,
    required this.summary,
    required this.instructions,
    required this.audioAdapter,
  });

  final String skill;
  final SkillPracticeExamSummary summary;
  final Map<String, dynamic> instructions;
  final AudioMediaAdapter audioAdapter;

  @override
  State<_SkillPreStartDialog> createState() => _SkillPreStartDialogState();
}

class _SkillPreStartDialogState extends State<_SkillPreStartDialog> {
  bool _micChecking = false;
  bool _micReady = false;
  String? _micError;

  bool get _requiresMic => widget.skill == 'speaking';

  Future<void> _runMicCheck() async {
    if (_micChecking) return;
    setState(() {
      _micChecking = true;
      _micError = null;
    });
    try {
      final granted = await widget.audioAdapter.hasRecordPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _micChecking = false;
          _micError = 'Microphone permission denied.';
        });
        return;
      }
      await widget.audioAdapter.startRecording(
        'mic_check_${widget.summary.examId}.m4a',
      );
      await widget.audioAdapter.stopRecording();
      if (!mounted) return;
      setState(() {
        _micChecking = false;
        _micReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _micChecking = false;
        _micError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final examName = (widget.instructions['examName'] as String?) ??
        widget.summary.title;
    final description = (widget.instructions['description'] as String?) ?? '';
    final creditCost =
        (widget.instructions['creditCost'] as num?)?.toInt() ??
            widget.summary.credits;
    final durationMinutes =
        (widget.instructions['durationMinutes'] as num?)?.toInt();
    final questionCount =
        (widget.instructions['questionCount'] as num?)?.toInt() ??
            widget.summary.questionCount;
    final canStart = !_requiresMic || _micReady;

    return PlacardPanel(
      title: '${widget.skill.toUpperCase()} INSTRUCTIONS',
      trailing: _requiresMic
          ? (_micReady
              ? const PlacardBadge.success('MIC READY')
              : const PlacardBadge.muted('MIC REQUIRED'))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            examName,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: SignageTypography.body(fontSize: 14),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$questionCount TASK · ${durationMinutes != null ? '$durationMinutes MIN · ' : ''}SPENDS $creditCost CREDIT${creditCost == 1 ? '' : 'S'}',
            style: SignageTypography.data(
              fontSize: 12,
              color: SignageColors.inkMuted,
            ),
          ),
          if (_requiresMic) ...[
            const SizedBox(height: 12),
            if (_micError != null) ...[
              PlacardAlert(
                variant: PlacardAlertVariant.danger,
                title: 'MICROPHONE CHECK FAILED',
                subtitle: _micError!,
              ),
              const SizedBox(height: 8),
            ],
            PlacardButton(
              key: const Key('skill-mic-check-btn'),
              label: _micChecking
                  ? 'TESTING MIC...'
                  : (_micReady ? 'MIC VERIFIED' : 'TEST MICROPHONE'),
              variant: PlacardButtonVariant.secondary,
              onPress: _micChecking ? null : _runMicCheck,
            ),
          ],
          const SizedBox(height: 12),
          PlacardButton(
            key: Key('confirm-start-${widget.skill}-${widget.summary.examId}'),
            label: 'START ATTEMPT',
            onPress: canStart ? () => Navigator.of(context).pop(true) : null,
          ),
          const SizedBox(height: 8),
          PlacardButton(
            label: 'CANCEL',
            variant: PlacardButtonVariant.secondary,
            onPress: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
