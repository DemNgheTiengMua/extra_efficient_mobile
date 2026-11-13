import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../models/path_models.dart';
import '../providers/path_providers.dart';

class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({super.key, required this.lessonId});

  final int lessonId;

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  PageController? _pageController;
  int _currentIndex = 0;
  bool _initializedIndex = false;
  bool _completed = false;
  bool _isAudioPlaying = false;
  final Map<int, String> _selectedOptions = {};
  final Map<int, MicroCheckResult> _microCheckResults = {};
  bool _isSubmittingCheck = false;
  String? _actionError;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _initPageIndex(LessonDetail lesson, LessonProgress? progress) {
    if (_initializedIndex) return;
    _initializedIndex = true;
    final maxIdx = lesson.cards.isEmpty ? 0 : lesson.cards.length - 1;
    final initial = (progress?.lastViewedCardIndex ?? 0).clamp(0, maxIdx);
    _currentIndex = initial;
    _completed = progress?.completed ?? false;
    _pageController = PageController(initialPage: initial);
  }

  bool _canAdvanceFrom(LessonCard card) {
    if (!card.isMicroCheck) return true;
    return _microCheckResults[card.id]?.correct == true;
  }

  Future<void> _goPrevious() async {
    if (_currentIndex <= 0) return;
    final next = _currentIndex - 1;
    setState(() => _currentIndex = next);
    await _pageController?.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goNext(LessonDetail lesson) async {
    if (_currentIndex >= lesson.cards.length - 1) return;
    final currentCard = lesson.cards[_currentIndex];
    if (!_canAdvanceFrom(currentCard)) return;

    // Progress is a write: if it fails the card must not advance silently.
    try {
      await ref
          .read(pathRepositoryProvider)
          .markCardViewed(lesson.id, currentCard.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = extractApiError(
          e,
          fallback: 'Could not save your progress in this lesson.',
        );
      });
      return;
    }
    if (!mounted) return;

    final next = _currentIndex + 1;
    setState(() => _currentIndex = next);
    await _pageController?.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _completeLesson(LessonDetail lesson) async {
    final currentCard = lesson.cards[_currentIndex];
    if (!_canAdvanceFrom(currentCard)) return;

    try {
      await ref
          .read(pathRepositoryProvider)
          .markCardViewed(lesson.id, currentCard.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = extractApiError(
          e,
          fallback: 'Could not save your progress in this lesson.',
        );
      });
      return;
    }
    if (mounted) {
      setState(() => _completed = true);
    }
    ref.invalidate(lessonProgressProvider(lesson.id));
    ref.invalidate(learningPathProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _submitMicroCheck(LessonDetail lesson, LessonCard card) async {
    final selected = _selectedOptions[card.id];
    if (selected == null) return;
    setState(() {
      _isSubmittingCheck = true;
      _actionError = null;
    });
    try {
      final result = await ref.read(pathRepositoryProvider).submitMicroCheck(
            lessonId: lesson.id,
            cardId: card.id,
            selectedOption: selected,
          );
      if (mounted) {
        setState(() => _microCheckResults[card.id] = result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = extractApiError(
          e,
          fallback: 'Could not check this answer.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCheck = false);
      }
    }
  }

  Future<void> _toggleAudio(String url) async {
    final adapter = ref.read(audioMediaAdapterProvider);
    if (_isAudioPlaying) {
      await adapter.pause();
      if (mounted) setState(() => _isAudioPlaying = false);
    } else {
      await adapter.setAudioUrl(url);
      await adapter.play();
      if (mounted) setState(() => _isAudioPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonDetailProvider(widget.lessonId));
    final progressAsync = ref.watch(lessonProgressProvider(widget.lessonId));

    return lessonAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          PlacardPanel(
            title: 'LOADING LESSON',
            child: Text('Loading lesson cards...'),
          ),
        ],
      ),
      error: (error, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StateBlock(
            stamp: 'LESSON ERROR',
            title: 'Unable to load lesson',
            description: extractApiError(
              error,
              fallback: 'This lesson could not be opened.',
            ),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () {
                ref.invalidate(lessonDetailProvider(widget.lessonId));
                ref.invalidate(lessonProgressProvider(widget.lessonId));
              },
            ),
          ),
        ],
      ),
      data: (lesson) {
        if (lesson == null || lesson.cards.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              StateBlock(
                stamp: 'EMPTY',
                title: 'No cards in this lesson',
                description: 'This lesson has no cards yet.',
              ),
            ],
          );
        }

        if (progressAsync.isLoading && !_initializedIndex) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              PlacardPanel(
                title: 'RESUMING PROGRESS',
                child: Text('Checking last viewed card...'),
              ),
            ],
          );
        }

        _initPageIndex(lesson, progressAsync.value);

        if (_completed) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StateBlock(
                stamp: 'LESSON COMPLETED',
                title: lesson.title,
                description:
                    'All ${lesson.cards.length} cards completed and progress saved.',
                action: PlacardButton(
                  label: 'REVIEW FROM CARD 1',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () {
                    setState(() {
                      _completed = false;
                      _currentIndex = 0;
                    });
                    _pageController?.jumpToPage(0);
                  },
                ),
              ),
            ],
          );
        }

        final total = lesson.cards.length;
        final currentCard = lesson.cards[_currentIndex];
        final isLast = _currentIndex == total - 1;
        final canAdvance = _canAdvanceFrom(currentCard);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lesson.title.toUpperCase(),
                      style: SignageTypography.label(fontSize: 13),
                    ),
                  ),
                  PlacardBadge.info('${_currentIndex + 1} OF $total'),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: canAdvance
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: total,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final card = lesson.cards[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _LessonCardView(
                      card: card,
                      selectedOption: _selectedOptions[card.id],
                      checkResult: _microCheckResults[card.id],
                      checkError: _actionError,
                      isSubmittingCheck: _isSubmittingCheck,
                      isAudioPlaying: _isAudioPlaying,
                      onSelectOption: (opt) => setState(() {
                        _selectedOptions[card.id] = opt;
                        _actionError = null;
                      }),
                      onSubmitCheck: () => _submitMicroCheck(lesson, card),
                      onToggleAudio: card.audioUrl != null
                          ? () => _toggleAudio(card.audioUrl!)
                          : null,
                    ),
                  );
                },
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: SignageColors.paper,
                border: Border(
                  top: BorderSide(color: SignageColors.ink, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: PlacardButton(
                        key: const Key('lesson-prev-btn'),
                        label: 'PREVIOUS',
                        variant: PlacardButtonVariant.secondary,
                        onPress: _currentIndex > 0 ? _goPrevious : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: isLast
                          ? PlacardButton(
                              key: const Key('lesson-complete-btn'),
                              label: 'COMPLETE LESSON',
                              onPress: canAdvance
                                  ? () => _completeLesson(lesson)
                                  : null,
                            )
                          : PlacardButton(
                              key: const Key('lesson-next-btn'),
                              label: 'NEXT',
                              onPress: canAdvance
                                  ? () => _goNext(lesson)
                                  : null,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LessonCardView extends StatelessWidget {
  const _LessonCardView({
    required this.card,
    required this.selectedOption,
    required this.checkResult,
    required this.checkError,
    required this.isSubmittingCheck,
    required this.isAudioPlaying,
    required this.onSelectOption,
    required this.onSubmitCheck,
    required this.onToggleAudio,
  });

  final LessonCard card;
  final String? selectedOption;
  final MicroCheckResult? checkResult;
  final String? checkError;
  final bool isSubmittingCheck;
  final bool isAudioPlaying;
  final ValueChanged<String> onSelectOption;
  final VoidCallback onSubmitCheck;
  final VoidCallback? onToggleAudio;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: card.title,
      trailing: _typeBadge(card.type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (card.body != null && card.body!.isNotEmpty) ...[
            Text(
              card.body!,
              style: SignageTypography.body(fontSize: 16),
            ),
            const SizedBox(height: 12),
          ],
          if (onToggleAudio != null) ...[
            PlacardButton(
              key: const Key('lesson-audio-btn'),
              label: isAudioPlaying ? 'PAUSE AUDIO' : 'PLAY AUDIO',
              variant: PlacardButtonVariant.secondary,
              onPress: onToggleAudio,
            ),
            const SizedBox(height: 12),
          ],
          if (card.isMicroCheck) ...[
            if (card.question != null) ...[
              Text(
                card.question!,
                style: SignageTypography.condensedSentence(fontSize: 17),
              ),
              const SizedBox(height: 12),
            ],
            for (final opt in card.options) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FTappable(
                  key: Key('micro-option-$opt'),
                  onPress: () => onSelectOption(opt),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedOption == opt
                          ? SignageColors.ink
                          : SignageColors.paper,
                      border: Border.all(color: SignageColors.ink, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        opt,
                        style: SignageTypography.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selectedOption == opt
                              ? SignageColors.paper
                              : SignageColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            PlacardButton(
              key: const Key('micro-check-submit-btn'),
              label: 'CHECK ANSWER',
              isLoading: isSubmittingCheck,
              onPress: selectedOption != null ? onSubmitCheck : null,
            ),
            if (checkResult != null) ...[
              const SizedBox(height: 12),
              PlacardAlert(
                variant: checkResult!.correct
                    ? PlacardAlertVariant.success
                    : PlacardAlertVariant.danger,
                title: checkResult!.correct ? 'CORRECT' : 'TRY AGAIN',
                subtitle: checkResult!.explanation,
              ),
            ] else if (checkError != null) ...[
              const SizedBox(height: 12),
              PlacardAlert(
                key: const Key('lesson-check-error'),
                variant: PlacardAlertVariant.danger,
                title: 'CHECK FAILED',
                subtitle: checkError!,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    return switch (type.toLowerCase()) {
      'rule' => const PlacardBadge.info('RULE'),
      'pitfall' => const PlacardBadge.warning('PITFALL'),
      'example' => const PlacardBadge.success('EXAMPLE'),
      'micro_check' => const PlacardBadge.danger('MICRO CHECK'),
      _ => PlacardBadge.muted(type.toUpperCase()),
    };
  }
}
