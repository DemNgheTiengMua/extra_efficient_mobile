import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../theme/signage_theme.dart';
import '../context/learner_context_provider.dart';

/// 5-tab Exam-Hall Signage shell (`PATH`, `PRACTICE`, `EXAMS`, `WALLET`, `ACCOUNT`)
/// with a Sign Blue (`#0b4ea2`) top header and tappable Credit balance pill.
class MainShell extends ConsumerWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const List<String> _tabTitles = [
    'PATH',
    'PRACTICE',
    'EXAMS',
    'WALLET',
    'ACCOUNT',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(learnerContextProvider);
    final creditBalance = contextAsync.value?.creditBalance ?? 0;
    final activeCode = contextAsync.value?.active.code ?? '---';
    final currentIndex = navigationShell.currentIndex;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tabTitles[currentIndex],
                        style: SignageTypography.title(
                          color: SignageColors.paper,
                        ).copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'CERTIFICATE: $activeCode',
                        style: SignageTypography.label(
                          fontSize: 11,
                          color: SignageColors.bandBlueMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                FTappable(
                  key: const Key('credit-balance-pill'),
                  onPress: () => navigationShell.goBranch(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SignageColors.ink,
                      border: Border.all(
                        color: SignageColors.paper,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '$creditBalance CREDITS',
                        style: SignageTypography.data(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SignageColors.paper,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      footer: DecoratedBox(
        decoration: const BoxDecoration(
          color: SignageColors.paper,
          border: Border(
            top: BorderSide(color: SignageColors.ink, width: 2),
          ),
        ),
        child: FBottomNavigationBar(
          index: currentIndex,
          onChange: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          children: const [
            FBottomNavigationBarItem(
              icon: Icon(FLucideIcons.compass),
              label: Text('PATH'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FLucideIcons.layers),
              label: Text('PRACTICE'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FLucideIcons.clipboardCheck),
              label: Text('EXAMS'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FLucideIcons.wallet),
              label: Text('WALLET'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FLucideIcons.user),
              label: Text('ACCOUNT'),
            ),
          ],
        ),
      ),
      child: Container(
        color: SignageColors.wall,
        child: navigationShell,
      ),
    );
  }
}
