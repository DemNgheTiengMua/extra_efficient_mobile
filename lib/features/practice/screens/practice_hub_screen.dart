import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../models/practice_models.dart';
import '../providers/practice_providers.dart';
import '../widgets/saved_questions_view.dart';
import '../widgets/weakness_analysis_view.dart';

enum _PracticeSubTab { drills, saved, weakness }

class PracticeHubScreen extends ConsumerStatefulWidget {
  const PracticeHubScreen({super.key});

  @override
  ConsumerState<PracticeHubScreen> createState() => _PracticeHubScreenState();
}

class _PracticeHubScreenState extends ConsumerState<PracticeHubScreen> {
  _PracticeSubTab _subTab = _PracticeSubTab.drills;
  bool _starting = false;

  /// The backend's own refusal for the last start attempt.
  String? _startError;

  Future<void> _startSession({int? sectionId, int? topicId, String? cefrLevelCode}) async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final sessionId = await ref.read(practiceRepositoryProvider).startSession(
            sectionId: sectionId,
            topicId: topicId,
            cefrLevelCode: cefrLevelCode,
          );
      if (!mounted) return;
      if (sessionId > 0) {
        await context.push('/practice/sessions/$sessionId');
      }
    } catch (e) {
      if (!mounted) return;
      // `extractApiError` prefers the backend's `detail`, which is where the
      // actionable sentence lives; `title` is only a short label.
      setState(() {
        _startError = extractApiError(
          e,
          fallback: 'This drill could not be started.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubTabBar(
          current: _subTab,
          onSelect: (tab) => setState(() => _subTab = tab),
        ),
        Expanded(
          child: switch (_subTab) {
            _PracticeSubTab.drills => _DrillsView(
                starting: _starting,
                startError: _startError,
                onDismissError: () => setState(() => _startError = null),
                onStartSection: (id) => _startSession(sectionId: id),
                onStartCell: (topicId, level) =>
                    _startSession(topicId: topicId, cefrLevelCode: level),
                onResumeSession: (sessionId) =>
                    context.push('/practice/sessions/$sessionId'),
                onOpenSpeaking: () =>
                    context.push('/practice/skill-practice'),
              ),
            _PracticeSubTab.saved => const SavedQuestionsView(),
            _PracticeSubTab.weakness => const WeaknessAnalysisView(),
          },
        ),
      ],
    );
  }
}

class _SubTabBar extends StatelessWidget {
  const _SubTabBar({required this.current, required this.onSelect});

