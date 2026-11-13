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

  group('GET /api/learner/learning-path with an active path', () {
    late LearningPathOverview path;

    setUpAll(() {
      path = LearningPathOverview.fromJson(learningPathActivePayload());
    });

    test('hasActivePath is the switch and the bands are real', () {
      expect(path.hasActivePath, isTrue);
      expect(path.learnerPathId, isNotNull);
      expect(path.fromBandCode, 'below_A1');
      expect(path.toBandCode, 'B2');
      expect(path.fromBandName, 'Below A1');
      expect(path.toBandName, 'Upper intermediate');
      expect(path.targetScore, 785);
      expect(path.activeCert.code, 'TOEIC');
    });

    test('remaining time and progress come from the payload, not a zero', () {
      expect(path.totalSteps, 16);
      expect(path.remainingMinutes, 720);
      expect(path.totalEstimatedMinutes, 720);
      expect(path.completedSteps, 0);
      expect(path.progressRatio, 0);
    });

    test('weeks are the plan\'s own, each with its steps and minutes', () {
      expect(path.weeks, hasLength(4));
      expect(path.weeks.map((w) => w.weekNumber), [1, 2, 3, 4]);

      final week1 = path.weeks.first;
      expect(week1.plannedSteps, 4);
      expect(week1.plannedMinutes, 180);
      expect(week1.isOnTrack, isFalse);
      expect(week1.steps, hasLength(4));
      expect(week1.steps.map((s) => s.stepId), [1, 2, 3, 4]);
    });

    test('a step carries its sequence, skill, level and exact item count', () {
      final step = path.openSteps.first;

      expect(step.stepId, 1);
      expect(step.weekNumber, 1);
      expect(step.weekSequence, 1);
      expect(step.stepType, 'focus_practice');
      expect(step.route, 'item_selector');
      expect(step.status, 'available');
      expect(step.skillCode, 'LIST');
      expect(step.skillName, 'Listening');
      expect(step.targetCefr, 'A2');
      expect(step.sizingTier, 'developing');
      expect(step.plannedItemCount, 10);
      expect(step.estimatedMinutes, 45);
      expect(step.targetAccuracyPct, 70);
      expect(step.canStart, isTrue);
      expect(step.isLocked, isFalse);
    });

    test('a not-yet-run step keeps its nulls null', () {
      final step = path.openSteps.first;

      expect(step.score, isNull);
      expect(step.actualAccuracyPct, isNull);
      expect(step.startedAt, isNull);
      expect(step.completedAt, isNull);
      expect(step.refLessonId, isNull);
      expect(step.refExamId, isNull);
    });

    test('a locked step is unavailable rather than absent', () {
      final locked = path.openSteps.firstWhere((s) => s.isLocked);

      expect(locked.stepId, 2);
      expect(locked.canStart, isFalse);
    });

    test('skillLevels reads each skill\'s own level', () {
      expect(path.skillLevels, {'LIST': 'A2', 'READ': 'A2'});
    });

    test('cefrBands mark the current and target rungs', () {
      final current = path.cefrBands.where((b) => b.isCurrent).single;
      final target = path.cefrBands.where((b) => b.isTarget).single;

      expect(current.code, 'below_A1');
      expect(target.code, 'B2');
      expect(path.cefrBands, hasLength(6));
    });
  });

  group('POST /api/learner/learning-path/steps/{id}/start', () {
    test('carries the server\'s redirect URL and session id', () {
      final started = StartStepResult.fromJson(startStepResultPayload());

      expect(started.stepId, 1);
      expect(started.stepType, 'focus_practice');
      expect(started.route, 'item_selector');
      expect(started.redirectUrl, '/practice/21');
      expect(started.sessionId, 21);
      expect(started.attemptId, isNull);
      expect(started.isSubstituted, isFalse);
    });
  });

  group('GET /api/learner/target-band', () {
    test('with no goal: the outer target is null and "" is absent', () {
      final view = TargetBandView.fromJson(targetBandNoGoalPayload());

      expect(view.hasTargetBand, isFalse);
      expect(view.targetBandCode, isNull);
      // The live oddity: `goal.targetBandCode` is "" while the outer is null.
      expect(view.goal!.targetBandCode, isNull);
      expect(view.currentBandCode, isNull);
      expect(view.currentTotalScore, isNull);
    });

    test('offers the certificate\'s own bands with their score ranges', () {
      final view = TargetBandView.fromJson(targetBandNoGoalPayload());

      expect(view.availableBands, hasLength(6));
      expect(
        view.availableBands.map((b) => b.code),
        ['below_A1', 'A1', 'A2', 'B1', 'B2', 'C1'],
      );

      final beginner = view.availableBands[1];
      expect(beginner.name, 'Beginner');
      expect(beginner.minTotal, 120);
      expect(beginner.maxTotal, 220);
      expect(beginner.description, '120 to 220 points');
      expect(beginner.rangeText, '120 to 220 points');
    });

    test('with a saved goal: the band, the assessed band and the flags', () {
      final view = TargetBandView.fromJson(targetBandWithGoalPayload());

      expect(view.hasTargetBand, isTrue);
      expect(view.targetBandCode, 'B2');
      expect(view.goal!.currentBandCode, 'below_A1');
      expect(view.goal!.targetBandCode, 'B2');
      // A goal with no deadline has no verdict; null is "cannot judge".
      expect(view.goal!.status, isNull);
      expect(view.availableBands.where((b) => b.isTarget).single.code, 'B2');
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
