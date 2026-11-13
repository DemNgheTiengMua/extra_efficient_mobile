import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/path/models/path_models.dart';

import 'path_fixtures.dart';

void main() {
  group('LearnerDashboard.fromJson binds the dashboard envelope', () {
    test('reads the measured band from goal, not a top-level placeholder', () {
      final dashboard = LearnerDashboard.fromJson(dashboardMeasuredPayload());

      expect(dashboard.goal.currentBandCode, 'below_A1');
      expect(dashboard.goal.currentBandName, 'Below A1');
      expect(dashboard.goal.currentScoreText, '10');
      expect(dashboard.goal.hasNoMeasurement, isFalse);
      expect(dashboard.certificate.code, 'TOEIC');
    });

    test('reads skill measurements with their real level and score', () {
      final dashboard = LearnerDashboard.fromJson(dashboardMeasuredPayload());

      expect(dashboard.skills, hasLength(3));
      final listening = dashboard.skills[0];
      expect(listening.name, 'Listening');
      expect(listening.levelCode, 'A2');
      expect(listening.scoreText, '5');
      expect(listening.maxScoreText, '495');
      expect(listening.isMeasured, isTrue);
      expect(listening.isStale, isFalse);

      final reading = dashboard.skills[1];
      expect(reading.weakestTopics.single.code, 'R-DET');
      expect(reading.weakestTopics.single.accuracyPercent, 100);

      final speaking = dashboard.skills[2];
      expect(speaking.levelCode, isNull);
      expect(speaking.latestScaledScore, isNull);
      expect(speaking.isMeasured, isFalse);
    });

    test('a never-measured learner is signalled by hasNoMeasurement', () {
      final dashboard = LearnerDashboard.fromJson(dashboardUnmeasuredPayload());

      expect(dashboard.goal.hasNoMeasurement, isTrue);
      expect(dashboard.goal.currentBandCode, isNull);
      expect(dashboard.goal.currentScoreText, isNull);
    });

    test('nextAction carries the server action URL and no invented type', () {
      final action = LearnerDashboard.fromJson(dashboardMeasuredPayload())
          .nextAction!;

      expect(action.actionUrl, '/exams/take/1005');
      expect(action.actionLabel, 'Resume');
      expect(action.eyebrow, 'PICK UP WHERE YOU LEFT OFF');
      expect(action.metaLabel, 'IN PROGRESS');
      expect(action.cascadeStep, 'resume_in_progress');
      expect(action.isResume, isTrue);
    });

    test('unfinished cards read examName and sectionName', () {
      final dashboard = LearnerDashboard.fromJson(dashboardMeasuredPayload());

      expect(dashboard.unfinishedAttempt!.examName, 'ETS 2024 - Test 1');
      expect(dashboard.unfinishedAttempt!.attemptId, 1005);
      expect(dashboard.unfinishedPractice!.sectionName, 'Incomplete Sentences');
      expect(dashboard.unfinishedPractice!.questionCount, 9);
    });
  });

  group('AiInsight.fromJson', () {
    test('pending is a normal state with no body and no failure', () {
      final insight = AiInsight.fromJson(dashboardInsightPendingPayload());

      expect(insight.status, 'pending');
      expect(insight.isPending, isTrue);
      expect(insight.isFailed, isFalse);
      expect(insight.isDone, isFalse);
      expect(insight.body, isNull);
    });

    test('failed carries its reason and is the only retryable state', () {
      final insight = AiInsight.fromJson({
        'status': 'failed',
        'failureReason': 'model timeout',
        'narrative': null,
      });

      expect(insight.isFailed, isTrue);
      expect(insight.body, isNull);
      expect(insight.failureReason, 'model timeout');
    });

    test('done prefers the formatted narrative', () {
      final insight = AiInsight.fromJson({
        'status': 'done',
        'narrative': 'raw',
        'formattedNarrative': 'ready to print',
      });

      expect(insight.body, 'ready to print');
      expect(insight.isFailed, isFalse);
    });
  });

  test('a tenths-scored certificate divides by scoreDisplayFactor', () {
    final goal = GoalStanding.fromJson({
      'currentBandCode': 'B2',
      'currentScore': 75,
      'scoreDisplayFactor': 10,
    });
    final skill = SkillMeasurement.fromJson({
      'skillId': 1,
      'code': 'LIST',
      'name': 'Listening',
      'modality': 'listening',
      'latestScaledScore': 65,
      'maxScaledScore': 90,
      'scoreDisplayFactor': 10,
      'levelCode': 'B2',
    });

    expect(goal.currentScoreText, '7.5');
    expect(skill.scoreText, '6.5');
    expect(skill.maxScoreText, '9');
  });
}
