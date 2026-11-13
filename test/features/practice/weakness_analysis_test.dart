import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/practice/models/practice_models.dart';
import '../../helpers/fake_http_adapter.dart';

/// The shape `GET /api/learner/weakness-analysis` really returns, recorded from the running
/// backend (`Contracts/WeaknessAnalysis/*.cs`). An invented `categories` array is included so the
/// widget tests can prove that axis is not rendered.
Map<String, dynamic> weaknessPayload({
  bool hasData = true,
  bool resolved = false,
}) {
  return {
    'certificate': {
      'code': 'TOEIC',
      'name': 'TOEIC Listening & Reading',
      'sectionNoun': 'Part',
    },
    'hasData': hasData,
    'gradedExamCount': 3,
    'completedPracticeCount': 2,
    'totalAnswered': 64,
    'totalCorrect': 40,
    'overallAccuracyPercentage': 63,
    'sections': [
      {
        'sectionId': 2,
        'code': 'P2',
        'name': 'Question-Response',
        'answered': 24,
        'correct': 10,
        'accuracyPercentage': 42,
        'isWeakest': true,
        'isStrongest': false,
      },
      {
        'sectionId': 5,
        'code': 'P5',
        'name': 'Incomplete Sentences',
        'answered': 40,
        'correct': 35,
        'accuracyPercentage': 88,
        'isWeakest': false,
        'isStrongest': true,
      },
      {
        'sectionId': 1,
        'code': 'P1',
        'name': 'Photographs',
        'answered': 0,
        'correct': 0,
        'accuracyPercentage': 0,
        'isWeakest': false,
        'isStrongest': false,
      },
    ],
    'frequentlyMissedTopics': [
      {
        'topicId': 9,
        'topicCode': 'L-DET',
        'topicName': 'Spoken detail recognition',
        'modality': 'listening',
        'levelCode': 'B1',
        'answered': 12,
        'correct': 3,
        'accuracyPercent': 25,
        'isWeakest': true,
        'observationFloor': 12,
        'lessonId': 72,
      },
    ],
    'recommendations': [
      if (hasData && !resolved)
        {
          'recId': 301,
          'text': 'Focus on Wh-Questions in Part 2; accuracy is 42% across 24 items.',
          'severity': 'major',
          'targetBandCode': null,
          'skillName': 'Listening',
          'createdAt': '2026-11-13T10:16:04.7442627+00:00',
          'isResolved': false,
        },
    ],
    'priorityPracticeSection': null,
    'topics': [
      {
        'topicId': 8,
        'topicCode': 'R-DET',
        'topicName': 'Local factual retrieval and paraphrase matching',
        'modality': 'reading',
        'levelCode': 'B2',
        'answered': 14,
        'correct': 6,
        'accuracyPercent': 43,
        'isWeakest': true,
        'observationFloor': 12,
        'lessonId': 71,
      },
    ],
    'weakestTopic': null,
    // The retired axis: an invented list the app used to render as CATEGORY ACCURACY.
    'categories': [
      {
        'name': 'Wh-Questions',
        'accuracyPercent': 40,
        'answeredCount': 15,
        'isWeakest': true,
        'isStrongest': false,
      },
    ],
  };
}

FakeHttpClientAdapter weaknessAdapter({
  required bool Function() hasData,
  required bool Function() resolved,
  required List<RequestOptions> postSink,
  int resolveStatusCode = 200,
  void Function()? onResolved,
}) {
  return FakeHttpClientAdapter((options, body) async {
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
    if (options.path == '/api/learner/weakness-analysis' &&
        options.method == 'GET') {
      return FakeHttpClientAdapter.jsonResponse(
        weaknessPayload(hasData: hasData(), resolved: resolved()),
      );
    }
    if (options.path == '/api/learner/recommendations/301/resolve' &&
        options.method == 'POST') {
      postSink.add(options);
      if (resolveStatusCode != 200) {
        return FakeHttpClientAdapter.jsonResponse({
          'title': 'Recommendation not found',
          'status': resolveStatusCode,
          'detail': 'Recommendation 301 was not found for this learner.',
          'code': 'RECOMMENDATION_NOT_FOUND',
        }, statusCode: resolveStatusCode);
      }
      // The backend marks the row resolved, so the next GET no longer lists it.
      onResolved?.call();
      return FakeHttpClientAdapter.jsonResponse({'recId': 301, 'isResolved': true});
    }
    return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
  });
}

Future<void> pumpApp(WidgetTester tester, FakeHttpClientAdapter adapter) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
  await tester.tap(find.text('WEAKNESS'));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) {
  return tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
}

