import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import 'core/router/app_router.dart';
import 'theme/signage_theme.dart';

/// Root application widget configured with Exam-Hall Signage [FTheme]
/// and `go_router` auth guards.
class ExtraEfficientApp extends ConsumerWidget {
  const ExtraEfficientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = buildSignageTheme();
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Extra Efficient',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => FTheme(
        data: theme,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
