import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/wallet/wallet_models.dart';
import '../../fixtures/wallet_fixtures.dart';

void main() {
  group('WalletSummary parses the wallet payload', () {
    test('balance is the ledger balance, not purchased minus used', () {
      final wallet = WalletSummary.fromJson(walletPayload);

      // 15 - 5 = 10, but an admin grant of 1 makes the ledger sum 11.
      expect(wallet.creditsPurchased, 15);
      expect(wallet.creditsUsed, 5);
      expect(wallet.balance, 11);
    });

    test('balance equals the sum of the ledger deltas', () {
      final wallet = WalletSummary.fromJson(walletPayload);
      final sum = wallet.ledger.fold<int>(0, (acc, e) => acc + e.delta);

      expect(sum, wallet.balance);
    });

    test('ledger entries carry their reason and note', () {
      final wallet = WalletSummary.fromJson(walletPayload);
      final grant = wallet.ledger.firstWhere((e) => e.id == 6);

      expect(grant.reason, 'admin_grant');
      expect(grant.note, 'Complaint make-good: audio stream stutter refund');
      expect(grant.delta, 1);
    });

    test('orders parse amount and gatewayErrorCode', () {
      final wallet = WalletSummary.fromJson(walletPayload);
      final failed = wallet.orders.first;

      expect(wallet.orders, hasLength(2));
      expect(failed.orderCode, 'DH-20261113-0051');
      expect(failed.amountVnd, 100000);
      expect(failed.status, OrderStatus.failed);
      expect(failed.errorCode, 'MOCK_DECLINED');
    });
  });

  group('CreditPackage', () {
    test('reads packageId, price and features', () {
      final pkg = CreditPackage.fromJson(packagesPayload.first);

      expect(pkg.id, 2);
      expect(pkg.name, 'Starter Pack');
      expect(pkg.credits, 5);
      expect(pkg.priceVnd, 100000);
      expect(pkg.isFeatured, isFalse);
      expect(pkg.features, contains('Never expires'));
    });
  });

  group('CheckoutPreview', () {
    test('reads price so the quote is never zero', () {
      final preview = CheckoutPreview.fromJson(checkoutPreviewPayload);

      expect(preview.packageId, 2);
      expect(preview.packageName, 'Starter Pack');
      expect(preview.credits, 5);
      expect(preview.amountVnd, 100000);
      expect(preview.openOrder, isNull);
    });

    test('reads the openOrder object so the guard fires', () {
      final preview = CheckoutPreview.fromJson(checkoutPreviewOpenOrderPayload);

      expect(preview.amountVnd, 190000);
      expect(preview.openOrder, isNotNull);
      expect(preview.openOrder!.orderCode, 'DH-20261113-0101');
      expect(preview.openOrder!.status, OrderStatus.pending);
    });
  });

  group('WalletOrder', () {
    test('reads amount and status from the create-order response', () {
      final order = WalletOrder.fromJson(createdOrderPayload);

      expect(order.orderCode, 'DH-20261113-0101');
      expect(order.amountVnd, 190000);
      expect(order.status, OrderStatus.pending);
      expect(order.checkoutUrl, contains('orderCode=DH-20261113-0101'));
    });

    test('reads gatewayErrorCode from the payment result', () {
      final order = WalletOrder.fromJson(
        paymentResultPayload(status: 'failed', gatewayErrorCode: 'PAYOS_TIMEOUT'),
      );

      expect(order.status, OrderStatus.failed);
      expect(order.errorCode, 'PAYOS_TIMEOUT');
      expect(order.amountVnd, 190000);
      expect(order.packageName, 'Intensive Pack');
      expect(order.credits, 10);
    });
  });
}