  final _PracticeSubTab current;
  final ValueChanged<_PracticeSubTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SignageColors.paper,
        border: Border(
          bottom: BorderSide(color: SignageColors.ink, width: 2),
        ),
      ),
      child: Row(
        children: [
          _tabItem(_PracticeSubTab.drills, 'DRILLS'),
          _tabItem(_PracticeSubTab.saved, 'SAVED'),
          _tabItem(_PracticeSubTab.weakness, 'WEAKNESS'),
        ],
      ),
    );
  }

  Widget _tabItem(_PracticeSubTab tab, String label) {
    final selected = current == tab;
    return Expanded(
      child: FTappable(
        onPress: () => onSelect(tab),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? SignageColors.ink : SignageColors.paper,
            border: const Border(
              right: BorderSide(color: SignageColors.lineSoft, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: SignageTypography.label(
                  fontSize: 12,
                  color: selected ? SignageColors.paper : SignageColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrillsView extends ConsumerWidget {
  const _DrillsView({
    required this.starting,
    required this.startError,
    required this.onDismissError,
    required this.onStartSection,
    required this.onStartCell,
    required this.onResumeSession,
    required this.onOpenSpeaking,
  });

  final bool starting;
  final String? startError;
  final VoidCallback onDismissError;
  final ValueChanged<int> onStartSection;
  final void Function(int topicId, String cefrLevelCode) onStartCell;
  final ValueChanged<int> onResumeSession;
  final VoidCallback onOpenSpeaking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(practiceCatalogProvider);

    return catalogAsync.when(
      loading: () => const Center(child: FCircularProgress()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: StateBlock(
          stamp: 'ERROR',
          title: 'Could not load practice catalog',
          description: extractApiError(
            err,
            fallback: 'The practice catalogue could not be loaded.',
          ),
          action: PlacardButton(
            label: 'RETRY',
            onPress: () => ref.invalidate(practiceCatalogProvider),
          ),
        ),
      ),
      data: (catalog) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (catalog.unfinishedSession != null) ...[
              _UnfinishedSessionBanner(
                session: catalog.unfinishedSession!,
                onResume: () =>
                    onResumeSession(catalog.unfinishedSession!.sessionId),
              ),
              const SizedBox(height: 16),
            ],
            if (startError != null) ...[
              PlacardAlert(
                title: 'Drill not started',
                subtitle: startError!,
                variant: PlacardAlertVariant.danger,
              ),
              const SizedBox(height: 8),
              PlacardButton(
                label: 'DISMISS',
                variant: PlacardButtonVariant.secondary,
                onPress: onDismissError,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              '${catalog.sectionNoun.toUpperCase()} CATALOG',
              style: SignageTypography.title().copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (catalog.skillGroups.isEmpty)
              const StateBlock(
                stamp: 'EMPTY',
                title: 'No sections for this certificate',
                description:
                    'This certificate has no drillable sections yet.',
              )
            else
              for (final group in catalog.skillGroups) ...[
                _SkillGroupHeader(
                  skillName: group.skillName,
                  sectionNoun: catalog.sectionNoun,
                  sectionCount: group.sections.length,
                ),
                const SizedBox(height: 8),
                for (final section in group.sections) ...[
                  _SectionCard(
                    section: section,
                    starting: starting,
                    onStart: () => onStartSection(section.sectionId),
                    onOpenSpeaking: onOpenSpeaking,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
              ],
            const SizedBox(height: 8),
            Text(
              'TOPIC × LEVEL MATRIX',
              style: SignageTypography.title().copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            ref.watch(practiceGridProvider).when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: FCircularProgress()),
                  ),
                  error: (err, _) => StateBlock(
                    stamp: 'ERROR',
                    title: 'Could not load the practice grid',
                    description: extractApiError(
                      err,
                      fallback: 'The topic and level grid could not be loaded.',
                    ),
                    action: PlacardButton(
                      label: 'RETRY',
                      onPress: () => ref.invalidate(practiceGridProvider),
                    ),
                  ),
                  data: (grid) => _MatrixTable(
                    grid: grid,
                    starting: starting,
                    onSelectCell: onStartCell,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _SkillGroupHeader extends StatelessWidget {
  const _SkillGroupHeader({
    required this.skillName,
    required this.sectionNoun,
    required this.sectionCount,
  });

  final String skillName;
  final String sectionNoun;
  final int sectionCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          skillName.toUpperCase(),
          style: SignageTypography.label(fontSize: 13),
        ),
        const SizedBox(width: 8),
        Text(
          '$sectionCount ${sectionNoun.toUpperCase()}${sectionCount == 1 ? '' : 'S'}',
          style: SignageTypography.data(
            fontSize: 12,
            color: SignageColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _UnfinishedSessionBanner extends StatelessWidget {
  const _UnfinishedSessionBanner({
    required this.session,
    required this.onResume,
  });

  final PracticeSession session;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      backgroundColor: SignageColors.goldWash,
      title: 'UNFINISHED PRACTICE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.sectionName,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${session.sectionCode} · ${session.questionCount} QUESTIONS'
            '${session.correctCount > 0 ? ' · ${session.correctCount} CORRECT' : ''}',
            style: SignageTypography.data(
              fontSize: 13,
              color: SignageColors.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          PlacardButton(
            label: 'RESUME SESSION',
            variant: PlacardButtonVariant.ink,
            onPress: onResume,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.starting,
    required this.onStart,
    required this.onOpenSpeaking,
  });

  final PracticeSection section;
  final bool starting;
  final VoidCallback onStart;
  final VoidCallback onOpenSpeaking;

  @override
  Widget build(BuildContext context) {
    final cooldown = section.categoriesInCooldown > 0;
    return PlacardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${section.code} · ${section.name}',
                      style: SignageTypography.condensedSentence(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        PlacardBadge.muted(
                          '${section.availableQuestionCount}/'
                          '${section.expectedQuestionCount} QUESTIONS',
                        ),
                        if (cooldown)
                          PlacardBadge.warning(
                            '${section.categoriesInCooldown} RESTING',
                          ),
                        if (!section.isSpeaking && !section.isAvailable)
                          const PlacardBadge.muted('NO QUESTIONS'),
                      ],
                    ),
                  ],
                ),
              ),
              if (section.accuracyPercentage != null)
                Text(
                  '${section.accuracyPercentage}%',
                  style: SignageTypography.data(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SignageColors.signBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (section.isSpeaking)
            PlacardButton(
              key: Key('speaking-section-${section.sectionId}'),
              label: 'SPEAKING ATTEMPT',
              variant: PlacardButtonVariant.secondary,
              onPress: onOpenSpeaking,
            )
          else
            PlacardButton(
              key: Key('start-section-${section.sectionId}'),
              label: section.isAvailable ? 'START DRILL' : 'NO QUESTIONS',
              isLoading: starting,
              onPress: section.isAvailable ? onStart : null,
            ),
        ],
      ),
    );
  }
}

class _MatrixTable extends StatelessWidget {
  const _MatrixTable({
    required this.grid,
    required this.starting,
    required this.onSelectCell,
  });

  final PracticeGrid grid;
  final bool starting;
  final void Function(int topicId, String cefrLevelCode) onSelectCell;

  @override
  Widget build(BuildContext context) {
    final matrix = grid.matrix;
    if (matrix.isEmpty) {
      return const StateBlock(
        stamp: 'EMPTY',
        title: 'No matrix cells available',
        description: 'No topic and level cells for this certificate.',
      );
    }

    return PlacardPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: SignageColors.softSurface,
              border: Border(
                bottom: BorderSide(color: SignageColors.ink, width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('TOPIC', style: SignageTypography.label()),
                  ),
                ),
                for (final level in matrix.levels)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Center(
                        child: Text(level, style: SignageTypography.label()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final topic in matrix.topics)
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: SignageColors.lineSoft, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        topic.name,
                        style: SignageTypography.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  for (final level in matrix.levels)
                    Expanded(
                      child: _MatrixCellTile(
                        cell: topic.cellAt(level),
                        lock: grid.lockFor(topic.topicId, level),
                        starting: starting,
                        onTap: () => onSelectCell(topic.topicId, level),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MatrixCellTile extends StatelessWidget {
  const _MatrixCellTile({
    required this.cell,
    required this.lock,
    required this.starting,
    required this.onTap,
  });

  final PracticeMatrixCell? cell;
  final PracticeFreeDrillState? lock;
  final bool starting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = lock != null && !lock!.isUnlocked;
    final available = cell != null && !cell!.isRestingNow && !locked;
    final label = switch (cell?.mastery) {
      null => '—',
      PracticeMastery.untested => 'NEW',
      PracticeMastery.learning => 'LEARN',
      PracticeMastery.reviewing => 'REVIEW',
      PracticeMastery.mastered => 'MSTR',
    };

    return FTappable(
      key: cell == null ? null : Key('matrix-cell-${cell!.topicId}-${cell!.levelCode}'),
      onPress: available ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: available ? SignageColors.paper : SignageColors.wall,
          border: const Border(
            left: BorderSide(color: SignageColors.lineSoft, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: SignageTypography.data(
                    fontSize: 11,
                    fontWeight: available ? FontWeight.w700 : FontWeight.w400,
                    color: available
                        ? SignageColors.signBlue
                        : SignageColors.inkMuted,
                  ),
                ),
                if (cell != null && !available) ...[
                  const SizedBox(height: 2),
                  Text(
                    cell!.isRestingNow ? 'REST' : 'LOCKED',
                    style: SignageTypography.label(
                      fontSize: 9,
                      color: SignageColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
