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
    'PATH dashboard renders nextAction, bands, skill measurements, resume cards, and retries AI insight',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      var insightRetryCount = 0;

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
        if (options.path == '/api/learner/dashboard' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'currentBandCode': 'B1',
            'targetBandCode': 'B2',
            'scaledScore': 620,
            'placementCompleted': true,
            'hasLearningPath': true,
            'nextAction': {
              'type': 'lesson',
              'title': 'Complete Clause Modifiers Lesson',
              'description': 'Finish cards 3 of 8 to unlock Part 5 drill.',
              'actionLabel': 'OPEN LESSON',
              'lessonId': 14,
            },
            'skillMeasurements': [
              {
                'skill': 'listening',
                'status': 'measured',
                'bandCode': 'B1',
                'scaledScore': 320,
              },
              {
                'skill': 'reading',
                'status': 'stale',
                'bandCode': 'A2',
                'scaledScore': 300,
              },
            ],
            'unfinishedAttempt': {
              'attemptId': 42,
              'title': 'Mock Attempt #42',
              'purpose': 'mock',
              'remainingMinutes': 45,
            },
            'unfinishedPractice': {
              'sessionId': 19,
              'title': 'Part 5 Grammar Drill',
              'answeredCount': 4,
              'totalCount': 10,
            },
          });
        }
        if (options.path == '/api/learner/insights/dashboard' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'status': 'ready',
            'narrative': 'Focus on Part 5 verb tense agreement to reach B2.',
          });
        }
        if (options.path == '/api/learner/insights/dashboard/retry' &&
            options.method == 'POST') {
          insightRetryCount++;
          return FakeHttpClientAdapter.jsonResponse({
            'status': 'ready',
            'narrative': 'Updated insight: Reading speed improved by 12%.',
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

      expect(find.textContaining('TOEIC Listening & Reading'), findsOneWidget);
      expect(find.text('Complete Clause Modifiers Lesson'), findsOneWidget);
      expect(find.text('620'), findsOneWidget);
      expect(find.textContaining('TARGET B2'), findsOneWidget);
      expect(find.text('LISTENING'), findsOneWidget);
      expect(find.text('READING'), findsOneWidget);
      expect(find.text('Mock Attempt #42'), findsOneWidget);
      expect(find.text('Part 5 Grammar Drill'), findsOneWidget);
      final retryBtn = find.byKey(const Key('retry-dashboard-insight-btn'));
      await tester.scrollUntilVisible(retryBtn, 300);
      await tester.drag(find.byType(ListView), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(
        find.text('Focus on Part 5 verb tense agreement to reach B2.'),
        findsOneWidget,
      );

      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(insightRetryCount, 1);
      expect(
        find.text('Updated insight: Reading speed improved by 12%.'),
        findsOneWidget,
      );
    },
  );
}
