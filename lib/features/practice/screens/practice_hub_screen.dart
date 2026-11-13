import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
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

  Future<void> _startSession({int? sectionId, int? topicId, String? cefrLevelCode}) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final source = ref.read(practiceQuestionSourceProvider);
      final feedback = ref.read(practiceFeedbackModeProvider);
      final sessionId = await ref.read(practiceRepositoryProvider).startSession(
            sectionId: sectionId,
            topicId: topicId,
            cefrLevelCode: cefrLevelCode,
            questionSource: source,
            feedbackMode: feedback,
          );
      if (!mounted) return;
      if (sessionId > 0) {
        await context.push('/practice/sessions/$sessionId');
      }
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
                onStartSection: (id) => _startSession(sectionId: id),
                onStartCell: (topicId, level) =>
                    _startSession(topicId: topicId, cefrLevelCode: level),
                onResumeSession: (sessionId) =>
                    context.push('/practice/sessions/$sessionId'),
                onOpenSpeaking: () => context.go('/exams'),
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
    required this.onStartSection,
    required this.onStartCell,
    required this.onResumeSession,
    required this.onOpenSpeaking,
  });

  final bool starting;
  final ValueChanged<int> onStartSection;
  final void Function(int topicId, String cefrLevelCode) onStartCell;
  final ValueChanged<int> onResumeSession;
  final VoidCallback onOpenSpeaking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(practiceCatalogProvider);
    final matrixAsync = ref.watch(practiceMatrixProvider);
    final selectedSource = ref.watch(practiceQuestionSourceProvider);
    final selectedFeedback = ref.watch(practiceFeedbackModeProvider);

    return catalogAsync.when(
      loading: () => const Center(child: FCircularProgress()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: StateBlock(
          stamp: 'ERROR',
          title: 'Could not load practice catalog',
          description: '$err',
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
            PlacardPanel(
              title: 'SESSION CONFIGURATION',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QUESTION SOURCE', style: SignageTypography.label()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final src in PracticeQuestionSource.values) ...[
                        Expanded(
                          child: _SelectionChip(
                            label: src.label,
                            selected: selectedSource == src,
                            onPress: () => ref
                                .read(practiceQuestionSourceProvider.notifier)
                                .select(src),
                          ),
                        ),
                        if (src != PracticeQuestionSource.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('FEEDBACK MODE', style: SignageTypography.label()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final mode in PracticeFeedbackMode.values) ...[
                        Expanded(
                          child: _SelectionChip(
                            label: mode.label,
                            selected: selectedFeedback == mode,
                            onPress: () => ref
                                .read(practiceFeedbackModeProvider.notifier)
                                .select(mode),
                          ),
                        ),
                        if (mode != PracticeFeedbackMode.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${catalog.sectionNoun.toUpperCase()} CATALOG',
              style: SignageTypography.title().copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            for (final section in catalog.sections) ...[
              _SectionCard(
                section: section,
                starting: starting,
                onStart: () => onStartSection(section.sectionId),
                onOpenSpeaking: onOpenSpeaking,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
              'TOPIC × CEFR MATRIX',
              style: SignageTypography.title().copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            matrixAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: FCircularProgress()),
              ),
              error: (err, _) => PlacardAlert(
                title: 'Matrix unavailable',
                subtitle: '$err',
                variant: PlacardAlertVariant.warning,
              ),
              data: (matrix) => _MatrixTable(
                matrix: matrix,
                onSelectCell: onStartCell,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UnfinishedSessionBanner extends StatelessWidget {
  const _UnfinishedSessionBanner({
    required this.session,
    required this.onResume,
  });

  final UnfinishedPracticeSession session;
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
            session.title,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${session.answeredCount}/${session.totalCount} ANSWERED',
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

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return FTappable(
      onPress: onPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? SignageColors.ink : SignageColors.paper,
          border: Border.all(color: SignageColors.ink, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: SignageTypography.label(
                fontSize: 11,
                color: selected ? SignageColors.paper : SignageColors.ink,
              ),
            ),
          ),
        ),
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

  final PracticeSectionItem section;
  final bool starting;
  final VoidCallback onStart;
  final VoidCallback onOpenSpeaking;

  @override
  Widget build(BuildContext context) {
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
                      section.title,
                      style: SignageTypography.condensedSentence(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        PlacardBadge.muted(section.skill.toUpperCase()),
                        if (section.cooldownActive)
                          const PlacardBadge.warning('COOLDOWN'),
                      ],
                    ),
                  ],
                ),
              ),
              if (section.accuracyPercent != null)
                Text(
                  '${section.accuracyPercent}%',
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
              label: 'START DRILL',
              isLoading: starting,
              onPress: onStart,
            ),
        ],
      ),
    );
  }
}

class _MatrixTable extends StatelessWidget {
  const _MatrixTable({
    required this.matrix,
    required this.onSelectCell,
  });

  final PracticeMatrix matrix;
  final void Function(int topicId, String cefrLevelCode) onSelectCell;

  @override
  Widget build(BuildContext context) {
    if (matrix.topics.isEmpty || matrix.levels.isEmpty) {
      return const StateBlock(
        stamp: 'EMPTY',
        title: 'No matrix cells available',
        description: 'No topic and CEFR level cells for this certificate.',
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
                        cell: topic.cells.cast<PracticeMatrixCell?>().firstWhere(
                              (c) => c?.cefrLevelCode == level,
                              orElse: () => null,
                            ),
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
  const _MatrixCellTile({required this.cell, required this.onTap});

  final PracticeMatrixCell? cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = cell != null && cell!.questionCount > 0;
    return FTappable(
      onPress: available ? onTap : null,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: SignageColors.lineSoft, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Center(
            child: Text(
              available
                  ? (cell!.accuracyPercent != null
                      ? '${cell!.accuracyPercent}%'
                      : '${cell!.questionCount}Q')
                  : '—',
              style: SignageTypography.data(
                fontSize: 12,
                fontWeight: available ? FontWeight.w700 : FontWeight.w400,
                color: available ? SignageColors.signBlue : SignageColors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
