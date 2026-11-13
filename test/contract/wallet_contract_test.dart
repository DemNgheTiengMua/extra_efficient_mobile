import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/wallet/wallet_models.dart';

import '../contract/fixture_loader.dart';

/// Recorded-payload suite for wallet and checkout. Every asset is real backend
/// bytes; every assertion checks a **non-default** value, because a wrong key
/// yields a valid object holding `0`, `''` or `[]`.
void main() {
  group('GET /api/learner/wallet', () {
    late WalletSummary wallet;

    setUpAll(() {
      wallet = WalletSummary.fromJson(
        loadFixture('wallet') as Map<String, dynamic>,
      );
    });

    test('balance is the ledger balance, not purchased minus used', () {
      // 15 - 5 = 10, but an admin grant of 1 makes the ledger sum 11.
      expect(wallet.creditsPurchased, 15);
      expect(wallet.creditsUsed, 5);
      expect(wallet.balance, 11);
    });

    test('balance equals the sum of the ledger deltas', () {
      final sum = wallet.ledger.fold<int>(0, (acc, e) => acc + e.delta);

      expect(sum, wallet.balance);
      expect(wallet.ledger, hasLength(8));
    });

    test('ledger entries read txnId, reason, note and orderCode', () {
      final grant = wallet.ledger.firstWhere((e) => e.reason == 'admin_grant');

      expect(grant.id, 6);
      expect(grant.delta, 1);
      expect(grant.note, 'Complaint make-good: audio stream stutter refund');

      final purchase = wallet.ledger.firstWhere((e) => e.reason == 'purchase');
      expect(purchase.orderCode, startsWith('DH-'));
      expect(purchase.delta, greaterThan(0));
    });

    test('orders read amount and gatewayErrorCode', () {
      expect(wallet.orders, hasLength(3));

      final failed = wallet.orders.firstWhere(
        (o) => o.status == OrderStatus.failed,
      );
      expect(failed.orderCode, 'DH-20261113-0051');
      expect(failed.amountVnd, 100000);
      expect(failed.packageName, 'Starter Pack');
      expect(failed.errorCode, 'MOCK_DECLINED');

      // The 190,000 order is the Intensive Pack one, paid.
      final paid = wallet.orders.firstWhere((o) => o.amountVnd == 190000);
      expect(paid.status, OrderStatus.paid);
      expect(paid.packageName, 'Intensive Pack');
    });

    test('no order is open in this snapshot', () {
      expect(wallet.openOrder, isNull);
    });
  });

  group('GET /api/packages', () {
    late List<CreditPackage> packages;

    setUpAll(() {
      packages = (loadFixture('credit_packages') as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CreditPackage.fromJson)
          .toList();
    });

    test('every package reads a non-zero id, price and credit count', () {
      expect(packages, hasLength(3));
      expect(packages.map((p) => p.id), everyElement(isPositive));
      expect(packages.map((p) => p.priceVnd), everyElement(isPositive));
      expect(packages.map((p) => p.credits), everyElement(isPositive));
    });

    test('Starter Pack reads its real name, price and newline features', () {
      final starter = packages.firstWhere((p) => p.id == 2);

      expect(starter.name, 'Starter Pack');
      expect(starter.credits, 5);
      expect(starter.priceVnd, 100000);
      expect(starter.featureList, contains('Never expires'));
    });

    test('Intensive Pack is the featured one', () {
      final featured = packages.firstWhere((p) => p.isFeatured);

      expect(featured.id, 1);
      expect(featured.name, 'Intensive Pack');
      expect(featured.priceVnd, 190000);
    });
  });

  group('GET /api/checkout/preview', () {
    test('reads price so the quote is never zero', () {
      final preview = CheckoutPreview.fromJson(
        loadFixture('checkout_preview') as Map<String, dynamic>,
      );

      expect(preview.packageId, 2);
      expect(preview.packageName, 'Starter Pack');
      expect(preview.credits, 5);
      expect(preview.amountVnd, 100000);
      expect(preview.openOrder, isNull);
    });

    test('reads the openOrder object so the guard fires', () {
      final preview = CheckoutPreview.fromJson(
        loadFixture('checkout_preview_open_order') as Map<String, dynamic>,
      );

      expect(preview.amountVnd, 190000);
      expect(preview.openOrder, isNotNull);
      expect(preview.openOrder!.orderCode, startsWith('DH-'));
      expect(preview.openOrder!.status, OrderStatus.pending);
      expect(preview.openOrder!.credits, 10);
    });
  });

  group('POST /api/checkout/orders', () {
    test('reads amount and status from CreateOrderResponse', () {
      final order = WalletOrder.fromJson(
        loadFixture('checkout_create_order') as Map<String, dynamic>,
      );

      expect(order.orderCode, startsWith('DH-'));
      expect(order.amountVnd, 190000);
      expect(order.status, OrderStatus.pending);
      expect(order.checkoutUrl, contains('orderCode='));
    });
  });

  group('GET /api/checkout/orders/{code}/result', () {
    test('reads gatewayErrorCode and a settled failure', () {
      final order = WalletOrder.fromJson(
        loadFixture('payment_result_failed') as Map<String, dynamic>,
      );

      expect(order.status, OrderStatus.failed);
      expect(order.errorCode, 'MOCK_DECLINED');
      expect(order.amountVnd, 190000);
      expect(order.packageName, 'Intensive Pack');
      expect(order.credits, 10);
      expect(order.packageId, 1);
    });
  });
}
