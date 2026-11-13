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
      'Saved Questions sub-tab filters by section, opens detail with transcript & audio, and deletes item',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final fakeAudio = FakeAudioMediaAdapter();
    String? lastSectionFilter;
    bool deleted901 = false;

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
        lastSectionFilter = options.queryParameters['sectionId']?.toString();
        final items = <Map<String, dynamic>>[
          if (!deleted901 &&
              (lastSectionFilter == null || lastSectionFilter == '2'))
            {
              'savedQuestionId': 901,
              'questionId': 501,
              'sectionId': 2,
              'sectionTitle': 'Part 2',
              'categoryId': 10,
              'categoryName': 'Wh-Questions',
              'source': 'manual',
              'stem': 'Where is the conference room?',
            },
          if (lastSectionFilter == null || lastSectionFilter == '5')
            {
              'savedQuestionId': 902,
              'questionId': 502,
              'sectionId': 5,
              'sectionTitle': 'Part 5',
              'categoryId': 11,
              'categoryName': 'Prepositions',
              'source': 'wrong',
              'stem': 'The train departs ____ 8:00 AM.',
            },
        ];
        return FakeHttpClientAdapter.jsonResponse({
          'items': items,
          'sections': [
            {'sectionId': 2, 'title': 'Part 2'},
            {'sectionId': 5, 'title': 'Part 5'},
          ],
          'categories': [
            {'categoryId': 10, 'name': 'Wh-Questions'},
            {'categoryId': 11, 'name': 'Prepositions'},
          ],
        });
      }
      if (options.path == '/api/learner/saved-questions/901' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'savedQuestionId': 901,
          'stem': 'Where is the conference room?',
          'generalExplanation': 'Listen for floor or building location.',
          'transcript': 'W: Excuse me, where is the conference room? M: Second floor.',
          'audioUrl': 'https://cdn.local/saved-901.mp3',
          'options': [
            {'optionId': 1, 'label': 'A', 'text': 'On the second floor.', 'isCorrect': true},
            {'optionId': 2, 'label': 'B', 'text': 'At 3 PM.', 'isCorrect': false},
          ],
        });
      }
      if (options.path == '/api/learner/saved-questions/901' &&
          options.method == 'DELETE') {
        deleted901 = true;
        return FakeHttpClientAdapter.jsonResponse(null, statusCode: 204);
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

    expect(find.text('Where is the conference room?'), findsOneWidget);
    expect(find.text('The train departs ____ 8:00 AM.'), findsOneWidget);

    // Filter by Part 2
    await tester.tap(find.byKey(const Key('saved-filter-section-2')));
    await tester.pumpAndSettle();
    expect(lastSectionFilter, '2');
    expect(find.text('Where is the conference room?'), findsOneWidget);
    expect(find.text('The train departs ____ 8:00 AM.'), findsNothing);

    // Open detail
    await tester.tap(find.byKey(const Key('saved-question-901')));
    await tester.pumpAndSettle();
    expect(find.text('Listen for floor or building location.'), findsOneWidget);
    expect(
      find.text('W: Excuse me, where is the conference room? M: Second floor.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('saved-detail-play-audio')));
    await tester.pumpAndSettle();
    expect(fakeAudio.lastLoadedUrl, 'https://cdn.local/saved-901.mp3');
    expect(fakeAudio.isPlaying, isTrue);

    await tester.tap(find.byKey(const Key('saved-detail-close')));
    await tester.pumpAndSettle();

    // Delete 901
    await tester.tap(find.byKey(const Key('delete-saved-901')));
    await tester.pumpAndSettle();
    expect(deleted901, isTrue);
    expect(find.text('Where is the conference room?'), findsNothing);
  });
}
