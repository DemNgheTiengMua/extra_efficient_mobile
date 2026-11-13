import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../theme/signage_theme.dart';
import '../../widgets/signage_primitives.dart';
/// Where the router lands a destination it has no route for.
///
/// The backend hands the app navigation URLs (NEXT ACTION, resume links), and
/// it may name a destination this build has not registered. A blank page there
/// looks like a broken app, so the fallback says what happened and offers the
/// two exits the learner actually has.
class UnmatchedRouteScreen extends StatelessWidget {
  const UnmatchedRouteScreen({super.key, this.location});

  /// The unregistered location the router was asked for.
  final String? location;

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(
          'DESTINATION UNAVAILABLE',
          style: SignageTypography.title().copyWith(fontSize: 18),
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StateBlock(
                stamp: '404',
                title: 'This destination is not available in this app',
                description: location == null
                    ? 'The link you followed points somewhere this version of the app '
                          'does not open.'
                    : 'The app does not open $location. It may be a newer feature, or '
                          'the link may be stale.',
              ),
              const SizedBox(height: 16),
              PlacardButton(
                key: const Key('unmatched-route-home'),
                label: 'GO TO PATH',
                onPress: () => context.go('/path'),
              ),
              const SizedBox(height: 8),
              if (context.canPop())
                PlacardButton(
                  label: 'BACK',
                  variant: PlacardButtonVariant.secondary,
                  onPress: () => context.pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
