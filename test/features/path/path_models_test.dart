import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/path/models/path_models.dart';

import 'path_fixtures.dart';

/// Recorded-payload suite for the PATH surfaces. Every assertion checks a
/// non-default value, because a wrong key yields a valid object holding `0`,
/// `''` or `[]` — presence alone would pass the defect these guard.
void main() {
  group('GET /api/learner/dashboard', () {
    late LearnerDashboard dashboard;

    setUpAll(() {
      dashboard = LearnerDashboard.fromJson(dashboardMeasuredPayload());
    });

    test('the band comes from goal, not a top-level placeholder', () {
      expect(dashboard.goal.currentBandCode, 'below_A1');
      expect(dashboard.goal.currentBandName, 'Below A1');
      expect(dashboard.goal.currentScoreText, '10');
      expect(dashboard.goal.currentSource, 'mock');
      expect(dashboard.goal.hasNoMeasurement, isFalse);
      expect(dashboard.certificate.code, 'TOEIC');
      expect(dashboard.certificate.sectionNoun, 'Part');
    });

    test('skills carry their real level and score', () {
      expect(dashboard.skills, hasLength(4));

      final listening = dashboard.skills.first;
      expect(listening.name, 'Listening');
      expect(listening.levelCode, 'A2');
      expect(listening.scoreText, '5');
      expect(listening.maxScoreText, '495');
      expect(listening.isMeasured, isTrue);
      expect(listening.isStale, isFalse);
      expect(listening.weakestTopics.first.code, 'L-DET');

      final reading = dashboard.skills[1];
      expect(reading.weakestTopics.single.accuracyPercent, 100);
      expect(reading.weakestTopics.single.answered, 1);
    });

    test('a skill nothing measured keeps null, never a bottom band', () {
      final speaking = dashboard.skills[2];
      expect(speaking.name, 'Speaking');
      expect(speaking.levelCode, isNull);
      expect(speaking.positionInBand, isNull);
      expect(speaking.measuredAt, isNull);
      expect(speaking.scoreText, isNull);
      expect(speaking.isMeasured, isFalse);
    });

    test('nextAction carries the server action URL and no invented type', () {
      final action = dashboard.nextAction!;

      expect(action.actionUrl, '/speaking/take/1006');
      expect(action.actionLabel, 'Resume');
      expect(action.eyebrow, 'PICK UP WHERE YOU LEFT OFF');
      expect(action.metaLabel, 'IN PROGRESS');
      expect(action.cascadeStep, 'resume_in_progress');
      expect(action.severity, 'warning');
      expect(action.isResume, isTrue);
    });

    test('unfinished rows read examName and sectionName', () {
      expect(dashboard.unfinishedAttempt!.examName, startsWith('ETS TOEIC'));
      expect(dashboard.unfinishedAttempt!.attemptId, 1006);
      expect(dashboard.unfinishedAttempt!.purpose, 'speaking_practice');
      expect(dashboard.unfinishedPractice!.sectionName, 'Talks');
      expect(dashboard.unfinishedPractice!.questionCount, 3);
      expect(dashboard.attemptCount, 6);
      expect(dashboard.practiceCount, 3);
    });
  });

  group('GET /api/learner/dashboard, never measured', () {
    test('hasNoMeasurement is the switch, and every band is null', () {
      final dashboard = LearnerDashboard.fromJson(
        dashboardUnmeasuredWithOpenPlacementPayload(),
      );

      expect(dashboard.goal.hasNoMeasurement, isTrue);
      expect(dashboard.goal.currentBandCode, isNull);
      expect(dashboard.goal.currentScore, isNull);
      expect(dashboard.goal.currentScoreText, isNull);
      expect(dashboard.skills.map((s) => s.isMeasured), everyElement(isFalse));
    });
  });

  group('GET /api/learner/insights/dashboard', () {
    test('a done insight exposes its narrative', () {
      final insight = AiInsight.fromJson(dashboardInsightDonePayload());

      expect(insight.isDone, isTrue);
      expect(insight.isFailed, isFalse);
      expect(insight.body, contains('Performance Summary'));
    });

    test('pending is a normal state with no body and no failure', () {
      final insight = AiInsight.fromJson(dashboardInsightPendingPayload());

      expect(insight.status, 'pending');
      expect(insight.isPending, isTrue);
      expect(insight.isFailed, isFalse);
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
  });

  test(
    'GET /api/learner/insights/path 404 is the LEARNING_PATH_NOT_FOUND code',
    () {
      final body = pathInsightNotFoundPayload();

      expect(body['status'], 404);
      expect((body['code'] as String).toLowerCase(), 'learning_path_not_found');
    },
  );

  test('GET /api/learner/learning-path says hasActivePath: false', () {
    final body = learningPathSummaryEmptyPayload();

    expect(body['hasActivePath'], isFalse);
    expect(body['skillLevels'], isA<Map<String, dynamic>>());
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
