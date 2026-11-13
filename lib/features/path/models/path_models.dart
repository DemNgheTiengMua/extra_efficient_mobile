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

/// One selectable band: `{code, name, minTotal, maxTotal, description, isCurrent, isTarget}`.
class TargetBandGoal {
  const TargetBandGoal({
    this.currentBandCode,
    this.targetBandCode,
    this.targetDate,
    this.weeklyStudyHours,
    this.currentBandName,
    this.currentTotalScore,
    this.availableBands = const [],
  });

  factory TargetBandGoal.fromJson(Map<String, dynamic> json) {
    // The backend sends availableBands as objects, not bare codes. Coercing them
    // with toString() renders "Instance of '_Map'", so read the code explicitly.
    final bandsRaw = json['availableBands'] as List<dynamic>? ?? const [];
    final bands = bandsRaw
        .whereType<Map<String, dynamic>>()
        .map(BandOption.fromJson)
        .toList(growable: false);

    final goal = json['goal'] is Map<String, dynamic>
        ? json['goal'] as Map<String, dynamic>
        : const <String, dynamic>{};

    // `goal.targetBandCode` is "" when unset while the outer one is null; both
    // mean "no target", so normalise the empty string away.
    final outerTarget = json['targetBandCode']?.toString();
    final goalTarget = goal['targetBandCode']?.toString();
    final target = (outerTarget != null && outerTarget.isNotEmpty)
        ? outerTarget
        : (goalTarget != null && goalTarget.isNotEmpty ? goalTarget : null);

    return TargetBandGoal(
      // The assessed band is reported at the top level; the goal's own column is
      // the fallback, because a goal records the band it was set from.
      currentBandCode:
          _asString(json['currentBandCode']) ?? _asString(goal['currentBandCode']),
      currentBandName: json['currentBandName']?.toString(),
      currentTotalScore: _asNum(json['currentTotalScore'])?.toInt(),
      targetBandCode: target,
      // The deadline and the pace are the saved goal's own columns, so they
      // arrive nested under `goal`.
      targetDate: _asString(json['targetDate']) ?? _asString(goal['targetDate']),
      weeklyStudyHours: _asNum(json['weeklyStudyHours']) ??
          _asNum(goal['weeklyStudyHours']),
      availableBands: bands,
    );
  }

  final String? currentBandCode;
  final String? currentBandName;
  final int? currentTotalScore;
  final String? targetBandCode;
  final String? targetDate;
  final num? weeklyStudyHours;
  final List<BandOption> availableBands;

  /// A path can only be generated towards a band that has been chosen, because
  /// `POST /learning-path/generate` answers 422 without one.
  bool get hasTargetBand => targetBandCode != null;
}

/// One selectable band: `{code, name, minTotal, maxTotal, description, isCurrent, isTarget}`.
class BandOption {
  const BandOption({
    required this.code,
    required this.name,
    this.minTotal,
    this.maxTotal,
    this.description,
    this.isCurrent = false,
    this.isTarget = false,
  });

  factory BandOption.fromJson(Map<String, dynamic> json) {
    return BandOption(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      minTotal: _asNum(json['minTotal'])?.toInt(),
      maxTotal: _asNum(json['maxTotal'])?.toInt(),
      description: json['description']?.toString(),
      isCurrent: json['isCurrent'] == true,
      isTarget: json['isTarget'] == true,
    );
  }

  final String code;
  final String name;
  final int? minTotal;
  final int? maxTotal;
  final String? description;
  final bool isCurrent;
  final bool isTarget;

  /// e.g. "Below A1 · 10–119 points"
  String get label {
    final range = (minTotal != null && maxTotal != null)
        ? ' · $minTotal–$maxTotal points'
        : '';
    return '$name$range';
  }

  /// The backend's own ready-to-print range, falling back to the two totals
  /// when it sends none.
  String get rangeText =>
      (description != null && description!.isNotEmpty)
          ? description!
          : (minTotal != null && maxTotal != null
                ? '$minTotal to $maxTotal points'
                : '');
}

