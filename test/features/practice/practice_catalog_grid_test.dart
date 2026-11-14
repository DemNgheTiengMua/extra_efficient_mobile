import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/practice_payloads.dart';
// The refused-start bytes are recorded from the running backend, not hand-shaped.
import '../../contract/fixture_loader.dart';

/// Ticket #14: the DRILLS catalogue and the topic-by-level grid read the
/// backend's real envelopes, mark an unavailable cell before it is tapped, and
/// surface a refused start in the backend's own words.
void main() {
  Map<String, dynamic> contextResponse({
    String code = 'TOEIC',
    String sectionNoun = 'Part',
  }) {
    return {
      'active': {
        'code': code,
        'name': 'TOEIC Listening & Reading',
        'sectionNoun': sectionNoun,
      },
      'certificates': [
        {'code': code, 'name': 'Active Cert', 'sectionNoun': sectionNoun},
      ],
      'creditBalance': 13,
      'examinedSkills': ['listening', 'reading'],
      'examDate': null,
    };
  }

  Future<ResponseBody> authMe() async => FakeHttpClientAdapter.jsonResponse({
        'userId': 2,
        'email': 'learner@demo.local',
        'fullName': 'Demo Learner',
        'role': 'learner',
        'emailVerified': true,
        'permissions': [],
        'held': [],
      });

  Future<void> pump(
    WidgetTester tester,
    FakeHttpClientAdapter adapter,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider
              .overrideWithValue(InMemoryTokenStorage(initialToken: 'valid-jwt')),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();
  }

  /// Scrolls the DRILLS list until [finder] is on screen. The list is built
  /// lazily, so a plain `find.text` would not see an off-screen row.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  /// Reveals a grid cell and lifts it clear of the bottom navigation bar,
  /// which otherwise swallows the tap.
  Future<void> revealCell(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -160));
    await tester.pumpAndSettle();
  }

  final sections = [
    practiceSection(
      sectionId: 1,
      code: 'P1',
      name: 'Photographs',
      modality: 'listening',
      skillCode: 'LIST',
      skillName: 'Listening',
      availableQuestionCount: 3,
      expectedQuestionCount: 6,
      accuracyPercentage: 72,
    ),
    practiceSection(
      sectionId: 5,
      code: 'P5',
      name: 'Incomplete Sentences',
      availableQuestionCount: 9,
      expectedQuestionCount: 30,
    ),
    practiceSection(
      sectionId: 15,
      code: 'W3',
      name: 'Write an opinion essay',
      modality: 'writing',
      skillCode: 'WRIT',
      skillName: 'Writing',
      availableQuestionCount: 0,
      expectedQuestionCount: 1,
    ),
    practiceSection(
      sectionId: 8,
      code: 'S1',
      name: 'Read a text aloud',
      modality: 'speaking',
      skillCode: 'SPEA',
      skillName: 'Speaking',
      availableQuestionCount: 0,
      expectedQuestionCount: 2,
    ),
  ];

  final cells = [
    practiceCell(
      topicId: 8,
      topicCode: 'R-DET',
      topicName: 'Local factual retrieval',
      levelCode: 'A2',
      mastery: 0,
    ),
    practiceCell(
      topicId: 8,
      topicCode: 'R-DET',
      topicName: 'Local factual retrieval',
      levelCode: 'B1',
      mastery: 1,
    ),
    practiceCell(
      topicId: 8,
      topicCode: 'R-DET',
      topicName: 'Local factual retrieval',
      levelCode: 'B2',
      mastery: 3,
    ),
    practiceCell(
      topicId: 2,
      topicCode: 'L-DET',
      topicName: 'Listening detail',
      levelCode: 'A2',
      modality: 'listening',
      mastery: 2,
    ),
    practiceCell(
      topicId: 2,
      topicCode: 'L-DET',
      topicName: 'Listening detail',
      levelCode: 'B1',
      modality: 'listening',
      mastery: 0,
      isResting: true,
      reopensAt: '2026-11-15T00:00:00+00:00',
    ),
  ];

  testWidgets(
      'DRILLS groups sections by skill with the certificate\'s own noun and '
      'real available counts', (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') return authMe();
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextResponse());
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(
            sections: sections,
            unfinishedSession: {
              'sessionId': 42,
              'sectionId': 5,
              'sectionCode': 'P5',
              'sectionName': 'Incomplete Sentences',
              'modality': 'reading',
              'questionCount': 9,
              'status': 'in_progress',
              'correctCount': 2,
              'questionSource': 'all',
              'startedAt': '2026-11-13T16:03:52+00:00',
              'finishedAt': null,
              'topicId': null,
              'cefrLevelCode': null,
              'isShort': false,
            },
            speakingPracticeExamId: 3,
          ),
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse(cells);
      }
      if (options.path == '/api/learner/practice/free-drill') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceFreeDrillResponse(),
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await pump(tester, adapter);

    // Section noun comes from the certificate: "Part", not "Section".
    expect(find.text('PART CATALOG'), findsOneWidget);
    expect(find.text('SECTION CATALOG'), findsNothing);

    // Grouped by skill, in catalogue order, with real names.
    await reveal(tester, find.text('LISTENING'));
    expect(find.text('LISTENING'), findsOneWidget);

    await reveal(tester, find.text('P1 · Photographs'));
    expect(find.text('P1 · Photographs'), findsOneWidget);
    expect(find.text('3/6 QUESTIONS'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);

    await reveal(tester, find.text('READING'));
    expect(find.text('READING'), findsOneWidget);

    await reveal(tester, find.text('P5 · Incomplete Sentences'));
    expect(find.text('P5 · Incomplete Sentences'), findsOneWidget);
    expect(find.text('9/30 QUESTIONS'), findsOneWidget);

    await reveal(tester, find.text('WRITING'));
    expect(find.text('WRITING'), findsOneWidget);

    await reveal(tester, find.text('W3 · Write an opinion essay'));
    expect(find.text('W3 · Write an opinion essay'), findsOneWidget);
    expect(find.text('0/1 QUESTIONS'), findsOneWidget);
    // A section with no questions cannot be started.
    expect(find.text('NO QUESTIONS'), findsWidgets);

    // The unfinished session offers a resume.
    await tester.scrollUntilVisible(
      find.text('RESUME SESSION'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('RESUME SESSION'), findsOneWidget);
    expect(find.text('Incomplete Sentences'), findsOneWidget);
  });

  testWidgets(
      'the grid derives level columns from the data, shows mastery as its own '
      'state, and refuses a resting cell before it is tapped', (tester) async {
    final startedCalls = <RequestOptions>[];
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') return authMe();
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextResponse());
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(sections: sections),
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse(cells);
      }
      if (options.path == '/api/learner/practice/free-drill') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceFreeDrillResponse(),
        );
      }
      if (options.path == '/api/learner/practice/sessions') {
        startedCalls.add(options);
        return FakeHttpClientAdapter.jsonResponse(
          {'sessionId': 77},
        );
      }
      if (options.path == '/api/learner/practice/sessions/77/take') {
        return FakeHttpClientAdapter.jsonResponse({
          'session': {
            'sessionId': 77,
            'sectionId': null,
            'sectionCode': 'L-DET',
            'sectionName': 'Listening detail',
            'modality': 'listening',
            'questionCount': 1,
            'status': 'in_progress',
            'correctCount': 0,
            'questionSource': 'all',
            'startedAt': '2026-11-13T16:03:52+00:00',
            'finishedAt': null,
            'topicId': 2,
            'cefrLevelCode': 'A2',
            'isShort': true,
          },
          'question': null,
          'questions': <dynamic>[],
          'navigator': <dynamic>[],
        });
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await pump(tester, adapter);

    await reveal(tester, find.text('TOPIC × LEVEL MATRIX'));

    // Columns are the distinct level codes present in the payload.
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('C1'), findsNothing);

    // Mastery is rendered as its own state, not a count or a percentage.
    expect(find.text('NEW'), findsWidgets);
    expect(find.text('LEARN'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);
    expect(find.text('MSTR'), findsOneWidget);

    // The resting cell says so and cannot start a drill.
    expect(find.text('REST'), findsOneWidget);
    await revealCell(tester, find.byKey(const Key('matrix-cell-2-B1')));
    await tester.tap(
      find.byKey(const Key('matrix-cell-2-B1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(startedCalls, isEmpty);

    // An available cell does start one.
    await revealCell(tester, find.byKey(const Key('matrix-cell-2-A2')));
    await tester.tap(find.byKey(const Key('matrix-cell-2-A2')));
    await tester.pumpAndSettle();
    expect(startedCalls, hasLength(1));
    expect(startedCalls.single.data['topicId'], 2);
    expect(startedCalls.single.data['cefrLevelCode'], 'A2');
  });

  testWidgets(
      'a cell the backend locks is visibly unavailable before the tap',
      (tester) async {
    final startedCalls = <RequestOptions>[];
    final lockNotice =
        'This topic and level have already had their session today. '
        'One session per cell per day keeps a cell from being exhausted.';

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') return authMe();
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextResponse());
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(sections: const []),
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse([cells.first]);
      }
      if (options.path == '/api/learner/practice/free-drill') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceFreeDrillResponse(
            isUnlocked: false,
            cellUsedToday: true,
            lockNotice: lockNotice,
          ),
        );
      }
      if (options.path == '/api/learner/practice/sessions') {
        startedCalls.add(options);
        return FakeHttpClientAdapter.jsonResponse({'sessionId': 1});
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await pump(tester, adapter);

    await revealCell(tester, find.byKey(const Key('matrix-cell-8-A2')));
    expect(find.text('LOCKED'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('matrix-cell-8-A2')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(startedCalls, isEmpty);
  });

  testWidgets('a refused drill shows the backend\'s own explanation',
      (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') return authMe();
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextResponse());
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(sections: sections),
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse([cells.first]);
      }
      if (options.path == '/api/learner/practice/free-drill') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceFreeDrillResponse(),
        );
      }
      if (options.path == '/api/learner/practice/sessions') {
        // Recorded from the running backend.
        return FakeHttpClientAdapter.jsonResponse(
          loadFixture('practice_start_refused'),
          statusCode: 404,
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await pump(tester, adapter);

    await revealCell(tester, find.byKey(const Key('matrix-cell-8-A2')));
    await tester.tap(find.byKey(const Key('matrix-cell-8-A2')));
    await tester.pumpAndSettle();

    // The banner is inserted at the top of the list.
    await tester.scrollUntilVisible(
      find.text('Drill not started'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Drill not started'), findsOneWidget);
    // The backend's own sentence from the recorded refusal, verbatim.
    final recorded =
        loadFixture('practice_start_refused') as Map<String, dynamic>;
    expect(find.text(recorded['detail'] as String), findsOneWidget);
    // The control stays usable: dismissing leaves the grid tappable.
    await tester.tap(find.text('DISMISS'));
    await tester.pumpAndSettle();
    expect(find.text('Drill not started'), findsNothing);
  });

  testWidgets('a failed catalogue load reaches the error branch, not a spinner',
      (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') return authMe();
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextResponse());
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          {'title': 'Error', 'status': 500, 'code': 'UNEXPECTED'},
          statusCode: 500,
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse(const <dynamic>[]);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await pump(tester, adapter);

    expect(find.text('Could not load practice catalog'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'a failed grid load reaches the grid\'s own error branch', (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') return authMe();
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextResponse());
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(sections: sections),
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse(
          {'title': 'Error', 'status': 500},
          statusCode: 500,
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await pump(tester, adapter);

    await reveal(tester, find.text('Could not load the practice grid'));
    expect(find.text('Could not load the practice grid'), findsOneWidget);
    // The catalogue above it still rendered.
    await tester.scrollUntilVisible(
      find.text('P5 · Incomplete Sentences'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('P5 · Incomplete Sentences'), findsOneWidget);
  });
}
