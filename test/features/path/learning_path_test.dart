import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/path/screens/learning_path_screen.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  testWidgets(
    'Learning Path generates path, displays modules & sequential items, retries path insight, starts lesson step, and resets path',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      var hasPath = false;
      var generateCalled = 0;
      var resetCalled = 0;
      var stepStartedId = 0;
      var pathInsightRetried = 0;

      final adapter = FakeHttpClientAdapter((options, body) async {
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
              'id': 1,
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'certificates': [
              {
                'id': 1,
                'code': 'TOEIC',
                'name': 'TOEIC Listening & Reading',
                'sectionNoun': 'Part',
              },
            ],
            'creditBalance': 13,
            'examinedSkills': ['listening', 'reading'],
            'examDate': '2026-12-20',
          });
        }
        if (options.path == '/api/learner/dashboard') {
          return FakeHttpClientAdapter.jsonResponse({
            'certificate': {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'nextAction': {
              'eyebrow': 'NEXT ON YOUR PATH',
              'title': 'Open this step',
              'description': 'Week 1 of your path is still open.',
              'actionLabel': 'Open this step',
              'actionUrl': '/path/learning-path',
              'severity': 'info',
              'cascadeStep': 'next_step',
              'metaLabel': 'WEEK 1',
            },
            'goal': {
              'currentBandCode': 'below_A1',
              'currentBandName': 'Below A1',
              'currentScore': 10,
              'currentSource': 'mock',
              'targetBandCode': 'B1',
              'targetBandName': 'Intermediate',
              'completedPathSteps': 0,
              'totalPathSteps': 0,
              'scoreDisplayFactor': 1,
              'hasNoMeasurement': false,
            },
            'skills': <Map<String, dynamic>>[],
            'attemptCount': 1,
            'practiceCount': 0,
          });
        }
        if (options.path == '/api/learner/insights/dashboard') {
          return FakeHttpClientAdapter.jsonResponse({
            'status': 'done',
            'formattedNarrative': 'Steady progress.',
          });
        }
        if (options.path == '/api/learner/learning-path' &&
            options.method == 'GET') {
          if (!hasPath) {
            return FakeHttpClientAdapter.jsonResponse({
              'message': 'No learning path yet',
            }, statusCode: 404);
          }
          return FakeHttpClientAdapter.jsonResponse({
            'currentBandCode': 'B1',
            'targetBandCode': 'B2',
            'remainingMinutes': 180,
            'modules': [
              {
                'id': 10,
                'weekNumber': 1,
                'title': 'Week 1: Grammar Fundamentals',
                'estimatedMinutes': 180,
                'items': [
                  {
                    'stepId': 101,
                    'title': 'Clause Modifiers',
                    'type': 'lesson',
                    'status': 'available',
                    'estimatedMinutes': 20,
                    'lessonId': 14,
                  },
                  {
                    'stepId': 102,
                    'title': 'Part 5 Timed Drill',
                    'type': 'practice',
                    'status': 'locked',
                    'estimatedMinutes': 30,
                  },
                ],
              },
            ],
          });
        }
        if (options.path == '/api/learner/learning-path/generate' &&
            options.method == 'POST') {
          generateCalled++;
          hasPath = true;
          return FakeHttpClientAdapter.jsonResponse({'generated': true});
        }
        if (options.path == '/api/learner/learning-path/reset' &&
            options.method == 'POST') {
          resetCalled++;
          hasPath = false;
          return FakeHttpClientAdapter.jsonResponse({'reset': true});
        }
        if (options.path == '/api/learner/learning-path/steps/101' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'stepId': 101,
            'title': 'Clause Modifiers',
            'type': 'lesson',
            'status': 'available',
            'lessonId': 14,
          });
        }
        if (options.path == '/api/learner/learning-path/steps/101/start' &&
            options.method == 'POST') {
          stepStartedId = 101;
          return FakeHttpClientAdapter.jsonResponse({
            'stepId': 101,
            'status': 'in_progress',
            'lessonId': 14,
          });
        }
        if (options.path == '/api/learner/insights/path' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(
            pathInsightRetried == 0
                // RETRY is offered only for a failed insight; the backend
                // rejects a retry for any other status.
                ? {'status': 'failed', 'failureReason': 'model timeout'}
                : {
                    'status': 'done',
                    'narrative': 'Refreshed path insight: 2 modules remaining.',
                    'formattedNarrative':
                        'Refreshed path insight: 2 modules remaining.',
                  },
          );
        }
        if (options.path == '/api/learner/insights/path/retry' &&
            options.method == 'POST') {
          pathInsightRetried++;
          // The real retry endpoint answers 204 and the app refetches.
          return FakeHttpClientAdapter.jsonResponse(null, statusCode: 204);
        }
        if (options.path == '/api/learner/lessons/14' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'id': 14,
            'title': 'Clause Modifiers',
            'cards': [
              {
                'id': 1,
                'type': 'rule',
                'title': 'Relative Clauses',
                'body': 'Use who/which/that to modify nouns.',
              },
            ],
          });
        }
        if (options.path == '/api/learner/lessons/14/progress' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'viewedCount': 0,
            'totalCount': 1,
            'lastViewedCardIndex': 0,
            'completed': false,
          });
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(tokenStorage),
            httpClientAdapterProvider.overrideWithValue(adapter),
            audioMediaAdapterProvider.overrideWithValue(
              FakeAudioMediaAdapter(),
            ),
          ],
          child: const ExtraEfficientApp(),
        ),
      );
      await tester.pumpAndSettle();

      final openPathBtn = find.byKey(const Key('open-learning-path-btn'));
      await tester.scrollUntilVisible(openPathBtn, 200);
      await tester.pumpAndSettle();
      await tester.tap(openPathBtn);
      await tester.pumpAndSettle();

      // Initially no path -> Generate button is shown.
      final genBtn = find.byKey(const Key('generate-learning-path-btn'));
      expect(genBtn, findsOneWidget);
      await tester.tap(genBtn);
      await tester.pumpAndSettle();

      expect(generateCalled, 1);
      expect(find.text('180 MIN REMAINING'), findsOneWidget);
      expect(find.text('WEEK 1: GRAMMAR FUNDAMENTALS'), findsOneWidget);
      expect(find.text('Clause Modifiers'), findsOneWidget);
      expect(find.text('Part 5 Timed Drill'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsOneWidget);
      expect(find.text('LOCKED'), findsWidgets);

      // Scroll to path insight & retry.
      final pathScrollable = find
          .descendant(
            of: find.byType(LearningPathScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final retryInsightBtn = find.byKey(const Key('retry-path-insight-btn'));
      await tester.scrollUntilVisible(
        retryInsightBtn,
        200,
        scrollable: pathScrollable,
      );
      await tester.drag(pathScrollable, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(retryInsightBtn);
      await tester.pumpAndSettle();

      expect(pathInsightRetried, 1);
      expect(
        find.text('Refreshed path insight: 2 modules remaining.'),
        findsOneWidget,
      );

      // Reset path test, then regenerate to test starting step.
      final resetBtn = find.byKey(const Key('reset-learning-path-btn'));
      await tester.scrollUntilVisible(
        resetBtn,
        -200,
        scrollable: pathScrollable,
      );
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();
      expect(resetCalled, 1);
      expect(
        find.byKey(const Key('generate-learning-path-btn')),
        findsOneWidget,
      );

      // Regenerate and start step 101.
      await tester.tap(find.byKey(const Key('generate-learning-path-btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start-step-101')));
      await tester.pumpAndSettle();
      expect(stepStartedId, 101);
    },
  );
}
