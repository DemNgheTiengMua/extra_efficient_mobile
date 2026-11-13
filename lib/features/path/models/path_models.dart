/// Domain models for the `PATH` tab: Dashboard, Insights, Target Band &
/// Calibration, Learning Path, and Lesson Player.
///
/// Every key below is the backend's own (`NextActionDto`, `GoalStandingDto`,
/// `SkillCardDto`, `RecentAttemptDto`, `RecentPracticeDto`, `AiInsightDto`).
/// Absence is a null, never a placeholder band.
library;

/// The one action the backend decided on (`nextAction` on
/// `GET /api/learner/dashboard`). `actionUrl` is an app path decided by the
/// server; the app routes on it rather than rebuilding it from a type.
class NextActionInfo {
  const NextActionInfo({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionUrl,
    required this.severity,
    required this.cascadeStep,
    this.metaLabel,
  });

  factory NextActionInfo.fromJson(Map<String, dynamic> json) {
    return NextActionInfo(
      eyebrow: json['eyebrow']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      actionLabel: json['actionLabel']?.toString() ?? 'CONTINUE',
      actionUrl: json['actionUrl']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'info',
      cascadeStep: json['cascadeStep']?.toString() ?? '',
      metaLabel: _asString(json['metaLabel']),
    );
  }

  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final String actionUrl;
  final String severity;
  final String cascadeStep;
  final String? metaLabel;

  /// The cascade step that produced this action, so a caller can recognise the
  /// "pick up where you left off" case without guessing from the URL.
  bool get isResume => cascadeStep.toLowerCase() == 'resume_in_progress';
}

/// The measured goal standing (`goal` on the dashboard).
///
/// [hasNoMeasurement] is the switch: when true nothing has been measured, so
/// every band and score is legitimately null and the page must not invent one.
class GoalStanding {
  const GoalStanding({
    this.currentBandCode,
    this.currentBandName,
    this.currentScore,
    this.currentSource,
    this.targetBandCode,
    this.targetBandName,
    this.targetMinScore,
    this.targetDate,
    this.weeklyStudyHours,
    this.status,
    this.completedPathSteps = 0,
    this.totalPathSteps = 0,
    this.currentWeekNumber,
    this.weekPlannedMinutes = 0,
    this.weekCompletedMinutes = 0,
    this.scoreDisplayFactor = 1,
    this.requiredTotalHours,
    this.overallLevelCode,
    this.limitingSkillCode,
    this.limitingSkillName,
    this.hasNoMeasurement = false,
  });

  factory GoalStanding.fromJson(Map<String, dynamic> json) {
    return GoalStanding(
      currentBandCode: _asString(json['currentBandCode']),
      currentBandName: _asString(json['currentBandName']),
      currentScore: _asInt(json['currentScore']),
      currentSource: _asString(json['currentSource']),
      targetBandCode: _asString(json['targetBandCode']),
      targetBandName: _asString(json['targetBandName']),
      targetMinScore: _asInt(json['targetMinScore']),
      targetDate: _asString(json['targetDate']),
      weeklyStudyHours: _asNum(json['weeklyStudyHours']),
      status: _asString(json['status']),
      completedPathSteps: _asInt(json['completedPathSteps']) ?? 0,
      totalPathSteps: _asInt(json['totalPathSteps']) ?? 0,
      currentWeekNumber: _asInt(json['currentWeekNumber']),
      weekPlannedMinutes: _asInt(json['weekPlannedMinutes']) ?? 0,
      weekCompletedMinutes: _asInt(json['weekCompletedMinutes']) ?? 0,
      scoreDisplayFactor: _asInt(json['scoreDisplayFactor']) ?? 1,
      requiredTotalHours: _asInt(json['requiredTotalHours']),
      overallLevelCode: _asString(json['overallLevelCode']),
      limitingSkillCode: _asString(json['limitingSkillCode']),
      limitingSkillName: _asString(json['limitingSkillName']),
      hasNoMeasurement: json['hasNoMeasurement'] == true,
    );
  }

