import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../account_models.dart';
import '../account_provider.dart';

/// Displays the learner's submitted Complaints with status badges, timestamps,
/// admin resolution notes, and any `grantedCredits` make-good.
class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(complaintsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            PlacardButton(
              key: const Key('complaints-back-button'),
              label: 'BACK',
              variant: PlacardButtonVariant.secondary,
              expand: false,
              onPress: () => context.go('/account'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'COMPLAINTS CENTER',
                style: SignageTypography.title(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PlacardButton(
                key: const Key('new-complaint-button'),
                label: 'FILE COMPLAINT',
                onPress: () => context.go('/account/complaints/new'),
              ),
            ),
            const SizedBox(width: 8),
            PlacardButton(
              key: const Key('refresh-complaints-button'),
              label: 'REFRESH',
              variant: PlacardButtonVariant.secondary,
              expand: false,
              onPress: () =>
                  ref.read(complaintsProvider.notifier).refreshComplaints(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        complaintsAsync.when(
          loading: () => const PlacardPanel(
            child: Text('Loading complaints...'),
          ),
          error: (err, _) => PlacardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlacardAlert(
                  variant: PlacardAlertVariant.danger,
                  title: extractApiError(
                    err,
                    fallback: 'Failed to load complaints',
                  ),
                ),
                const SizedBox(height: 12),
                PlacardButton(
                  label: 'RETRY',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () =>
                      ref.read(complaintsProvider.notifier).refreshComplaints(),
                ),
              ],
            ),
          ),
          data: (complaints) {
            if (complaints.isEmpty) {
              return const StateBlock(
                stamp: 'EMPTY',
                title: 'No complaints filed',
                description:
                    'If you experience a mentor no-show, grading issue, or payment problem, file a complaint against the affected booking, attempt, or order.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < complaints.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ComplaintCard(complaint: complaints[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final badgeVariant = switch (complaint.status) {
      ComplaintStatus.open => PlacardBadgeVariant.info,
      ComplaintStatus.reviewing => PlacardBadgeVariant.warning,
      ComplaintStatus.resolved => PlacardBadgeVariant.success,
    };

    return PlacardPanel(
      key: Key('complaint-card-${complaint.id}'),
      title: complaint.type.label,
      trailing: PlacardBadge(
        label: complaint.status.label,
        variant: badgeVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            complaint.subjectSummary,
            style: SignageTypography.condensedSentence(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            complaint.reason,
            style: SignageTypography.body(fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (complaint.createdAt != null)
            Text(
              'FILED: ${_formatTimestamp(complaint.createdAt!)}',
              style: SignageTypography.data(
                fontSize: 12,
                color: SignageColors.inkMuted,
              ),
            ),
          if (complaint.resolvedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              'RESOLVED: ${_formatTimestamp(complaint.resolvedAt!)}',
              style: SignageTypography.data(
                fontSize: 12,
                color: SignageColors.inkMuted,
              ),
            ),
          ],
          if (complaint.resolution != null &&
              complaint.resolution!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: SignageColors.lineSoft),
            const SizedBox(height: 10),
            Text(
              'ADMIN RESOLUTION',
              style: SignageTypography.label(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              complaint.resolution!,
              style: SignageTypography.body(fontSize: 14),
            ),
          ],
          if (complaint.grantedCredits > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SignageColors.greenWash,
                border: Border.all(color: SignageColors.signGreen, width: 2),
              ),
              child: Text(
                '+${complaint.grantedCredits} CREDITS',
                style: SignageTypography.data(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SignageColors.greenInk,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatTimestamp(DateTime dt) {
  final utc = dt.toUtc();
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  final hh = utc.hour.toString().padLeft(2, '0');
  final mm = utc.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm UTC';
}
