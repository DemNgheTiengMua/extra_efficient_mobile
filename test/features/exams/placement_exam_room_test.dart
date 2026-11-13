import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/screens/placement_exam_room_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  Widget buildTestApp({
    required FakeHttpClientAdapter adapter,
    required FakeAudioMediaAdapter audioAdapter,
    int placementId = 555,
  }) {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final router = GoRouter(
      initialLocation: '/placement/take/$placementId',
      routes: [
        GoRoute(
          path: '/placement/take/:placementId',
          builder: (context, state) => PlacementExamRoomScreen(
            placementId:
                int.parse(state.pathParameters['placementId'] ?? '555'),
          ),
        ),
        GoRoute(
          path: '/placement/result/:placementId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'RESULT #${state.pathParameters['placementId']}',
              ),
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

  Map<String, dynamic> fullSittingPayload({Duration? remaining}) => {
        'placementId': 555,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(remaining ?? const Duration(minutes: 25))
            .toIso8601String(),
        'status': 'in_progress',
        'questions': [
          {
            'questionId': 1,
            'index': 0,
            'skill': 'listening',
            'sectionName': 'Part 2',
            'prompt': 'Where is the meeting room?',
            'audioUrl': 'https://cdn.example.com/master-track.mp3',
            'audioStartMs': 5000,
            'audioEndMs': 18500,
            'options': [
              {'optionId': 101, 'label': 'A', 'text': 'On the second floor.'},
              {'optionId': 102, 'label': 'B', 'text': 'At 3 PM.'},
              {'optionId': 103, 'label': 'C', 'text': 'Yes, I did.'},
            ],
            'isFlagged': false,
          },
          {
            'questionId': 2,
            'index': 1,
            'skill': 'reading',
            'sectionName': 'Part 7',
            'passageText':
                'Dear Mr. Tanaka, Thank you for submitting your quarterly report.',
            'prompt': 'What did Mr. Tanaka submit?',
            'options': [
              {'optionId': 201, 'label': 'A', 'text': 'A quarterly report'},
              {'optionId': 202, 'label': 'B', 'text': 'A travel request'},
              {'optionId': 203, 'label': 'C', 'text': 'An invoice'},
              {'optionId': 204, 'label': 'D', 'text': 'A resignation'},
            ],
            'isFlagged': false,
          },
          {
            'questionId': 3,
            'index': 2,
            'skill': 'writing',
            'sectionName': 'Writing Task 1',
            'prompt': 'Describe the main trend in the chart.',
            'wordFloor': 50,
            'options': [],
            'isFlagged': false,
          },
          {
            'questionId': 4,
            'index': 3,
            'skill': 'speaking',
            'sectionName': 'Speaking Part 1',
            'prompt': 'Introduce your current role and daily responsibilities.',
            'prepSeconds': 15,
            'responseSeconds': 45,
            'options': [],
            'isFlagged': false,
          },
        ],
      };

  testWidgets(
      'exam room handles audio slicing, dynamic options, ~400ms debounced autosave, writing draft, speaking mic, and submit',
      (tester) async {
    final audioAdapter = FakeAudioMediaAdapter();
    Map<String, dynamic>? savedAnswerBody;
    Map<String, dynamic>? savedDraftBody;
    Map<String, dynamic>? submitBody;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/take/555' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(fullSittingPayload());
      }
      if (options.path == '/api/learner/placement/take/555/answers/1' &&
          options.method == 'POST') {
        savedAnswerBody = body as Map<String, dynamic>?;
        return FakeHttpClientAdapter.jsonResponse({'saved': true});
      }
      if (options.path == '/api/learner/placement/take/555/draft' &&
          options.method == 'POST') {
        savedDraftBody = body as Map<String, dynamic>?;
        return FakeHttpClientAdapter.jsonResponse({'saved': true});
      }
      if (options.path == '/api/learner/placement/take/555/submit' &&
          options.method == 'POST') {
        submitBody = body as Map<String, dynamic>?;
        return FakeHttpClientAdapter.jsonResponse({'submitted': true});
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      buildTestApp(adapter: adapter, audioAdapter: audioAdapter),
    );
    await tester.pumpAndSettle();

    // Header present, bottom nav absent
    expect(find.byKey(const Key('exam-room-header')), findsOneWidget);
    expect(find.byKey(const Key('exam-countdown-clock')), findsOneWidget);
    expect(find.text('PATH'), findsNothing);

    // Listening audio slicing
    expect(audioAdapter.lastLoadedUrl, 'https://cdn.example.com/master-track.mp3');
    expect(audioAdapter.lastClipStart, const Duration(milliseconds: 5000));
    expect(audioAdapter.lastClipEnd, const Duration(milliseconds: 18500));

    // Dynamic 3-option MCQ (never hardcoded 4)
    await tester.scrollUntilVisible(
      find.byKey(const Key('mcq-option-101')),
      200,
    );
    expect(find.byKey(const Key('mcq-option-101')), findsOneWidget);
    expect(find.byKey(const Key('mcq-option-102')), findsOneWidget);
    expect(find.byKey(const Key('mcq-option-103')), findsOneWidget);

    // Tap option B -> debounced ~400ms save
    await tester.tap(find.byKey(const Key('mcq-option-102')));
    await tester.pump();
    expect(find.text('SAVING'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(savedAnswerBody, isNotNull);
    expect(savedAnswerBody!['selectedOptionId'], 102);
    expect(find.text('SAVED'), findsOneWidget);

    // Next -> Reading passage + 4 options
    await tester.tap(find.byKey(const Key('next-question-btn')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dear Mr. Tanaka'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('mcq-option-204')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('mcq-option-204')), findsOneWidget);

    // Next -> Writing draft + word count
    await tester.tap(find.byKey(const Key('next-question-btn')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('writing-draft-input')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('writing-draft-input')),
      'The chart shows steady growth.',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('5 WORDS'), findsOneWidget);
    expect(savedDraftBody, isNotNull);
    expect(savedDraftBody!['questionId'], 3);
    expect(savedDraftBody!['responseText'], 'The chart shows steady growth.');

    // Next -> Speaking mic recording
    await tester.tap(find.byKey(const Key('next-question-btn')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('speaking-record-btn')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('speaking-record-btn')));
    await tester.pumpAndSettle();
    expect(audioAdapter.isRecording, isTrue);

    await tester.tap(find.byKey(const Key('speaking-stop-btn')));
    await tester.pumpAndSettle();
    expect(audioAdapter.isRecording, isFalse);

    // Submit confirmation dialog
    await tester.tap(find.byKey(const Key('exam-submit-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-submit-btn')));
    await tester.pumpAndSettle();

    expect(submitBody, isNotNull);
    expect(submitBody!['isAutoSubmit'], false);
    expect(find.text('RESULT #555'), findsOneWidget);
  });

  testWidgets('auto-submits with isAutoSubmit: true when expiresAt elapses',
      (tester) async {
    final audioAdapter = FakeAudioMediaAdapter();
    Map<String, dynamic>? submitBody;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/take/555' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(
          fullSittingPayload(remaining: const Duration(seconds: 1)),
        );
      }
      if (options.path == '/api/learner/placement/take/555/submit' &&
          options.method == 'POST') {
        submitBody = body as Map<String, dynamic>?;
        return FakeHttpClientAdapter.jsonResponse({'submitted': true});
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      buildTestApp(adapter: adapter, audioAdapter: audioAdapter),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(submitBody, isNotNull);
    expect(submitBody!['isAutoSubmit'], true);
    expect(find.text('RESULT #555'), findsOneWidget);
  });
}