  final String? currentBandCode;
  final String? currentBandName;
  final int? currentScore;
  final String? currentSource;
  final String? targetBandCode;
  final String? targetBandName;
  final int? targetMinScore;
  final String? targetDate;
  final num? weeklyStudyHours;
  final String? status;
  final int completedPathSteps;
  final int totalPathSteps;
  final int? currentWeekNumber;
  final int weekPlannedMinutes;
  final int weekCompletedMinutes;
  final int scoreDisplayFactor;
  final int? requiredTotalHours;
  final String? overallLevelCode;
  final String? limitingSkillCode;
  final String? limitingSkillName;
  final bool hasNoMeasurement;

  String? get currentScoreText =>
      _formatStoredScore(currentScore, scoreDisplayFactor);
}

/// One skill of the active certificate, with whatever has been measured.
///
/// `levelCode`, `positionInBand` and `measuredAt` are null together for a skill
/// nothing measured; a null level is never rendered as a band.
class SkillMeasurement {
  const SkillMeasurement({
    required this.skillId,
    required this.code,
    required this.name,
    required this.modality,
    this.latestScaledScore,
    this.maxScaledScore,
    this.weakestTopics = const [],
    this.scoreDisplayFactor = 1,
    this.levelCode,
    this.positionInBand,
    this.measuredAt,
    this.isStale = false,
  });

  factory SkillMeasurement.fromJson(Map<String, dynamic> json) {
    final topicsRaw = json['weakestTopics'] as List<dynamic>? ?? const [];
    return SkillMeasurement(
      skillId: _asInt(json['skillId']) ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      modality: json['modality']?.toString() ?? '',
      latestScaledScore: _asInt(json['latestScaledScore']),
      maxScaledScore: _asInt(json['maxScaledScore']),
      weakestTopics: topicsRaw
          .whereType<Map<String, dynamic>>()
          .map(SkillCategory.fromJson)
          .toList(growable: false),
      scoreDisplayFactor: _asInt(json['scoreDisplayFactor']) ?? 1,
      levelCode: _asString(json['levelCode']),
      positionInBand: _asInt(json['positionInBand']),
      measuredAt: _asString(json['measuredAt']),
      isStale: json['isStale'] == true,
    );
  }

  final int skillId;
  final String code;
  final String name;
  final String modality;
  final int? latestScaledScore;
  final int? maxScaledScore;
  final List<SkillCategory> weakestTopics;
  final int scoreDisplayFactor;
  final String? levelCode;
  final int? positionInBand;
  final String? measuredAt;
  final bool isStale;

  bool get isMeasured => levelCode != null && levelCode!.isNotEmpty;

  String? get scoreText =>
      _formatStoredScore(latestScaledScore, scoreDisplayFactor);

  String? get maxScoreText =>
      _formatStoredScore(maxScaledScore, scoreDisplayFactor);
}

class SkillCategory {
  const SkillCategory({
    required this.code,
    required this.name,
    required this.accuracyPercent,
    required this.answered,
    required this.levelCode,
  });

  factory SkillCategory.fromJson(Map<String, dynamic> json) {
    return SkillCategory(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      accuracyPercent: _asInt(json['accuracyPercent']) ?? 0,
      answered: _asInt(json['answered']) ?? 0,
      levelCode: json['levelCode']?.toString() ?? '',
    );
  }

  final String code;
  final String name;
  final int accuracyPercent;
  final int answered;
  final String levelCode;
}

class UnfinishedAttemptSummary {
  const UnfinishedAttemptSummary({
    required this.attemptId,
    required this.examName,
    required this.purpose,
    required this.status,
    this.startedAt,
    this.totalScore,
    this.bandCode,
  });

  factory UnfinishedAttemptSummary.fromJson(Map<String, dynamic> json) {
    return UnfinishedAttemptSummary(
      attemptId: _asInt(json['attemptId']) ?? 0,
      examName: json['examName']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      startedAt: _asString(json['startedAt']),
      totalScore: _asInt(json['totalScore']),
      bandCode: _asString(json['bandCode']),
    );
  }

