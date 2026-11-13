import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  testWidgets('switching active Certificate in ACCOUNT calls PUT /api/learner/active-certificate and refreshes tabs', (tester) async {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    var activeCode = 'TOEIC';
    String? switchedTo;

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
      if (options.path == '/api/learner/context' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'active': {
            'code': activeCode,
            'name': activeCode == 'IELTS'
                ? 'IELTS Academic & General'
                : 'TOEIC Listening & Reading',
            'sectionNoun': activeCode == 'IELTS' ? 'Section' : 'Part',
          },
          'certificates': [
            {'code': 'TOEIC', 'name': 'TOEIC Listening & Reading', 'sectionNoun': 'Part'},
            {'code': 'IELTS', 'name': 'IELTS Academic & General', 'sectionNoun': 'Section'},
            {'code': 'VSTEP', 'name': 'VSTEP — the Vietnamese national test', 'sectionNoun': 'Section'},
            {'code': 'TOEIC_SW', 'name': 'TOEIC Speaking & Writing', 'sectionNoun': 'Part'},
            {'code': 'TOEIC_CAT', 'name': 'TOEIC Multi-Stage Adaptive CAT', 'sectionNoun': 'Part'},
          ],
          'creditBalance': 13,
          'examinedSkills': ['listening', 'reading'],
          'examDate': null,
        });
      }
      if (options.path == '/api/learner/active-certificate' && options.method == 'PUT') {
        switchedTo = body['code'] as String;
        activeCode = switchedTo!;
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

    // Initially PATH tab shows TOEIC.
    expect(find.textContaining('TOEIC'), findsWidgets);

    // Switch to ACCOUNT tab and select IELTS.
    await tester.tap(find.text('ACCOUNT'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cert-option-IELTS')));
    await tester.pumpAndSettle();

    expect(switchedTo, 'IELTS');

    // Return to PATH tab and confirm it now reflects IELTS.
    await tester.tap(find.text('PATH'));
    await tester.pumpAndSettle();
    expect(find.textContaining('IELTS Academic & General'), findsOneWidget);
  });
}
