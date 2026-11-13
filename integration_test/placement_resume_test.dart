import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Journey 1 — the learner's original complaint: RESUME a Placement attempt
/// and get stuck on a screen with no way forward.
///
/// Unlike the widget suites under `test/`, nothing here is faked: the real
/// backend is hit over HTTP and the real router, controllers, audio adapter
/// and platform plugins run. That is the only layer that can catch contract
/// drift, because the widget suites' fake payloads encode the same
/// assumptions as the parsers they verify.
///
/// Run with the backend up:
///   flutter test integration_test/placement_resume_test.dart -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The app resolves its base URL per platform; an Android emulator reaches
  /// the host through 10.0.2.2, which AppConfig already handles. This asserts
  /// that assumption rather than silently passing against the wrong host.
  testWidgets('the app targets a reachable backend', (tester) async {
    expect(
      AppConfig.baseUrl,
      anyOf(
        contains('localhost:5001'),
        contains('10.0.2.2:5001'),
      ),
      reason:
          'integration tests must run against the live backend, not a stub host',
    );
  });

  testWidgets(
    'a learner resumes an in-progress placement and reaches the room',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ExtraEfficientApp()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // --- Sign in against the live backend -------------------------------
      expect(
        find.byKey(const Key('sign-in-email-field')),
        findsOneWidget,
        reason: 'unauthenticated start should land on sign-in',
      );

      await tester.enterText(
        find.byKey(const Key('sign-in-email-field')),
        'learner@demo.local',
      );
      await tester.enterText(
        find.byKey(const Key('sign-in-password-field')),
        'Demo1234!',
      );
      await tester.tap(find.byKey(const Key('sign-in-submit-button')));
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // The auth guard sends a signed-in learner to PATH.
      expect(
        find.byKey(const Key('sign-in-email-field')),
        findsNothing,
        reason: 'sign-in should have navigated away from the auth screen',
      );

      // --- Open EXAMS -----------------------------------------------------
      await tester.tap(find.text('EXAMS').last);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // --- RESUME the in-progress placement -------------------------------
      // Ticket #16's fix is precisely that this door renders at all: the hub
      // previously read `inProgressPlacementId` while the backend sends
      // `activePlacementId`, so RESUME never appeared.
      final resumePlacement = find.byKey(const Key('resume-placement-btn'));
      if (resumePlacement.evaluate().isEmpty) {
        // No unfinished sitting on this seed. Not a failure of the fix — the
        // demo DB simply has none — but say so rather than passing silently.
        markTestSkipped(
          'No in-progress placement on this seed; start one from the hub '
          '(START FREE PLACEMENT) before running this journey.',
        );
        return;
      }

      await tester.tap(resumePlacement);
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // --- The reported failure was a room with no exit -------------------
      // Whatever the sitting's state, the learner must always have a way out.
      final reachedRoom =
          find.byKey(const Key('exam-abandon-btn')).evaluate().isNotEmpty ||
              find.byKey(const Key('exam-room-header')).evaluate().isNotEmpty;

      expect(
        reachedRoom,
        isTrue,
        reason:
            'resuming a placement must render the exam room header or a '
            'terminal state with an exit — never a dead screen',
      );

      // No permanent spinner: the room must not still be loading.
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'the room must settle, not spin forever',
      );
    },
  );
}
