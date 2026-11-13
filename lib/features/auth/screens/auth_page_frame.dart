import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';

/// Shared exam-hall signage layout frame for unauthenticated auth screens.
class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.screenTitle,
    required this.panelTitle,
    required this.child,
  });

  final String screenTitle;
  final String panelTitle;
  final Widget child;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'EXTRA EFFICIENT — $screenTitle'.toUpperCase(),
                    style: SignageTypography.label(
                      fontSize: 15,
                      color: SignageColors.paper,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Container(
        color: SignageColors.wall,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: PlacardPanel(
                title: panelTitle,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
