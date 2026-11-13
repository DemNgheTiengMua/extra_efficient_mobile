import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../contract/fixture_loader.dart';
import '../../helpers/fake_http_adapter.dart';

Map<String, dynamic> _user() => {
  'userId': 2,
  'email': 'learner@demo.local',
  'fullName': 'Demo Learner',
  'role': 'learner',
  'emailVerified': true,
  'permissions': [],
  'held': [],
};

Map<String, dynamic> _context() => {
  'active': {'code': 'TOEIC', 'name': 'TOEIC', 'sectionNoun': 'Part'},
  'certificates': [
    {'code': 'TOEIC', 'name': 'TOEIC', 'sectionNoun': 'Part'},
  ],
  'creditBalance': 11,
  'examinedSkills': ['listening', 'reading'],
  'examDate': null,
};

Future<void> _pumpWallet(WidgetTester tester, Object walletPayload) async {
  final adapter = FakeHttpClientAdapter((options, body) async {
    if (options.path == '/api/auth/me') {
      return FakeHttpClientAdapter.jsonResponse(_user());
    }
    if (options.path == '/api/learner/context') {
      return FakeHttpClientAdapter.jsonResponse(_context());
    }
    if (options.path == '/api/learner/wallet') {
      return FakeHttpClientAdapter.jsonResponse(walletPayload);
    }
    if (options.path == '/api/packages') {
      return FakeHttpClientAdapter.jsonResponse(loadFixture('credit_packages'));
    }
    return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage(initialToken: 'valid-jwt'),
        ),
        httpClientAdapterProvider.overrideWithValue(adapter),
        audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
      ],
      child: const ExtraEfficientApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('WALLET'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'WALLET placard shows the ledger balance, keeps purchased/used totals, and lists reason + note',
    (tester) async {
      await _pumpWallet(tester, loadFixture('wallet'));

      // The ledger balance is 11, not purchased-minus-used (15 - 5 = 10).
      expect(find.text('11'), findsWidgets);
      expect(
        find.text('LEDGER BALANCE (INCLUDING ADMIN GRANTS)'),
        findsOneWidget,
      );
      expect(find.text('10'), findsNothing);

      // Purchased and used remain visible as separate informative totals.
      expect(find.text('15'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Real package names and prices from the backend.
      expect(find.text('Starter Pack'), findsWidgets);
      expect(find.text('Intensive Pack'), findsOneWidget);
      expect(find.textContaining('100,000 ₫'), findsOneWidget);
      expect(find.text('FEATURED'), findsOneWidget);

      // Ledger rows carry their reason and the administrator's note.
      await tester.scrollUntilVisible(find.text('admin_grant'), 200);
      expect(find.text('admin_grant'), findsOneWidget);
      expect(
        find.text('Complaint make-good: audio stream stutter refund'),
        findsOneWidget,
      );
      expect(find.textContaining('mock_exam_start'), findsWidgets);

      // Past orders show the failed one with its gateway error code available.
      await tester.scrollUntilVisible(find.text('DH-20261113-0051'), 200);
      expect(find.text('DH-20261113-0051'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
    },
  );

  testWidgets('an open order on the wallet offers to inspect it', (
    tester,
  ) async {
    final wallet = loadFixture('wallet') as Map<String, dynamic>;
    final openOrder =
        (loadFixture('checkout_preview_open_order')
            as Map<String, dynamic>)['openOrder'];

    await _pumpWallet(tester, {
      ...wallet,
      'balance': 0,
      'creditsPurchased': 0,
      'creditsUsed': 0,
      'orders': [openOrder],
      'ledger': const [],
    });

    expect(find.textContaining('DH-20261113-0103'), findsWidgets);
    expect(find.byKey(const Key('view-open-order-button')), findsOneWidget);

    // BUY is inert while an order is open: no checkout preview opens.
    await tester.scrollUntilVisible(find.text('Starter Pack'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-package-2')));
    await tester.pumpAndSettle();
    expect(find.text('CHECKOUT PREVIEW'), findsNothing);
  });
}