  final int attemptId;
  final String examName;
  final String purpose;
  final String status;
  final String? startedAt;
  final int? totalScore;
  final String? bandCode;

  bool get isPlacement => purpose.toLowerCase() == 'placement';
}

class UnfinishedPracticeSummary {
  const UnfinishedPracticeSummary({
    required this.sessionId,
    required this.sectionName,
    required this.status,
    this.correctCount = 0,
    this.questionCount = 0,
    this.startedAt,
  });

  factory UnfinishedPracticeSummary.fromJson(Map<String, dynamic> json) {
    return UnfinishedPracticeSummary(
      sessionId: _asInt(json['sessionId']) ?? 0,
      sectionName: json['sectionName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      correctCount: _asInt(json['correctCount']) ?? 0,
      questionCount: _asInt(json['questionCount']) ?? 0,
      startedAt: _asString(json['startedAt']),
    );
  }

  final int sessionId;
  final String sectionName;
  final String status;
  final int correctCount;
  final int questionCount;
  final String? startedAt;
}

/// `GET /api/learner/dashboard` as the envelope it is.
class LearnerDashboard {
  const LearnerDashboard({
    required this.certificate,
    required this.goal,
    this.nextAction,
    this.skills = const [],
    this.attemptCount = 0,
    this.practiceCount = 0,
    this.unfinishedAttempt,
    this.unfinishedPractice,
  });

  factory LearnerDashboard.fromJson(Map<String, dynamic> json) {
    final nextActionRaw = json['nextAction'];
    final goalRaw = json['goal'];
    final skillsRaw = json['skills'] as List<dynamic>? ?? const [];
    final attemptRaw = json['unfinishedAttempt'];
    final practiceRaw = json['unfinishedPractice'];

    return LearnerDashboard(
      certificate: json['certificate'] is Map<String, dynamic>
          ? DashboardCertificate.fromJson(
              json['certificate'] as Map<String, dynamic>,
            )
          : const DashboardCertificate(),
      goal: goalRaw is Map<String, dynamic>
          ? GoalStanding.fromJson(goalRaw)
          : const GoalStanding(),
      nextAction: nextActionRaw is Map<String, dynamic>
          ? NextActionInfo.fromJson(nextActionRaw)
          : null,
      skills: skillsRaw
          .whereType<Map<String, dynamic>>()
          .map(SkillMeasurement.fromJson)
          .toList(growable: false),
      attemptCount: _asInt(json['attemptCount']) ?? 0,
      practiceCount: _asInt(json['practiceCount']) ?? 0,
      unfinishedAttempt: attemptRaw is Map<String, dynamic>
          ? UnfinishedAttemptSummary.fromJson(attemptRaw)
          : null,
      unfinishedPractice: practiceRaw is Map<String, dynamic>
          ? UnfinishedPracticeSummary.fromJson(practiceRaw)
          : null,
    );
  }

  final DashboardCertificate certificate;
  final GoalStanding goal;
  final NextActionInfo? nextAction;
  final List<SkillMeasurement> skills;
  final int attemptCount;
  final int practiceCount;
  final UnfinishedAttemptSummary? unfinishedAttempt;
  final UnfinishedPracticeSummary? unfinishedPractice;
}

class DashboardCertificate {
  const DashboardCertificate({
    this.code = '',
    this.name = '',
    this.sectionNoun = 'Section',
  });

  factory DashboardCertificate.fromJson(Map<String, dynamic> json) {
    return DashboardCertificate(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sectionNoun: json['sectionNoun']?.toString() ?? 'Section',
    );
  }

  final String code;
  final String name;
  final String sectionNoun;
}

/// `AiInsightDto`: generated asynchronously, so `pending` is a normal state and
/// only `failed` may be retried (the backend rejects everything else).
class AiInsight {
  const AiInsight({
    required this.status,
    this.narrative,
    this.formattedNarrative,
    this.failureReason,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      status: json['status']?.toString() ?? '',
      narrative: _asString(json['narrative']),
      formattedNarrative: _asString(json['formattedNarrative']),
      failureReason: _asString(json['failureReason']),
    );
  }

