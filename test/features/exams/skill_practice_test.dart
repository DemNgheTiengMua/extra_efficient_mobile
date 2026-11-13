import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/screens/skill_practice_catalog_screen.dart';
import 'package:extra_efficient_mobile/features/exams/screens/skill_practice_result_screen.dart';
import 'package:extra_efficient_mobile/features/exams/screens/skill_practice_room_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  Widget buildTestApp({
    required FakeHttpClientAdapter adapter,
    required FakeAudioMediaAdapter audioAdapter,
    String initialLocation = '/practice/skill-practice',
  }) {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/practice/skill-practice',
          builder: (context, state) => const SkillPracticeCatalogScreen(),
        ),
        GoRoute(
          path: '/practice/skill-practice/:skill/attempts/:attemptId',
          builder: (context, state) {
            final skill = state.pathParameters['skill'] ?? 'speaking';
            final id = int.parse(state.pathParameters['attemptId'] ?? '0');
            return SkillPracticeRoomScreen(skill: skill, attemptId: id);
          },
        ),
        GoRoute(
          path: '/practice/skill-practice/:skill/attempts/:attemptId/result',
          builder: (context, state) {
            final skill = state.pathParameters['skill'] ?? 'speaking';
            final id = int.parse(state.pathParameters['attemptId'] ?? '0');
            return SkillPracticeResultScreen(skill: skill, attemptId: id);
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        httpClientAdapterProvider.overrideWithValue(adapter),
        audioMediaAdapterProvider.overrideWithValue(audioAdapter),
      ],
      child: MaterialApp.router(
        theme: ThemeData(
          useMaterial3: false,
          scaffoldBackgroundColor: SignageColors.wall,
        ),
        builder: (context, child) => FTheme(
          data: buildSignageTheme(),
          child: child ?? const SizedBox.shrink(),
        ),
        routerConfig: router,
      ),
    );
  }

  testWidgets(
      'Speaking skill practice records audio, uploads multipart, submits, polls pending, retries failed grading, and shows rubric review',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    bool instructionsFetched = false;
    bool attemptStarted = false;
    bool uploadedAudio = false;
    bool submitted = false;
    bool retried = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/skill-practice/speaking':
          return FakeHttpClientAdapter.jsonResponse({
            'exams': [
              {
                'examId': 201,
                'title': 'Speaking Part 2 Photo',
                'credits': 1,
                'questionCount': 1,
              },
            ],
          });
        case 'GET /api/learner/skill-practice/writing':
          return FakeHttpClientAdapter.jsonResponse({
            'exams': [
              {
                'examId': 301,
                'title': 'Writing Task 2 Essay',
                'credits': 1,
                'questionCount': 1,
              },
            ],
          });
        case 'GET /api/learner/speaking/201/instructions':
          instructionsFetched = true;
          return FakeHttpClientAdapter.jsonResponse({
            'examId': 201,
            'examName': 'Speaking Part 2 Photo',
            'description': 'Speak clearly for each prompt after preparation.',
            'durationMinutes': 10,
            'questionCount': 1,
            'creditCost': 1,
            'creditBalance': 5,
          });
        case 'POST /api/learner/speaking/201/start':
          attemptStarted = true;
          return FakeHttpClientAdapter.jsonResponse({'attemptId': 401});
        case 'GET /api/learner/speaking/attempts/401':
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 401,
            'examTitle': 'Speaking Part 2 Photo',
            'questions': [
              {
                'questionId': 1,
                'index': 0,
                'skill': 'speaking',
                'prompt': 'Describe the workspace in the picture.',
                'prepSeconds': 15,
                'responseSeconds': 45,
              },
              {
                'questionId': 2,
                'index': 1,
                'skill': 'speaking',
                'prompt': 'What would you improve in this workspace?',
                'prepSeconds': 10,
                'responseSeconds': 30,
              },
            ],
          });
        case 'POST /api/learner/speaking/attempts/401/questions/1/audio':
          expect(options.data, isA<FormData>());
          final formData = options.data as FormData;
          expect(
            formData.files.any((entry) => entry.key == 'audioFile'),
            isTrue,
          );
          expect(
            formData.fields.any(
              (entry) =>
                  entry.key == 'durationMs' &&
                  int.tryParse(entry.value) != null,
            ),
            isTrue,
          );
          uploadedAudio = true;
          return FakeHttpClientAdapter.jsonResponse({'uploaded': true});
        case 'POST /api/learner/speaking/attempts/401/submit':
          submitted = true;
          return FakeHttpClientAdapter.jsonResponse({'submitted': true});
        case 'GET /api/learner/speaking/attempts/401/pending':
          return FakeHttpClientAdapter.jsonResponse({
            'status': retried ? 'COMPLETED' : 'FAILED',
            'errorMessage': retried ? null : 'AI grading timeout',
          });
        case 'POST /api/learner/speaking/attempts/401/retry':
          retried = true;
          return FakeHttpClientAdapter.jsonResponse({'status': 'PENDING'});
        case 'GET /api/learner/speaking/attempts/401/review':
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 401,
            'examTitle': 'Speaking Part 2 Photo',
            'estimatedBand': 'B2',
            'totalScore': 16,
            'maxScore': 20,
            'criteria': [
              {
                'name': 'Pronunciation',
                'score': 8,
                'maxScore': 10,
                'comment': 'Clear articulation and steady pacing.',
              },
              {
                'name': 'Fluency',
                'score': 8,
                'maxScore': 10,
                'comment': 'Minimal hesitation.',
              },
            ],
          });
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(buildTestApp(adapter: adapter, audioAdapter: audio));
    await tester.pumpAndSettle();

    expect(find.text('Speaking Part 2 Photo'), findsOneWidget);
    expect(find.text('Writing Task 2 Essay'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-speaking-201')));
    await tester.pumpAndSettle();

    expect(instructionsFetched, isTrue);
    expect(attemptStarted, isFalse);
    expect(
      find.text('Speak clearly for each prompt after preparation.'),
      findsOneWidget,
    );

    // Mic check required before starting speaking practice
    await tester.tap(find.byKey(const Key('skill-mic-check-btn')));
    await tester.pumpAndSettle();
    expect(find.text('MIC READY'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-start-speaking-201')));
    await tester.pumpAndSettle();
    expect(attemptStarted, isTrue);

    expect(
      find.text('Describe the workspace in the picture.'),
      findsOneWidget,
    );
    expect(find.text('Q1/2'), findsOneWidget);
    expect(find.byKey(const Key('skill-prep-timer')), findsOneWidget);
    expect(find.text('00:15'), findsOneWidget);
    expect(find.byKey(const Key('skill-response-timer')), findsOneWidget);
    expect(find.text('00:45'), findsOneWidget);

    // Record and stop -> multipart upload
    await tester.tap(find.byKey(const Key('skill-record-btn')));
    await tester.pumpAndSettle();
    expect(audio.isRecording, isTrue);

    await tester.tap(find.byKey(const Key('skill-record-btn')));
    await tester.pumpAndSettle();
    expect(audio.isRecording, isFalse);
    expect(uploadedAudio, isTrue);

    // Navigate to Q2
    await tester.tap(find.byKey(const Key('skill-next-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Q2/2'), findsOneWidget);
    expect(
      find.text('What would you improve in this workspace?'),
      findsOneWidget,
    );
    expect(find.text('00:10'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);

    // Submit
    await tester.tap(find.byKey(const Key('skill-submit-btn')));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);

    // Failed grading -> retry -> rubric review
    expect(find.byKey(const Key('skill-retry-grading-btn')), findsOneWidget);
    await tester.tap(find.byKey(const Key('skill-retry-grading-btn')));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(retried, isTrue);
    expect(find.text('PRONUNCIATION'), findsOneWidget);
    expect(
      find.text('Clear articulation and steady pacing.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Writing skill practice saves essay draft, submits, polls pending, and renders rubric review',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    String? savedDraft;
    bool submitted = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/writing/attempts/402':
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 402,
            'examTitle': 'Writing Task 2 Essay',
            'questions': [
              {
                'questionId': 5,
                'index': 0,
                'skill': 'writing',
                'prompt': 'Should cities subsidize public transit?',
                'wordFloor': 100,
              },
            ],
          });
        case 'POST /api/learner/writing/attempts/402/draft':
          savedDraft = (body as Map<String, dynamic>)['responseText'] as String?;
          return FakeHttpClientAdapter.jsonResponse({'saved': true});
        case 'POST /api/learner/writing/attempts/402/submit':
          submitted = true;
          return FakeHttpClientAdapter.jsonResponse({'submitted': true});
        case 'GET /api/learner/writing/attempts/402/pending':
          return FakeHttpClientAdapter.jsonResponse({'status': 'COMPLETED'});
        case 'GET /api/learner/writing/attempts/402/review':
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 402,
            'examTitle': 'Writing Task 2 Essay',
            'estimatedBand': 'B2',
            'totalScore': 17,
            'maxScore': 20,
            'criteria': [
              {
                'name': 'Task Response',
                'score': 9,
                'maxScore': 10,
                'comment': 'Well-supported argument with clear examples.',
              },
            ],
          });
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(
      buildTestApp(
        adapter: adapter,
        audioAdapter: audio,
        initialLocation: '/practice/skill-practice/writing/attempts/402',
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('skill-writing-input')),
      'Public transit reduces urban congestion and emissions.',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      savedDraft,
      'Public transit reduces urban congestion and emissions.',
    );

    await tester.tap(find.byKey(const Key('skill-submit-btn')));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);

    expect(find.text('TASK RESPONSE'), findsOneWidget);
    expect(
      find.text('Well-supported argument with clear examples.'),
      findsOneWidget,
    );
  });
}
