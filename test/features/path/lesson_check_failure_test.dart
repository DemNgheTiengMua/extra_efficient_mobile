import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';

import '../../helpers/fake_http_adapter.dart';
import 'path_fixtures.dart';

/// A micro-check is a write. A refusal must say so rather than leave the card
/// looking unanswered with no explanation.
void main() {
  testWidgets(
      'a failed micro-check reports the backend message and stays submit-able',
      (tester) async {
    var attempts = 0;
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'email': 'learner@demo.local',
          'fullName': 'Demo Learner',
          'role': 'learner',
          'emailVerified': true,
          'permissions': <String>[],
          'held': <String>[],
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
        });
      }
      if (options.path == '/api/learner/dashboard') {
        return FakeHttpClientAdapter.jsonResponse({
          ...dashboardMeasuredPayload(),
          'nextAction': {
            'eyebrow': 'PICK UP YOUR PLAN',
            'title': 'Quick Check',
            'description': 'Resume lesson',
            'actionLabel': 'Open this step',
            'actionUrl': '/path/lessons/14',
            'severity': 'info',
            'cascadeStep': 'next_step',
            'metaLabel': 'WEEK 1',
          },
        });
      }
      if (options.path == '/api/learner/insights/dashboard') {
        return FakeHttpClientAdapter.jsonResponse(
          dashboardInsightPendingPayload(),
        );
      }
      if (options.path == '/api/learner/lessons/14' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'id': 14,
          'title': 'Subject-Verb Agreement',
          'cards': [
            {
              'id': 203,
              'type': 'micro_check',
              'title': 'Quick Check',
              'question': 'The list of items ___ on the desk.',
              'options': ['is', 'are'],
            },
          ],
        });
      }
      if (options.path == '/api/learner/lessons/14/progress' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'viewedCount': 0,
          'totalCount': 1,
          'lastViewedCardIndex': 0,
          'completed': false,
        });
      }
      if (options.path == '/api/learner/lessons/14/cards/203/micro-check') {
        attempts++;
        return FakeHttpClientAdapter.jsonResponse({
          'title': 'Lesson error',
          'status': 409,
          'detail': 'This micro-check was already answered.',
          'code': 'VALIDATION',
        }, statusCode: 409);
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

    await tester.tap(find.byKey(const Key('next-action-btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('micro-option-is')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('micro-check-submit-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lesson-check-error')), findsOneWidget);
    expect(find.text('This micro-check was already answered.'), findsOneWidget);

    // The control is offered again rather than left spinning.
    await tester.tap(find.byKey(const Key('micro-check-submit-btn')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
