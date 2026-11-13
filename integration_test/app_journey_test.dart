import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Device journey — every tab and the flows the user reported.
///
/// Drives the app by widget key against the LIVE backend, so it exercises real
/// HTTP, real routing, real platform plugins and real layout. Unlike `test/`,
/// nothing here is a fake payload: a contract drift fails this suite.
///
/// Run (backend up, adb reverse tcp:5001 tcp:5001 done):
///   flutter test integration_test/app_journey_test.dart -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const demoEmail = 'learner@demo.local';
  const demoPassword = 'Demo1234!';

  /// A missed tap must fail loudly. Flutter only *warns* on a missed tap, so a
  /// green run could otherwise hide a broken journey.
  Future<void> tapOrFail(WidgetTester tester, Finder finder, String what) async {
    expect(finder, findsWidgets, reason: 'could not find $what');
    await tester.tap(finder.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 8));
  }

  /// No permanent spinner: any screen the learner lands on must settle.
  void expectNoSpinner() {
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'screen is still spinning after settling',
    );
  }

  /// The raw dio internals must never reach the learner.
  void expectNoRawDioText() {
    expect(
      find.textContaining('DioException'),
      findsNothing,
      reason: 'a raw DioException leaked into the UI',
    );
    expect(
      find.textContaining('cannot be solved by the library'),
      findsNothing,
      reason: 'dio internal guidance leaked into the UI',
    );
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ExtraEfficientApp()));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    final emailField = find.byKey(const Key('sign-in-email-field'));
    if (emailField.evaluate().isEmpty) {
      // Already authenticated (secure storage survives within a run).
      return;
    }
    await tester.enterText(emailField, demoEmail);
    await tester.enterText(
      find.byKey(const Key('sign-in-password-field')),
      demoPassword,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('sign-in-submit-button')),
      warnIfMissed: false,
    );
    // Wait for the auth round trip, then for the shell to mount.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (emailField.evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Surface the screen's own message if we are still on sign-in, so the
    // failure names the cause instead of "could not find the PATH tab".
    if (emailField.evaluate().isNotEmpty) {
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .where((t) => t.trim().isNotEmpty)
          .toList();
      fail('still on sign-in after submitting. Visible text: $texts');
    }
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tapOrFail(tester, find.text(label), 'the $label tab');
    await tester.pumpAndSettle(const Duration(seconds: 8));
  }

  testWidgets('the app points at the live backend', (tester) async {
    expect(
      AppConfig.baseUrl,
      anyOf(contains('localhost:5001'), contains('10.0.2.2:5001')),
      reason: 'integration tests must target the live API',
    );
  });

  testWidgets('sign in reaches PATH with real data', (tester) async {
    await signIn(tester);

    expectNoRawDioText();
    expectNoSpinner();

    // PATH renders the certificate and a credit balance from the server.
    expect(find.text('PATH'), findsWidgets);
    expect(find.textContaining('CERTIFICATE:'), findsWidgets);
    expect(find.textContaining('CREDITS'), findsWidgets);
  });

  testWidgets('every tab renders without an error or a spinner', (tester) async {
    await signIn(tester);

    for (final tab in ['PRACTICE', 'EXAMS', 'WALLET', 'ACCOUNT', 'PATH']) {
      await openTab(tester, tab);
      expectNoSpinner();
      expectNoRawDioText();
      expect(
        find.textContaining('UNABLE TO LOAD'),
        findsNothing,
        reason: '$tab showed a load error',
      );
    }
  });

  testWidgets('EXAMS shows the placement and mock catalogues', (tester) async {
    await signIn(tester);
    await openTab(tester, 'EXAMS');

    expect(find.textContaining('PLACEMENT ASSESSMENT'), findsWidgets);
    expect(find.textContaining('MOCK EXAM CATALOG'), findsWidgets);
    expectNoRawDioText();

    // HISTORY & REVIEW must render its own designed empty or populated state.
    await tapOrFail(tester, find.text('HISTORY & REVIEW'), 'HISTORY & REVIEW');
    expectNoSpinner();
    expectNoRawDioText();
  });

  testWidgets('PRACTICE renders the catalogue and the topic grid', (tester) async {
    await signIn(tester);
    await openTab(tester, 'PRACTICE');
    expectNoRawDioText();

    // The sub-tabs must all be reachable and settle.
    for (final sub in ['SAVED', 'WEAKNESS', 'DRILLS']) {
      await tapOrFail(tester, find.text(sub), '$sub sub-tab');
      expectNoSpinner();
      expectNoRawDioText();
    }
  });

  testWidgets('WALLET shows the ledger balance and packages', (tester) async {
    await signIn(tester);
    await openTab(tester, 'WALLET');
    expectNoRawDioText();
    expectNoSpinner();

    expect(find.textContaining('CREDITS'), findsWidgets);
    expect(find.textContaining('CREDIT PACKAGES'), findsWidgets);

    // A package price must never read a bare zero. `textContaining('0 ₫')`
    // would also match "100,000 ₫", so match the whole string.
    expect(
      find.text('0 ₫'),
      findsNothing,
      reason: 'a package quoted 0 dong',
    );
  });

  testWidgets('WALLET mentor detail lists real slots and credits', (tester) async {
    await signIn(tester);
    await openTab(tester, 'WALLET');
    await tapOrFail(tester, find.text('MENTORS & BOOKINGS'), 'MENTORS & BOOKINGS');
    expectNoRawDioText();

    // Open the first mentor's booking screen via its BOOK control.
    if (find.text('BOOK').evaluate().isNotEmpty) {
      await tapOrFail(tester, find.text('BOOK'), 'BOOK');
      expectNoRawDioText();
      expectNoSpinner();
      expect(
        find.textContaining('0 CREDITS'),
        findsNothing,
        reason: 'mentor quoted 0 credits',
      );
    }
  });

  testWidgets('ACCOUNT opens profile and complaints without crashing', (tester) async {
    await signIn(tester);
    await openTab(tester, 'ACCOUNT');
    expectNoSpinner();
    expectNoRawDioText();

    if (find.textContaining('COMPLAINT').evaluate().isNotEmpty) {
      await tapOrFail(tester, find.textContaining('COMPLAINT').first, 'complaints');
      expectNoSpinner();
      expectNoRawDioText();
    }
  });
}
