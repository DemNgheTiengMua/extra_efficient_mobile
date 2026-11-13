import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/path_models.dart';
import '../providers/path_providers.dart';

class LearningPathScreen extends ConsumerWidget {
  const LearningPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(learningPathProvider);
    final insightAsync = ref.watch(pathInsightProvider);

    return pathAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          PlacardPanel(
            title: 'LOADING LEARNING PATH',
            child: Text('Loading modules and progress...'),
          ),
        ],
      ),
      error: (error, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StateBlock(
            stamp: 'PATH ERROR',
            title: 'Could not load learning path',
            description: error.toString(),
            action: PlacardButton(
              label: 'RETRY',
              onPress: () => ref.invalidate(learningPathProvider),
            ),
          ),
        ],
      ),
      data: (path) {
        if (path == null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StateBlock(
                stamp: 'NO LEARNING PATH',
                title: 'Generate your personalized learning path',
                description:
                    'Build a weekly module sequence matched to your current and target band.',
                action: PlacardButton(
                  key: const Key('generate-learning-path-btn'),
                  label: 'GENERATE LEARNING PATH',
                  onPress: () =>
                      ref.read(learningPathProvider.notifier).generate(),
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PlacardPanel(
              title: 'LEARNING PATH OVERVIEW',
              trailing: path.targetBandCode != null
                  ? PlacardBadge.info(
                      'TARGET ${path.targetBandCode!.toUpperCase()}',
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CefrBandBar(currentBand: path.currentBandCode),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${path.remainingMinutes} MIN REMAINING',
                          style: SignageTypography.data(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      PlacardButton(
                        key: const Key('reset-learning-path-btn'),
                        label: 'RESET PATH',
                        variant: PlacardButtonVariant.destructive,
                        expand: false,
                        onPress: () =>
                            ref.read(learningPathProvider.notifier).reset(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final module in path.modules) ...[
              _PathModuleCard(module: module),
              const SizedBox(height: 12),
            ],
            insightAsync.when(
              loading: () => const PlacardPanel(
                title: 'PATH INSIGHT',
                child: Text('Generating path insight...'),
              ),
              error: (error, _) => PlacardPanel(
                title: 'PATH INSIGHT',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PlacardAlert(
                      variant: PlacardAlertVariant.warning,
                      title: 'Path insight unavailable',
                      subtitle: error.toString(),
                    ),
                    const SizedBox(height: 12),
                    PlacardButton(
                      key: const Key('retry-path-insight-btn'),
                      label: 'RETRY INSIGHT',
                      variant: PlacardButtonVariant.secondary,
                      onPress: () =>
                          ref.read(pathInsightProvider.notifier).retry(),
                    ),
                  ],
                ),
              ),
              data: (insight) {
                if (insight == null) return const SizedBox.shrink();
                return PlacardPanel(
                  title: 'PATH INSIGHT',
                  trailing: insight.isFailed
                      ? const PlacardBadge.danger('FAILED')
                      : const PlacardBadge.success('READY'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        insight.narrative,
                        style: SignageTypography.body(fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      PlacardButton(
                        key: const Key('retry-path-insight-btn'),
                        label: 'RETRY INSIGHT',
                        variant: PlacardButtonVariant.secondary,
                        onPress: () =>
                            ref.read(pathInsightProvider.notifier).retry(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PathModuleCard extends ConsumerWidget {
  const _PathModuleCard({required this.module});

  final PathModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlacardPanel(
      title: module.title,
      trailing: module.estimatedMinutes != null
          ? PlacardBadge.muted('${module.estimatedMinutes} MIN')
          : null,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < module.items.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1),
            _PathItemRow(item: module.items[i]),
          ],
        ],
      ),
    );
  }
}

class _PathItemRow extends ConsumerWidget {
  const _PathItemRow({required this.item});

  final PathModuleItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _statusBadge(item.status),
                    PlacardBadge.muted(item.type.toUpperCase()),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: SignageTypography.condensedSentence(fontSize: 16),
                ),
                if (item.estimatedMinutes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${item.estimatedMinutes} MIN',
                    style: SignageTypography.data(
                      fontSize: 12,
                      color: SignageColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          PlacardButton(
            key: Key('start-step-${item.stepId}'),
            label: item.isLocked ? 'LOCKED' : 'START',
            variant: item.isLocked
                ? PlacardButtonVariant.secondary
                : PlacardButtonVariant.primary,
            expand: false,
            onPress: item.isLocked
                ? null
                : () async {
                    final started = await ref
                        .read(learningPathProvider.notifier)
                        .startStep(item.stepId);
                    if (!context.mounted) return;
                    final lessonId = started.lessonId ?? item.lessonId;
                    if (lessonId != null || item.type == 'lesson') {
                      if (lessonId != null) {
                        context.push('/path/lessons/$lessonId');
                      }
                    } else if (item.type == 'practice') {
                      context.go('/practice');
                    } else if (item.type == 'mock' || item.type == 'ai_task') {
                      context.go('/exams');
                    } else if (item.type == 'mentor') {
                      context.go('/wallet');
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    return switch (status.toLowerCase()) {
      'done' => const PlacardBadge.success('DONE'),
      'in_progress' => const PlacardBadge.info('IN PROGRESS'),
      'available' => const PlacardBadge.warning('AVAILABLE'),
      _ => const PlacardBadge.muted('LOCKED'),
    };
  }
}