  final String status;
  final String? narrative;
  final String? formattedNarrative;
  final String? failureReason;

  /// What a reader can actually show: the formatted narrative when the insight
  /// is done, null while pending or after a failure.
  String? get body => formattedNarrative ?? narrative;

  bool get isFailed => status.toLowerCase() == 'failed';

  bool get isPending => status.toLowerCase() == 'pending';

  bool get isDone => status.toLowerCase() == 'done';
}

/// One band of the certificate's own ladder (`CefrBandInfoDto`). The ladder is
/// the certificate's, not a shared six-rung one, so it is fed by the payload.
class CefrBandInfo {
  const CefrBandInfo({
    required this.code,
    required this.name,
    required this.minTotal,
    required this.maxTotal,
    this.isReached = false,
    this.isCurrent = false,
    this.isTarget = false,
  });

  factory CefrBandInfo.fromJson(Map<String, dynamic> json) {
    return CefrBandInfo(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      minTotal: _asInt(json['minTotal']) ?? 0,
      maxTotal: _asInt(json['maxTotal']) ?? 0,
      isReached: json['isReached'] == true,
      isCurrent: json['isCurrent'] == true,
      isTarget: json['isTarget'] == true,
    );
  }

  final String code;
  final String name;
  final int minTotal;
  final int maxTotal;
  final bool isReached;
  final bool isCurrent;
  final bool isTarget;

  String get rangeText => '$minTotal to $maxTotal points';
}

/// One band a goal may aim at (`TargetBandOptionDto`), with the backend's
/// ready-to-print range and its own current/target flags.
class TargetBandOption {
  const TargetBandOption({
    required this.code,
    required this.name,
    required this.minTotal,
    required this.maxTotal,
    this.description,
    this.isCurrent = false,
    this.isTarget = false,
  });

  factory TargetBandOption.fromJson(Map<String, dynamic> json) {
    return TargetBandOption(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      minTotal: _asInt(json['minTotal']) ?? 0,
      maxTotal: _asInt(json['maxTotal']) ?? 0,
      description: _asString(json['description']),
      isCurrent: json['isCurrent'] == true,
      isTarget: json['isTarget'] == true,
    );
  }

  final String code;
  final String name;
  final int minTotal;
  final int maxTotal;
  final String? description;
  final bool isCurrent;
  final bool isTarget;

  String get rangeText =>
      description ?? '$minTotal to $maxTotal points';
}

/// The saved goal's verdict (`GoalStatusDto`). `status` is null whenever there
/// is nothing to answer — no deadline — which is not a refusal.
class GoalStatus {
  const GoalStatus({
    this.currentBandCode,
    this.targetBandCode,
    this.targetDate,
    this.weeklyStudyHours,
    this.requiredHours,
    this.availableHours,
    this.status,
    this.suggestedWeeklyHours,
    this.earliestFeasibleDate,
  });

  factory GoalStatus.fromJson(Map<String, dynamic> json) {
    return GoalStatus(
      currentBandCode: _asString(json['currentBandCode']),
      // Live, `targetBandCode` is "" while the outer one is null. "" is absent.
      targetBandCode: _asString(json['targetBandCode']),
      targetDate: _asString(json['targetDate']),
      weeklyStudyHours: _asNum(json['weeklyStudyHours']),
      requiredHours: _asInt(json['requiredHours']),
      availableHours: _asNum(json['availableHours']),
      status: _asString(json['status']),
      suggestedWeeklyHours: _asInt(json['suggestedWeeklyHours']),
      earliestFeasibleDate: _asString(json['earliestFeasibleDate']),
    );
  }

