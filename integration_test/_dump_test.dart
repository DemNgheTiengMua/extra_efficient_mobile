import 'package:extra_efficient_mobile/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('dump after sign in', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ExtraEfficientApp()));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    final email = find.byKey(const Key('sign-in-email-field'));
    if (email.evaluate().isNotEmpty) {
      await tester.enterText(email, 'learner@demo.local');
      await tester.enterText(find.byKey(const Key('sign-in-password-field')), 'Demo1234!');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign-in-submit-button')), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 15));
    }
    final texts = find.byType(Text).evaluate()
        .map((e) => (e.widget as Text).data)
        .where((t) => t != null && t.trim().isNotEmpty)
        .take(40).toList();
    debugPrint('VISIBLE_TEXT: $texts');
  });
}
