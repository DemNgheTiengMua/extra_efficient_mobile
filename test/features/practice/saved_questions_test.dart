import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/practice_payloads.dart';

const _row4 = '''
{"savedQuestionId":4,"questionId":null,"itemId":3,"itemVersionId":3,
 "isRetiredDefective":false,"source":"manual","savedAt":"2026-11-13T15:57:13.8863723+00:00",
 "sectionId":5,"sectionCode":"P5","sectionName":"Incomplete Sentences",
 "topicCode":null,"topicName":null,
 "categoryId":10,"categoryName":"Prepositions",
 "stem":"Look at the photograph and choose the statement that best describes what you see in the image.",
 "passage":null,"imagePath":"/img/part1-sample.svg","audioPath":"/audio/toeic/test1-p1.mp3",
 "hint":"Focus on what the person in the centre is holding and doing.",
 "explanation":"Option C correctly describes the action: the woman is writing notes on the whiteboard.",
 "transcript":null,
 "options":[{"optionId":31,"label":"A","text":"They are leaving the meeting room.","isCorrect":false},
            {"optionId":33,"label":"C","text":"A woman is writing on a whiteboard.","isCorrect":true}],
 "scopeCode":"P5","scopeName":"Incomplete Sentences"}
''';

const _row2 = '''
{"savedQuestionId":2,"questionId":null,"itemId":1,"itemVersionId":1,
 "isRetiredDefective":false,"source":"incorrect","savedAt":"2026-11-07T01:44:02.8671889+07:00",
 "sectionId":null,"sectionCode":null,"sectionName":null,
 "topicCode":"L-DET","topicName":"Explicit factual detail and extraction",
 "categoryId":null,"categoryName":null,
 "stem":"On what date will the festival open?",
 "passage":null,"imagePath":null,"audioPath":"/audio/vstep/sample1-listening.mp3",
 "hint":null,"explanation":"The speaker explicitly states June 8th.",
 "transcript":"Speaker: Good afternoon listeners.",
 "options":[{"optionId":12,"label":"B","text":"June 8th","isCorrect":true}],
 "scopeCode":"L-DET","scopeName":"Explicit factual detail and extraction"}
''';

String _detail4() => _row4;

String _detail2() => _row2;

String _categories() => '''
[{"categoryId":10,"name":"Prepositions","count":1},
 {"categoryId":11,"name":"Word Forms","count":0}]
''';

String _oneSavedQuestion() => '''
{
  "certificate": {"code":"TOEIC","name":"TOEIC Listening & Reading","sectionNoun":"Part"},
  "totalSavedCount": 1, "manualSavedCount": 0, "incorrectSavedCount": 1,
  "questions": [$_row2],
  "sections": [{"sectionId":5,"code":"P5","name":"Incomplete Sentences","count":1}],
  "categories": ${_categories()}
}
''';

String _twoSavedQuestions() => '''
{
  "certificate": {"code":"TOEIC","name":"TOEIC Listening & Reading","sectionNoun":"Part"},
  "totalSavedCount": 2, "manualSavedCount": 1, "incorrectSavedCount": 1,
  "questions": [$_row4, $_row2],
  "sections": [{"sectionId":5,"code":"P5","name":"Incomplete Sentences","count":1}],
  "categories": ${_categories()}
}
''';

