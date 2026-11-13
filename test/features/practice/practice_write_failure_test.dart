import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/practice_payloads.dart';

/// A refused write must report the backend's message and leave the control
/// usable. Submitting an answer and requesting a hint are the two the learner
/// would otherwise believe succeeded.
void main() {
  FakeHttpClientAdapter adapterWith({required List<String> failedPaths}) {
    return FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'email': 'learner@demo.local',
          'fullName': 'Demo Learner',
          'role': 'learner',
          'emailVerified': true,
          'permissions': <String>[],
          'held': <String>[],
        });
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse({
          'active': {
            'code': 'TOEIC',
            'name': 'TOEIC Listening & Reading',
            'sectionNoun': 'Part',
          },
          'certificates': [
            {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
          ],
          'creditBalance': 13,
          'examinedSkills': ['listening', 'reading'],
        });
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(
            sections: [
              practiceSection(
                sectionId: 5,
                code: 'P5',
                name: 'Incomplete Sentences',
                accuracyPercentage: 72,
              ),
            ],
          ),
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse(const <dynamic>[]);
      }
      if (options.path == '/api/learner/practice/free-drill') {
        return FakeHttpClientAdapter.jsonResponse(practiceFreeDrillResponse());
      }
      if (options.path == '/api/learner/practice/sessions' &&
          options.method == 'POST') {
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 77,
          'title': 'Part 5: Incomplete Sentences',
        });
      }
      if (options.path == '/api/learner/practice/sessions/77/take') {
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 77,
          'title': 'Part 5: Incomplete Sentences',
          'feedbackMode': 'immediate',
          'questions': [
            {
              'questionId': 501,
              'displayOrder': 1,
              'questionType': 'mcq',
              'stem': 'The shipment ____ before noon.',
              'options': [
                {'optionId': 5001, 'label': 'A', 'text': 'arrived'},
                {'optionId': 5002, 'label': 'B', 'text': 'arriving'},
              ],
            },
          ],
        });
      }
      if (failedPaths.contains(options.path) && options.method == 'POST') {
        // Recorded from the running backend: `detail` carries the sentence.
        return FakeHttpClientAdapter.jsonResponse({
          'title': 'Practice session error',
          'status': 404,
          'detail': 'Practice session 77 is no longer open.',
          'code': 'PRACTICE_SESSION_NOT_FOUND',
        }, statusCode: 404);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });
  }

  Future<void> openSession(WidgetTester tester, FakeHttpClientAdapter adapter) async {
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
    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-section-5')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('start-section-5')));
    await tester.pumpAndSettle();
    expect(find.text('The shipment ____ before noon.'), findsOneWidget);
  }

  testWidgets('a failed answer reports the backend message and stays submit-able',
      (tester) async {
    final adapter = adapterWith(
      failedPaths: ['/api/learner/practice/sessions/77/questions/501/answer'],
    );
    await openSession(tester, adapter);

    await tester.tap(find.text('A. arrived'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('CHECK ANSWER'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('CHECK ANSWER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pumpAndSettle();

    expect(find.text('Practice session 77 is no longer open.'), findsOneWidget);
    // The control is offered again rather than left spinning or disabled.
    expect(find.text('CHECK ANSWER'), findsOneWidget);

    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pumpAndSettle();
    final attempts = adapter.requests
        .where((r) => r.path.endsWith('/questions/501/answer'))
        .length;
    expect(attempts, 2);
  });

  testWidgets('a failed hint reports the backend message and stays requestable',
      (tester) async {
    final adapter = adapterWith(
      failedPaths: ['/api/learner/practice/sessions/77/questions/501/hint'],
    );
    await openSession(tester, adapter);

    await tester.scrollUntilVisible(
      find.text('REQUEST HINT'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('REQUEST HINT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REQUEST HINT'));
    await tester.pumpAndSettle();

    expect(find.text('Practice session 77 is no longer open.'), findsOneWidget);
    expect(find.text('REQUEST HINT'), findsOneWidget);
  });
}
