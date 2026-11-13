import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  testWidgets(
      'Writing drill validates word floor and required keywords, and bookmark toggles saved question',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    Map<String, dynamic>? submittedAnswer;
    bool bookmarked = false;
    bool deletedBookmark = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'email': 'learner@demo.local',
          'fullName': 'Demo Learner',
          'role': 'learner',
          'emailVerified': true,
          'permissions': [],
          'held': [],
        });
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse({
          'active': {
            'code': 'TOEIC_SW',
            'name': 'TOEIC Speaking & Writing',
            'sectionNoun': 'Part',
          },
          'certificates': [
            {
              'code': 'TOEIC_SW',
              'name': 'TOEIC Speaking & Writing',
              'sectionNoun': 'Part',
            },
          ],
          'creditBalance': 10,
          'examinedSkills': ['speaking', 'writing'],
          'examDate': null,
        });
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse({
          'sectionNoun': 'Part',
          'sections': [
            {
              'sectionId': 6,
              'title': 'Part 6: Respond to a Written Request',
              'skill': 'writing',
              'accuracyPercent': 75,
              'cooldownActive': false,
              'isSpeaking': false,
            },
          ],
        });
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse({'levels': [], 'topics': []});
      }
      if (options.path == '/api/learner/practice/sessions' &&
          options.method == 'POST') {
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 88,
          'title': 'Part 6: Respond to a Written Request',
        });
      }
      if (options.path == '/api/learner/practice/sessions/88/take' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 88,
          'title': 'Part 6: Respond to a Written Request',
          'feedbackMode': 'immediate',
          'questions': [
            {
              'questionId': 601,
              'displayOrder': 1,
              'questionType': 'writing',
              'stem': 'Reply to the client email about the meeting time.',
              'wordFloor': 10,
              'requiredKeywords': ['schedule', 'confirm'],
            },
          ],
        });
      }
      if (options.path ==
              '/api/learner/practice/sessions/88/questions/601/answer' &&
          options.method == 'POST') {
        submittedAnswer = body as Map<String, dynamic>;
        return FakeHttpClientAdapter.jsonResponse({
          'isCorrect': true,
          'generalExplanation': 'Word floor and required keywords satisfied.',
          'wordCount': 11,
        });
      }
      if (options.path == '/api/learner/saved-questions/questions/601' &&
          options.method == 'POST') {
        bookmarked = true;
        return FakeHttpClientAdapter.jsonResponse({
          'savedQuestionId': 901,
        });
      }
      if (options.path == '/api/learner/saved-questions/901' &&
          options.method == 'DELETE') {
        deletedBookmark = true;
        return FakeHttpClientAdapter.jsonResponse(null, statusCode: 204);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
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
      find.byKey(const Key('start-section-6')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('start-section-6')));
    await tester.pumpAndSettle();

    expect(find.text('MIN 10 WORDS'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('CONFIRM'), findsOneWidget);

    // Bookmark & unbookmark
    await tester.tap(find.byKey(const Key('bookmark-question-601')));
    await tester.pumpAndSettle();
    expect(bookmarked, isTrue);
    expect(find.text('SAVED'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bookmark-question-601')));
    await tester.pumpAndSettle();
    expect(deletedBookmark, isTrue);
    expect(find.text('SAVE QUESTION'), findsOneWidget);

    // Enter 11 words with both required keywords
    await tester.enterText(
      find.byKey(const Key('writing-response-input')),
      'I would like to confirm the new schedule for our Tuesday meeting.',
    );
    await tester.pumpAndSettle();
    expect(find.text('12 WORDS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('CHECK ANSWER'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pumpAndSettle();

    expect(
      submittedAnswer?['responseText'],
      'I would like to confirm the new schedule for our Tuesday meeting.',
    );
    expect(find.text('CORRECT'), findsOneWidget);
    expect(
      find.text('Word floor and required keywords satisfied.'),
      findsOneWidget,
    );
  });
}
