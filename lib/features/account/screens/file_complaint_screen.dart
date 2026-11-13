import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../account_models.dart';
import '../account_provider.dart';

/// File a new Complaint against one eligible owned Booking, Attempt, or Order.
class FileComplaintScreen extends ConsumerStatefulWidget {
  const FileComplaintScreen({super.key});

  @override
  ConsumerState<FileComplaintScreen> createState() =>
      _FileComplaintScreenState();
}

class _FileComplaintScreenState extends ConsumerState<FileComplaintScreen> {
  final _reasonController = TextEditingController();
  EligibleSubject? _selectedSubject;
  ComplaintType? _selectedType;
  bool _isSubmitting = false;
  String? _submitError;
  String? _subjectError;
  String? _reasonError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _selectSubject(EligibleSubject subject) {
    final allowedTypes = ComplaintType.forCategory(subject.category);
    setState(() {
      _selectedSubject = subject;
      _subjectError = null;
      if (_selectedType == null || !allowedTypes.contains(_selectedType)) {
        _selectedType = allowedTypes.first;
      }
    });
  }

  Future<void> _submit() async {
    final subject = _selectedSubject;
    final reason = _reasonController.text.trim();

    setState(() {
      _subjectError =
          subject == null ? 'Select an eligible booking, attempt, or order.' : null;
      _reasonError = reason.isEmpty ? 'Please describe the issue.' : null;
      _submitError = null;
    });

    if (subject == null || _selectedType == null || _reasonError != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(complaintsProvider.notifier).fileComplaint(
            type: _selectedType!,
            reason: reason,
            subject: subject,
          );
      if (mounted) {
        context.go('/account/complaints');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitError = extractApiError(
            e,
            fallback: 'Could not submit complaint.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(eligibleSubjectsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            PlacardButton(
              key: const Key('file-complaint-back-button'),
              label: 'BACK',
              variant: PlacardButtonVariant.secondary,
              expand: false,
              onPress: () => context.go('/account/complaints'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'FILE COMPLAINT',
                style: SignageTypography.title(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        subjectsAsync.when(
          loading: () => const PlacardPanel(
            child: Text('Loading eligible subjects...'),
          ),
          error: (err, _) => PlacardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlacardAlert(
                  variant: PlacardAlertVariant.danger,
                  title: extractApiError(
                    err,
                    fallback: 'Failed to load eligible subjects',
                  ),
                ),
                const SizedBox(height: 12),
                PlacardButton(
                  label: 'RETRY',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () => ref.invalidate(eligibleSubjectsProvider),
                ),
              ],
            ),
          ),
          data: (subjects) {
            if (subjects.isEmpty) {
              return const StateBlock(
                stamp: 'NONE',
                title: 'No eligible subjects',
                description:
                    'You have no recent bookings, exam attempts, or orders eligible for a complaint.',
              );
            }

            final allowedTypes = _selectedSubject != null
                ? ComplaintType.forCategory(_selectedSubject!.category)
                : const <ComplaintType>[];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_submitError != null) ...[
                  PlacardAlert(
                    variant: PlacardAlertVariant.danger,
                    title: _submitError!,
                  ),
                  const SizedBox(height: 12),
                ],
                PlacardPanel(
                  title: '1. SELECT SUBJECT',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_subjectError != null) ...[
                        Text(
                          _subjectError!,
                          style: SignageTypography.body(
                            fontSize: 13,
                            color: SignageColors.signRed,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (var i = 0; i < subjects.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _SelectableTile(
                          key: Key(
                            'eligible-subject-${subjects[i].category.name}-${subjects[i].id}',
                          ),
                          title: subjects[i].summary,
                          subtitle: subjects[i].subtitle,
                          badgeLabel: subjects[i].category.label,
                          selected: _selectedSubject?.category ==
                                  subjects[i].category &&
                              _selectedSubject?.id == subjects[i].id,
                          onTap: () => _selectSubject(subjects[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                if (allowedTypes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  PlacardPanel(
                    title: '2. COMPLAINT TYPE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < allowedTypes.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _SelectableTile(
                            key: Key(
                              'complaint-type-${allowedTypes[i].apiValue}',
                            ),
                            title: allowedTypes[i].label,
                            badgeLabel: allowedTypes[i].category.label,
                            selected: _selectedType == allowedTypes[i],
                            onTap: () => setState(
                              () => _selectedType = allowedTypes[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                PlacardPanel(
                  title: '3. REASON',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FTextField.multiline(
                        key: const Key('complaint-reason-field'),
                        control: FTextFieldControl.managed(
                          controller: _reasonController,
                        ),
                        label: Text(
                          'DESCRIBE WHAT HAPPENED',
                          style: SignageTypography.label(),
                        ),
                        hint: 'Provide clear details for the admin review...',
                        minLines: 3,
                        maxLines: 5,
                        error: _reasonError != null ? Text(_reasonError!) : null,
                      ),
                      const SizedBox(height: 16),
                      PlacardButton(
                        key: const Key('submit-complaint-button'),
                        label: 'SUBMIT COMPLAINT',
                        isLoading: _isSubmitting,
                        onPress: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.badgeLabel,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String badgeLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? SignageColors.ink : SignageColors.paper;
    final fg = selected ? SignageColors.paper : SignageColors.ink;
    final subFg =
        selected ? SignageColors.bandInkMuted : SignageColors.inkMuted;

    return FTappable(
      onPress: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: SignageColors.ink, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SignageTypography.condensedSentence(
                        fontSize: 15,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: SignageTypography.data(
                          fontSize: 12,
                          color: subFg,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PlacardBadge(
                label: selected ? 'SELECTED' : badgeLabel,
                variant: selected
                    ? PlacardBadgeVariant.info
                    : PlacardBadgeVariant.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
