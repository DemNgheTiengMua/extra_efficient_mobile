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
          builder: (context, state) => const Scaffold(body: ExamHubScreen()),
        ),
        GoRoute(
          path: '/placement',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('PLACEMENT OVERVIEW'))),
        ),
        GoRoute(
          path: '/placement/take/:placementId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'PLACEMENT ROOM #${state.pathParameters['placementId']}',
              ),
            ),
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
            final attemptId = int.parse(
              state.pathParameters['attemptId'] ?? '0',
            );
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

  /// Recorded shape of `GET /api/learner/placement`: an envelope.
  Map<String, dynamic> placementCatalogPayload({
    int? activePlacementId = 41,
    bool includeExam = true,
  }) => {
    'activeCert': {
      'code': 'TOEIC',
      'name': 'TOEIC Listening & Reading',
      'sectionNoun': 'Part',
    },
    'currentBandCode': null,
    'currentBandName': null,
    'currentTotalScore': null,
    'exams': [
      if (includeExam)
        {
          'examId': 2,
          'certId': 1,
          'certCode': 'TOEIC',
          'name': 'TOEIC Placement Test — Diagnostic',
          'description': 'A 29-question diagnostic across all four skills.',
          'durationMinutes': 45,
          'questionCount': 29,
          'isRecommended': true,
          'activePlacementId': activePlacementId,
        },
    ],
    'activePlacementId': activePlacementId,
    'activeAttemptId': 3,
    'isRetake': false,
    'allSkillsRetakeCredits': 5,
    'listeningAndReadingRetakeCredits': 3,
    'creditBalance': null,
  };

  /// Recorded shape of `GET /api/learner/exams`: an envelope, `name`/`creditCost`.
  Map<String, dynamic> mockListPayload() => {
    'certificate': {
      'code': 'TOEIC',
      'name': 'TOEIC Listening & Reading',
      'sectionNoun': 'Part',
    },
    'creditBalance': 11,
    'exams': [
      {
        'examId': 101,
        'name': 'TOEIC Full Mock #1',
        'durationMinutes': 120,
        'questionCount': 200,
        'creditCost': 5,
        'activeAttemptId': null,
      },
      {
        'examId': 102,
        'name': 'TOEIC Listening & Reading #2',
        'durationMinutes': 90,
        'questionCount': 100,
        'creditCost': 3,
        'activeAttemptId': 888,
      },
    ],
  };

  /// Recorded shape of `GET /api/learner/exams/history`: lowercase `status`,
  /// `examName`, `totalScore`, `bandCode`.
  Map<String, dynamic> historyPayload() => {
    'certificate': {
      'code': 'TOEIC',
      'name': 'TOEIC Listening & Reading',
      'sectionNoun': 'Part',
    },
    'totalAttempts': 2,
    'bestScore': 785,
    'averageScore': 402,
    'bestScoreBandCode': 'B2',
    'bestScoreBandName': 'Upper intermediate',
    'attempts': [
      {
        'attemptId': 701,
        'examId': 101,
        'examName': 'TOEIC Full Mock #1',
        'certId': 1,
        'certCode': 'TOEIC',
        'startedAt': '2026-11-10T08:00:00Z',
        'submittedAt': '2026-11-10T10:00:00Z',
        'totalScore': 785,
        'bandCode': 'B2',
        'bandName': 'Upper intermediate',
        'skillScores': [],
        'status': 'graded',
      },
      {
        'attemptId': 702,
        'examId': 102,
        'examName': 'TOEIC Listening & Reading #2',
        'certId': 1,
        'certCode': 'TOEIC',
        'startedAt': '2026-11-12T08:00:00Z',
        'submittedAt': '2026-11-12T08:00:00Z',
        'totalScore': 0,
        'bandCode': null,
        'bandName': null,
        'skillScores': [],
        'status': 'in_progress',
      },
    ],
  };

  testWidgets(
    'hub shows a RESUME door for an unfinished placement and a start surface '
    'enabled by the catalogue exam',
    (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /api/learner/context':
            return FakeHttpClientAdapter.jsonResponse(contextPayload());
          case 'GET /api/learner/placement':
            return FakeHttpClientAdapter.jsonResponse(
              placementCatalogPayload(),
            );
          case 'GET /api/learner/exams':
            return FakeHttpClientAdapter.jsonResponse(mockListPayload());
          case 'GET /api/learner/exams/history':
            return FakeHttpClientAdapter.jsonResponse(historyPayload());
          default:
            return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        }
      });

      await tester.pumpWidget(
        buildTestApp(adapter: adapter, audioAdapter: FakeAudioMediaAdapter()),
      );
      await tester.pumpAndSettle();

      expect(find.text('PLACEMENT ASSESSMENT'), findsOneWidget);
      expect(find.text('ATTEMPT 41 IS UNFINISHED'), findsOneWidget);
      expect(find.text('TOEIC Placement Test — Diagnostic'), findsOneWidget);
      expect(find.textContaining('45 MIN'), findsOneWidget);
      expect(find.textContaining('29 QUESTIONS'), findsOneWidget);

      // Both doors are present: the way back and the way in.
      final resume = find.byKey(const Key('resume-placement-btn'));
      expect(resume, findsOneWidget);
      expect(find.byKey(const Key('start-placement-hub-btn')), findsOneWidget);

      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(find.text('PLACEMENT ROOM #41'), findsOneWidget);
    },
  );

  testWidgets('hub disables the start surface when no placement exam exists', (
    tester,
  ) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/context':
          return FakeHttpClientAdapter.jsonResponse(contextPayload());
        case 'GET /api/learner/placement':
          return FakeHttpClientAdapter.jsonResponse(
            placementCatalogPayload(
              activePlacementId: null,
              includeExam: false,
            ),
          );
        case 'GET /api/learner/exams':
          return FakeHttpClientAdapter.jsonResponse(mockListPayload());
        case 'GET /api/learner/exams/history':
          return FakeHttpClientAdapter.jsonResponse(historyPayload());
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(
      buildTestApp(adapter: adapter, audioAdapter: FakeAudioMediaAdapter()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resume-placement-btn')), findsNothing);
    expect(find.byKey(const Key('start-placement-hub-btn')), findsNothing);
    expect(find.text('NO PLACEMENT EXAM AVAILABLE'), findsOneWidget);
  });

  testWidgets(
    'mock catalogue renders the real name/duration/question count/credit cost '
    'and a RESUME control for the exam with an active attempt',
    (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /api/learner/context':
            return FakeHttpClientAdapter.jsonResponse(contextPayload());
          case 'GET /api/learner/placement':
            return FakeHttpClientAdapter.jsonResponse(
              placementCatalogPayload(activePlacementId: null),
            );
          case 'GET /api/learner/exams':
            return FakeHttpClientAdapter.jsonResponse(mockListPayload());
          case 'GET /api/learner/exams/history':
            return FakeHttpClientAdapter.jsonResponse(historyPayload());
          default:
            return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        }
      });

      await tester.pumpWidget(
        buildTestApp(adapter: adapter, audioAdapter: FakeAudioMediaAdapter()),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('TOEIC Full Mock #1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('TOEIC Full Mock #1'), findsOneWidget);
      expect(find.text('120 MIN · 200 QUESTIONS'), findsOneWidget);
      expect(find.text('5 CREDITS'), findsOneWidget);

      // The exam with an unfinished attempt offers RESUME, not INSTRUCTIONS.
      await tester.scrollUntilVisible(
        find.byKey(const Key('resume-mock-exam-102')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('resume-mock-exam-102')), findsOneWidget);
      expect(find.byKey(const Key('open-mock-exam-102')), findsNothing);
      expect(find.byKey(const Key('open-mock-exam-101')), findsOneWidget);

      await tester.tap(find.byKey(const Key('resume-mock-exam-102')));
      await tester.pumpAndSettle();
      expect(find.text('MOCK ROOM #888'), findsOneWidget);
    },
  );

  testWidgets('history rows show the real score and band, and in_progress is '
      'distinguished from graded', (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/context':
          return FakeHttpClientAdapter.jsonResponse(contextPayload());
        case 'GET /api/learner/placement':
          return FakeHttpClientAdapter.jsonResponse(
            placementCatalogPayload(activePlacementId: null),
          );
        case 'GET /api/learner/exams':
          return FakeHttpClientAdapter.jsonResponse(mockListPayload());
        case 'GET /api/learner/exams/history':
          return FakeHttpClientAdapter.jsonResponse(historyPayload());
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(
      buildTestApp(adapter: adapter, audioAdapter: FakeAudioMediaAdapter()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('HISTORY & REVIEW'));
    await tester.pumpAndSettle();

    // The graded row carries its real score and band.
    expect(find.text('785'), findsOneWidget);
    expect(find.text('B2 · Upper intermediate'), findsOneWidget);
    expect(find.byKey(const Key('history-result-701')), findsOneWidget);
    expect(find.byKey(const Key('history-review-701')), findsOneWidget);

    // The in-progress row offers RESUME instead, with no invented score.
    expect(find.byKey(const Key('history-resume-702')), findsOneWidget);
    expect(find.byKey(const Key('history-result-702')), findsNothing);
    expect(find.text('IN PROGRESS'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-resume-702')));
    await tester.pumpAndSettle();
    expect(find.text('MOCK ROOM #702'), findsOneWidget);
  });

  testWidgets('history survives the designed empty state', (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/context':
          return FakeHttpClientAdapter.jsonResponse(contextPayload());
        case 'GET /api/learner/placement':
          return FakeHttpClientAdapter.jsonResponse(
            placementCatalogPayload(activePlacementId: null),
          );
        case 'GET /api/learner/exams':
          return FakeHttpClientAdapter.jsonResponse(mockListPayload());
        case 'GET /api/learner/exams/history':
          return FakeHttpClientAdapter.jsonResponse({
            'certificate': {'code': 'TOEIC', 'name': 'TOEIC'},
            'totalAttempts': 0,
            'bestScore': null,
            'averageScore': null,
            'bestScoreBandCode': null,
            'bestScoreBandName': null,
            'cefrBands': [],
            'attempts': [],
          });
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(
      buildTestApp(adapter: adapter, audioAdapter: FakeAudioMediaAdapter()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('HISTORY & REVIEW'));
    await tester.pumpAndSettle();

    expect(find.text('NO ATTEMPTS YET'), findsOneWidget);
  });

  testWidgets(
    'Mock Exam flow opens instructions with the real name and credit cost, '
    'starts an attempt, verifies preflight, and enters the room',
    (tester) async {
      final audio = FakeAudioMediaAdapter();
      bool preflightVerified = false;

      final adapter = FakeHttpClientAdapter((options, body) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /api/learner/context':
            return FakeHttpClientAdapter.jsonResponse(contextPayload());
          case 'GET /api/learner/placement':
            return FakeHttpClientAdapter.jsonResponse(
              placementCatalogPayload(activePlacementId: null),
            );
          case 'GET /api/learner/exams':
            return FakeHttpClientAdapter.jsonResponse(mockListPayload());
          case 'GET /api/learner/exams/history':
            return FakeHttpClientAdapter.jsonResponse(historyPayload());
          case 'GET /api/learner/exams/101/instructions':
            return FakeHttpClientAdapter.jsonResponse({
              'examId': 101,
              'certId': 1,
              'certCode': 'TOEIC',
              'examName': 'TOEIC Full Mock #1',
              'description': 'A full TOEIC Listening & Reading form.',
              'durationMinutes': 120,
              'questionCount': 200,
              'creditCost': 5,
              'creditBalance': 11,
              'activeAttemptId': null,
              'sections': [
                {
                  'sectionId': 1,
                  'skillCode': 'LIST',
                  'skillName': 'Listening',
                  'modality': 'listening',
                  'sectionCode': 'P1',
                  'sectionName': 'Photographs',
                  'expectedQuestionCount': 6,
                  'questionCount': 100,
                  'durationMinutes': 45,
                  'displayOrder': 1,
                },
                {
                  'sectionId': 2,
                  'skillCode': 'READ',
                  'skillName': 'Reading',
                  'modality': 'reading',
                  'sectionCode': 'P5',
                  'sectionName': 'Incomplete Sentences',
                  'expectedQuestionCount': 30,
                  'questionCount': 100,
                  'durationMinutes': 75,
                  'displayOrder': 2,
                },
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

      await tester.pumpWidget(
        buildTestApp(adapter: adapter, audioAdapter: audio),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('open-mock-exam-101')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('open-mock-exam-101')));
      await tester.pumpAndSettle();

      expect(find.text('TOEIC FULL MOCK #1'), findsOneWidget);
      expect(find.text('5 CREDITS'), findsOneWidget);
      expect(find.text('120 MIN · 200 QUESTIONS'), findsOneWidget);
      // Section counts are the authored ones, not the blueprint targets.
      expect(find.text('100 Q'), findsNWidgets(2));

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
    },
  );
}
