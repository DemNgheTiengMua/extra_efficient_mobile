import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/screens/exam_hub_screen.dart';
import 'package:extra_efficient_mobile/features/exams/screens/mock_instructions_screen.dart';
import 'package:extra_efficient_mobile/features/exams/screens/mock_preflight_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  Widget buildTestApp({
    required FakeHttpClientAdapter adapter,
    required FakeAudioMediaAdapter audioAdapter,
  }) {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final router = GoRouter(
      initialLocation: '/exams',
      routes: [
        GoRoute(
          path: '/exams',
          builder: (context, state) => const Scaffold(
            body: ExamHubScreen(),
          ),
        ),
        GoRoute(
          path: '/placement',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('PLACEMENT OVERVIEW')),
          ),
        ),
        GoRoute(
          path: '/exams/:examId/instructions',
          builder: (context, state) {
            final examId = int.parse(state.pathParameters['examId'] ?? '0');
            return MockInstructionsScreen(examId: examId);
          },
        ),
        GoRoute(
          path: '/exams/attempts/:attemptId/preflight',
          builder: (context, state) {
            final attemptId =
                int.parse(state.pathParameters['attemptId'] ?? '0');
            return MockPreflightScreen(attemptId: attemptId);
          },
        ),
        GoRoute(
          path: '/exams/attempts/:attemptId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('MOCK ROOM #${state.pathParameters['attemptId']}'),
            ),
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
          path: '/exams/attempts/:attemptId/review',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('MOCK REVIEW #${state.pathParameters['attemptId']}'),
            ),
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

  Map<String, dynamic> contextPayload() => {
        'active': {'code': 'TOEIC', 'name': 'TOEIC'},
        'certificates': [
          {'code': 'TOEIC', 'name': 'TOEIC', 'isActive': true},
        ],
        'creditBalance': 12,
      };

  Map<String, dynamic> examsPayload() => {
        'exams': [
          {
            'examId': 101,
            'title': 'TOEIC Full Mock #1',
            'durationMinutes': 120,
            'questionCount': 200,
            'credits': 5,
            'inProgressAttemptId': null,
          },
          {
            'examId': 102,
            'title': 'TOEIC Listening & Reading #2',
            'durationMinutes': 90,
            'questionCount': 100,
            'credits': 3,
            'inProgressAttemptId': 888,
          },
        ],
      };

  Map<String, dynamic> historyPayload() => {
        'attempts': [
          {
            'attemptId': 701,
            'examId': 101,
            'examTitle': 'TOEIC Full Mock #1',
            'status': 'COMPLETED',
            'totalScaledScore': 785,
            'overallBand': 'B2',
            'completedAt': '2026-11-10T10:00:00Z',
          },
        ],
      };

  testWidgets(
      'ExamHubScreen renders Mock Exams catalog, History & Review tab, and resumes via authorizationCode',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    String? resumedCode;
    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/context':
          return FakeHttpClientAdapter.jsonResponse(contextPayload());
        case 'GET /api/learner/exams':
          return FakeHttpClientAdapter.jsonResponse(examsPayload());
        case 'GET /api/learner/exams/history':
          return FakeHttpClientAdapter.jsonResponse(historyPayload());
        case 'POST /api/learner/attempts/resume':
          resumedCode = (body as Map<String, dynamic>)['authorizationCode'] as String?;
          return FakeHttpClientAdapter.jsonResponse({'attemptId': 901});
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(buildTestApp(adapter: adapter, audioAdapter: audio));
    await tester.pumpAndSettle();

    expect(find.text('MOCK EXAMS'), findsOneWidget);
    expect(find.text('HISTORY & REVIEW'), findsOneWidget);
    expect(find.text('PLACEMENT ASSESSMENT'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('TOEIC Full Mock #1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TOEIC Full Mock #1'), findsOneWidget);
    expect(find.text('5 CREDITS'), findsOneWidget);

    // Switch to History & Review tab
    await tester.tap(find.text('HISTORY & REVIEW'));
    await tester.pumpAndSettle();

    expect(find.text('TOEIC FULL MOCK #1'), findsOneWidget);
    expect(find.text('785'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);

    // Switch back to Mock Exams and resume via authorizationCode
    await tester.tap(find.text('MOCK EXAMS'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('resume-auth-code-btn')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('resume-auth-code-input')),
      'AUTH-901',
    );
    await tester.tap(find.byKey(const Key('resume-auth-code-btn')));
    await tester.pumpAndSettle();

    expect(resumedCode, 'AUTH-901');
    expect(find.text('MOCK ROOM #901'), findsOneWidget);
  });

  testWidgets(
      'Mock Exam flow opens instructions, starts attempt, verifies preflight audio/mic, and enters room',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    bool preflightVerified = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/context':
          return FakeHttpClientAdapter.jsonResponse(contextPayload());
        case 'GET /api/learner/exams':
          return FakeHttpClientAdapter.jsonResponse(examsPayload());
        case 'GET /api/learner/exams/history':
          return FakeHttpClientAdapter.jsonResponse(historyPayload());
        case 'GET /api/learner/exams/101/instructions':
          return FakeHttpClientAdapter.jsonResponse({
            'examId': 101,
            'title': 'TOEIC Full Mock #1',
            'durationMinutes': 120,
            'questionCount': 200,
            'credits': 5,
            'instructions': [
              'Listening audio plays once per question group.',
              'Do not leave the exam room before submitting.',
            ],
            'sections': [
              {'name': 'Listening', 'questionCount': 100},
              {'name': 'Reading', 'questionCount': 100},
            ],
          });
        case 'POST /api/learner/exams/101/start':
          return FakeHttpClientAdapter.jsonResponse({'attemptId': 902});
        case 'GET /api/learner/attempts/902/preflight':
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 902,
            'audioSampleUrl': 'https://cdn.example.com/preflight.mp3',
            'requiresMicrophone': true,
          });
        case 'POST /api/learner/attempts/902/preflight/verify':
          preflightVerified = true;
          return FakeHttpClientAdapter.jsonResponse({'verified': true});
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(buildTestApp(adapter: adapter, audioAdapter: audio));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('open-mock-exam-101')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open-mock-exam-101')));
    await tester.pumpAndSettle();

    expect(find.text('TOEIC FULL MOCK #1'), findsOneWidget);
    expect(
      find.text('Listening audio plays once per question group.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('start-mock-attempt-btn')));
    await tester.pumpAndSettle();

    expect(find.text('MOCK ATTEMPT PREFLIGHT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('preflight-audio-check-btn')));
    await tester.pumpAndSettle();
    expect(audio.lastLoadedUrl, 'https://cdn.example.com/preflight.mp3');

    await tester.tap(find.byKey(const Key('preflight-mic-check-btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('enter-mock-room-btn')));
    await tester.pumpAndSettle();

    expect(preflightVerified, isTrue);
    expect(find.text('MOCK ROOM #902'), findsOneWidget);
  });
}
