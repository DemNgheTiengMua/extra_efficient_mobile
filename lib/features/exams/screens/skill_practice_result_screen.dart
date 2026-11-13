import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/skill_practice_models.dart';
import '../providers/skill_practice_providers.dart';

/// Polls asynchronous AI Grading for Speaking/Writing Skill Practice Attempts,
/// supports free retry on FAILED, and displays rubric criterion scores/comments.
class SkillPracticeResultScreen extends ConsumerStatefulWidget {
  const SkillPracticeResultScreen({
    super.key,
    required this.skill,
    required this.attemptId,
  });

  final String skill;
  final int attemptId;

  @override
  ConsumerState<SkillPracticeResultScreen> createState() =>
      _SkillPracticeResultScreenState();
}

class _SkillPracticeResultScreenState
    extends ConsumerState<SkillPracticeResultScreen> {
  SkillPracticePendingStatus? _pending;
  SkillPracticeReview? _review;
  bool _loading = true;
  bool _retrying = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_checkStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final repo = ref.read(skillPracticeRepositoryProvider);
      final status = await repo.fetchPending(widget.skill, widget.attemptId);
      if (!mounted) return;
      if (status.isCompleted) {
        _pollTimer?.cancel();
        final rev = await repo.fetchReview(widget.skill, widget.attemptId);
        if (!mounted) return;
        setState(() {
          _pending = status;
          _review = rev;
          _loading = false;
        });
      } else {
        setState(() {
          _pending = status;
          _loading = false;
        });
        if (status.isPending) {
          _startPolling();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_checkStatus());
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await ref
          .read(skillPracticeRepositoryProvider)
          .retryGrading(widget.skill, widget.attemptId);
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _pending = const SkillPracticePendingStatus(status: 'PENDING');
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onPress: () => context.go('/practice'),
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
                      'PRACTICE',
                      style: SignageTypography.label(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.skill.toUpperCase()} GRADING',
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
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: StateBlock(
                    stamp: 'ERROR',
                    title: 'GRADING CHECK FAILED',
                    description: _error!,
                    action: PlacardButton(label: 'RETRY', onPress: _checkStatus),
                  ),
                )
              : (_pending?.isFailed ?? false)
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: StateBlock(
                        stamp: 'FAILED',
                        title: 'AI GRADING FAILED',
                        description: _pending?.errorMessage ??
                            'Grading failed. Retry for free.',
                        action: PlacardButton(
                          key: const Key('skill-retry-grading-btn'),
                          label: _retrying ? 'RETRYING...' : 'RETRY GRADING (FREE)',
                          onPress: _retrying ? null : _retry,
                        ),
                      ),
                    )
                  : _review == null
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: StateBlock(
                            stamp: 'GRADING',
                            title: 'AI GRADING IN PROGRESS',
                            description:
                                'Your submission is being graded against the rubric.',
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ScorePlacard(
                              totalScore:
                                  '${_review!.totalScore.toStringAsFixed(0)}/${_review!.maxScore.toStringAsFixed(0)}',
                              caption:
                                  '${_review!.examTitle} · EST. BAND ${_review!.estimatedBand}',
                            ),
                            const SizedBox(height: 16),
                            for (final c in _review!.criteria) ...[
                              PlacardPanel(
                                title: c.name,
                                trailing: PlacardBadge.info(
                                  '${c.score.toStringAsFixed(0)}/${c.maxScore.toStringAsFixed(0)}',
                                ),
                                child: Text(
                                  c.comment,
                                  style: SignageTypography.body(fontSize: 14),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
    );
  }
}