void main() {
  testWidgets(
      'Saved tab lists the backend questions, opens detail with explanation and audio, and removes an item',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final fakeAudio = FakeAudioMediaAdapter();
    String? lastSectionFilter;
    bool deleted4 = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'email': 'learner@demo.local',
          'fullName': 'Demo Learner',
          'role': 'learner',
          'emailVerified': true,
          'permissions': [],
          'held': [],
        });
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse({
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
        });
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse(
          practiceCatalogResponse(sections: const []),
        );
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse(const <dynamic>[]);
      }
      if (options.path == '/api/learner/saved-questions' &&
          options.method == 'GET') {
        lastSectionFilter = options.queryParameters['sectionId']?.toString();
        return FakeHttpClientAdapter.rawJsonResponse(
          deleted4
              ? _oneSavedQuestion()
              : _twoSavedQuestions(),
        );
      }
      if (options.path == '/api/learner/saved-questions/4' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.rawJsonResponse(_detail4());
      }
      if (options.path == '/api/learner/saved-questions/2' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.rawJsonResponse(_detail2());
      }
      if (options.path == '/api/learner/saved-questions/4' &&
          options.method == 'DELETE') {
        deleted4 = true;
        return FakeHttpClientAdapter.jsonResponse({
          'isSaved': false,
          'source': null,
          'savedAt': null,
          'savedQuestionId': null,
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

    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVED'));
    await tester.pumpAndSettle();

    // Both rows come from the `questions` key, and the pool item shows the
    // server's topic scope rather than an absent section.
    expect(
      find.text(
        'Look at the photograph and choose the statement that best describes '
        'what you see in the image.',
      ),
      findsOneWidget,
    );
    expect(find.text('On what date will the festival open?'), findsOneWidget);
    expect(find.text('INCOMPLETE SENTENCES'), findsOneWidget);
    expect(
      find.text('EXPLICIT FACTUAL DETAIL AND EXTRACTION'),
      findsOneWidget,
    );
    expect(lastSectionFilter, isNull);

    // The pool row's detail is the same shape as a list row: explanation,
    // options and audio under the backend's own key names.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved-question-2')));
    await tester.pumpAndSettle();
    expect(find.text('The speaker explicitly states June 8th.'), findsOneWidget);
    expect(find.text('B. June 8th'), findsOneWidget);
    expect(
      find.text('Speaker: Good afternoon listeners.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('saved-detail-play-audio')));
    await tester.pumpAndSettle();
    expect(fakeAudio.lastLoadedUrl, '/audio/vstep/sample1-listening.mp3');
    expect(fakeAudio.isPlaying, isTrue);
    await tester.tap(find.byKey(const Key('saved-detail-close')));
    await tester.pumpAndSettle();

    // The backend ignores `?sectionId`, so the chip narrows the fetched rows.
    await tester.tap(find.byKey(const Key('saved-filter-section-5')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Look at the photograph and choose the statement that best describes '
        'what you see in the image.',
      ),
      findsOneWidget,
    );
    expect(find.text('On what date will the festival open?'), findsNothing);

    await tester.tap(find.byKey(const Key('delete-saved-4')));
    await tester.pumpAndSettle();
    expect(deleted4, isTrue);
    expect(find.text('Nothing matches these filters'), findsOneWidget);
  });

  testWidgets(
      'a filter that matches nothing says so instead of showing the empty bank',
      (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'email': 'learner@demo.local',
          'fullName': 'Demo Learner',
          'role': 'learner',
          'emailVerified': true,
          'permissions': [],
          'held': [],
        });
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse({
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
        });
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse({
          'sectionNoun': 'Part',
          'sections': [],
        });
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse({'levels': [], 'topics': []});
      }
      if (options.path == '/api/learner/saved-questions' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.rawJsonResponse(_twoSavedQuestions());
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVED'));
    await tester.pumpAndSettle();

    // No saved row carries category 11 (the pool item's category is null).
    await tester.tap(find.byKey(const Key('saved-filter-category-11')));
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches these filters'), findsOneWidget);
    expect(find.text('No saved questions'), findsNothing);
  });

  testWidgets(
      'saving a pool item during a drill posts the item version and the item then appears in SAVED',
      (tester) async {
    bool savedViaItemVersion = false;
    bool savedViaQuestionRoute = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'email': 'learner@demo.local',
          'fullName': 'Demo Learner',
          'role': 'learner',
          'emailVerified': true,
          'permissions': [],
          'held': [],
        });
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse({
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
        });
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse({
          'sectionNoun': 'Part',
          'sections': [
            {
              'sectionId': 5,
              'title': 'Part 5: Incomplete Sentences',
              'skill': 'reading',
              'accuracyPercent': null,
              'cooldownActive': false,
              'isSpeaking': false,
            },
          ],
        });
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse({'levels': [], 'topics': []});
      }
      if (options.path == '/api/learner/practice/sessions' &&
          options.method == 'POST') {
        return FakeHttpClientAdapter.jsonResponse({
          'sessionId': 4,
          'sectionCode': 'P5',
          'sectionName': 'Incomplete Sentences',
        });
      }
      if (options.path == '/api/learner/practice/sessions/4/take') {
        return FakeHttpClientAdapter.rawJsonResponse('''
        {"session":{"sessionId":4,"sectionId":5,"sectionCode":"P5",
                    "sectionName":"Incomplete Sentences","modality":"reading",
                    "questionCount":1,"status":"in_progress","correctCount":0,
                    "questionSource":"all","startedAt":"2026-11-13T16:03:52+00:00",
                    "finishedAt":null,"topicId":null,"cefrLevelCode":null,"isShort":false},
         "question":{"sessionId":4,"sectionName":"Incomplete Sentences","questionId":null,
                     "displayOrder":1,"totalQuestions":1,
                     "stem":"All client inquiries must be resolved ------- forty-eight hours of submission.",
                     "categoryName":null,"hint":null,"hintUsed":false,
                     "options":[{"optionId":81,"label":"A","text":"in"},
                                {"optionId":84,"label":"D","text":"within"}],
                     "selectedOptionId":null,"isCorrect":null,"correctOptionId":null,
                     "explanation":null,"transcript":null,"passage":null,"audioPath":null,
                     "imagePath":null,"imageAlt":null,"isSaved":false,"audioStartMs":null,
                     "audioEndMs":null,"questionType":"mcq","maxSelections":null,
                     "allowNumber":true,"acceptedAnswersJson":null,"requiredKeywords":null,
                     "minWords":null,"maxWords":null,"responseText":null,"selectedOptionIds":[],
                     "selectedOptionIdsJson":null,"correctOptionIds":[],"itemVersionId":8,
                     "savedQuestionId":null,"cefrLevelCode":null,"address":8},
         "questions":[{"sessionId":4,"sectionName":"Incomplete Sentences","questionId":null,
                     "displayOrder":1,"totalQuestions":1,
                     "stem":"All client inquiries must be resolved ------- forty-eight hours of submission.",
                     "categoryName":null,"hint":null,"hintUsed":false,
                     "options":[{"optionId":81,"label":"A","text":"in"},
                                {"optionId":84,"label":"D","text":"within"}],
                     "selectedOptionId":null,"isCorrect":null,"correctOptionId":null,
                     "explanation":null,"transcript":null,"passage":null,"audioPath":null,
                     "imagePath":null,"imageAlt":null,"isSaved":false,"audioStartMs":null,
                     "audioEndMs":null,"questionType":"mcq","maxSelections":null,
                     "allowNumber":true,"acceptedAnswersJson":null,"requiredKeywords":null,
                     "minWords":null,"maxWords":null,"responseText":null,"selectedOptionIds":[],
                     "selectedOptionIdsJson":null,"correctOptionIds":[],"itemVersionId":8,
                     "savedQuestionId":null,"cefrLevelCode":null,"address":8}],
         "navigator":[{"questionId":null,"displayOrder":1,"isAnswered":false,"isCorrect":null,
                       "isSaved":false,"isCurrent":true,"itemVersionId":8,
                       "savedQuestionId":null,"address":8}]}
        ''');
      }
      if (options.path.startsWith(
              '/api/learner/saved-questions/item-versions/') &&
          options.method == 'POST') {
        savedViaItemVersion =
            options.path == '/api/learner/saved-questions/item-versions/8';
        return FakeHttpClientAdapter.jsonResponse({
          'isSaved': true,
          'source': 'manual',
          'savedAt': '2026-11-13T17:16:56.8643227+00:00',
          'savedQuestionId': 6,
        });
      }
      if (options.path.startsWith('/api/learner/saved-questions/questions/') &&
          options.method == 'POST') {
        savedViaQuestionRoute = true;
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
      if (options.path == '/api/learner/saved-questions' &&
          options.method == 'GET') {
        // The drill save is now in the bank.
        if (!savedViaItemVersion) {
          return FakeHttpClientAdapter.rawJsonResponse(
            '{"certificate":{"code":"TOEIC","name":"TOEIC Listening & Reading",'
            '"sectionNoun":"Part"},"totalSavedCount":0,"manualSavedCount":0,'
            '"incorrectSavedCount":0,"questions":[],"sections":[],"categories":[]}',
          );
        }
        return FakeHttpClientAdapter.rawJsonResponse('''
        {"certificate":{"code":"TOEIC","name":"TOEIC Listening & Reading","sectionNoun":"Part"},
         "totalSavedCount":1,"manualSavedCount":1,"incorrectSavedCount":0,
         "questions":[{"savedQuestionId":6,"questionId":null,"itemId":3,"itemVersionId":8,
           "isRetiredDefective":false,"source":"manual",
           "savedAt":"2026-11-13T17:16:56.8643227+00:00",
           "sectionId":null,"sectionCode":null,"sectionName":null,
           "topicCode":"R-DET","topicName":"Local factual retrieval and paraphrase matching",
           "categoryId":null,"categoryName":null,
           "stem":"All client inquiries must be resolved ------- forty-eight hours of submission.",
           "passage":null,"imagePath":null,"audioPath":null,"hint":null,
           "explanation":"Only 'within' marks a window ending at a deadline.",
           "transcript":null,
           "options":[{"optionId":81,"label":"A","text":"in","isCorrect":false},
                      {"optionId":84,"label":"D","text":"within","isCorrect":true}],
           "scopeCode":"R-DET","scopeName":"Local factual retrieval and paraphrase matching"}],
         "sections":[],"categories":[]}
        ''');
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
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
      find.byKey(const Key('start-section-5')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('start-section-5')));
    await tester.pumpAndSettle();

    // A pool item has no question row; the bookmark names the item version.
    await tester.tap(find.byKey(const Key('bookmark-question-8')));
    await tester.pumpAndSettle();

    expect(savedViaItemVersion, isTrue);
    expect(
      savedViaQuestionRoute,
      isFalse,
      reason: 'a pool item must not be filed against a question row id',
    );

    // The bookmark button now reads SAVED too, so leave the room by its key
    // rather than hunting for that text.
    await tester.tap(find.byKey(const Key('session-back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVED'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'All client inquiries must be resolved ------- forty-eight hours of submission.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('LOCAL FACTUAL RETRIEVAL AND PARAPHRASE MATCHING'),
      findsOneWidget,
    );
  });

  testWidgets(
      'an empty bank shows the explicit empty state, with no filter panel',
      (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 3,
          'email': 'learner.fresh@demo.local',
          'fullName': 'Fresh Learner',
          'role': 'learner',
          'emailVerified': true,
          'permissions': [],
          'held': [],
        });
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse({
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
          'creditBalance': 0,
          'examinedSkills': ['listening', 'reading'],
          'examDate': null,
        });
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse({
          'sectionNoun': 'Part',
          'sections': [],
        });
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse({'levels': [], 'topics': []});
      }
      if (options.path == '/api/learner/saved-questions' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.rawJsonResponse('''
        {"certificate":{"code":"TOEIC","name":"TOEIC Listening & Reading","sectionNoun":"Part"},
         "totalSavedCount":0,"manualSavedCount":0,"incorrectSavedCount":0,
         "questions":[],"sections":[],"categories":[]}
        ''');
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVED'));
    await tester.pumpAndSettle();

    expect(find.text('No saved questions'), findsOneWidget);
    expect(find.text('FILTERS'), findsNothing);
  });

  testWidgets('a failed removal reports the backend message and keeps the row',
      (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'email': 'learner@demo.local',
          'fullName': 'Demo Learner',
          'role': 'learner',
          'emailVerified': true,
          'permissions': [],
          'held': [],
        });
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse({
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
        });
      }
      if (options.path == '/api/learner/practice/catalog') {
        return FakeHttpClientAdapter.jsonResponse({
          'sectionNoun': 'Part',
          'sections': [],
        });
      }
      if (options.path == '/api/learner/practice/matrix') {
        return FakeHttpClientAdapter.jsonResponse({'levels': [], 'topics': []});
      }
      if (options.path == '/api/learner/saved-questions' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.rawJsonResponse(_twoSavedQuestions());
      }
      if (options.path == '/api/learner/saved-questions/4' &&
          options.method == 'DELETE') {
        return FakeHttpClientAdapter.jsonResponse(
          {
            'title': 'Saved question not found',
            'status': 404,
            'code': 'SAVED_QUESTION_NOT_FOUND',
          },
          statusCode: 404,
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PRACTICE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVED'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete-saved-4')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saved-error')), findsOneWidget);
    expect(find.text('Saved question not found'), findsOneWidget);
    expect(
      find.text('On what date will the festival open?'),
      findsOneWidget,
      reason: 'a failed removal must not drop the row',
    );
  });
}
