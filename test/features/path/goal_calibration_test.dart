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
            'certificate': {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'nextAction': {
              'eyebrow': 'SET THE TARGET',
              'title': 'Choose the band you are working towards',
              'description': 'Goals turn practice into a plan.',
              'actionLabel': 'Set your target band',
              'actionUrl': '/placement/target-band',
              'severity': 'info',
              'cascadeStep': 'next_step',
              'metaLabel': 'NOW below_A1',
            },
            'goal': {
              'currentBandCode': 'below_A1',
              'currentBandName': 'Below A1',
              'currentScore': 10,
              'currentSource': 'mock',
              'targetBandCode': targetBand,
              'targetBandName': 'Intermediate',
              'completedPathSteps': 0,
              'totalPathSteps': 0,
              'scoreDisplayFactor': 1,
              'hasNoMeasurement': false,
            },
            'skills': <Map<String, dynamic>>[],
            'attemptCount': 1,
            'practiceCount': 0,
          });
        }
        if (options.path == '/api/learner/insights/dashboard') {
          return FakeHttpClientAdapter.jsonResponse({
            'status': 'done',
            'formattedNarrative': 'Steady progress.',
          });
        }
        if (options.path == '/api/learner/target-band' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'currentBandCode': 'B1',
            'targetBandCode': targetBand,
            'targetDate': '2026-12-20',
            'weeklyStudyHours': 8,
            'availableBands': [
            {
              'code': 'A1',
              'name': 'Beginner',
              'minTotal': 120,
              'maxTotal': 220,
              'description': '120 to 220 points',
              'isCurrent': false,
              'isTarget': false,
            },
            {
              'code': 'A2',
              'name': 'Elementary',
              'minTotal': 225,
              'maxTotal': 545,
              'description': '225 to 545 points',
              'isCurrent': false,
              'isTarget': false,
            },
            {
              'code': 'B1',
              'name': 'Intermediate',
              'minTotal': 550,
              'maxTotal': 780,
              'description': '550 to 780 points',
              'isCurrent': false,
              'isTarget': false,
            },
            {
              'code': 'B2',
              'name': 'Upper intermediate',
              'minTotal': 785,
              'maxTotal': 940,
              'description': '785 to 940 points',
              'isCurrent': false,
              'isTarget': false,
            },
            {
              'code': 'C1',
              'name': 'Advanced',
              'minTotal': 945,
              'maxTotal': 990,
              'description': '945 to 990 points',
              'isCurrent': false,
              'isTarget': false,
            },
          ],
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
            'placedBandCode': 'below_A1',
            'placedBandName': 'Below A1',
            'validAnswerCount': 24,
            'requiredValidAnswerCount': 20,
            'excludedRushedCount': 1,
            'observedAccuracyPct': 88.5,
            'reason': 'above_threshold',
            'proposal': calibrationPending
                ? {
                    'proposedBandCode': 'C1',
                    'proposedBandName': 'Advanced',
                    'observedAccuracyPct': 88.5,
                    'validAnswerCount': 24,
                    'requiredAccuracyPct': 85,
                    'evidence':
                        'Recent mock scores exceed B2 threshold on 24 answers.',
                  }
                : null,
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
            'decision': calibrationDecisionPayload!['adjust'] == true
                ? 'adjusted'
                : 'kept',
            'placedBandCode': 'below_A1',
            'proposedBandCode': 'C1',
            'pathAdjusted': calibrationDecisionPayload!['adjust'] == true,
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

      final goalBtn = find.byKey(const Key('open-goal-calibration-btn'));
      await tester.scrollUntilVisible(goalBtn, 200);
      await tester.pumpAndSettle();
      await tester.tap(goalBtn);
      await tester.pumpAndSettle();

      expect(find.text('TARGET BAND & STUDY GOAL'), findsOneWidget);

      final goalScrollable = find
          .descendant(
            of: find.byType(GoalCalibrationScreen),
            matching: find.byType(Scrollable),
          )
          .first;

      await tester.scrollUntilVisible(
        find.text('SUGGESTED TARGET: ADVANCED'),
        200,
        scrollable: goalScrollable,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Recent mock scores exceed B2 threshold on 24 answers.'),
        findsOneWidget,
      );
      expect(find.text('SUGGESTED TARGET: ADVANCED'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('target-band-C1')),
        -200,
        scrollable: goalScrollable,
      );
      await tester.pumpAndSettle();

      // Select C1 target band and update weekly hours.
      await tester.tap(find.byKey(const Key('target-band-C1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('weekly-hours-input')), '10');
      await tester.pumpAndSettle();

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
