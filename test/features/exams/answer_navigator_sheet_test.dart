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
  testWidgets(
      '10-column AnswerNavigatorSheet shows cell states, filters Only Flagged, and jumps to question',
      (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final audioAdapter = FakeAudioMediaAdapter();

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/take/555' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'placementId': 555,
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 20))
              .toIso8601String(),
          'status': 'in_progress',
          'questions': [
            {
              'questionId': 1,
              'index': 0,
              'skill': 'reading',
              'sectionName': 'Part 5',
              'prompt': 'Question 1 prompt',
              'options': [
                {'optionId': 11, 'label': 'A', 'text': 'Opt A'},
                {'optionId': 12, 'label': 'B', 'text': 'Opt B'},
              ],
              'selectedOptionId': 11,
              'isFlagged': false,
            },
            {
              'questionId': 2,
              'index': 1,
              'skill': 'reading',
              'sectionName': 'Part 5',
              'prompt': 'Question 2 prompt',
              'options': [
                {'optionId': 21, 'label': 'A', 'text': 'Opt A'},
                {'optionId': 22, 'label': 'B', 'text': 'Opt B'},
              ],
              'isFlagged': true,
            },
            {
              'questionId': 3,
              'index': 2,
              'skill': 'reading',
              'sectionName': 'Part 5',
              'prompt': 'Question 3 prompt',
              'options': [
                {'optionId': 31, 'label': 'A', 'text': 'Opt A'},
                {'optionId': 32, 'label': 'B', 'text': 'Opt B'},
              ],
              'isFlagged': false,
            },
          ],
        });
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    final router = GoRouter(
      initialLocation: '/placement/take/555',
      routes: [
        GoRoute(
          path: '/placement/take/:placementId',
          builder: (context, state) => const PlacementExamRoomScreen(
            placementId: 555,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    await tester.pumpAndSettle();

    // Open AnswerNavigatorSheet via GRID button
    await tester.tap(find.byKey(const Key('exam-grid-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('answer-navigator-sheet')), findsOneWidget);
    expect(find.byKey(const Key('nav-cell-0')), findsOneWidget);
    expect(find.byKey(const Key('nav-cell-1')), findsOneWidget);
    expect(find.byKey(const Key('nav-cell-2')), findsOneWidget);

    // Verify 10-column GridView
    final gridView = tester.widget<GridView>(
      find.byKey(const Key('answer-navigator-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 10);

    // Verify cell colors: cell 0 answered (#14181d), cell 1 flagged (#f2b705)
    final cell0Decoration = tester
        .widget<Container>(find.byKey(const Key('nav-cell-0')))
        .decoration as BoxDecoration;
    expect(cell0Decoration.color, SignageColors.ink);

    final cell1Decoration = tester
        .widget<Container>(find.byKey(const Key('nav-cell-1')))
        .decoration as BoxDecoration;
    expect(cell1Decoration.color, SignageColors.signGold);

    // Toggle Only Flagged -> only cell 1 remains visible
    await tester.tap(find.byKey(const Key('only-flagged-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-cell-0')), findsNothing);
    expect(find.byKey(const Key('nav-cell-1')), findsOneWidget);
    expect(find.byKey(const Key('nav-cell-2')), findsNothing);

    // Tap cell 1 -> jumps to Q2 and closes sheet
    await tester.tap(find.byKey(const Key('nav-cell-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('answer-navigator-sheet')), findsNothing);
    expect(find.text('Question 2 prompt'), findsOneWidget);
  });
}
