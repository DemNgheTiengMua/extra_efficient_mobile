import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';

import '../../contract/fixture_loader.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/practice_payloads.dart';

/// Ticket #18: the room consumes the composite take payload, addresses a pool
/// question by the handle the backend assigned, shows the key and explanation,
/// reveals a hint and reports a failed write.
void main() {
  Future<ResponseBody> authMe() async => FakeHttpClientAdapter.jsonResponse({
        'userId': 2,
        'email': 'learner@demo.local',
        'fullName': 'Demo Learner',
        'role': 'learner',
        'emailVerified': true,
        'permissions': [],
        'held': [],
      });

  Map<String, dynamic> contextResponse() => {
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
        'creditBalance': 13,
        'examinedSkills': ['listening', 'reading'],
        'examDate': null,
      };

  /// The recorded take payload, with its addresses intact. Every question is a
  /// pool item: `questionId` is null and `address` is the pinned item version.
  Map<String, dynamic> recordedTake() =>
      loadFixture('practice_take') as Map<String, dynamic>;

  Future<void> pumpToSession(
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-section-2')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('start-section-2')));
    await tester.pumpAndSettle();
  }

  FakeHttpClientAdapter roomAdapter({
    required List<RequestOptions> writes,
    Map<String, dynamic>? take,
    Map<String, dynamic>? summary,
    Map<String, dynamic>? insight,
    List<RequestOptions>? starts,
    ResponseBody Function(RequestOptions options)? onWrite,
  }) {
    final payload = take ?? recordedTake();
    return FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') return authMe();
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextResponse());
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(
            sections: [
              practiceSection(
                sectionId: 2,
                code: 'P2',
                name: 'Question-Response',
                modality: 'listening',
                skillCode: 'LIST',
                skillName: 'Listening',
                availableQuestionCount: 5,
              ),
            ],
          ),
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse(const <dynamic>[]);
      }
      if (options.path == '/api/learner/practice/free-drill') {
        return FakeHttpClientAdapter.jsonResponse(practiceFreeDrillResponse());
      }
      if (options.path == '/api/learner/practice/sessions' &&
          options.method == 'POST') {
        starts?.add(options);
        return FakeHttpClientAdapter.jsonResponse(
          practiceSession(
            sessionId: 17,
            sectionId: 2,
            sectionCode: 'P2',
            sectionName: 'Question-Response',
            modality: 'listening',
            questionCount: 5,
          ),
        );
      }
      if (options.path == '/api/learner/practice/sessions/17/take') {
        return FakeHttpClientAdapter.jsonResponse(payload);
      }
      if (options.path.endsWith('/answer') ||
          options.path.endsWith('/hint') ||
          options.path.startsWith('/api/learner/saved-questions')) {
        writes.add(options);
        if (onWrite != null) return onWrite(options);
        if (options.path.endsWith('/hint')) {
          return FakeHttpClientAdapter.jsonResponse(
            loadFixture('practice_hint'),
          );
        }
        if (options.path.startsWith('/api/learner/saved-questions')) {
          return FakeHttpClientAdapter.jsonResponse({
            'isSaved': true,
            'source': 'manual',
            'savedAt': '2026-11-13T18:03:28.8871271+00:00',
            'savedQuestionId': 77,
          });
        }
        // Walk the recorded questions in order: the next display order is the
        // one after this question, so the room can advance and finish.
        final address =
            int.parse(options.path.split('/questions/').last.split('/').first);
        final ordered = (payload['questions'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final index = ordered.indexWhere((q) => q['address'] == address);
        final next = index >= 0 && index + 1 < ordered.length
            ? ordered[index + 1]['displayOrder'] as int
            : null;
        final graded = loadFixture('practice_answer_wrong')
            as Map<String, dynamic>;
        return FakeHttpClientAdapter.jsonResponse({
          ...graded,
          'nextQuestionDisplayOrder': next,
          'isSessionFinished': next == null,
        });
      }
      if (options.path == '/api/learner/practice/sessions/17/summary') {
        return FakeHttpClientAdapter.jsonResponse(
          summary ?? loadFixture('practice_summary'),
        );
      }
      if (options.path == '/api/learner/insights/practice/17') {
        return FakeHttpClientAdapter.jsonResponse(
          insight ??
              <String, dynamic>{
                'status': 'failed',
                'errorMessage': 'Temporary AI timeout.',
              },
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });
  }

  testWidgets(
      'the room opens on the first question with the real section title and '
      'counts, and names the pool item by its address', (tester) async {
    final writes = <RequestOptions>[];
    await pumpToSession(tester, roomAdapter(writes: writes));

    final take = recordedTake();
    final session = take['session'] as Map<String, dynamic>;
    final questions = take['questions'] as List<dynamic>;

    // The title comes from the session inside the composite, under the
    // backend's own names (there is no `title` field on the wire).
    expect(
      find.text('${session['sectionCode']} · ${session['sectionName']}'),
      findsOneWidget,
    );
    // The counts are the session's, not a default.
    expect(
      find.text('Q1/${session['questionCount']}'),
      findsOneWidget,
    );
    expect(
      find.text((questions.first as Map<String, dynamic>)['stem'] as String),
      findsOneWidget,
    );

    // The address is the pinned item version, never a collapsed 0.
    final address = (questions.first as Map<String, dynamic>)['address'] as int;
    expect(address, 4);
    expect(find.byKey(Key('bookmark-question-$address')), findsOneWidget);
  });

  testWidgets(
      'answering a pool question posts to its address and shows correctness, '
      'the correct option and the explanation', (tester) async {
    final writes = <RequestOptions>[];
    await pumpToSession(tester, roomAdapter(writes: writes));

    // Pick the first option of the recorded question.
    final question =
        (recordedTake()['questions'] as List<dynamic>).first
            as Map<String, dynamic>;
    final firstOption =
        (question['options'] as List<dynamic>).first as Map<String, dynamic>;
    await tester.tap(
      find.text('${firstOption['label']}. ${firstOption['text']}'),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('CHECK ANSWER'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pumpAndSettle();

    // The write went to the address, not the null questionId.
    final answer = writes.singleWhere((r) => r.path.endsWith('/answer'));
    expect(answer.path, '/api/learner/practice/sessions/17/questions/4/answer');
    expect((answer.data as Map<String, dynamic>)['selectedOptionId'], 41);

    // INCORRECT, the key and the recorded explanation.
    expect(find.text('INCORRECT'), findsOneWidget);
    final graded = loadFixture('practice_answer_wrong') as Map<String, dynamic>;
    await tester.scrollUntilVisible(
      find.text(graded['explanation'] as String),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(graded['explanation'] as String), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('B. On the conference room table.'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('B. On the conference room table.'), findsOneWidget);
  });

  testWidgets('requesting a hint posts to the address and shows the hint',
      (tester) async {
    final writes = <RequestOptions>[];
    await pumpToSession(tester, roomAdapter(writes: writes));

    await tester.scrollUntilVisible(
      find.byKey(const Key('practice-request-hint')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('practice-request-hint')));
    await tester.pumpAndSettle();

    final hint = writes.singleWhere((r) => r.path.endsWith('/hint'));
    expect(hint.path, '/api/learner/practice/sessions/17/questions/4/hint');

    final recorded = loadFixture('practice_hint') as Map<String, dynamic>;
    await tester.scrollUntilVisible(
      find.text(recorded['hint'] as String),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(recorded['hint'] as String), findsOneWidget);
  });

  testWidgets('saving a pool question files the item version, not a zero id',
      (tester) async {
    final writes = <RequestOptions>[];
    await pumpToSession(tester, roomAdapter(writes: writes));

    await tester.tap(find.byKey(const Key('bookmark-question-4')));
    await tester.pumpAndSettle();

    final save = writes.singleWhere(
      (r) => r.path.startsWith('/api/learner/saved-questions'),
    );
    // A question row and an item version are separate id counters; a pool item
    // only has the latter.
    expect(save.path, '/api/learner/saved-questions/item-versions/4');
    expect(find.text('SAVED'), findsOneWidget);
  });

  testWidgets('a failed submit reports the backend message and leaves the '
      'control usable', (tester) async {
    final writes = <RequestOptions>[];
    var fail = true;
    await pumpToSession(
      tester,
      roomAdapter(
        writes: writes,
        onWrite: (options) {
          if (options.path.endsWith('/answer') && fail) {
            return FakeHttpClientAdapter.jsonResponse(
              {
                'title': 'Question already answered',
                'status': 409,
                'detail': 'This question has already been graded.',
                'code': 'PRACTICE_ALREADY_ANSWERED',
              },
              statusCode: 409,
            );
          }
          return FakeHttpClientAdapter.jsonResponse(
            loadFixture('practice_answer_wrong'),
          );
        },
      ),
    );

    final question =
        (recordedTake()['questions'] as List<dynamic>).first
            as Map<String, dynamic>;
    final firstOption =
        (question['options'] as List<dynamic>).first as Map<String, dynamic>;
    await tester.tap(
      find.text('${firstOption['label']}. ${firstOption['text']}'),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('CHECK ANSWER'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pumpAndSettle();

    // The backend's own sentence, not a generic one.
    await tester.scrollUntilVisible(
      find.byKey(const Key('practice-write-error')),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('This question has already been graded.'),
      findsOneWidget,
    );

    // The control is usable again: a second press reaches the backend.
    fail = false;
    await tester.scrollUntilVisible(
      find.text('CHECK ANSWER'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pumpAndSettle();
    expect(
      writes.where((r) => r.path.endsWith('/answer')),
      hasLength(2),
    );
    expect(find.text('INCORRECT'), findsOneWidget);
  });

  testWidgets('a failed hint reports the backend message and keeps the button',
      (tester) async {
    final writes = <RequestOptions>[];
    await pumpToSession(
      tester,
      roomAdapter(
        writes: writes,
        onWrite: (options) => FakeHttpClientAdapter.jsonResponse(
          {
            'title': 'Session already finished',
            'status': 400,
            'detail': 'This session is already finished.',
            'code': 'PRACTICE_SESSION_FINISHED',
          },
          statusCode: 400,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('practice-request-hint')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('practice-request-hint')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('practice-write-error')),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('This session is already finished.'), findsOneWidget);
    // Still offered, so the learner can try again.
    await tester.scrollUntilVisible(
      find.byKey(const Key('practice-request-hint')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('practice-request-hint')), findsOneWidget);
  });

  testWidgets(
      'the summary shows the real score and a per-question breakdown that '
      'distinguishes a skipped question from a wrong one', (tester) async {
    final writes = <RequestOptions>[];
    // A summary whose middle row is unanswered: the key still ships, but the
    // row must not read as wrong.
    final recorded = loadFixture('practice_summary') as Map<String, dynamic>;
    final rows = (recorded['questions'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
    rows[1]['isCorrect'] = null;
    rows[1]['selectedOptionLabel'] = null;
    rows[1]['selectedOptionText'] = null;

    final adapter = roomAdapter(writes: writes, summary: {
      ...recorded,
      'questions': rows,
      'answeredCount': 4,
      'skippedCount': 1,
    });
    await pumpToSession(tester, adapter);

    // Answer the last question so the client offers VIEW SUMMARY.
    final questions = recordedTake()['questions'] as List<dynamic>;
    for (var i = 0; i < questions.length; i++) {
      await tester.pumpAndSettle();
      final question = questions[i] as Map<String, dynamic>;
      final option =
          (question['options'] as List<dynamic>).first as Map<String, dynamic>;
      await tester.tap(
        find.text('${option['label']}. ${option['text']}'),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('CHECK ANSWER'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('CHECK ANSWER'));
      await tester.pumpAndSettle();
      final last = i == questions.length - 1;
      await tester.scrollUntilVisible(
        find.text(last ? 'VIEW SUMMARY' : 'NEXT QUESTION'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(last ? 'VIEW SUMMARY' : 'NEXT QUESTION'));
      await tester.pumpAndSettle();
    }

    // The score comes from `accuracyPercentage` / `totalQuestions`.
    expect(find.text('${recorded['accuracyPercentage']}%'), findsOneWidget);
    expect(
      find.text('${recorded['correctCount']}/${recorded['totalQuestions']} CORRECT'),
      findsOneWidget,
    );

    // The breakdown distinguishes the three outcomes.
    await tester.scrollUntilVisible(
      find.text('QUESTION BREAKDOWN'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('WRONG'), findsWidgets);
    expect(find.text('NOT ANSWERED'), findsOneWidget);
    // The key shows for a skipped row too.
    expect(
      find.textContaining('On the conference room table.'),
      findsWidgets,
    );
  });

  testWidgets(
      'a productive question reads minWords, requiredKeywords and submits its '
      'text to the address', (tester) async {
    final writes = <RequestOptions>[];
    final take = practiceTakeResponse(
      session: practiceSession(
        sessionId: 17,
        sectionId: 13,
        sectionCode: 'W1',
        sectionName: 'Write a sentence based on a picture',
        modality: 'writing',
      ),
      questions: [
        practiceQuestion(
          itemVersionId: 61,
          displayOrder: 1,
          totalQuestions: 1,
          questionType: 'free_response',
          stem: 'Reply to the client email about the meeting time.',
          minWords: 10,
          maxWords: 40,
          requiredKeywords: '["schedule","confirm"]',
          audioPath: '/audio/toeic/w1.mp3',
          audioStartMs: 1200,
          audioEndMs: 8000,
        ),
      ],
    );

    await pumpToSession(
      tester,
      roomAdapter(
        writes: writes,
        take: take,
        onWrite: (options) => FakeHttpClientAdapter.jsonResponse(
          practiceGradedAnswer(
            isCorrect: null,
            responseText: 'I would like to confirm the schedule.',
            isSessionFinished: true,
          ),
        ),
      ),
    );

    // The word bounds and the keyword list carry the backend's own names.
    expect(find.text('MIN 10 WORDS'), findsOneWidget);
    expect(find.text('MAX 40 WORDS'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('CONFIRM'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('writing-response-input')),
      'I would like to confirm the schedule for our Tuesday meeting.',
    );
    await tester.pumpAndSettle();
    expect(find.text('11 WORDS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('CHECK ANSWER'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pumpAndSettle();

    final answer = writes.singleWhere((r) => r.path.endsWith('/answer'));
    // The address is the pinned item version, and the body carries the text.
    expect(answer.path, '/api/learner/practice/sessions/17/questions/61/answer');
    final body = answer.data as Map<String, dynamic>;
    expect(
      body['responseText'],
      'I would like to confirm the schedule for our Tuesday meeting.',
    );
    expect(body.containsKey('selectedOptionId'), isFalse);

    // An ungraded productive answer is recorded, not called wrong.
    expect(find.text('ANSWER RECORDED'), findsOneWidget);
    expect(find.text('INCORRECT'), findsNothing);
  });

  testWidgets('a productive question sends nothing when the text is empty',
      (tester) async {
    final writes = <RequestOptions>[];
    final take = practiceTakeResponse(
      session: practiceSession(
        sessionId: 17,
        sectionId: 13,
        sectionCode: 'W1',
        sectionName: 'Write a sentence',
        modality: 'writing',
      ),
      questions: [
        practiceQuestion(
          itemVersionId: 61,
          displayOrder: 1,
          questionType: 'free_response',
          stem: 'Write a sentence.',
          minWords: 5,
        ),
      ],
    );
    await pumpToSession(tester, roomAdapter(writes: writes, take: take));

    // Nothing typed: the submit control is inert.
    await tester.scrollUntilVisible(
      find.text('CHECK ANSWER'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('CHECK ANSWER'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(writes.where((r) => r.path.endsWith('/answer')), isEmpty);
  });

  testWidgets('the room offers no question-source or feedback-timing control',      (tester) async {
    final writes = <RequestOptions>[];
    final starts = <RequestOptions>[];
    await pumpToSession(
      tester,
      roomAdapter(writes: writes, starts: starts),
    );

    // The backend ignores both fields, so the app must not present them.
    expect(find.text('QUESTION SOURCE'), findsNothing);
    expect(find.text('FEEDBACK MODE'), findsNothing);
    expect(find.text('WRONG ONLY'), findsNothing);
    expect(find.text('END OF SESSION'), findsNothing);
    expect(find.text('SESSION CONFIGURATION'), findsNothing);

    // And the start request carries neither field.
    expect(starts, hasLength(1));
    final body = starts.single.data as Map<String, dynamic>;
    expect(body.containsKey('questionSource'), isFalse);
    expect(body.containsKey('feedbackMode'), isFalse);
    expect(body['sectionId'], 2);
  });
}
