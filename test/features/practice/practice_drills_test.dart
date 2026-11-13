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
      'PRACTICE Drills tab renders catalog, matrix, config controls, speaking link, and refreshes on certificate switch',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    var activeCode = 'TOEIC';
    int catalogCalls = 0;
    Map<String, dynamic>? startedPayload;

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
      if (options.path == '/api/learner/context' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'active': {
            'code': activeCode,
            'name': activeCode == 'IELTS'
                ? 'IELTS Academic & General'
                : 'TOEIC Listening & Reading',
            'sectionNoun': activeCode == 'IELTS' ? 'Section' : 'Part',
          },
          'certificates': [
            {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            {
              'code': 'IELTS',
              'name': 'IELTS Academic & General',
              'sectionNoun': 'Section',
            },
          ],
          'creditBalance': 13,
          'examinedSkills': ['listening', 'reading'],
          'examDate': null,
        });
      }
      if (options.path == '/api/learner/active-certificate' &&
          options.method == 'PUT') {
        activeCode = (body as Map<String, dynamic>)['code'] as String;
        return FakeHttpClientAdapter.jsonResponse(null, statusCode: 204);
      }
      if (options.path == '/api/learner/practice/catalog' &&
          options.method == 'GET') {
        catalogCalls++;
        if (activeCode == 'IELTS') {
          return FakeHttpClientAdapter.jsonResponse({
            'sectionNoun': 'Section',
            'unfinishedSession': null,
            'sections': [
              {
                'sectionId': 11,
                'title': 'Section 1: Academic Reading',
                'skill': 'reading',
                'accuracyPercent': 65,
                'cooldownActive': false,
                'isSpeaking': false,
              },
            ],
          });
        }
        return FakeHttpClientAdapter.jsonResponse({
          'sectionNoun': 'Part',
          'unfinishedSession': {
            'sessionId': 99,
            'title': 'Part 2: Question-Response',
            'answeredCount': 3,
            'totalCount': 10,
          },
          'sections': [
            {
              'sectionId': 5,
              'title': 'Part 5: Incomplete Sentences',
              'skill': 'reading',
              'accuracyPercent': 72,
              'cooldownActive': true,
              'cooldownRemainingSeconds': 180,
              'isSpeaking': false,
            },
            {
              'sectionId': 8,
              'title': 'Part 8: Read Aloud',
              'skill': 'speaking',
              'accuracyPercent': 55,
              'cooldownActive': false,
              'isSpeaking': true,
            },
          ],
        });
      }
      if (options.path == '/api/learner/practice/matrix' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'levels': ['A2', 'B1', 'B2'],
          'topics': [
            {
              'topicId': 101,
              'name': 'Verb Tenses',
              'cells': [
                {'cefrLevelCode': 'A2', 'questionCount': 12, 'accuracyPercent': 80},
                {'cefrLevelCode': 'B1', 'questionCount': 8, 'accuracyPercent': 50},
                {'cefrLevelCode': 'B2', 'questionCount': 0, 'accuracyPercent': null},
              ],
            },
          ],
        });
      }
      if (options.path == '/api/learner/practice/sessions' &&
          options.method == 'POST') {
        startedPayload = body as Map<String, dynamic>;
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 42,
          'title': 'Part 5: Incomplete Sentences',
          'feedbackMode': startedPayload?['feedbackMode'] ?? 'immediate',
        });
      }
      if (options.path == '/api/learner/practice/sessions/42/take' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 42,
          'title': 'Part 5: Incomplete Sentences',
          'feedbackMode': 'end',
          'questions': [],
        });
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

    // Navigate to PRACTICE tab.
    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();

    expect(catalogCalls, 1);
    expect(find.textContaining('Part 2: Question-Response'), findsOneWidget);
    expect(find.text('RESUME SESSION'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Part 5: Incomplete Sentences'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Part 5: Incomplete Sentences'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('COOLDOWN'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SPEAKING ATTEMPT'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('SPEAKING ATTEMPT'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Verb Tenses'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Verb Tenses'), findsOneWidget);

    // Scroll back up to select WRONG ONLY and END OF SESSION, then start Part 5 drill.
    await tester.scrollUntilVisible(
      find.text('WRONG ONLY'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('WRONG ONLY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('END OF SESSION'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-section-5')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('start-section-5')));
    await tester.pumpAndSettle();

    expect(startedPayload?['sectionId'], 5);
    expect(startedPayload?['questionSource'], 'wrong');
    expect(startedPayload?['feedbackMode'], 'end');

    // Navigate back to PRACTICE and switch certificate in ACCOUNT.
    await tester.tap(find.byKey(const Key('session-back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACCOUNT'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cert-option-IELTS')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();

    expect(catalogCalls, greaterThanOrEqualTo(2));
    expect(find.text('Section 1: Academic Reading'), findsOneWidget);
  });
}
