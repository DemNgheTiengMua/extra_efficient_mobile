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

  void _syncControllers(TargetBandView view) {
    if (_initializedFromData) return;
    _initializedFromData = true;
    _selectedTargetBand = view.targetBandCode;
    _targetDateController.text = view.goal?.targetDate ?? '';
    final hours = view.goal?.weeklyStudyHours;
    _weeklyHoursController.text = hours != null ? '$hours' : '';
  }

  /// The band the learner was assessed at. `GET /target-band` reports it at the
  /// top level; `goal.currentBandCode` is only what a goal previously recorded,
  /// so the payload's own assessment wins and null means "use the assessed
  /// band" (`SetGoalRequest.CurrentBandCode` is nullable for exactly that).
  String? _currentBand(TargetBandView view) {
    if (view.currentBandCode != null) return view.currentBandCode;
    final goalBand = view.goal?.currentBandCode;
    // The recorded goal may be stale by a calibration, so only use it as a
    // fallback when the payload measured nothing else.
    return goalBand;
  }

  Future<void> _saveGoal(TargetBandView view) async {
    final target = _selectedTargetBand ?? view.targetBandCode;
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
            currentBandCode: _currentBand(view),
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

  Future<void> _saveTargetBandOnly(TargetBandView view) async {
    final target = _selectedTargetBand ?? view.targetBandCode;
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
          data: (view) {
            if (view == null) return const SizedBox.shrink();
            _syncControllers(view);
            final selected = _selectedTargetBand ?? view.targetBandCode;

            return PlacardPanel(
              title: 'TARGET BAND & STUDY GOAL',
              trailing: PlacardBadge.info(
                'CURRENT ${view.currentBandCode == null ? '--' : _bandLabel(view.currentBandCode!)}',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SELECT TARGET BAND',
                    style: SignageTypography.label(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (view.availableBands.isEmpty)
                    Text(
                      'This certificate reports no bands, so no target can be '
                      'chosen.',
                      style: SignageTypography.body(
                        fontSize: 14,
                        color: SignageColors.inkMuted,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final band in view.availableBands)
                          _BandOptionRow(
                            band: band,
                            selected: selected == band.code,
                            onSelect: () => setState(() {
                              _selectedTargetBand = band.code;
                            }),
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
                    onPress: () => _saveGoal(view),
                  ),
                  const SizedBox(height: 8),
                  PlacardButton(
                    key: const Key('save-target-band-btn'),
                    label: 'SET TARGET BAND ONLY',
                    variant: PlacardButtonVariant.secondary,
                    isLoading: _isSaving,
                    onPress: () => _saveTargetBandOnly(view),
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
            return PlacardPanel(
              title: 'BAND CALIBRATION',
              trailing: calibration.pending
                  ? const PlacardBadge.warning('PENDING')
                  : const PlacardBadge.muted('NONE'),
              child: calibration.pending
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (calibration.recommendedBandCode != null)
                          Text(
                            'RECOMMENDED TARGET: ${calibration.recommendedBandCode!.toUpperCase()}',
                            style: SignageTypography.label(fontSize: 13),
                          ),
                        if (calibration.reason != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            calibration.reason!,
                            style: SignageTypography.body(fontSize: 15),
                          ),
                        ],
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
                      'No calibration adjustments pending.',
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

/// One band of the certificate's own ladder, with the backend's ready-to-print
/// score range. The ladder is the payload's, never a hardcoded six-rung one.
class _BandOptionRow extends StatelessWidget {
  const _BandOptionRow({
    required this.band,
    required this.selected,
    required this.onSelect,
  });

  final TargetBandOption band;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final detail = [
      band.name,
      band.rangeText,
      if (band.isCurrent) 'YOUR BAND',
      if (band.isTarget) 'CURRENT TARGET',
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FTappable(
        key: Key('target-band-${band.code}'),
        onPress: onSelect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? SignageColors.ink : SignageColors.paper,
            border: Border.all(color: SignageColors.ink, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _bandLabel(band.code),
                    style: SignageTypography.data(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? SignageColors.paper
                          : SignageColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    detail,
                    style: SignageTypography.body(
                      fontSize: 13,
                      color: selected
                          ? SignageColors.paper
                          : SignageColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `below_A1` is the server's code for the band the signage bar paints `<A1`.
String _bandLabel(String code) {
  final lower = code.toLowerCase();
  if (lower == 'below_a1' || lower == '<a1') return '<A1';
  return code.toUpperCase();
}