void main() {
  test('parses the recorded weakness payload under the backend field names', () {
    final data = WeaknessAnalysisData.fromJson(weaknessPayload());

    expect(data.hasData, isTrue);
    expect(data.sections, hasLength(3));

    final weakestSection = data.sections.first;
    expect(weakestSection.name, 'Question-Response');
    expect(weakestSection.code, 'P2');
    expect(weakestSection.answered, 24);
    expect(weakestSection.correct, 10);
    expect(weakestSection.accuracyPercentage, 42);
    expect(weakestSection.isWeakest, isTrue);
    expect(data.sections[1].isStrongest, isTrue);

    final rec = data.recommendations.single;
    expect(rec.recId, 301);
    expect(rec.text, contains('Wh-Questions'));
    expect(rec.severity, 'major');
    expect(rec.skillName, 'Listening');
    expect(rec.isResolved, isFalse);

    final topic = data.topics.single;
    expect(topic.topicName, 'Local factual retrieval and paraphrase matching');
    expect(topic.levelCode, 'B2');
    expect(topic.answered, 14);
    expect(topic.accuracyPercent, 43);
    expect(topic.isWeakest, isTrue);
  });

  testWidgets(
      'WEAKNESS shows real recommendation text, severity, skill, answered counts, marks and the topic axis',
      (tester) async {
    final adapter = weaknessAdapter(
      hasData: () => true,
      resolved: () => false,
      postSink: [],
    );

    await pumpApp(tester, adapter);

    // Section rows carry the backend's answered counts and accuracy figures.
    expect(find.text('Question-Response'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('24 ANSWERED'), findsOneWidget);
    expect(find.text('Incomplete Sentences'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('WEAKEST'), findsWidgets);
    expect(find.text('STRONGEST'), findsWidgets);

    // The topic axis the backend supplies is surfaced.
    await scrollTo(tester, find.text('Local factual retrieval and paraphrase matching'));
    expect(find.text('Local factual retrieval and paraphrase matching'), findsOneWidget);
    expect(find.text('43%'), findsOneWidget);

    // The invented category axis is gone.
    expect(find.text('CATEGORY ACCURACY'), findsNothing);
    expect(find.text('Wh-Questions'), findsNothing);

    // The recommendation shows its real text, severity and skill.
    await scrollTo(
      tester,
      find.textContaining('accuracy is 42% across 24 items'),
    );
    expect(
      find.textContaining('accuracy is 42% across 24 items'),
      findsOneWidget,
    );
    expect(find.text('MAJOR'), findsWidgets);
    expect(find.text('LISTENING'), findsWidgets);
  });

  testWidgets(
      'RESOLVE changes the panel and the resolved state survives a reload of the tab',
      (tester) async {
    var resolved = false;
    final posts = <RequestOptions>[];
    final adapter = weaknessAdapter(
      hasData: () => true,
      resolved: () => resolved,
      postSink: posts,
      // Mirror the backend: the POST flips the row, so the follow-up GET omits it.
      onResolved: () => resolved = true,
    );

    await pumpApp(tester, adapter);

    final recText = find.textContaining('accuracy is 42% across 24 items');
    await scrollTo(tester, recText);
    expect(recText, findsOneWidget);

    await scrollTo(tester, find.byKey(const Key('resolve-rec-301')));
    await tester.tap(find.byKey(const Key('resolve-rec-301')));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));

    // The panel visibly changes: the same recommendation now carries RESOLVED and no control.
    await tester.pumpAndSettle();
    expect(recText, findsOneWidget);
    expect(find.text('RESOLVED'), findsOneWidget);
    expect(find.byKey(const Key('resolve-rec-301')), findsNothing);

    // Reload the tab: the provider refetches and the resolved recommendation stays gone.
    await tester.tap(find.text('DRILLS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WEAKNESS'));
    await tester.pumpAndSettle();

    final gets = adapter.requests
        .where((r) =>
            r.path == '/api/learner/weakness-analysis' && r.method == 'GET')
        .length;
    expect(gets, greaterThanOrEqualTo(2));
    expect(find.byKey(const Key('resolve-rec-301')), findsNothing);
    expect(find.textContaining('accuracy is 42% across 24 items'), findsNothing);
  });

  testWidgets(
      'a failed RESOLVE reports the backend message and leaves the control usable',
      (tester) async {
    final posts = <RequestOptions>[];
    final adapter = weaknessAdapter(
      hasData: () => true,
      resolved: () => false,
      postSink: posts,
      resolveStatusCode: 404,
    );

    await pumpApp(tester, adapter);

    final button = find.byKey(const Key('resolve-rec-301'));
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    expect(find.text('Recommendation not found'), findsOneWidget);
    // The recommendation is still there, and its control is offered again.
    expect(find.textContaining('accuracy is 42% across 24 items'), findsOneWidget);
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(posts, hasLength(2));
  });

  testWidgets('a learner with no practice history sees an explicit empty state',
      (tester) async {
    final adapter = weaknessAdapter(
      hasData: () => false,
      resolved: () => false,
      postSink: [],
    );

    await pumpApp(tester, adapter);

    expect(find.textContaining('No practice history'), findsOneWidget);
    expect(find.text('Photographs'), findsNothing);
    expect(find.text('WEAKEST'), findsNothing);
  });
}
