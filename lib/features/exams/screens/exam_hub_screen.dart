import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../context/learner_context_provider.dart';

/// EXAMS tab hub presenting the Placement Assessment card and exam pathways.
class ExamHubScreen extends ConsumerWidget {
  const ExamHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(learnerContextProvider);
    final activeCode = contextAsync.value?.active.code ?? '---';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PlacardPanel(
          title: 'PLACEMENT ASSESSMENT',
          trailing: PlacardBadge.info(activeCode),
          footer: PlacardButton(
            key: const Key('open-placement-btn'),
            label: 'OPEN PLACEMENT & PREFLIGHT',
            onPress: () => context.push('/placement'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diagnose your starting Band for $activeCode',
                style: SignageTypography.condensedSentence(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'First placement attempt per certificate is free. Run audio & microphone preflight checks before entering the timed exam room.',
                style: SignageTypography.body(
                  fontSize: 14,
                  color: SignageColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'MOCK & SKILL PRACTICE',
          child: Text(
            'Full timed Mock attempts and AI-graded Speaking/Writing Skill practice attempts appear here.',
            style: SignageTypography.body(
              fontSize: 14,
              color: SignageColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