  final String? currentBandCode;
  final String? targetBandCode;
  final String? targetDate;
  final num? weeklyStudyHours;
  final int? requiredHours;
  final num? availableHours;
  final String? status;
  final int? suggestedWeeklyHours;
  final String? earliestFeasibleDate;
}

/// `GET /api/learner/target-band` as the envelope it is: the certificate's real
/// bands (each with its score range) plus whatever goal is already saved.
class TargetBandView {
  const TargetBandView({
    this.activeCert = const DashboardCertificate(),
    this.currentBandCode,
    this.currentTotalScore,
    this.currentBandName,
    this.targetBandCode,
    this.cefrBands = const [],
    this.availableBands = const [],
    this.goal,
  });

  factory TargetBandView.fromJson(Map<String, dynamic> json) {
    final bandsRaw = json['availableBands'] as List<dynamic>? ?? const [];
    final cefrRaw = json['cefrBands'] as List<dynamic>? ?? const [];
    final goalRaw = json['goal'];
    return TargetBandView(
      activeCert: json['activeCert'] is Map<String, dynamic>
          ? DashboardCertificate.fromJson(
              json['activeCert'] as Map<String, dynamic>,
            )
          : const DashboardCertificate(),
      currentBandCode: _asString(json['currentBandCode']),
      currentTotalScore: _asInt(json['currentTotalScore']),
      currentBandName: _asString(json['currentBandName']),
      targetBandCode: _asString(json['targetBandCode']),
      cefrBands: cefrRaw
          .whereType<Map<String, dynamic>>()
          .map(CefrBandInfo.fromJson)
          .toList(growable: false),
      availableBands: bandsRaw
          .whereType<Map<String, dynamic>>()
          .map(TargetBandOption.fromJson)
          .toList(growable: false),
      goal: goalRaw is Map<String, dynamic>
          ? GoalStatus.fromJson(goalRaw)
          : null,
    );
  }

  final DashboardCertificate activeCert;
  final String? currentBandCode;
  final int? currentTotalScore;
  final String? currentBandName;
  final String? targetBandCode;
  final List<CefrBandInfo> cefrBands;
  final List<TargetBandOption> availableBands;
  final GoalStatus? goal;

  /// A path can only be generated towards a band that has been chosen.
  bool get hasTargetBand => targetBandCode != null;
}

class CalibrationStatus {
  const CalibrationStatus({
    this.pending = false,
    this.currentTargetBandCode,
    this.recommendedBandCode,
    this.reason,
  });

  factory CalibrationStatus.fromJson(Map<String, dynamic> json) {
    return CalibrationStatus(
      pending: json['pending'] == true || json['status'] == 'pending',
      currentTargetBandCode: json['currentTargetBandCode']?.toString(),
      recommendedBandCode: json['recommendedBandCode']?.toString(),
      reason: json['reason']?.toString(),
    );
  }

  final bool pending;
  final String? currentTargetBandCode;
  final String? recommendedBandCode;
  final String? reason;
}

/// `PathStepDto`: one step's coordinate and state, before it starts.
///
/// A step belongs to a week, not to a module — the backend retired modules, so
/// [weekNumber] is what the screen groups by.
class PathStep {
  const PathStep({
    required this.stepId,
    required this.weekNumber,
    required this.weekSequence,
    required this.stepType,
    required this.route,
    required this.title,
    required this.status,
    this.skillCode = '',
    this.skillName = '',
    this.modality = '',
    this.topicCode = '',
    this.topicName = '',
    this.targetCefr = '',
    this.sizingTier = '',
    this.plannedItemCount,
    this.estimatedMinutes,
    this.score,
    this.actualAccuracyPct,
    this.targetAccuracyPct = 0,
    this.canStart = false,
    this.startedAt,
    this.completedAt,
    this.refLessonId,
    this.refExamId,
  });

