import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';

import '../../helpers/fake_http_adapter.dart';
import 'path_fixtures.dart';

void main() {
  testWidgets(
    'Lesson Player resumes from last viewed card, plays audio, enforces micro_check gate, and completes lesson',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      final fakeAudio = FakeAudioMediaAdapter();
      final viewedCardIds = <int>[];
      final microCheckSubmissions = <String>[];

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
          });
        }
        if (options.path == '/api/learner/dashboard') {
          // The PATH tab needs a real envelope; only the action button matters
          // here, and it navigates to the server's actionUrl.
          return FakeHttpClientAdapter.jsonResponse({
            ...dashboardMeasuredPayload(),
            'nextAction': {
              'eyebrow': 'PICK UP YOUR PLAN',
              'title': 'Subject-Verb Agreement',
              'description': 'Resume lesson',
              'actionLabel': 'Open this step',
              'actionUrl': '/path/lessons/14',
              'severity': 'info',
              'cascadeStep': 'next_step',
              'metaLabel': 'WEEK 1',
            },
          });
        }
        if (options.path == '/api/learner/insights/dashboard') {
          return FakeHttpClientAdapter.jsonResponse(
            dashboardInsightPendingPayload(),
          );
        }
        if (options.path == '/api/learner/lessons/14' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'id': 14,
            'title': 'Subject-Verb Agreement',
            'cards': [
              {
                'id': 201,
                'type': 'rule',
                'title': 'Core Rule',
                'body': 'Singular subjects take singular verbs.',
                'audioUrl': 'https://cdn.example.com/audio/201.mp3',
              },
              {
                'id': 202,
                'type': 'pitfall',
                'title': 'Prepositional Phrases',
                'body': 'Ignore phrases between subject and verb.',
              },
              {
                'id': 203,
                'type': 'micro_check',
                'title': 'Quick Check',
                'question': 'The list of items ___ on the desk.',
                'options': ['is', 'are'],
              },
              {
                'id': 204,
                'type': 'example',
                'title': 'Applied Example',
                'body': 'The box of chocolates is empty.',
              },
            ],
          });
        }
        if (options.path == '/api/learner/lessons/14/progress' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'viewedCount': 1,
            'totalCount': 4,
            'lastViewedCardIndex': 1,
            'completed': false,
          });
        }
        if (options.path.startsWith('/api/learner/lessons/14/cards/') &&
            options.path.endsWith('/view') &&
            options.method == 'POST') {
          final segments = options.path.split('/');
          final cardId = int.parse(segments[segments.length - 2]);
          viewedCardIds.add(cardId);
          return FakeHttpClientAdapter.jsonResponse({
            'viewedCount': viewedCardIds.length + 1,
            'totalCount': 4,
          });
        }
        if (options.path == '/api/learner/lessons/14/cards/203/micro-check' &&
            options.method == 'POST') {
          final selected = (body as Map)['selectedOption'] as String;
          microCheckSubmissions.add(selected);
          final isCorrect = selected == 'is';
          return FakeHttpClientAdapter.jsonResponse({
            'correct': isCorrect,
            'explanation': isCorrect
                ? 'Correct! "list" is singular.'
                : 'The subject is "list" (singular).',
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

      await tester.tap(find.byKey(const Key('next-action-btn')));
      await tester.pumpAndSettle();

      // Resumes at card index 1 -> "2 OF 4".
      expect(find.text('2 OF 4'), findsOneWidget);
      expect(find.text('PREPOSITIONAL PHRASES'), findsOneWidget);

      // Go back to card 1 and play audio.
      await tester.tap(find.byKey(const Key('lesson-prev-btn')));
      await tester.pumpAndSettle();
      expect(find.text('1 OF 4'), findsOneWidget);
      expect(find.text('CORE RULE'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lesson-audio-btn')));
      await tester.pumpAndSettle();
      expect(fakeAudio.lastLoadedUrl, 'https://cdn.example.com/audio/201.mp3');
      expect(fakeAudio.isPlaying, isTrue);

      // Advance to card 2, then card 3 (micro_check).
      await tester.tap(find.byKey(const Key('lesson-next-btn')));
      await tester.pumpAndSettle();
      expect(find.text('2 OF 4'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lesson-next-btn')));
      await tester.pumpAndSettle();
      expect(viewedCardIds, contains(202));
      expect(find.text('3 OF 4'), findsOneWidget);
      expect(find.text('The list of items ___ on the desk.'), findsOneWidget);

      // Tapping NEXT before answering micro_check should keep us on 3 OF 4.
      await tester.tap(find.byKey(const Key('lesson-next-btn')));
      await tester.pumpAndSettle();
      expect(find.text('3 OF 4'), findsOneWidget);

      // Submit wrong answer 'are'.
      await tester.tap(find.byKey(const Key('micro-option-are')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('micro-check-submit-btn')));
      await tester.pumpAndSettle();
      expect(microCheckSubmissions, ['are']);
      expect(find.text('The subject is "list" (singular).'), findsOneWidget);
      expect(find.text('3 OF 4'), findsOneWidget);

      // Submit right answer 'is'.
      await tester.tap(find.byKey(const Key('micro-option-is')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('micro-check-submit-btn')));
      await tester.pumpAndSettle();
      expect(microCheckSubmissions, ['are', 'is']);
      expect(find.text('Correct! "list" is singular.'), findsOneWidget);

      // Now NEXT advances to 4 OF 4.
      await tester.tap(find.byKey(const Key('lesson-next-btn')));
      await tester.pumpAndSettle();
      expect(find.text('4 OF 4'), findsOneWidget);
      expect(find.text('APPLIED EXAMPLE'), findsOneWidget);

      // Complete lesson.
      await tester.tap(find.byKey(const Key('lesson-complete-btn')));
      await tester.pumpAndSettle();
      expect(viewedCardIds, contains(204));
      expect(find.text('LESSON COMPLETED'), findsOneWidget);
    },
  );
}
