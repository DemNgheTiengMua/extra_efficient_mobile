import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../models/exam_room_stop.dart';

/// The painted LEAVING control: it navigates and nothing else.
///
/// It exists because the reported "stuck screen with no buttons" came from an
/// EXIT that awaited a cancel the backend refused. Leaving is a navigation, not
/// a transaction, so this never awaits anything.
class ExamRoomExitButton extends StatelessWidget {
  const ExamRoomExitButton({
    super.key,
    required this.onLeave,
    this.label = 'EXIT',
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.fontSize = 11,
  });

  final VoidCallback onLeave;
  final String label;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return FTappable(
      key: key ?? const Key('exam-exit-btn'),
      onPress: onLeave,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: SignageColors.paper,
          border: Border.all(color: SignageColors.ink, width: 2),
        ),
        child: Text(
          label,
          style: SignageTypography.label(fontSize: fontSize),
        ),
      ),
    );
  }
}

/// Renders a sitting that cannot be opened, with the one way out it allows.
///
/// Two exits are always painted: the state's own destination and the hub, so no
/// terminal state can become a trap.
class ExamRoomTerminalView extends StatelessWidget {
  const ExamRoomTerminalView({
    super.key,
    required this.stop,
    required this.onLeave,
  });

  final ExamRoomStop stop;

  /// The unconditional escape, used for the secondary control.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StateBlock(
          stamp: stop.stamp,
          title: stop.title,
          description: stop.description,
          action: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlacardButton(
                key: const Key('exam-terminal-primary-btn'),
                label: stop.actionLabel,
                onPress: () => context.go(stop.actionRoute),
              ),
              const SizedBox(height: 8),
              PlacardButton(
                key: const Key('exam-terminal-leave-btn'),
                label: 'LEAVE ROOM',
                variant: PlacardButtonVariant.secondary,
                onPress: onLeave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
