/// Insets for the PATH surfaces from the recorded backend payloads in
/// `test/contract/fixtures/`, so a test asserts against real bytes rather than
/// a client-shaped guess.
library;

import '../../contract/fixture_loader.dart';

/// `GET /api/learner/dashboard` for the measured demo learner.
Map<String, dynamic> dashboardMeasuredPayload() =>
    _asMap(loadFixture('learner_dashboard'));

/// `GET /api/learner/dashboard` for `learner.fresh@demo.local`: nothing measured,
/// and a placement already open, so the cascade offers to resume it.
Map<String, dynamic> dashboardUnmeasuredWithOpenPlacementPayload() =>
    _asMap(loadFixture('learner_dashboard_unmeasured'));

/// A never-measured learner with nothing open.
///
/// Not in the seed, so it is derived from the recorded unmeasured payload by
/// clearing the unfinished rows and using step 2 of the backend's own cascade
/// (`LearnerService.NextAction.cs`), whose wording this copies verbatim.
Map<String, dynamic> dashboardUnmeasuredNoSittingPayload() {
  final payload = dashboardUnmeasuredWithOpenPlacementPayload();
  return {
    ...payload,
    'nextAction': {
      'eyebrow': 'START HERE',
      'title': 'Find your TOEIC level',
      'description':
          'A free placement test sets your starting band, then your practice and '
          'your learning path are chosen from it. No credit is spent. It takes '
          'about 45 minutes.',
      'actionLabel': 'Take the free placement test',
      'actionUrl': '/placement',
      'severity': 'info',
      'cascadeStep': 'retry_unmeasured_skill',
      'metaLabel': 'FREE',
    },
    'attemptCount': 0,
    'practiceCount': 0,
    'unfinishedAttempt': null,
    'unfinishedPractice': null,
  };
}

/// `GET /api/learner/insights/dashboard`, recorded while `status` is `done`.
Map<String, dynamic> dashboardInsightDonePayload() =>
    _asMap(loadFixture('learner_insight_dashboard'));

/// The same shape while `status` is `pending`, which is the normal state right
/// after a page first asks for one.
Map<String, dynamic> dashboardInsightPendingPayload() {
  final payload = dashboardInsightDonePayload();
  return {
    ...payload,
    'narrative': null,
    'trend': null,
    'status': 'pending',
    'model': null,
    'promptTokens': null,
    'completionTokens': null,
    'completedAt': null,
    'recommendations': <Map<String, dynamic>>[],
    'formattedNarrative': null,
  };
}

/// The recorded `GET /api/learner/insights/path` 404 body: a designed empty
/// state, not a broken request.
Map<String, dynamic> pathInsightNotFoundPayload() =>
    _asMap(loadFixture('learner_insight_path_not_found'));

/// `GET /api/learner/learning-path` with no active path.
Map<String, dynamic> learningPathSummaryEmptyPayload() =>
    _asMap(loadFixture('learner_learning_path_empty'));

Map<String, dynamic> _asMap(dynamic json) =>
    Map<String, dynamic>.from(json as Map);
