import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  Map<String, dynamic> authMePayload() => {
        'userId': 2,
        'email': 'learner@demo.local',
        'fullName': 'Demo Learner',
        'role': 'learner',
        'emailVerified': true,
        'permissions': [],
        'held': [],
      };

  Map<String, dynamic> contextPayload({int creditBalance = 10}) => {
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
        'creditBalance': creditBalance,
        'examinedSkills': ['listening', 'reading'],
        'examDate': null,
      };

  testWidgets(
      'free first placement shows FREE badge, runs audio/mic preflight, and starts attempt',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final audioAdapter = FakeAudioMediaAdapter();
    Map<String, dynamic>? startPayload;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse(authMePayload());
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextPayload(creditBalance: 0));
      }
      if (options.path == '/api/learner/placement' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'examId': 101,
          'examTitle': 'TOEIC Diagnostic Placement',
          'certificateCode': 'TOEIC',
          'isFirstPlacement': true,
          'creditBalance': 0,
          'scopes': [
            {'scope': 'all_skills', 'label': 'All 4 Skills', 'credits': 5},
            {
              'scope': 'listening_and_reading',
              'label': 'Listening & Reading',
              'credits': 3,
            },
          ],
        });
      }
      if (options.path == '/api/learner/placement/preflight' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'audioSampleUrl': 'https://cdn.example.com/preflight.mp3',
          'requiresMicrophone': true,
          'reusableSkills': [
            {
              'skill': 'reading',
              'band': 'B1',
              'expiresAt': '2026-12-01T00:00:00Z',
              'canReuse': true,
            },
          ],
        });
      }
      if (options.path == '/api/learner/placement/start' &&
          options.method == 'POST') {
        startPayload = body as Map<String, dynamic>?;
        return FakeHttpClientAdapter.jsonResponse({
          'placementId': 555,
        });
      }
      if (options.path == '/api/learner/placement/take/555' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'placementId': 555,
          'expiresAt':
              DateTime.now().toUtc().add(const Duration(minutes: 20)).toIso8601String(),
          'questions': [
            {
              'questionId': 1,
              'index': 0,
              'skill': 'listening',
              'sectionName': 'Part 1',
              'prompt': 'Look at the picture.',
              'options': [
                {'optionId': 11, 'label': 'A', 'text': 'Option A'},
                {'optionId': 12, 'label': 'B', 'text': 'Option B'},
              ],
              'isFlagged': false,
            },
          ],
        });
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(audioAdapter),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to EXAMS tab
    await tester.tap(find.text('EXAMS'));
    await tester.pumpAndSettle();

    expect(find.text('PLACEMENT ASSESSMENT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-placement-btn')));
    await tester.pumpAndSettle();

    expect(find.text('FREE FIRST PLACEMENT'), findsOneWidget);
    expect(find.text('TOEIC Diagnostic Placement'), findsOneWidget);

    // Run audio check
    await tester.scrollUntilVisible(
      find.byKey(const Key('preflight-audio-check-btn')),
      200,
    );
    await tester.tap(find.byKey(const Key('preflight-audio-check-btn')));
    await tester.pumpAndSettle();
    expect(audioAdapter.lastLoadedUrl, 'https://cdn.example.com/preflight.mp3');

    // Run microphone check
    await tester.scrollUntilVisible(
      find.byKey(const Key('preflight-mic-check-btn')),
      200,
    );
    await tester.tap(find.byKey(const Key('preflight-mic-check-btn')));
    await tester.pumpAndSettle();

    // Start placement
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-placement-btn')),
      200,
    );
    await tester.tap(find.byKey(const Key('start-placement-btn')));
    await tester.pumpAndSettle();

    expect(startPayload, isNotNull);
    expect(startPayload!['examId'], 101);
    expect(startPayload!['scope'], 'all_skills');
    expect(find.byKey(const Key('exam-room-header')), findsOneWidget);
  });

  testWidgets(
      'paid retake allows choosing listening_and_reading (3 Credits) and reuseValidSkills',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final audioAdapter = FakeAudioMediaAdapter();
    Map<String, dynamic>? startPayload;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse(authMePayload());
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextPayload(creditBalance: 13));
      }
      if (options.path == '/api/learner/placement' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'examId': 101,
          'examTitle': 'TOEIC Diagnostic Placement',
          'certificateCode': 'TOEIC',
          'isFirstPlacement': false,
          'creditBalance': 13,
          'scopes': [
            {'scope': 'all_skills', 'label': 'All 4 Skills', 'credits': 5},
            {
              'scope': 'listening_and_reading',
              'label': 'Listening & Reading',
              'credits': 3,
            },
          ],
        });
      }
      if (options.path == '/api/learner/placement/preflight' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'audioSampleUrl': 'https://cdn.example.com/preflight.mp3',
          'requiresMicrophone': false,
          'reusableSkills': [
            {
              'skill': 'speaking',
              'band': 'B2',
              'expiresAt': '2026-12-01T00:00:00Z',
              'canReuse': true,
            },
          ],
        });
      }
      if (options.path == '/api/learner/placement/start' &&
          options.method == 'POST') {
        startPayload = body as Map<String, dynamic>?;
        return FakeHttpClientAdapter.jsonResponse({'placementId': 777});
      }
      if (options.path == '/api/learner/placement/take/777' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'placementId': 777,
          'expiresAt':
              DateTime.now().toUtc().add(const Duration(minutes: 20)).toIso8601String(),
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
          audioMediaAdapterProvider.overrideWithValue(audioAdapter),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('EXAMS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-placement-btn')));
    await tester.pumpAndSettle();

    expect(find.text('PAID RETAKE'), findsOneWidget);
    expect(find.textContaining('5 CREDITS'), findsWidgets);
    expect(find.textContaining('3 CREDITS'), findsWidgets);

    // Select listening_and_reading scope
    await tester.scrollUntilVisible(
      find.byKey(const Key('scope-option-listening_and_reading')),
      200,
    );
    await tester.tap(find.byKey(const Key('scope-option-listening_and_reading')));
    await tester.pumpAndSettle();

    // Toggle reuseValidSkills
    await tester.scrollUntilVisible(
      find.byKey(const Key('reuse-skills-toggle')),
      200,
    );
    await tester.tap(find.byKey(const Key('reuse-skills-toggle')));
    await tester.pumpAndSettle();

    // Run audio check
    await tester.scrollUntilVisible(
      find.byKey(const Key('preflight-audio-check-btn')),
      200,
    );
    await tester.tap(find.byKey(const Key('preflight-audio-check-btn')));
    await tester.pumpAndSettle();

    // Start placement
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-placement-btn')),
      200,
    );
    await tester.tap(find.byKey(const Key('start-placement-btn')));
    await tester.pumpAndSettle();

    expect(startPayload, isNotNull);
    expect(startPayload!['scope'], 'listening_and_reading');
    expect(startPayload!['reuseValidSkills'], true);
  });
}
