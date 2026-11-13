import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';

Map<String, dynamic> _contextPayload({String activeCode = 'TOEIC'}) => {
      'active': {
        'code': activeCode,
        'name': activeCode == 'IELTS'
            ? 'IELTS Academic & General'
            : 'TOEIC Listening & Reading',
        'sectionNoun': activeCode == 'IELTS' ? 'Section' : 'Part',
      },
      'certificates': [
        {
          'code': 'TOEIC',
          'name': 'TOEIC Listening & Reading',
          'sectionNoun': 'Part',
        },
        {
          'code': 'IELTS',
          'name': 'IELTS Academic & General',
          'sectionNoun': 'Section',
        },
        {
          'code': 'VSTEP',
          'name': 'VSTEP — the Vietnamese national test',
          'sectionNoun': 'Section',
        },
        {
          'code': 'TOEIC_SW',
          'name': 'TOEIC Speaking & Writing',
          'sectionNoun': 'Part',
        },
        {
          'code': 'TOEIC_CAT',
          'name': 'TOEIC Multi-Stage Adaptive CAT',
          'sectionNoun': 'Part',
        },
      ],
      'creditBalance': 13,
      'examinedSkills': ['listening', 'reading', 'speaking', 'writing'],
      'examDate': null,
    };

void main() {
  group('Auth Flows & 401 Redirect', () {
    testWidgets('learner signs in with standard form (no demo button), persists JWT, and lands in 5-tab shell', (tester) async {
      final tokenStorage = InMemoryTokenStorage();
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/auth/sign-in' && options.method == 'POST') {
          expect(body['email'], 'learner@demo.local');
          expect(body['password'], 'Demo1234!');
          return FakeHttpClientAdapter.jsonResponse({
            'token': 'jwt-token-1',
            'expiresAt': '2026-11-13T16:56:25Z',
            'user': {
              'userId': 2,
              'email': 'learner@demo.local',
              'fullName': 'Demo Learner',
              'role': 'learner',
              'emailVerified': true,
              'permissions': [],
              'held': [],
            },
          });
        }
        if (options.path == '/api/learner/context') {
          return FakeHttpClientAdapter.jsonResponse(_contextPayload());
        }
        return FakeHttpClientAdapter.jsonResponse({'error': 'Not found'}, statusCode: 404);
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

      // Standard sign-in form is shown; no 1-tap demo sign-in button.
      expect(find.text('SIGN IN'), findsWidgets);
      expect(find.textContaining('DEMO'), findsNothing);

      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), 'learner@demo.local');
      await tester.enterText(fields.at(1), 'Demo1234!');
      await tester.tap(find.byKey(const Key('sign-in-submit-button')));
      await tester.pumpAndSettle();

      expect(await tokenStorage.readToken(), 'jwt-token-1');
      // 5-tab shell + Credit balance pill visible.
      expect(find.text('PATH'), findsWidgets);
      expect(find.text('PRACTICE'), findsOneWidget);
      expect(find.text('EXAMS'), findsOneWidget);
      expect(find.text('WALLET'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('13 CREDITS'), findsOneWidget);
    });

    testWidgets('401 response clears token and redirects learner back to Sign-in', (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'stale-jwt');
      var return401 = false;

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
          if (return401) {
            return FakeHttpClientAdapter.jsonResponse(
              {'message': 'Unauthorized'},
              statusCode: 401,
            );
          }
          return FakeHttpClientAdapter.jsonResponse(_contextPayload());
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

      expect(find.text('13 CREDITS'), findsOneWidget);

      // Simulate token expiry on next context refresh (e.g. switching certificate).
      return401 = true;
      await tester.tap(find.text('ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('refresh-context-button')));
      await tester.pumpAndSettle();

      expect(await tokenStorage.readToken(), isNull);
      expect(find.byKey(const Key('sign-in-submit-button')), findsOneWidget);
    });

    testWidgets('register, verify email, and forgot/reset password screens submit expected API payloads', (tester) async {
      final tokenStorage = InMemoryTokenStorage();
      final calledPaths = <String>[];

      final adapter = FakeHttpClientAdapter((options, body) async {
        calledPaths.add('${options.method} ${options.path}');
        return FakeHttpClientAdapter.jsonResponse({'message': 'OK'});
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

      // Navigate to Register
      await tester.tap(find.byKey(const Key('go-register-button')));
      await tester.pumpAndSettle();
      final regFields = find.byType(EditableText);
      await tester.enterText(regFields.at(0), 'Nguyen Van A');
      await tester.enterText(regFields.at(1), 'a@example.com');
      await tester.enterText(regFields.at(2), '0901234567');
      await tester.enterText(regFields.at(3), 'Password123!');
      await tester.tap(find.byKey(const Key('register-terms-checkbox')));
      await tester.tap(find.byKey(const Key('register-submit-button')));
      await tester.pumpAndSettle();
      expect(calledPaths, contains('POST /api/auth/register'));

      // Navigate to Verify Email
      await tester.ensureVisible(find.byKey(const Key('go-verify-email-button')));
      await tester.tap(find.byKey(const Key('go-verify-email-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'verify-tok-1');
      await tester.tap(find.byKey(const Key('verify-email-submit-button')));
      await tester.pumpAndSettle();
      expect(calledPaths, contains('POST /api/auth/verify-email'));

      // Back to Sign In -> Forgot Password
      await tester.tap(find.byKey(const Key('back-to-sign-in-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('go-forgot-password-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'a@example.com');
      await tester.tap(find.byKey(const Key('forgot-password-submit-button')));
      await tester.pumpAndSettle();
      expect(calledPaths, contains('POST /api/auth/forgot-password'));

      // Reset password
      final resetFields = find.byType(EditableText);
      await tester.enterText(resetFields.at(1), 'reset-tok-1');
      await tester.enterText(resetFields.at(2), 'NewPass123!');
      await tester.ensureVisible(find.byKey(const Key('reset-password-submit-button')));
      await tester.tap(find.byKey(const Key('reset-password-submit-button')));
      await tester.pumpAndSettle();
      expect(calledPaths, contains('POST /api/auth/reset-password'));
    });
  });
}
