import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/router/app_router.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';

import '../../helpers/fake_http_adapter.dart';

/// The backend hands the app navigation URLs, and may name a destination this
/// build has not registered (its NEXT ACTION url is free text). A blank page
/// there looks like a broken app, so the router's fallback must explain itself.
void main() {
  testWidgets(
      'an unregistered destination renders an explanation and a way home',
      (tester) async {
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
          'creditBalance': 11,
          'examinedSkills': ['listening', 'reading'],
        });
      }
      if (options.path == '/api/learner/dashboard') {
        return FakeHttpClientAdapter.jsonResponse({
          'goal': {'currentBandCode': null, 'targetBandCode': null},
          'skills': <dynamic>[],
          'nextAction': null,
        });
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

    // A destination the backend can emit but this build does not register.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExtraEfficientApp)),
    );
    container.read(appRouterProvider).go('/learning-path/steps/7');
    await tester.pumpAndSettle();

    expect(find.text('DESTINATION UNAVAILABLE'), findsOneWidget);
    expect(
      find.text('This destination is not available in this app'),
      findsOneWidget,
    );
    expect(find.textContaining('/learning-path/steps/7'), findsOneWidget);

    // The way home actually goes home.
    await tester.tap(find.byKey(const Key('unmatched-route-home')));
    await tester.pumpAndSettle();
    expect(find.text('DESTINATION UNAVAILABLE'), findsNothing);
  });
}
