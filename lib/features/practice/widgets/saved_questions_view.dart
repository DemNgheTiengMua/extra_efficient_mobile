import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/practice_models.dart';
import '../providers/practice_providers.dart';

class SavedQuestionsView extends ConsumerWidget {
  const SavedQuestionsView({super.key});

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    int savedQuestionId,
  ) async {
    final detail = await ref
        .read(practiceRepositoryProvider)
        .fetchSavedQuestionDetail(savedQuestionId);
    if (!context.mounted) return;
    await showFDialog<void>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        style: style,
        animation: animation,
        builder: (context, _) => _SavedDetailDialog(detail: detail),
      ),
    );
  }

  Future<void> _deleteItem(WidgetRef ref, int savedQuestionId) async {
    await ref
        .read(practiceRepositoryProvider)
        .deleteSavedQuestion(savedQuestionId);
    ref.invalidate(savedQuestionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedQuestionsProvider);
    final selectedSection = ref.watch(savedSectionFilterProvider);
    final selectedCategory = ref.watch(savedCategoryFilterProvider);

    return savedAsync.when(
      loading: () => const Center(child: FCircularProgress()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: StateBlock(
          stamp: 'ERROR',
          title: 'Could not load saved questions',
          description: '$err',
          action: PlacardButton(
            label: 'RETRY',
            onPress: () => ref.invalidate(savedQuestionsProvider),
          ),
        ),
      ),
      data: (data) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (data.sections.isNotEmpty || data.categories.isNotEmpty) ...[
              PlacardPanel(
                title: 'FILTERS',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.sections.isNotEmpty) ...[
                      Text('SECTION', style: SignageTypography.label()),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'ALL',
                            selected: selectedSection == null,
                            onTap: () => ref
                                .read(savedSectionFilterProvider.notifier)
                                .select(null),
                          ),
                          for (final s in data.sections)
                            _FilterChip(
                              key: Key('saved-filter-section-${s.id}'),
                              label: s.label,
                              selected: selectedSection == s.id,
                              onTap: () => ref
                                  .read(savedSectionFilterProvider.notifier)
                                  .select(s.id),
                            ),
                        ],
                      ),
                    ],
                    if (data.categories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('CATEGORY', style: SignageTypography.label()),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'ALL',
                            selected: selectedCategory == null,
                            onTap: () => ref
                                .read(savedCategoryFilterProvider.notifier)
                                .select(null),
                          ),
                          for (final c in data.categories)
                            _FilterChip(
                              key: Key('saved-filter-category-${c.id}'),
                              label: c.label,
                              selected: selectedCategory == c.id,
                              onTap: () => ref
                                  .read(savedCategoryFilterProvider.notifier)
                                  .select(c.id),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (data.items.isEmpty)
              const StateBlock(
                stamp: 'EMPTY',
                title: 'No saved questions',
                description: 'Bookmark questions during practice to review them here.',
              )
            else
              for (final item in data.items) ...[
                PlacardPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (item.sectionTitle != null)
                            PlacardBadge.info(item.sectionTitle!),
                          if (item.categoryName != null)
                            PlacardBadge.muted(item.categoryName!),
                          PlacardBadge.warning(item.source.toUpperCase()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.stem,
                        style: SignageTypography.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: PlacardButton(
                              key: Key('saved-question-${item.savedQuestionId}'),
                              label: 'REVIEW',
                              variant: PlacardButtonVariant.secondary,
                              onPress: () => _openDetail(
                                context,
                                ref,
                                item.savedQuestionId,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PlacardButton(
                              key: Key('delete-saved-${item.savedQuestionId}'),
                              label: 'REMOVE',
                              variant: PlacardButtonVariant.destructive,
                              onPress: () =>
                                  _deleteItem(ref, item.savedQuestionId),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FTappable(
      onPress: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? SignageColors.ink : SignageColors.paper,
          border: Border.all(color: SignageColors.ink, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label.toUpperCase(),
            style: SignageTypography.label(
              fontSize: 11,
              color: selected ? SignageColors.paper : SignageColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedDetailDialog extends ConsumerWidget {
  const _SavedDetailDialog({required this.detail});

  final SavedQuestionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlacardPanel(
      title: 'SAVED QUESTION REVIEW',
      footer: PlacardButton(
        key: const Key('saved-detail-close'),
        label: 'CLOSE',
        variant: PlacardButtonVariant.ink,
        onPress: () => Navigator.of(context).pop(),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                detail.stem,
                style: SignageTypography.body(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail.audioUrl != null && detail.audioUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                PlacardButton(
                  key: const Key('saved-detail-play-audio'),
                  label: 'PLAY AUDIO',
                  onPress: () async {
                    final audio = ref.read(audioMediaAdapterProvider);
                    await audio.setAudioUrl(
                      detail.audioUrl!,
                      clipStart: detail.clipStartMs != null
                          ? Duration(milliseconds: detail.clipStartMs!)
                          : null,
                      clipEnd: detail.clipEndMs != null
                          ? Duration(milliseconds: detail.clipEndMs!)
                          : null,
                    );
                    await audio.play();
                  },
                ),
              ],
              if (detail.options.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final opt in detail.options) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: opt.isCorrect
                          ? SignageColors.greenWash
                          : SignageColors.paper,
                      border: Border.all(
                        color: opt.isCorrect
                            ? SignageColors.signGreen
                            : SignageColors.lineSoft,
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${opt.label}. ${opt.text}',
                              style: SignageTypography.body(fontSize: 14),
                            ),
                          ),
                          if (opt.isCorrect)
                            const PlacardBadge.success('CORRECT'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
              if (detail.generalExplanation != null &&
                  detail.generalExplanation!.isNotEmpty) ...[
                const SizedBox(height: 12),
                PlacardAlert(
                  title: 'EXPLANATION',
                  subtitle: detail.generalExplanation,
                  variant: PlacardAlertVariant.info,
                ),
              ],
              if (detail.transcript != null &&
                  detail.transcript!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('TRANSCRIPT', style: SignageTypography.label()),
                const SizedBox(height: 4),
                Text(
                  detail.transcript!,
                  style: SignageTypography.body(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