/// What the backend can say about whether practice still matches the placed
/// band (`CalibrationViewDto`). `proposal` is null when there is nothing to
/// propose, and [reason] says which of the reasons that is.
class CalibrationStatus {
  const CalibrationStatus({
    this.placedBandCode = '',
    this.placedBandName,
    this.validAnswerCount = 0,
    this.requiredValidAnswerCount = 0,
    this.excludedRushedCount = 0,
    this.observedAccuracyPct,
    this.reason = '',
    this.proposal,
  });

  factory CalibrationStatus.fromJson(Map<String, dynamic> json) {
    final rawProposal = json['proposal'];
    return CalibrationStatus(
      placedBandCode: json['placedBandCode']?.toString() ?? '',
      placedBandName: json['placedBandName']?.toString(),
      validAnswerCount: _asNum(json['validAnswerCount'])?.toInt() ?? 0,
      requiredValidAnswerCount:
          _asNum(json['requiredValidAnswerCount'])?.toInt() ?? 0,
      excludedRushedCount: _asNum(json['excludedRushedCount'])?.toInt() ?? 0,
      observedAccuracyPct: _asNum(json['observedAccuracyPct']),
      reason: json['reason']?.toString() ?? '',
      proposal: rawProposal is Map<String, dynamic>
          ? CalibrationProposal.fromJson(rawProposal)
          : null,
    );
  }

  final String placedBandCode;
  final String? placedBandName;
  final int validAnswerCount;
  final int requiredValidAnswerCount;
  final int excludedRushedCount;
  final num? observedAccuracyPct;
  final String reason;
  final CalibrationProposal? proposal;

  /// A proposal exists only when the backend offers one; there is no band to
  /// adjust towards otherwise.
  bool get hasProposal => proposal != null;

  /// Enough answers for the comparison to mean anything.
  bool get hasEnoughAnswers => validAnswerCount >= requiredValidAnswerCount;
}

class CalibrationProposal {
  const CalibrationProposal({
    required this.proposedBandCode,
    required this.proposedBandName,
    required this.observedAccuracyPct,
    required this.validAnswerCount,
    required this.requiredAccuracyPct,
    required this.evidence,
  });

  factory CalibrationProposal.fromJson(Map<String, dynamic> json) {
    return CalibrationProposal(
      proposedBandCode: json['proposedBandCode']?.toString() ?? '',
      proposedBandName: json['proposedBandName']?.toString() ?? '',
      observedAccuracyPct: _asNum(json['observedAccuracyPct']) ?? 0,
      validAnswerCount: _asNum(json['validAnswerCount'])?.toInt() ?? 0,
      requiredAccuracyPct: _asNum(json['requiredAccuracyPct'])?.toInt() ?? 0,
      evidence: json['evidence']?.toString() ?? '',
    );
  }

  final String proposedBandCode;
  final String proposedBandName;
  final num observedAccuracyPct;
  final int validAnswerCount;
  final int requiredAccuracyPct;
  final String evidence;
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
          .map(BandOption.fromJson)
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
  final List<BandOption> cefrBands;
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

/// One answer choice on a `micro_check` card. The backend sends four separate
/// fields (`optionA`–`optionD`) and grades against a single-letter label, so the
/// label — not the text — is what a submission carries.
class LessonOption {
  const LessonOption({required this.label, required this.text});

  final String label;
  final String text;
}

/// One card of a lesson module (`LessonCardDto`).
///
/// `cardType` is `rule | pitfall | example | micro_check`. Only a `micro_check`
/// carries a prompt and options, and `correctOption` is **null** on the lesson
/// payload even for one — the key is revealed by the graded micro-check.
class LessonCard {
  const LessonCard({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.question,
    this.options = const [],
    this.displayOrder = 0,
  });

