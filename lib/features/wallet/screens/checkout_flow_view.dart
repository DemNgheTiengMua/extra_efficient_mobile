import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../context/learner_context_provider.dart';
import '../wallet_models.dart';
import '../wallet_providers.dart';

/// In-tab checkout & order reconciliation flow for a selected package or open order.
class CheckoutFlowView extends ConsumerStatefulWidget {
  const CheckoutFlowView({
    super.key,
    this.packageId,
    this.initialOrder,
    required this.onClose,
  }) : assert(packageId != null || initialOrder != null);

  final int? packageId;
  final WalletOrder? initialOrder;
  final VoidCallback onClose;

  @override
  ConsumerState<CheckoutFlowView> createState() => _CheckoutFlowViewState();
}

class _CheckoutFlowViewState extends ConsumerState<CheckoutFlowView> {
  CheckoutPreview? _preview;
  WalletOrder? _order;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    if (_order == null && widget.packageId != null) {
      _loadPreview(widget.packageId!);
    }
  }

  Future<void> _loadPreview(int packageId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final preview =
          await ref.read(walletRepositoryProvider).previewCheckout(packageId);
      if (mounted) {
        setState(() {
          _preview = preview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createOrder() async {
    final packageId = _preview?.packageId ?? widget.packageId;
    if (packageId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order =
          await ref.read(walletRepositoryProvider).createOrder(packageId);
      await ref.read(walletSummaryProvider.notifier).refresh();
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkStatus() async {
    final code = _order?.orderCode;
    if (code == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final updated =
          await ref.read(walletRepositoryProvider).getOrderResult(code);
      await _syncIfSettled(updated);
      if (mounted) {
        setState(() {
          _order = updated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleReturn() async {
    final code = _order?.orderCode;
    if (code == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final updated =
          await ref.read(walletRepositoryProvider).handleReturn(code);
      await _syncIfSettled(updated);
      if (mounted) {
        setState(() {
          _order = updated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelOrder() async {
    final code = _order?.orderCode;
    if (code == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(walletRepositoryProvider).cancelOrder(code);
      await ref.read(walletSummaryProvider.notifier).refresh();
      if (mounted) {
        setState(() {
          _order = WalletOrder(
            orderCode: _order!.orderCode,
            packageId: _order!.packageId,
            packageName: _order!.packageName,
            credits: _order!.credits,
            amountVnd: _order!.amountVnd,
            status: OrderStatus.cancelled,
            createdAt: _order!.createdAt,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _mockGateway(String action) async {
    final code = _order?.orderCode;
    if (code == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(walletRepositoryProvider);
      await repo.mockGatewayAction(
        orderCode: code,
        action: action,
        errorCode: action == 'failed' ? 'MOCK_DECLINED' : null,
      );
      final updated = await repo.getOrderResult(code);
      await _syncIfSettled(updated);
      if (mounted) {
        setState(() {
          _order = updated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncIfSettled(WalletOrder order) async {
    await ref.read(walletSummaryProvider.notifier).refresh();
    if (order.status == OrderStatus.paid) {
      await ref.read(learnerContextProvider.notifier).refreshContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PlacardButton(
            key: const Key('back-to-wallet-button'),
            label: 'BACK TO WALLET',
            expand: false,
            variant: PlacardButtonVariant.secondary,
            onPress: widget.onClose,
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          PlacardAlert(
            variant: PlacardAlertVariant.danger,
            title: 'Checkout error',
            subtitle: _error,
          ),
          const SizedBox(height: 16),
        ],
        if (_isLoading && _preview == null && _order == null)
          const Center(child: CircularProgressIndicator())
        else if (_order != null)
          _buildOrderState(_order!)
        else if (_preview != null)
          _buildPreview(_preview!),
      ],
    );
  }

  Widget _buildPreview(CheckoutPreview preview) {
    if (preview.hasOpenOrder) {
      return StateBlock(
        stamp: 'BLOCKED',
        title: 'Do not pay again',
        description:
            'You already have an open order (${preview.openOrderCode ?? 'pending'}). Complete or cancel it before starting a new order.',
        action: PlacardButton(
          label: 'RETURN TO WALLET',
          onPress: widget.onClose,
        ),
      );
    }

    return PlacardPanel(
      title: 'CHECKOUT PREVIEW',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            preview.packageName,
            style: SignageTypography.headline(),
          ),
          const SizedBox(height: 8),
          Text(
            '${preview.credits} CREDITS',
            style: SignageTypography.data(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SignageColors.signBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatVnd(preview.amountVnd),
            style: SignageTypography.data(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const PlacardAlert(
            variant: PlacardAlertVariant.info,
            title: 'One open order per account',
            subtitle:
                'Creating an order reserves a 15-minute payOS payment window.',
          ),
          const SizedBox(height: 16),
          PlacardButton(
            key: const Key('create-order-button'),
            label: 'CREATE ORDER',
            isLoading: _isLoading,
            onPress: _createOrder,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderState(WalletOrder order) {
    final (String title, String description, Widget extra) =
        switch (order.status) {
      OrderStatus.pending => (
          'Awaiting gateway payment',
          'Complete payment in payOS or use Mock Gateway controls below.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (order.checkoutUrl != null) ...[
                PlacardButton(
                  key: const Key('open-gateway-url-button'),
                  label: 'OPEN PAYMENT GATEWAY',
                  onPress: () => ref
                      .read(urlLauncherAdapterProvider)
                      .launchExternalUrl(order.checkoutUrl!),
                ),
                const SizedBox(height: 8),
              ],
              PlacardButton(
                key: const Key('check-order-status-button'),
                label: 'CHECK STATUS',
                variant: PlacardButtonVariant.secondary,
                isLoading: _isLoading,
                onPress: _checkStatus,
              ),
              const SizedBox(height: 8),
              PlacardButton(
                key: const Key('handle-return-button'),
                label: 'VERIFY RETURN REDIRECT',
                variant: PlacardButtonVariant.secondary,
                isLoading: _isLoading,
                onPress: _handleReturn,
              ),
              const SizedBox(height: 8),
              PlacardButton(
                key: const Key('cancel-order-button'),
                label: 'CANCEL ORDER',
                variant: PlacardButtonVariant.destructive,
                isLoading: _isLoading,
                onPress: _cancelOrder,
              ),
            ],
          ),
        ),
      OrderStatus.reconciling => (
          'Payment reconciling — Do not pay again',
          'Your payment is being verified with the gateway. Do not create a new order.',
          PlacardButton(
            key: const Key('check-order-status-button'),
            label: 'CHECK STATUS',
            variant: PlacardButtonVariant.secondary,
            isLoading: _isLoading,
            onPress: _checkStatus,
          ),
        ),
      OrderStatus.paid => (
          'Credits added to your ledger',
          '${order.credits} credits have been credited for ${order.packageName}.',
          PlacardButton(
            label: 'RETURN TO WALLET',
            onPress: widget.onClose,
          ),
        ),
      OrderStatus.failed => (
          'Payment failed',
          'Gateway reported an error${order.errorCode != null ? ' (${order.errorCode})' : ''}. You may retry checkout.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlacardButton(
                key: const Key('check-order-status-button'),
                label: 'CHECK STATUS',
                variant: PlacardButtonVariant.secondary,
                isLoading: _isLoading,
                onPress: _checkStatus,
              ),
              const SizedBox(height: 8),
              PlacardButton(
                label: 'RETRY CHECKOUT',
                onPress: () => setState(() {
                  _order = null;
                  _loadPreview(order.packageId);
                }),
              ),
            ],
          ),
        ),
      OrderStatus.expired => (
          'Order expired',
          'The 15-minute reconciliation window elapsed. Please start a new order.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlacardButton(
                key: const Key('check-order-status-button'),
                label: 'CHECK STATUS',
                variant: PlacardButtonVariant.secondary,
                isLoading: _isLoading,
                onPress: _checkStatus,
              ),
              const SizedBox(height: 8),
              PlacardButton(
                label: 'START NEW ORDER',
                onPress: () => setState(() {
                  _order = null;
                  _loadPreview(order.packageId);
                }),
              ),
            ],
          ),
        ),
      OrderStatus.cancelled || OrderStatus.unknown => (
          'Order ${order.status.name}',
          'This order is closed.',
          PlacardButton(
            label: 'RETURN TO WALLET',
            onPress: widget.onClose,
          ),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlacardPanel(
          title: 'ORDER DETAILS',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderCode,
                      style: SignageTypography.data(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.packageName} · ${order.credits} CREDITS · ${formatVnd(order.amountVnd)}',
                      style: SignageTypography.body(
                        fontSize: 13,
                        color: SignageColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StateBlock(
          stamp: order.status.label,
          title: title,
          description: description,
          action: extra,
        ),
        if (order.status == OrderStatus.pending) ...[
          const SizedBox(height: 16),
          PlacardPanel(
            title: 'MOCK GATEWAY (DEV / TEST)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlacardButton(
                  key: const Key('mock-gateway-paid-button'),
                  label: 'SIMULATE PAID',
                  isLoading: _isLoading,
                  onPress: () => _mockGateway('paid'),
                ),
                const SizedBox(height: 8),
                PlacardButton(
                  key: const Key('mock-gateway-failed-button'),
                  label: 'SIMULATE FAILED',
                  variant: PlacardButtonVariant.destructive,
                  isLoading: _isLoading,
                  onPress: () => _mockGateway('failed'),
                ),
                const SizedBox(height: 8),
                PlacardButton(
                  key: const Key('mock-gateway-cancelled-button'),
                  label: 'SIMULATE CANCELLED',
                  variant: PlacardButtonVariant.secondary,
                  isLoading: _isLoading,
                  onPress: () => _mockGateway('cancelled'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
