import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/placement_models.dart';
import '../providers/placement_providers.dart';

/// Placement Result & Async AI Grading Polling screen.
/// Polls `GET /api/learner/placement/result/{placementId}/status` every 3 seconds
/// while `PENDING`, surfaces a free retry CTA on `FAILED`, and renders
/// [ScorePlacard] + [CefrBandBar] when `COMPLETED`.
class PlacementResultScreen extends ConsumerStatefulWidget {
  const PlacementResultScreen({super.key, required this.placementId});

  final int placementId;

  @override
  ConsumerState<PlacementResultScreen> createState() =>
      _PlacementResultScreenState();
}

class _PlacementResultScreenState extends ConsumerState<PlacementResultScreen> {
  PlacementResult? _result;
  String? _error;
  bool _isLoading = true;
  bool _retrying = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final res = await ref
          .read(placementRepositoryProvider)
          .fetchResult(widget.placementId);
      if (!mounted) return;
      setState(() {
        _result = res;
        _isLoading = false;
        _error = null;
      });
      if (res.isPending) {
        _startPolling();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final status = await ref
            .read(placementRepositoryProvider)
            .fetchResultStatus(widget.placementId);
        if (!mounted) return;
        setState(() {
          _result = status;
        });
        if (!status.isPending) {
          _pollTimer?.cancel();
        }
      } catch (_) {
        // Keep polling on transient network errors.
      }
    });
  }

  Future<void> _retryGrading() async {
    setState(() => _retrying = true);
    try {
      await ref
          .read(placementRepositoryProvider)
          .retryGrading(widget.placementId);
      if (!mounted) return;
      setState(() {
        _retrying = false;
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
    final result = _result;

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: SignageColors.wall,
        child: Column(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: SignageColors.signBlue,
                border: Border(
                  bottom: BorderSide(color: SignageColors.ink, width: 2),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      FTappable(
                        onPress: () => context.go('/exams'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: SignageColors.paper,
                            border: Border.all(
                              color: SignageColors.ink,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'EXAMS',
                            style: SignageTypography.label(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'PLACEMENT RESULT',
                          style: SignageTypography.title(
                            color: SignageColors.paper,
                          ).copyWith(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: FCircularProgress())
                  : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        PlacardAlert(
                          variant: PlacardAlertVariant.danger,
                          title: 'Unable to load placement result',
                          subtitle: _error,
                        ),
                      ],
                    )
                  : result == null
                  ? const SizedBox.shrink()
                  : result.hasFailedGrading
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const PlacardAlert(
                          variant: PlacardAlertVariant.danger,
                          title: 'AI grading failed',
                          subtitle: 'One or more free-response tasks could not be graded. Retrying is completely free.',
                        ),
                        const SizedBox(height: 16),
                        PlacardButton(
                          key: const Key('retry-grading-btn'),
                          label: 'RETRY AI GRADING (FREE)',
                          isLoading: _retrying,
                          onPress: _retryGrading,
                        ),
                      ],
                    )
                  : result.isPending
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        StateBlock(
                          stamp: 'PENDING',
                          title: 'AI grading in progress',
                          description: result.stageDescriptor ?? 'Your free-response tasks are being evaluated against the certificate rubric. Checking status every 3 seconds...',
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ScorePlacard(
                          totalScore: '${result.displayTotalScore}',
                          caption:
                              '${result.examName} · BAND ${result.bandLabel}',
                          splits: [
                            for (final s in result.skillScores)
                              ScoreSplit(
                                label: s.skillName,
                                value: '${s.scaledScore}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (result.isBanded) ...[
                          CefrBandBar(currentBand: result.bandCode),
                          const SizedBox(height: 16),
                        ],
                        for (final s in result.skillScores) ...[
                          PlacardPanel(
                            title: s.skillName.toUpperCase(),
                            trailing: s.isBanded
                                ? PlacardBadge.info(s.bandLabel)
                                : const PlacardBadge.muted('NOT YET BANDED'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SCALED: ${s.scaledScore}',
                                  style: SignageTypography.data(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'RAW: ${s.rawScore}/${s.totalQuestions}',
                                  style: SignageTypography.data(
                                    fontSize: 14,
                                    color: SignageColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        PlacardButton(
                          key: const Key('configure-path-cta'),
                          label: 'CONFIGURE TARGET BAND & PATH',
                          onPress: () => context.go('/path'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
