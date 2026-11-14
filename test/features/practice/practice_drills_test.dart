import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/practice_payloads.dart';

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
          return FakeHttpClientAdapter.jsonResponse(
            practiceCatalogResponse(
              code: 'IELTS',
              name: 'IELTS Academic & General',
              sectionNoun: 'Section',
              sections: [
                practiceSection(
                  sectionId: 11,
                  code: 'S1',
                  name: 'Academic Reading',
                  skillCode: 'READ',
                  skillName: 'Reading',
                  accuracyPercentage: 65,
                ),
              ],
            ),
          );
        }
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(
            sections: [
              practiceSection(
                sectionId: 5,
                code: 'P5',
                name: 'Incomplete Sentences',
                accuracyPercentage: 72,
                categoriesInCooldown: 1,
                nextReviewDueAt: '2026-11-13T18:00:00+00:00',
              ),
              practiceSection(
                sectionId: 8,
                code: 'S1',
                name: 'Read Aloud',
                modality: 'speaking',
                skillCode: 'SPEA',
                skillName: 'Speaking',
                availableQuestionCount: 0,
                expectedQuestionCount: 2,
              ),
            ],
            unfinishedSession: {
              'sessionId': 99,
              'sectionId': 2,
              'sectionCode': 'P2',
              'sectionName': 'Question-Response',
              'modality': 'listening',
              'questionCount': 10,
              'status': 'in_progress',
              'correctCount': 3,
              'questionSource': 'all',
              'startedAt': '2026-11-13T16:03:52+00:00',
              'finishedAt': null,
              'topicId': null,
              'cefrLevelCode': null,
              'isShort': false,
            },
          ),
        );
      }
      if (options.path == '/api/learner/practice/matrix' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse([
          practiceCell(
            topicId: 101,
            topicCode: 'R-TEN',
            topicName: 'Verb Tenses',
            levelCode: 'A2',
            mastery: 2,
          ),
          practiceCell(
            topicId: 101,
            topicCode: 'R-TEN',
            topicName: 'Verb Tenses',
            levelCode: 'B1',
            mastery: 1,
          ),
          practiceCell(
            topicId: 101,
            topicCode: 'R-TEN',
            topicName: 'Verb Tenses',
            levelCode: 'B2',
            mastery: 0,
          ),
        ]);
      }
      if (options.path == '/api/learner/practice/free-drill') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceFreeDrillResponse(),
        );
      }
      if (options.path == '/api/learner/practice/sessions' &&
          options.method == 'POST') {
        startedPayload = body as Map<String, dynamic>;
        return FakeHttpClientAdapter.jsonResponse(
          practiceSession(
            sessionId: 42,
            sectionId: 5,
            sectionCode: 'P5',
            sectionName: 'Incomplete Sentences',
            questionCount: 0,
          ),
        );
      }
      if (options.path == '/api/learner/practice/sessions/42/take' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceTakeResponse(
            session: practiceSession(
              sessionId: 42,
              sectionId: 5,
              sectionCode: 'P5',
              sectionName: 'Incomplete Sentences',
              questionCount: 0,
            ),
            questions: const [],
          ),
        );
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
    expect(find.textContaining('Question-Response'), findsOneWidget);
    expect(find.text('RESUME SESSION'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('P5 · Incomplete Sentences'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('P5 · Incomplete Sentences'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('1 RESTING'), findsOneWidget);
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

    // Scroll back up and start the Part 5 drill.
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-section-5')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('start-section-5')));
    await tester.pumpAndSettle();

    expect(startedPayload?['sectionId'], 5);
    // The start request names only what the backend reads: a question source
    // and a feedback mode are not fields on `StartPracticeRequest`.
    expect(startedPayload?.containsKey('questionSource'), isFalse);
    expect(startedPayload?.containsKey('feedbackMode'), isFalse);

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
    await tester.scrollUntilVisible(
      find.text('S1 · Academic Reading'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('S1 · Academic Reading'), findsOneWidget);
    expect(find.text('SECTION CATALOG'), findsOneWidget);
  });
}