  factory PathStep.fromJson(Map<String, dynamic> json) {
    return PathStep(
      stepId: _asInt(json['stepId']) ?? 0,
      weekNumber: _asInt(json['weekNumber']) ?? 0,
      weekSequence: _asInt(json['weekSequence']) ?? 0,
      stepType: json['stepType']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      skillCode: json['skillCode']?.toString() ?? '',
      skillName: json['skillName']?.toString() ?? '',
      modality: json['modality']?.toString() ?? '',
      topicCode: json['topicCode']?.toString() ?? '',
      topicName: json['topicName']?.toString() ?? '',
      targetCefr: json['targetCefr']?.toString() ?? '',
      sizingTier: json['sizingTier']?.toString() ?? '',
      plannedItemCount: _asInt(json['plannedItemCount']),
      estimatedMinutes: _asInt(json['estimatedMinutes']),
      score: _asNum(json['score']),
      actualAccuracyPct: _asNum(json['actualAccuracyPct']),
      targetAccuracyPct: _asInt(json['targetAccuracyPct']) ?? 0,
      canStart: json['canStart'] == true,
      startedAt: _asString(json['startedAt']),
      completedAt: _asString(json['completedAt']),
      refLessonId: _asInt(json['refLessonId']),
      refExamId: _asInt(json['refExamId']),
    );
  }

  final int stepId;
  final int weekNumber;
  final int weekSequence;
  final String stepType;
  final String route;
  final String title;

  /// `locked | available | in_progress | done`.
  final String status;
  final String skillCode;
  final String skillName;
  final String modality;
  final String topicCode;
  final String topicName;
  final String targetCefr;
  final String sizingTier;
  final int? plannedItemCount;
  final int? estimatedMinutes;
  final num? score;
  final num? actualAccuracyPct;
  final int targetAccuracyPct;
  final bool canStart;
  final String? startedAt;
  final String? completedAt;
  final int? refLessonId;
  final int? refExamId;

  bool get isLocked => status.toLowerCase() == 'locked';

  bool get isDone => status.toLowerCase() == 'done';

  String get typeLabel => switch (stepType.toLowerCase()) {
    'diagnostic_drill' => 'DIAGNOSTIC',
    'focus_practice' => 'PRACTICE',
    'review_spaced' => 'REVIEW',
    'concept_lesson' => 'LESSON',
    'expanded_remedial' => 'REMEDIAL',
    'mock_section' => 'MOCK',
    _ => stepType.toUpperCase(),
  };
}

/// `LearningPathWeekSummaryDto`: a planning week and the backend's On Track
/// verdict on it.
class LearningPathWeek {
  const LearningPathWeek({
    required this.weekNumber,
    required this.plannedSteps,
    required this.completedSteps,
    required this.plannedMinutes,
    required this.completedMinutes,
    this.isOnTrack = false,
    this.targetAccuracyPct = 0,
    this.actualAccuracyPct,
    this.steps = const [],
  });

  factory LearningPathWeek.fromJson(Map<String, dynamic> json) {
    final stepsRaw = json['steps'] as List<dynamic>? ?? const [];
    return LearningPathWeek(
      weekNumber: _asInt(json['weekNumber']) ?? 0,
      plannedSteps: _asInt(json['plannedSteps']) ?? 0,
      completedSteps: _asInt(json['completedSteps']) ?? 0,
      plannedMinutes: _asInt(json['plannedMinutes']) ?? 0,
      completedMinutes: _asInt(json['completedMinutes']) ?? 0,
      isOnTrack: json['isOnTrack'] == true,
      targetAccuracyPct: _asInt(json['targetAccuracyPct']) ?? 0,
      actualAccuracyPct: _asNum(json['actualAccuracyPct']),
      steps: stepsRaw
          .whereType<Map<String, dynamic>>()
          .map(PathStep.fromJson)
          .toList(growable: false),
    );
  }

