import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../models/practice_models.dart';
import '../providers/practice_providers.dart';

class SavedQuestionsView extends ConsumerStatefulWidget {
  const SavedQuestionsView({super.key});

  @override
  ConsumerState<SavedQuestionsView> createState() => _SavedQuestionsViewState();
}

class _SavedQuestionsViewState extends ConsumerState<SavedQuestionsView> {
  String? _error;
  int? _deletingId;

  Future<void> _openDetail(int savedQuestionId) async {
    final SavedQuestionItem detail;
    try {
      detail = await ref
          .read(practiceRepositoryProvider)
          .fetchSavedQuestionDetail(savedQuestionId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractApiError(e, fallback: 'Could not load saved question');
      });
      return;
    }
    if (!mounted) return;
    await showFDialog<void>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        style: style,
        animation: animation,
        builder: (context, _) => _SavedDetailDialog(detail: detail),
      ),
    );
  }

  Future<void> _deleteItem(int savedQuestionId) async {
    setState(() {
      _deletingId = savedQuestionId;
      _error = null;
    });
    try {
      // DELETE answers 200 with `isSaved: false`; the body is the confirmation.
      final result = await ref
          .read(practiceRepositoryProvider)
          .deleteSavedQuestion(savedQuestionId);
      if (!mounted) return;
      if (result.isSaved) {
        setState(() => _error = 'The question is still saved.');
        return;
      }
      ref.invalidate(savedQuestionsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractApiError(e, fallback: 'Could not remove saved question');
      });
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          description: extractApiError(err, fallback: '$err'),
          action: PlacardButton(
            label: 'RETRY',
            onPress: () => ref.invalidate(savedQuestionsProvider),
          ),
        ),
      ),
      data: (data) {
        // The backend builds these two facets but applies neither when the list
        // is fetched, so narrow here rather than letting a chip claim a filter
        // the server did not make. Both lists are empty on the live certificate
        // (a pool item is section- and category-free), so the panel is absent.
        final hasFilters =
            data.sections.isNotEmpty || data.categories.isNotEmpty;
        final items = data.items.where((item) {
          if (selectedSection != null && item.sectionId != selectedSection) {
            return false;
          }
          if (selectedCategory != null && item.categoryId != selectedCategory) {
            return false;
          }
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              PlacardAlert(
                key: const Key('saved-error'),
                title: _error!,
                variant: PlacardAlertVariant.danger,
              ),
              const SizedBox(height: 16),
            ],
            if (hasFilters) ...[
              PlacardPanel(
                title: 'FILTERS',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.sections.isNotEmpty) ...[
                      Text(
                        data.sectionNoun.toUpperCase(),
                        style: SignageTypography.label(),
                      ),
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
                              label: '${s.label} (${s.count})',
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
                              label: '${c.label} (${c.count})',
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
            if (items.isEmpty)
              StateBlock(
                stamp: 'EMPTY',
                title: data.items.isEmpty
                    ? 'No saved questions'
                    : 'Nothing matches these filters',
                description: data.items.isEmpty
                    ? 'Bookmark a question during practice and it is filed here '
                        'with its explanation and audio.'
                    : 'Clear the filter to see every saved question again.',
              )
            else
              for (final item in items) ...[
                _SavedItemCard(
                  item: item,
                  isDeleting: _deletingId == item.savedQuestionId,
                  onReview: () => _openDetail(item.savedQuestionId),
                  onRemove: () => _deleteItem(item.savedQuestionId),
                ),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _SavedItemCard extends StatelessWidget {
  const _SavedItemCard({
    required this.item,
    required this.isDeleting,
    required this.onReview,
    required this.onRemove,
  });

  final SavedQuestionItem item;
  final bool isDeleting;
  final VoidCallback onReview;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // `scopeName` is the server's own pick: a section drill's section
              // or a pool item's topic. Never read `sectionName` directly.
              if (item.scopeName.isNotEmpty)
                PlacardBadge.info(item.scopeName),
              if (item.categoryName != null)
                PlacardBadge.muted(item.categoryName!),
              PlacardBadge.warning(item.source),
              if (item.isRetiredDefective)
                const PlacardBadge.danger('RETIRED DEFECTIVE'),
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
                  onPress: onReview,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PlacardButton(
                  key: Key('delete-saved-${item.savedQuestionId}'),
                  label: 'REMOVE',
                  variant: PlacardButtonVariant.destructive,
                  isLoading: isDeleting,
                  onPress: onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
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

class _SavedDetailDialog extends ConsumerStatefulWidget {
  const _SavedDetailDialog({required this.detail});

  final SavedQuestionItem detail;

  @override
  ConsumerState<_SavedDetailDialog> createState() => _SavedDetailDialogState();
}

class _SavedDetailDialogState extends ConsumerState<_SavedDetailDialog> {
  String? _audioError;

  Future<void> _playAudio(String path) async {
    setState(() => _audioError = null);
    try {
      final audio = ref.read(audioMediaAdapterProvider);
      await audio.setAudioUrl(path);
      await audio.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _audioError = extractApiError(e, fallback: 'Could not play audio');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final audioPath = detail.audioPath;

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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (detail.scopeName.isNotEmpty)
                    PlacardBadge.info(detail.scopeName),
                  PlacardBadge.warning(detail.source),
                  if (detail.isRetiredDefective)
                    const PlacardBadge.danger('RETIRED DEFECTIVE'),
                ],
              ),
              const SizedBox(height: 8),
              if (detail.passage != null && detail.passage!.isNotEmpty) ...[
                Text(detail.passage!, style: SignageTypography.body()),
                const SizedBox(height: 12),
                const Divider(color: SignageColors.lineSoft, height: 1),
                const SizedBox(height: 12),
              ],
              Text(
                detail.stem,
                style: SignageTypography.body(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (audioPath != null && audioPath.isNotEmpty) ...[
                const SizedBox(height: 12),
                PlacardButton(
                  key: const Key('saved-detail-play-audio'),
                  label: 'PLAY AUDIO',
                  onPress: () => _playAudio(audioPath),
                ),
                if (_audioError != null) ...[
                  const SizedBox(height: 8),
                  PlacardAlert(
                    key: const Key('saved-detail-audio-error'),
                    title: _audioError!,
                    variant: PlacardAlertVariant.warning,
                  ),
                ],
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
              if (detail.explanation != null &&
                  detail.explanation!.isNotEmpty) ...[
                const SizedBox(height: 12),
                PlacardAlert(
                  key: const Key('saved-detail-explanation'),
                  title: 'EXPLANATION',
                  subtitle: detail.explanation,
                  variant: PlacardAlertVariant.info,
                ),
              ],
              if (detail.hint != null && detail.hint!.isNotEmpty) ...[
                const SizedBox(height: 12),
                PlacardAlert(
                  title: 'HINT',
                  subtitle: detail.hint,
                  variant: PlacardAlertVariant.warning,
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
