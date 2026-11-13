import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/core/platform/external_url_launcher.dart';

void main() {
  group('ExternalUrlLauncher', () {
    test('resolves a root-relative checkout url against the API host', () async {
      Uri? launched;
      final launcher = ExternalUrlLauncher(
        baseUrl: 'http://localhost:5001',
        launch: (url) async {
          launched = url;
          return true;
        },
      );

      final ok = await launcher.launchExternalUrl(
        '/checkout/mock-gateway?orderCode=DH-20261113-0101',
      );

      expect(ok, isTrue);
      expect(
        launched.toString(),
        'http://localhost:5001/checkout/mock-gateway?orderCode=DH-20261113-0101',
      );
    });

    test('passes an absolute url through untouched', () async {
      Uri? launched;
      final launcher = ExternalUrlLauncher(
        launch: (url) async {
          launched = url;
          return true;
        },
      );

      await launcher.launchExternalUrl('https://meet.google.com/abc-defg-hij');

      expect(launched.toString(), 'https://meet.google.com/abc-defg-hij');
    });

    test('reports failure when the platform cannot launch', () async {
      final launcher = ExternalUrlLauncher(
        launch: (url) async => false,
      );

      expect(await launcher.launchExternalUrl('https://pay.payos.vn/x'), isFalse);
    });

    test('reports failure instead of throwing when the launch throws', () async {
      final launcher = ExternalUrlLauncher(
        launch: (url) async => throw StateError('no activity'),
      );

      expect(await launcher.launchExternalUrl('https://pay.payos.vn/x'), isFalse);
    });

    test('reports failure for an empty url', () async {
      var called = false;
      final launcher = ExternalUrlLauncher(
        launch: (url) async {
          called = true;
          return true;
        },
      );

      expect(await launcher.launchExternalUrl('   '), isFalse);
      expect(called, isFalse);
    });
  });
}