  final int weekNumber;
  final int plannedSteps;
  final int completedSteps;
  final int plannedMinutes;
  final int completedMinutes;
  final bool isOnTrack;
  final int targetAccuracyPct;
  final num? actualAccuracyPct;
  final List<PathStep> steps;
}

/// `GET /api/learner/learning-path` as the envelope it is.
///
/// [hasActivePath] is the existence switch: when it is false every figure is
/// zero and every list is empty, so the screen must offer generation rather
/// than an empty shell of weeks.
class LearningPathOverview {
  const LearningPathOverview({
    this.hasActivePath = false,
    this.activeCert = const DashboardCertificate(),
    this.learnerPathId,
    this.fromBandCode,
    this.toBandCode,
    this.fromBandName,
    this.toBandName,
    this.currentBandCode,
    this.currentScore,
    this.targetBandCode,
    this.targetScore,
    this.status,
    this.startedAt,
    this.totalSteps = 0,
    this.completedSteps = 0,
    this.totalEstimatedMinutes = 0,
    this.remainingMinutes = 0,
    this.cefrBands = const [],
    this.openSteps = const [],
    this.nextStepId,
    this.weeks = const [],
    this.skillLevels = const {},
  });

  factory LearningPathOverview.fromJson(Map<String, dynamic> json) {
    List<PathStep> stepsOf(dynamic raw) => (raw as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PathStep.fromJson)
        .toList(growable: false);

    final weeksRaw = json['weeks'] as List<dynamic>? ?? const [];
    final skillLevelsRaw = json['skillLevels'];
    final cefrRaw = json['cefrBands'] as List<dynamic>? ?? const [];

    return LearningPathOverview(
      hasActivePath: json['hasActivePath'] == true,
      activeCert: json['activeCert'] is Map<String, dynamic>
          ? DashboardCertificate.fromJson(
              json['activeCert'] as Map<String, dynamic>,
            )
          : const DashboardCertificate(),
      learnerPathId: _asInt(json['learnerPathId']),
      fromBandCode: _asString(json['fromBandCode']),
      toBandCode: _asString(json['toBandCode']),
      fromBandName: _asString(json['fromBandName']),
      toBandName: _asString(json['toBandName']),
      currentBandCode: _asString(json['currentBandCode']),
      currentScore: _asInt(json['currentScore']),
      targetBandCode: _asString(json['targetBandCode']),
      targetScore: _asInt(json['targetScore']),
      status: _asString(json['status']),
      startedAt: _asString(json['startedAt']),
      totalSteps: _asInt(json['totalSteps']) ?? 0,
      completedSteps: _asInt(json['completedSteps']) ?? 0,
      totalEstimatedMinutes: _asInt(json['totalEstimatedMinutes']) ?? 0,
      remainingMinutes: _asInt(json['remainingMinutes']) ?? 0,
      cefrBands: cefrRaw
          .whereType<Map<String, dynamic>>()
          .map(CefrBandInfo.fromJson)
          .toList(growable: false),
      openSteps: stepsOf(json['openSteps']),
      nextStepId: _asInt(json['nextStepId']),
      weeks: weeksRaw
          .whereType<Map<String, dynamic>>()
          .map(LearningPathWeek.fromJson)
          .toList(growable: false),
      skillLevels: skillLevelsRaw is Map
          ? {
              for (final entry in skillLevelsRaw.entries)
                entry.key.toString(): entry.value.toString(),
            }
          : const {},
    );
  }

  final bool hasActivePath;
  final DashboardCertificate activeCert;
  final int? learnerPathId;
  final String? fromBandCode;
  final String? toBandCode;
  final String? fromBandName;
  final String? toBandName;
  final String? currentBandCode;
  final int? currentScore;
  final String? targetBandCode;
  final int? targetScore;
  final String? status;
  final String? startedAt;
  final int totalSteps;
  final int completedSteps;
  final int totalEstimatedMinutes;
  final int remainingMinutes;
  final List<CefrBandInfo> cefrBands;
  final List<PathStep> openSteps;
  final int? nextStepId;
  final List<LearningPathWeek> weeks;

  /// Each skill's own level, as the plan reads it (`LIST: A2`).
  final Map<String, String> skillLevels;

