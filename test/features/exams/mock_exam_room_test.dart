import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/screens/mock_exam_room_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  Widget buildTestApp({
    required FakeHttpClientAdapter adapter,
    required FakeAudioMediaAdapter audioAdapter,
    int attemptId = 902,
  }) {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final router = GoRouter(
      initialLocation: '/exams/attempts/$attemptId',
      routes: [
        GoRoute(
          path: '/exams/attempts/:attemptId',
          builder: (context, state) => MockExamRoomScreen(
            attemptId: int.parse(state.pathParameters['attemptId'] ?? '902'),
          ),
        ),
        GoRoute(
          path: '/exams/attempts/:attemptId/result',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('MOCK RESULT #${state.pathParameters['attemptId']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/exams',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('EXAMS HUB')),
          ),
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

  Map<String, dynamic> mockSittingPayload() => {
        'attemptId': 902,
        'examTitle': 'TOEIC Full Mock #1',
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 45))
            .toIso8601String(),
        'status': 'in_progress',
        'questions': [
          {
            'questionId': 1,
            'index': 0,
            'skill': 'listening',
            'sectionName': 'Part 1',
            'prompt': 'Which statement describes the photo?',
            'audioUrl': 'https://cdn.example.com/mock-master.mp3',
            'audioStartMs': 5000,
            'audioEndMs': 18000,
            'options': [
              {'optionId': 11, 'label': 'A', 'text': 'They are boarding.'},
              {'optionId': 12, 'label': 'B', 'text': 'They are eating.'},
            ],
          },
          {
            'questionId': 2,
            'index': 1,
            'skill': 'writing',
            'sectionName': 'Essay',
            'prompt': 'Discuss remote work pros and cons.',
            'wordFloor': 50,
          },
        ],
      };

  testWidgets(
      'MockExamRoomScreen handles audio slice, debounced answer/draft autosave, navigator sheet, sync, and submit-with-drafts',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    final savedAnswers = <Map<String, dynamic>>[];
    final savedDrafts = <Map<String, dynamic>>[];
    bool synced = false;
    Map<String, dynamic>? submitPayload;

    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/attempts/902':
          return FakeHttpClientAdapter.jsonResponse(mockSittingPayload());
        case 'POST /api/learner/attempts/902/answers/1':
          savedAnswers.add(Map<String, dynamic>.from(body as Map));
          return FakeHttpClientAdapter.jsonResponse({'saved': true});
        case 'POST /api/learner/attempts/902/draft':
          savedDrafts.add(Map<String, dynamic>.from(body as Map));
          return FakeHttpClientAdapter.jsonResponse({'saved': true});
        case 'POST /api/learner/attempts/902/sync':
          synced = true;
          return FakeHttpClientAdapter.jsonResponse({'synced': true});
        case 'POST /api/learner/attempts/902/submit-with-drafts':
          submitPayload = Map<String, dynamic>.from(body as Map);
          return FakeHttpClientAdapter.jsonResponse({'submitted': true});
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(buildTestApp(adapter: adapter, audioAdapter: audio));
    await tester.pumpAndSettle();

    expect(audio.lastLoadedUrl, 'https://cdn.example.com/mock-master.mp3');
    expect(audio.lastClipStart, const Duration(milliseconds: 5000));
    expect(audio.lastClipEnd, const Duration(milliseconds: 18000));

    // Select MCQ option
    await tester.tap(find.byKey(const Key('option-11')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(savedAnswers, isNotEmpty);
    expect(savedAnswers.last['selectedOptionId'], 11);

    // Open AnswerNavigatorSheet and jump to Q2 (writing)
    await tester.tap(find.byKey(const Key('open-grid-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-cell-1')));
    await tester.pumpAndSettle();

    // Enter writing draft
    await tester.enterText(
      find.byKey(const Key('writing-draft-input')),
      'Remote work increases flexibility for teams.',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(savedDrafts, isNotEmpty);
    expect(savedDrafts.last['questionId'], 2);

    // Sync sitting
    await tester.tap(find.byKey(const Key('sync-sitting-btn')));
    await tester.pumpAndSettle();
    expect(synced, isTrue);

    // Submit with drafts
    await tester.tap(find.byKey(const Key('submit-exam-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-submit-btn')));
    await tester.pumpAndSettle();

    expect(submitPayload, isNotNull);
    expect(find.text('MOCK RESULT #902'), findsOneWidget);
  });

  testWidgets('MockExamRoomScreen cancels attempt and returns to /exams',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    bool cancelled = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/attempts/902':
          return FakeHttpClientAdapter.jsonResponse(mockSittingPayload());
        case 'POST /api/learner/attempts/902/cancel':
          cancelled = true;
          return FakeHttpClientAdapter.jsonResponse({'cancelled': true});
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(buildTestApp(adapter: adapter, audioAdapter: audio));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cancel-exam-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-btn')));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(find.text('EXAMS HUB'), findsOneWidget);
  });

  testWidgets(
      'MockExamRoomScreen supports skill/unit/group transitions, audio-review gate, and speaking audio upload',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    bool skillTransitioned = false;
    int? unitTransitioned;
    int? groupTransitioned;
    bool audioReviewStarted = false;
    bool speakingUploaded = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/attempts/902':
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 902,
            'examTitle': 'TOEIC 4-Skill Mock',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 45))
                .toIso8601String(),
            'status': 'in_progress',
            'activeSkillId': 1,
            'activeUnitNumber': 1,
            'activeGroupId': 10,
            'questions': [
              {
                'questionId': 1,
                'index': 0,
                'skill': 'listening',
                'skillId': 1,
                'unitNumber': 1,
                'groupId': 10,
                'sectionName': 'Part 1',
                'prompt': 'Listen to the announcement.',
                'audioUrl': 'https://cdn.example.com/mock-master.mp3',
                'options': [
                  {'optionId': 11, 'label': 'A', 'text': 'Option A'},
                ],
              },
              {
                'questionId': 2,
                'index': 1,
                'skill': 'listening',
                'skillId': 1,
                'unitNumber': 2,
                'groupId': 20,
                'sectionName': 'Part 2',
                'prompt': 'Listen to the conversation.',
                'options': [
                  {'optionId': 21, 'label': 'A', 'text': 'Option A'},
                ],
              },
              {
                'questionId': 3,
                'index': 2,
                'skill': 'speaking',
                'skillId': 2,
                'unitNumber': 3,
                'groupId': 30,
                'sectionName': 'Speaking Part 1',
                'prompt': 'Introduce yourself.',
              },
            ],
          });
        case 'POST /api/learner/attempts/902/audio-review/start':
          audioReviewStarted = true;
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 902,
            'remainingSeconds': 120,
          });
        case 'POST /api/learner/attempts/902/transition/unit':
          unitTransitioned =
              (body as Map<String, dynamic>)['targetUnitNumber'] as int?;
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 902,
            'activeUnitNumber': unitTransitioned,
          });
        case 'POST /api/learner/attempts/902/transition/group':
          groupTransitioned =
              (body as Map<String, dynamic>)['targetGroupId'] as int?;
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 902,
            'activeGroupId': groupTransitioned,
          });
        case 'POST /api/learner/attempts/902/transition/skill':
          skillTransitioned = true;
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 902,
            'activeSkillId': 2,
            'activeUnitNumber': 3,
            'activeGroupId': 30,
          });
        case 'POST /api/learner/speaking/attempts/902/questions/3/audio':
          expect(options.data, isA<FormData>());
          final formData = options.data as FormData;
          expect(formData.files.any((e) => e.key == 'audioFile'), isTrue);
          expect(
            formData.fields.any(
              (e) => e.key == 'durationMs' && int.tryParse(e.value) != null,
            ),
            isTrue,
          );
          speakingUploaded = true;
          return FakeHttpClientAdapter.jsonResponse({'uploaded': true});
        case 'POST /api/learner/attempts/902/answers/3':
          return FakeHttpClientAdapter.jsonResponse({'saved': true});
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(buildTestApp(adapter: adapter, audioAdapter: audio));
    await tester.pumpAndSettle();

    // Start audio review gate
    await tester.tap(find.byKey(const Key('start-audio-review-btn')));
    await tester.pumpAndSettle();
    expect(audioReviewStarted, isTrue);
    expect(find.byKey(const Key('audio-review-banner')), findsOneWidget);

    // Next question triggers unit/group transition
    await tester.tap(find.byKey(const Key('next-question-btn')));
    await tester.pumpAndSettle();
    expect(unitTransitioned, 2);
    expect(groupTransitioned, 20);

    // Transition to next skill (Speaking)
    await tester.tap(find.byKey(const Key('transition-skill-btn')));
    await tester.pumpAndSettle();
    expect(skillTransitioned, isTrue);
    expect(find.text('Introduce yourself.'), findsOneWidget);

    // Record & upload speaking response
    await tester.tap(find.byKey(const Key('speaking-record-btn')));
    await tester.pumpAndSettle();
    expect(audio.isRecording, isTrue);

    await tester.tap(find.byKey(const Key('speaking-record-btn')));
    await tester.pumpAndSettle();
    expect(audio.isRecording, isFalse);
    expect(speakingUploaded, isTrue);
  });
}
