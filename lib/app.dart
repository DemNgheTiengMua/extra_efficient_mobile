import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import 'core/router/app_router.dart';
import 'features/context/learner_context_provider.dart';
import 'features/wallet/wallet_providers.dart';
import 'theme/signage_theme.dart';

/// Root application widget configured with Exam-Hall Signage [FTheme]
/// and `go_router` auth guards.
class ExtraEfficientApp extends ConsumerStatefulWidget {
  const ExtraEfficientApp({super.key});

  @override
  ConsumerState<ExtraEfficientApp> createState() => _ExtraEfficientAppState();
}

class _ExtraEfficientAppState extends ConsumerState<ExtraEfficientApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The balance can change outside the app - an admin grant, a refund, a
    // payment settling on another device. Re-read it whenever the learner comes
    // back to the app, so the credit pill is never stale.
    ref.read(learnerContextProvider.notifier).refreshContextQuietly();
    ref.read(walletSummaryProvider.notifier).refreshQuietly();
  }

  @override
  Widget build(BuildContext context) {
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