  factory LessonCard.fromJson(Map<String, dynamic> json) {
    // Options are four named fields, not a list. Read the label alongside its
    // text so a submission sends "B", which is what the grader compares.
    final options = <LessonOption>[
      for (final entry in const [
        ('A', 'optionA'),
        ('B', 'optionB'),
        ('C', 'optionC'),
        ('D', 'optionD'),
      ])
        if (_asString(json[entry.$2]) case final text?)
          LessonOption(label: entry.$1, text: text),
    ];

    return LessonCard(
      id: _asInt(json['cardId']) ?? 0,
      type: json['cardType']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: _asString(json['contentMarkdown']),
      question: _asString(json['questionPrompt']),
      options: options,
      displayOrder: _asInt(json['displayOrder']) ?? 0,
    );
  }

  final int id;
  final String type;
  final String title;
  final String? body;
  final String? question;
  final List<LessonOption> options;
  final int displayOrder;

  bool get isMicroCheck => type.toLowerCase() == 'micro_check';
}

class LessonDetail {
  const LessonDetail({
    required this.id,
    required this.title,
    this.summary,
    this.estimatedMinutes = 0,
    this.cards = const [],
    this.topicCode = '',
    this.topicName = '',
    this.cefrLevel = '',
    this.module = 'primary',
    this.hasRemedialModule = false,
  });

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    final cardsRaw = json['cards'] as List<dynamic>? ?? const [];
    return LessonDetail(
      id: _asInt(json['lessonId']) ?? 0,
      title: json['title']?.toString() ?? '',
      summary: _asString(json['summary']),
      estimatedMinutes: _asInt(json['estimatedMinutes']) ?? 0,
      cards: cardsRaw
          .whereType<Map<String, dynamic>>()
          .map(LessonCard.fromJson)
          .toList(growable: false),
      topicCode: json['topicCode']?.toString() ?? '',
      topicName: json['topicName']?.toString() ?? '',
      cefrLevel: json['cefrLevel']?.toString() ?? '',
      module: json['module']?.toString() ?? 'primary',
      hasRemedialModule: json['hasRemedialModule'] == true,
    );
  }

  final int id;
  final String title;
  final String? summary;
  final int estimatedMinutes;
  final List<LessonCard> cards;
  final String topicCode;
  final String topicName;
  final String cefrLevel;
  final String module;
  final bool hasRemedialModule;
}

/// `LessonProgressDto`: where the learner stopped inside one module.
///
/// [resumeCardIndex] is 1-based, as the service computes it, so the reader opens
/// on `resumeCardIndex - 1`.
class LessonProgress {
  const LessonProgress({
    this.cardsCompleted = 0,
    this.totalCards = 0,
    this.isCompleted = false,
    this.lastViewedCardId,
    this.resumeCardIndex = 1,
    this.module = 'primary',
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      cardsCompleted: _asInt(json['cardsCompleted']) ?? 0,
      totalCards: _asInt(json['totalCards']) ?? 0,
      isCompleted: json['isCompleted'] == true,
      lastViewedCardId: _asInt(json['lastViewedCardId']),
      resumeCardIndex: _asInt(json['resumeCardIndex']) ?? 1,
      module: json['module']?.toString() ?? 'primary',
    );
  }

  final int cardsCompleted;
  final int totalCards;
  final bool isCompleted;
  final int? lastViewedCardId;

  /// 1-based position of the card the reader opens on.
  final int resumeCardIndex;
  final String module;

  /// The 0-based page index `resumeCardIndex` names.
  int get resumeCardOffset => resumeCardIndex <= 0 ? 0 : resumeCardIndex - 1;
}

/// `MicroCheckResultDto`: the verdict the backend grades, and the only place the
/// correct option is revealed.
class MicroCheckResult {
  const MicroCheckResult({
    required this.isCorrect,
    this.correctOption,
    this.explanation,
  });

  factory MicroCheckResult.fromJson(Map<String, dynamic> json) {
    return MicroCheckResult(
      isCorrect: json['isCorrect'] == true,
      correctOption: _asString(json['correctOption']),
      explanation: _asString(json['explanation']),
    );
  }

  final bool isCorrect;
  final String? correctOption;
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
