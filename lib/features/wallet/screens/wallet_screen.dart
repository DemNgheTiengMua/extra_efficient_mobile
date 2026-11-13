import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../wallet_models.dart';
import '../wallet_providers.dart';
import 'checkout_flow_view.dart';
import 'mentors_bookings_view.dart';

enum _WalletSubTab { creditsAndOrders, mentorsAndBookings }

/// Root `WALLET` tab with two signage sub-tabs:
/// 1. Credits & Orders (derived balance, packages, checkout, append-only ledger, orders)
/// 2. Mentors & Bookings (human/AI mentors, slots, bookings, cancel refund, rating)
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _WalletSubTab _activeTab = _WalletSubTab.creditsAndOrders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _SignageSubTabBar(
            activeTab: _activeTab,
            onSelect: (tab) => setState(() => _activeTab = tab),
          ),
        ),
        Expanded(
          child: switch (_activeTab) {
            _WalletSubTab.creditsAndOrders => const _CreditsAndOrdersView(),
            _WalletSubTab.mentorsAndBookings => const MentorsBookingsView(),
          },
        ),
      ],
    );
  }
}

class _SignageSubTabBar extends StatelessWidget {
  const _SignageSubTabBar({
    required this.activeTab,
    required this.onSelect,
  });

  final _WalletSubTab activeTab;
  final ValueChanged<_WalletSubTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignageColors.paper,
        border: Border.all(color: SignageColors.ink, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SubTabItem(
              key: const Key('wallet-subtab-credits'),
              label: 'CREDITS & ORDERS',
              selected: activeTab == _WalletSubTab.creditsAndOrders,
              onPress: () => onSelect(_WalletSubTab.creditsAndOrders),
            ),
          ),
          Container(width: 2, height: 44, color: SignageColors.ink),
          Expanded(
            child: _SubTabItem(
              key: const Key('wallet-subtab-mentors'),
              label: 'MENTORS & BOOKINGS',
              selected: activeTab == _WalletSubTab.mentorsAndBookings,
              onPress: () => onSelect(_WalletSubTab.mentorsAndBookings),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubTabItem extends StatelessWidget {
  const _SubTabItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return FTappable(
      onPress: onPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? SignageColors.ink : SignageColors.paper,
        ),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: SignageTypography.label(
                fontSize: 12,
                color: selected ? SignageColors.paper : SignageColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditsAndOrdersView extends ConsumerStatefulWidget {
  const _CreditsAndOrdersView();

  @override
  ConsumerState<_CreditsAndOrdersView> createState() =>
      _CreditsAndOrdersViewState();
}

class _CreditsAndOrdersViewState extends ConsumerState<_CreditsAndOrdersView> {
  int? _checkoutPackageId;
  WalletOrder? _inspectOrder;

  @override
  Widget build(BuildContext context) {
    if (_checkoutPackageId != null || _inspectOrder != null) {
      return CheckoutFlowView(
        packageId: _checkoutPackageId,
        initialOrder: _inspectOrder,
        onClose: () => setState(() {
          _checkoutPackageId = null;
          _inspectOrder = null;
        }),
      );
    }

    final walletAsync = ref.watch(walletSummaryProvider);
    final packagesAsync = ref.watch(creditPackagesProvider);

    return walletAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: StateBlock(
          stamp: 'ERROR',
          title: 'Could not load wallet',
          description: err.toString(),
          action: PlacardButton(
            label: 'RETRY',
            onPress: () => ref.read(walletSummaryProvider.notifier).refresh(),
          ),
        ),
      ),
      data: (wallet) {
        if (wallet == null) {
          return const SizedBox.shrink();
        }
        final packages = packagesAsync.value ?? const <CreditPackage>[];
        final openOrder = wallet.openOrder;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ScorePlacard(
              totalScore: '${wallet.derivedBalance}',
              caption: 'LEDGER BALANCE (PURCHASED − USED)',
              splits: [
                ScoreSplit(
                  label: 'PURCHASED',
                  value: '${wallet.creditsPurchased}',
                ),
                ScoreSplit(
                  label: 'USED',
                  value: '${wallet.creditsUsed}',
                ),
                ScoreSplit(
                  label: 'BALANCE',
                  value: '${wallet.derivedBalance}',
                ),
              ],
            ),
            if (openOrder != null) ...[
              const SizedBox(height: 16),
              StateBlock(
                stamp: openOrder.status.label,
                title: 'Open order ${openOrder.orderCode}',
                description:
                    'One open order per account. Do not pay again while this order is ${openOrder.status.name}.',
                action: PlacardButton(
                  key: const Key('view-open-order-button'),
                  label: 'VIEW OPEN ORDER',
                  onPress: () => setState(() => _inspectOrder = openOrder),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _PackagesSection(
              packages: packages,
              blockedByOpenOrder: openOrder != null,
              onBuy: (pkg) => setState(() => _checkoutPackageId = pkg.id),
            ),
            const SizedBox(height: 16),
            _LedgerSection(entries: wallet.ledger),
            const SizedBox(height: 16),
            _OrdersSection(orders: wallet.orders),
          ],
        );
      },
    );
  }
}

class _PackagesSection extends StatelessWidget {
  const _PackagesSection({
    required this.packages,
    required this.blockedByOpenOrder,
    required this.onBuy,
  });

  final List<CreditPackage> packages;
  final bool blockedByOpenOrder;
  final ValueChanged<CreditPackage> onBuy;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'CREDIT PACKAGES',
      padding: EdgeInsets.zero,
      child: packages.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No active credit packages.',
                style: SignageTypography.body(
                  fontSize: 14,
                  color: SignageColors.inkMuted,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < packages.length; i++) ...[
                  if (i > 0)
                    Container(height: 1, color: SignageColors.lineSoft),
                  _PackageRow(
                    package: packages[i],
                    onBuy: blockedByOpenOrder ? null : () => onBuy(packages[i]),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.package,
    required this.onBuy,
  });

  final CreditPackage package;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: package.isFeatured
            ? SignageColors.blueWash
            : SignageColors.paper,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          package.name,
                          style: SignageTypography.condensedSentence(
                            fontSize: 17,
                          ),
                        ),
                      ),
                      if (package.isFeatured) ...[
                        const SizedBox(width: 8),
                        const PlacardBadge.warning('FEATURED'),
                      ],
                    ],
                  ),
                  if (package.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      package.description,
                      style: SignageTypography.body(
                        fontSize: 13,
                        color: SignageColors.inkMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${package.credits} CREDITS · ${formatVnd(package.priceVnd)}',
                    style: SignageTypography.data(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SignageColors.signBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PlacardButton(
              key: Key('buy-package-${package.id}'),
              label: 'BUY',
              expand: false,
              variant: package.isFeatured
                  ? PlacardButtonVariant.primary
                  : PlacardButtonVariant.secondary,
              onPress: onBuy,
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'APPEND-ONLY LEDGER',
      padding: EdgeInsets.zero,
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No credit movements recorded yet.',
                style: SignageTypography.body(
                  fontSize: 14,
                  color: SignageColors.inkMuted,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(color: SignageColors.ink),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'REASON / PROVENANCE',
                            style: SignageTypography.label(
                              fontSize: 11,
                              color: SignageColors.paper,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'DELTA',
                            textAlign: TextAlign.right,
                            style: SignageTypography.label(
                              fontSize: 11,
                              color: SignageColors.paper,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    Container(height: 1, color: SignageColors.lineSoft),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entries[i].reason,
                                style: SignageTypography.data(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (entries[i].provenance.isNotEmpty)
                                Text(
                                  entries[i].provenance,
                                  style: SignageTypography.data(
                                    fontSize: 12,
                                    color: SignageColors.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            entries[i].formattedDelta,
                            textAlign: TextAlign.right,
                            style: SignageTypography.data(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: entries[i].delta >= 0
                                  ? SignageColors.signGreen
                                  : SignageColors.signRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _OrdersSection extends StatelessWidget {
  const _OrdersSection({required this.orders});

  final List<WalletOrder> orders;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      title: 'PAST ORDERS',
      padding: EdgeInsets.zero,
      child: orders.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No orders yet.',
                style: SignageTypography.body(
                  fontSize: 14,
                  color: SignageColors.inkMuted,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < orders.length; i++) ...[
                  if (i > 0)
                    Container(height: 1, color: SignageColors.lineSoft),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                orders[i].orderCode,
                                style: SignageTypography.data(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${orders[i].packageName} · ${formatVnd(orders[i].amountVnd)}',
                                style: SignageTypography.body(
                                  fontSize: 13,
                                  color: SignageColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PlacardBadge(
                          label: orders[i].status.label,
                          variant: switch (orders[i].status) {
                            OrderStatus.paid => PlacardBadgeVariant.success,
                            OrderStatus.pending ||
                            OrderStatus.reconciling =>
                              PlacardBadgeVariant.warning,
                            OrderStatus.failed ||
                            OrderStatus.expired =>
                              PlacardBadgeVariant.danger,
                            _ => PlacardBadgeVariant.muted,
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
