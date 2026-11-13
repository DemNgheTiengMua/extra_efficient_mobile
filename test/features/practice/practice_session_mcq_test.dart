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
      'Practice session player plays audio, requests hint, grades dynamic-option MCQ with rationale, and loads summary + AI insight',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final fakeAudio = FakeAudioMediaAdapter();
    bool hintRequested = false;
    bool insightRetried = false;
    final submittedAnswers = <int, Map<String, dynamic>>{};

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
          'examDate': null,
        });
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse({
          'sectionNoun': 'Part',
          'sections': [
            {
              'sectionId': 2,
              'title': 'Part 2: Question-Response',
              'skill': 'listening',
              'accuracyPercent': 68,
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
          'sessionId': 77,
          'title': 'Part 2: Question-Response',
        });
      }
      if (options.path == '/api/learner/practice/sessions/77/take' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 77,
          'title': 'Part 2: Question-Response',
          'feedbackMode': 'immediate',
          'questions': [
            {
              'questionId': 501,
              'displayOrder': 1,
              'questionType': 'mcq',
              'stem': 'Where did you put the quarterly report?',
              'audioUrl': 'https://cdn.local/part2-q1.mp3',
              'clipStartMs': 1000,
              'clipEndMs': 8000,
              'options': [
                {'optionId': 5001, 'label': 'A', 'text': 'On your desk yesterday.'},
                {'optionId': 5002, 'label': 'B', 'text': 'Tomorrow afternoon.'},
                {'optionId': 5003, 'label': 'C', 'text': 'Yes, I reported it.'},
              ],
            },
            {
              'questionId': 502,
              'displayOrder': 2,
              'questionType': 'mcq',
              'stem': 'The shipment ____ before noon.',
              'options': [
                {'optionId': 6001, 'label': 'A', 'text': 'arrived'},
                {'optionId': 6002, 'label': 'B', 'text': 'arriving'},
                {'optionId': 6003, 'label': 'C', 'text': 'to arrive'},
                {'optionId': 6004, 'label': 'D', 'text': 'arrival'},
              ],
            },
          ],
        });
      }
      if (options.path ==
              '/api/learner/practice/sessions/77/questions/501/hint' &&
          options.method == 'POST') {
        hintRequested = true;
        return FakeHttpClientAdapter.jsonResponse({
          'hint': 'Listen for a location phrase.',
        });
      }
      if (options.path ==
              '/api/learner/practice/sessions/77/questions/501/answer' &&
          options.method == 'POST') {
        submittedAnswers[501] = body as Map<String, dynamic>;
        return FakeHttpClientAdapter.jsonResponse({
          'isCorrect': false,
          'correctOptionId': 5001,
          'generalExplanation': 'Where-questions expect a place.',
          'selectedOptionRationale': 'Option B answers a when-question.',
        });
      }
      if (options.path ==
              '/api/learner/practice/sessions/77/questions/502/answer' &&
          options.method == 'POST') {
        submittedAnswers[502] = body as Map<String, dynamic>;
        return FakeHttpClientAdapter.jsonResponse({
          'isCorrect': true,
          'correctOptionId': 6001,
          'generalExplanation': 'Past simple verb fits the main clause.',
        });
      }
      if (options.path == '/api/learner/practice/sessions/77/summary' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 77,
          'title': 'Part 2: Question-Response',
          'correctCount': 1,
          'totalCount': 2,
          'accuracyPercent': 50,
          'items': [
            {
              'questionId': 501,
              'stem': 'Where did you put the quarterly report?',
              'isCorrect': false,
              'generalExplanation': 'Where-questions expect a place.',
            },
            {
              'questionId': 502,
              'stem': 'The shipment ____ before noon.',
              'isCorrect': true,
              'generalExplanation': 'Past simple verb fits the main clause.',
            },
          ],
        });
      }
      if (options.path == '/api/learner/insights/practice/77' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'status': insightRetried ? 'ready' : 'failed',
          'narrative': insightRetried ? 'Focus on Wh-question cues.' : null,
          'errorMessage': insightRetried ? null : 'Temporary AI timeout.',
        });
      }
      if (options.path == '/api/learner/insights/practice/77/retry' &&
          options.method == 'POST') {
        insightRetried = true;
        return FakeHttpClientAdapter.jsonResponse({
          'status': 'ready',
          'narrative': 'Focus on Wh-question cues.',
        });
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(fakeAudio),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-section-2')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('start-section-2')));
    await tester.pumpAndSettle();

    // Q1: 3 options, audio, hint
    expect(find.text('Where did you put the quarterly report?'), findsOneWidget);
    expect(find.text('A. On your desk yesterday.'), findsOneWidget);
    expect(find.text('B. Tomorrow afternoon.'), findsOneWidget);
    expect(find.text('C. Yes, I reported it.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('practice-play-audio')));
    await tester.pumpAndSettle();
    expect(fakeAudio.lastLoadedUrl, 'https://cdn.local/part2-q1.mp3');
    expect(fakeAudio.isPlaying, isTrue);

    await tester.tap(find.text('REQUEST HINT'));
    await tester.pumpAndSettle();
    expect(hintRequested, isTrue);
    expect(find.text('Listen for a location phrase.'), findsOneWidget);

    await tester.tap(find.text('B. Tomorrow afternoon.'));
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

    expect(submittedAnswers[501]?['selectedOptionId'], 5002);
    expect(find.text('INCORRECT'), findsOneWidget);
    expect(find.text('Where-questions expect a place.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Option B answers a when-question.'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Option B answers a when-question.'), findsOneWidget);

    // Advance to Q2 (4 options)
    await tester.scrollUntilVisible(
      find.text('NEXT QUESTION'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('NEXT QUESTION'));
    await tester.pumpAndSettle();
    expect(find.text('D. arrival'), findsOneWidget);

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
    expect(submittedAnswers[502]?['selectedOptionId'], 6001);

    // View Summary + AI Insight + Retry
    await tester.scrollUntilVisible(
      find.text('VIEW SUMMARY'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('VIEW SUMMARY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEW SUMMARY'));
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1/2 CORRECT'), findsOneWidget);
    expect(find.text('RETRY INSIGHT'), findsOneWidget);

    await tester.tap(find.text('RETRY INSIGHT'));
    await tester.pumpAndSettle();
    expect(insightRetried, isTrue);
    expect(find.text('Focus on Wh-question cues.'), findsOneWidget);
  });
}
