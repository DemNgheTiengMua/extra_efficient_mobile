import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../models/path_models.dart';
import '../providers/path_providers.dart';

class GoalCalibrationScreen extends ConsumerStatefulWidget {
  const GoalCalibrationScreen({super.key});

  @override
  ConsumerState<GoalCalibrationScreen> createState() =>
      _GoalCalibrationScreenState();
}

class _GoalCalibrationScreenState extends ConsumerState<GoalCalibrationScreen> {
  final _targetDateController = TextEditingController();
  final _weeklyHoursController = TextEditingController();
  String? _selectedTargetBand;
  bool _initializedFromData = false;
  bool _isSaving = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _targetDateController.dispose();
    _weeklyHoursController.dispose();
    super.dispose();
  }

  void _syncControllers(TargetBandGoal goal) {
    if (_initializedFromData) return;
    _initializedFromData = true;
    _selectedTargetBand = goal.targetBandCode;
    _targetDateController.text = goal.targetDate ?? '';
    _weeklyHoursController.text =
        goal.weeklyStudyHours != null ? '${goal.weeklyStudyHours}' : '';
  }

  Future<void> _saveGoal(TargetBandGoal goal) async {
    final target = _selectedTargetBand ?? goal.targetBandCode;
    if (target == null || target.isEmpty) {
      setState(() => _errorMessage = 'Please select a target band.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final dateText = _targetDateController.text.trim();
      final hoursText = _weeklyHoursController.text.trim();
      final hours = hoursText.isEmpty ? null : num.tryParse(hoursText);

      await ref.read(targetBandGoalProvider.notifier).saveGoal(
            currentBandCode: goal.currentBandCode,
            targetBandCode: target,
            targetDate: dateText.isEmpty ? null : dateText,
            weeklyStudyHours: hours,
          );
      if (mounted) {
        setState(() {
          _statusMessage = 'Study goal updated to $target.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = extractApiError(e, fallback: e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveTargetBandOnly(TargetBandGoal goal) async {
    final target = _selectedTargetBand ?? goal.targetBandCode;
    if (target == null || target.isEmpty) {
      setState(() => _errorMessage = 'Please select a target band.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      await ref.read(targetBandGoalProvider.notifier).updateTargetBand(target);
      if (mounted) {
        setState(() {
          _statusMessage = 'Target band set to $target.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = extractApiError(e, fallback: e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _decideCalibration(bool adjust) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      await ref.read(calibrationProvider.notifier).decide(adjust: adjust);
      if (mounted) {
        setState(() {
          _statusMessage = adjust
              ? 'CALIBRATION APPLIED'
              : 'CALIBRATION DISMISSED';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = extractApiError(e, fallback: e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalAsync = ref.watch(targetBandGoalProvider);
    final calibrationAsync = ref.watch(calibrationProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_errorMessage != null) ...[
          PlacardAlert(
            variant: PlacardAlertVariant.danger,
            title: _errorMessage!,
          ),
          const SizedBox(height: 12),
        ],
        if (_statusMessage != null) ...[
          PlacardAlert(
            variant: PlacardAlertVariant.success,
            title: _statusMessage!,
          ),
          const SizedBox(height: 12),
        ],
        goalAsync.when(
          loading: () => const PlacardPanel(
            title: 'TARGET BAND & STUDY GOAL',
            child: Text('Loading target band settings...'),
          ),
          error: (error, _) => StateBlock(
            stamp: 'UNAVAILABLE',
            title: 'Could not load target band',
            description: error.toString(),
          ),
          data: (goal) {
            if (goal == null) return const SizedBox.shrink();
            _syncControllers(goal);
            final selected = _selectedTargetBand ?? goal.targetBandCode;

            return PlacardPanel(
              title: 'TARGET BAND & STUDY GOAL',
              trailing: PlacardBadge.info(
                'CURRENT ${goal.currentBandCode == null ? '--' : _bandCodeLabel(goal.currentBandCode!)}',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SELECT TARGET BAND',
                    style: SignageTypography.label(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final band in goal.availableBands)
                        FTappable(
                          key: Key('target-band-${band.code}'),
                          onPress: () => setState(() {
                            _selectedTargetBand = band.code;
                          }),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: selected == band.code
                                  ? SignageColors.ink
                                  : SignageColors.paper,
                              border: Border.all(
                                color: SignageColors.ink,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_bandCodeLabel(band.code)} · ${band.name}'
                                        .toUpperCase(),
                                    style: SignageTypography.data(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: selected == band.code
                                          ? SignageColors.paper
                                          : SignageColors.ink,
                                    ),
                                  ),
                                  // The band's own score range, as the
                                  // certificate defines it.
                                  Text(
                                    band.rangeText,
                                    style: SignageTypography.body(
                                      fontSize: 12,
                                      color: selected == band.code
                                          ? SignageColors.paper
                                          : SignageColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FTextField(
                    key: const Key('target-date-input'),
                    control: FTextFieldControl.managed(
                      controller: _targetDateController,
                    ),
                    label: Text(
                      'TARGET EXAM DATE (YYYY-MM-DD)',
                      style: SignageTypography.label(),
                    ),
                    hint: '2026-12-20',
                  ),
                  const SizedBox(height: 12),
                  FTextField(
                    key: const Key('weekly-hours-input'),
                    control: FTextFieldControl.managed(
                      controller: _weeklyHoursController,
                    ),
                    label: Text(
                      'WEEKLY STUDY HOURS',
                      style: SignageTypography.label(),
                    ),
                    hint: '8',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  PlacardButton(
                    key: const Key('save-goal-btn'),
                    label: 'SAVE STUDY GOAL',
                    isLoading: _isSaving,
                    onPress: () => _saveGoal(goal),
                  ),
                  const SizedBox(height: 8),
                  PlacardButton(
                    key: const Key('save-target-band-btn'),
                    label: 'SET TARGET BAND ONLY',
                    variant: PlacardButtonVariant.secondary,
                    isLoading: _isSaving,
                    onPress: () => _saveTargetBandOnly(goal),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        calibrationAsync.when(
          loading: () => const PlacardPanel(
            title: 'BAND CALIBRATION',
            child: Text('Checking calibration status...'),
          ),
          error: (error, _) => PlacardAlert(
            variant: PlacardAlertVariant.warning,
            title: 'Calibration unavailable',
            subtitle: error.toString(),
          ),
          data: (calibration) {
            if (calibration == null) return const SizedBox.shrink();
            final proposal = calibration.proposal;
            return PlacardPanel(
              title: 'BAND CALIBRATION',
              trailing: proposal != null
                  ? const PlacardBadge.warning('SUGGESTED')
                  : const PlacardBadge.muted('NONE'),
              child: proposal != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'SUGGESTED TARGET: ${proposal.proposedBandName.toUpperCase()}',
                          style: SignageTypography.label(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          proposal.evidence,
                          style: SignageTypography.body(fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${proposal.observedAccuracyPct.toStringAsFixed(0)}% accuracy over '
                          '${proposal.validAnswerCount} answers (needs '
                          '${proposal.requiredAccuracyPct}%)',
                          style: SignageTypography.data(
                            fontSize: 12,
                            color: SignageColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: PlacardButton(
                                key: const Key('calibration-accept-btn'),
                                label: 'ACCEPT ADJUSTMENT',
                                isLoading: _isSaving,
                                onPress: () => _decideCalibration(true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PlacardButton(
                                key: const Key('calibration-decline-btn'),
                                label: 'KEEP CURRENT',
                                variant: PlacardButtonVariant.secondary,
                                isLoading: _isSaving,
                                onPress: () => _decideCalibration(false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(
                      calibration.reason == 'below_threshold'
                          ? 'Your practice still matches ${calibration.placedBandName ?? calibration.placedBandCode}.'
                          : 'No calibration adjustments pending.',
                      style: SignageTypography.body(
                        fontSize: 14,
                        color: SignageColors.inkMuted,
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

/// `below_A1` is the server's code for the band the signage bar paints `<A1`.
String _bandCodeLabel(String code) {
  final lower = code.toLowerCase();
  if (lower == 'below_a1' || lower == '<a1') return '<A1';
  return code.toUpperCase();
}
