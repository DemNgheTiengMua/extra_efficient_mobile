import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  testWidgets(
      'Weakness Analysis sub-tab renders section & category accuracy tables with strongest/weakest badges and resolves recommendations',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    bool resolved301 = false;

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
      if (options.path == '/api/learner/weakness-analysis' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'sections': [
            {
              'name': 'Part 2: Question-Response',
              'accuracyPercent': 42,
              'answeredCount': 24,
              'isWeakest': true,
              'isStrongest': false,
            },
            {
              'name': 'Part 5: Incomplete Sentences',
              'accuracyPercent': 88,
              'answeredCount': 40,
              'isWeakest': false,
              'isStrongest': true,
            },
          ],
          'categories': [
            {
              'name': 'Wh-Questions',
              'accuracyPercent': 40,
              'answeredCount': 15,
              'isWeakest': true,
              'isStrongest': false,
            },
            {
              'name': 'Verb Tenses',
              'accuracyPercent': 90,
              'answeredCount': 20,
              'isWeakest': false,
              'isStrongest': true,
            },
          ],
          'recommendations': [
            {
              'recId': 301,
              'title': 'Focus on Wh-Questions',
              'description': 'Accuracy is 40% across 15 items.',
              'resolved': resolved301,
            },
          ],
        });
      }
      if (options.path == '/api/learner/recommendations/301/resolve' &&
          options.method == 'POST') {
        resolved301 = true;
        return FakeHttpClientAdapter.jsonResponse(null, statusCode: 204);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
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

    expect(find.text('Part 2: Question-Response'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('WEAKEST'), findsWidgets);
    expect(find.text('Part 5: Incomplete Sentences'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('STRONGEST'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Wh-Questions'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Wh-Questions'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('resolve-rec-301')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('resolve-rec-301')));
    await tester.pumpAndSettle();

    expect(resolved301, isTrue);
    expect(find.text('RESOLVED'), findsOneWidget);
  });
}
