import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
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
      setState(() => _error = e.toString());
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
              onStart: (id) => _startSkillAttempt('speaking', id),
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
              onStart: (id) => _startSkillAttempt('writing', id),
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
  final ValueChanged<int> onStart;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => StateBlock(
        stamp: 'ERROR',
        title: 'UNABLE TO LOAD',
        description: err.toString(),
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
                            starting ? null : () => onStart(items[i].examId),
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
