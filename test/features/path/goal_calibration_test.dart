import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/path/screens/goal_calibration_screen.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  testWidgets(
    'Goal & Calibration screen saves target band, study goal, and submits calibration decision',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      Map<String, dynamic>? savedGoalPayload;
      Map<String, dynamic>? calibrationDecisionPayload;
      var calibrationPending = true;
      var targetBand = 'B2';

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
              'id': 1,
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'certificates': [
              {
                'id': 1,
                'code': 'TOEIC',
                'name': 'TOEIC Listening & Reading',
                'sectionNoun': 'Part',
              },
            ],
            'creditBalance': 13,
            'examinedSkills': ['listening', 'reading'],
            'examDate': '2026-12-20',
          });
        }
        if (options.path == '/api/learner/dashboard') {
          return FakeHttpClientAdapter.jsonResponse({
            'currentBandCode': 'B1',
            'targetBandCode': targetBand,
            'scaledScore': 620,
            'placementCompleted': true,
            'hasLearningPath': true,
          });
        }
        if (options.path == '/api/learner/insights/dashboard') {
          return FakeHttpClientAdapter.jsonResponse({
            'status': 'ready',
            'narrative': 'Steady progress.',
          });
        }
        if (options.path == '/api/learner/target-band' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'currentBandCode': 'B1',
            'targetBandCode': targetBand,
            'targetDate': '2026-12-20',
            'weeklyStudyHours': 8,
            'availableBands': ['A1', 'A2', 'B1', 'B2', 'C1'],
          });
        }
        if (options.path == '/api/learner/goal' && options.method == 'POST') {
          savedGoalPayload = Map<String, dynamic>.from(body as Map);
          targetBand = savedGoalPayload!['targetBandCode'] as String;
          return FakeHttpClientAdapter.jsonResponse({
            'currentBandCode': 'B1',
            'targetBandCode': targetBand,
            'targetDate': savedGoalPayload!['targetDate'],
            'weeklyStudyHours': savedGoalPayload!['weeklyStudyHours'],
          });
        }
        if (options.path == '/api/learner/calibration' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'pending': calibrationPending,
            'currentTargetBandCode': targetBand,
            'recommendedBandCode': 'C1',
            'reason': 'Recent mock scores exceed B2 threshold.',
          });
        }
        if (options.path == '/api/learner/calibration/decision' &&
            options.method == 'POST') {
          calibrationDecisionPayload = Map<String, dynamic>.from(body as Map);
          calibrationPending = false;
          if (calibrationDecisionPayload!['adjust'] == true) {
            targetBand = 'C1';
          }
          return FakeHttpClientAdapter.jsonResponse({
            'pending': false,
            'targetBandCode': targetBand,
          });
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(tokenStorage),
            httpClientAdapterProvider.overrideWithValue(adapter),
            audioMediaAdapterProvider.overrideWithValue(
              FakeAudioMediaAdapter(),
            ),
          ],
          child: const ExtraEfficientApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-goal-calibration-btn')));
      await tester.pumpAndSettle();

      expect(find.text('TARGET BAND & STUDY GOAL'), findsOneWidget);
      expect(
        find.text('Recent mock scores exceed B2 threshold.'),
        findsOneWidget,
      );

      // Select C1 target band and update weekly hours.
      await tester.tap(find.byKey(const Key('target-band-C1')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('weekly-hours-input')),
        '10',
      );
      await tester.pumpAndSettle();

      final goalScrollable = find
          .descendant(
            of: find.byType(GoalCalibrationScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final saveBtn = find.byKey(const Key('save-goal-btn'));
      await tester.scrollUntilVisible(saveBtn, 200, scrollable: goalScrollable);
      await tester.drag(goalScrollable, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedGoalPayload, isNotNull);
      expect(savedGoalPayload!['targetBandCode'], 'C1');
      expect(savedGoalPayload!['weeklyStudyHours'], 10);

      // Accept calibration recommendation.
      final acceptBtn = find.byKey(const Key('calibration-accept-btn'));
      await tester.scrollUntilVisible(
        acceptBtn,
        200,
        scrollable: goalScrollable,
      );
      await tester.drag(goalScrollable, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      expect(calibrationDecisionPayload, {'adjust': true});
      await tester.drag(goalScrollable, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('CALIBRATION APPLIED'), findsOneWidget);
    },
  );
}