  double get progressRatio =>
      totalSteps <= 0 ? 0 : (completedSteps / totalSteps).clamp(0.0, 1.0);
}

/// `StartStepResultDto`: the surface this step opened. [redirectUrl] is the
/// server's own app path, so it is followed rather than rebuilt.
class StartStepResult {
  const StartStepResult({
    required this.stepId,
    required this.stepType,
    required this.route,
    required this.redirectUrl,
    this.sessionId,
    this.attemptId,
    this.substitutedFromTopicId,
  });

  factory StartStepResult.fromJson(Map<String, dynamic> json) {
    return StartStepResult(
      stepId: _asInt(json['stepId']) ?? 0,
      stepType: json['stepType']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      redirectUrl: json['redirectUrl']?.toString() ?? '',
      sessionId: _asInt(json['sessionId']),
      attemptId: _asInt(json['attemptId']),
      substitutedFromTopicId: _asInt(json['substitutedFromTopicId']),
    );
  }

  final int stepId;
  final String stepType;
  final String route;
  final String redirectUrl;
  final int? sessionId;
  final int? attemptId;
  final int? substitutedFromTopicId;

  /// A sibling topic supplied the draw, so the screen says so rather than
  /// silently serving a different topic.
  bool get isSubstituted => substitutedFromTopicId != null;
}

/// A step that is not on this learner's active path (`404
/// LEARNING_PATH_STEP_NOT_FOUND`). Terminal: it is not retryable, because the
/// step will never be on the path however many times it is asked.
class PathStepUnavailable implements Exception {
  const PathStepUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

class LessonCard {
  const LessonCard({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.question,
    this.options = const [],
    this.audioUrl,
  });

  factory LessonCard.fromJson(Map<String, dynamic> json) {
    final optsRaw = json['options'] as List<dynamic>? ?? const [];
    return LessonCard(
      id: _asInt(json['id']) ?? _asInt(json['cardId']) ?? 0,
      type: json['type']?.toString() ?? 'rule',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? json['content']?.toString(),
      question: json['question']?.toString(),
      options: optsRaw.map((e) => e.toString()).toList(growable: false),
      audioUrl: json['audioUrl']?.toString(),
    );
  }

  final int id;
  final String type;
  final String title;
  final String? body;
  final String? question;
  final List<String> options;
  final String? audioUrl;

  bool get isMicroCheck => type.toLowerCase() == 'micro_check';
}

class LessonDetail {
  const LessonDetail({
    required this.id,
    required this.title,
    this.cards = const [],
  });

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    final cardsRaw = json['cards'] as List<dynamic>? ?? const [];
    return LessonDetail(
      id: _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Lesson',
      cards: cardsRaw
          .whereType<Map<String, dynamic>>()
          .map(LessonCard.fromJson)
          .toList(growable: false),
    );
  }

  final int id;
  final String title;
  final List<LessonCard> cards;
}

class LessonProgress {
  const LessonProgress({
    this.viewedCount = 0,
    this.totalCount = 0,
    this.lastViewedCardIndex = 0,
    this.completed = false,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      viewedCount: _asInt(json['viewedCount']) ?? 0,
      totalCount: _asInt(json['totalCount']) ?? 0,
      lastViewedCardIndex: _asInt(json['lastViewedCardIndex']) ?? 0,
      completed: json['completed'] == true,
    );
  }

  final int viewedCount;
  final int totalCount;
  final int lastViewedCardIndex;
  final bool completed;
}

class MicroCheckResult {
  const MicroCheckResult({required this.correct, this.explanation});

  factory MicroCheckResult.fromJson(Map<String, dynamic> json) {
    return MicroCheckResult(
      correct: json['correct'] == true,
      explanation: json['explanation']?.toString(),
    );
  }

  final bool correct;
  final String? explanation;
}

num? _asNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _asString(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

/// A stored score as the learner reads it: certificates that keep marks in
/// tenths (IELTS 8.0 is stored as 80) send `scoreDisplayFactor: 10`.
String? _formatStoredScore(int? stored, int factor) {
  if (stored == null) return null;
  final divisor = factor <= 0 ? 1 : factor;
  final value = stored / divisor;
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
