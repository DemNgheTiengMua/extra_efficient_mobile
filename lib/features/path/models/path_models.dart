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

class TargetBandGoal {
  const TargetBandGoal({
    this.currentBandCode,
    this.targetBandCode,
    this.targetDate,
    this.weeklyStudyHours,
    this.availableBands = const ['<A1', 'A1', 'A2', 'B1', 'B2', 'C1'],
  });

  factory TargetBandGoal.fromJson(Map<String, dynamic> json) {
    final bandsRaw = json['availableBands'] as List<dynamic>?;
    final bands = bandsRaw != null && bandsRaw.isNotEmpty
        ? bandsRaw.map((e) => e.toString()).toList(growable: false)
        : const ['<A1', 'A1', 'A2', 'B1', 'B2', 'C1'];

    return TargetBandGoal(
      currentBandCode: json['currentBandCode']?.toString(),
      targetBandCode: json['targetBandCode']?.toString(),
      targetDate: json['targetDate']?.toString(),
      weeklyStudyHours: _asNum(json['weeklyStudyHours']),
      availableBands: bands,
    );
  }

  final String? currentBandCode;
  final String? targetBandCode;
  final String? targetDate;
  final num? weeklyStudyHours;
  final List<String> availableBands;
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

class PathModuleItem {
  const PathModuleItem({
    required this.stepId,
    required this.title,
    required this.type,
    required this.status,
    this.estimatedMinutes,
    this.lessonId,
    this.description,
  });

  factory PathModuleItem.fromJson(Map<String, dynamic> json) {
    return PathModuleItem(
      stepId: _asInt(json['stepId']) ?? _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Step',
      type: json['type']?.toString() ?? 'practice',
      status: json['status']?.toString() ?? 'locked',
      estimatedMinutes: _asInt(json['estimatedMinutes']),
      lessonId: _asInt(json['lessonId']),
      description: json['description']?.toString(),
    );
  }

  final int stepId;
  final String title;
  final String type;
  final String status;
  final int? estimatedMinutes;
  final int? lessonId;
  final String? description;

  bool get isLocked => status.toLowerCase() == 'locked';
}

class PathModule {
  const PathModule({
    required this.id,
    required this.title,
    this.weekNumber,
    this.estimatedMinutes,
    this.description,
    this.isPremiumOnly = false,
    this.items = const [],
  });

  factory PathModule.fromJson(Map<String, dynamic> json) {
    final itemsRaw =
        json['items'] as List<dynamic>? ??
        json['steps'] as List<dynamic>? ??
        const [];
    return PathModule(
      id: _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Module',
      weekNumber: _asInt(json['weekNumber']),
      estimatedMinutes: _asInt(json['estimatedMinutes']),
      description: json['description']?.toString(),
      isPremiumOnly: json['isPremiumOnly'] == true,
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(PathModuleItem.fromJson)
          .toList(growable: false),
    );
  }

  final int id;
  final String title;
  final int? weekNumber;
  final int? estimatedMinutes;
  final String? description;
  final bool isPremiumOnly;
  final List<PathModuleItem> items;
}

class LearningPathOverview {
  const LearningPathOverview({
    this.currentBandCode = '<A1',
    this.targetBandCode,
    this.remainingMinutes = 0,
    this.modules = const [],
  });

  factory LearningPathOverview.fromJson(Map<String, dynamic> json) {
    final modulesRaw = json['modules'] as List<dynamic>? ?? const [];
    return LearningPathOverview(
      currentBandCode: json['currentBandCode']?.toString() ?? '<A1',
      targetBandCode: json['targetBandCode']?.toString(),
      remainingMinutes: _asInt(json['remainingMinutes']) ?? 0,
      modules: modulesRaw
          .whereType<Map<String, dynamic>>()
          .map(PathModule.fromJson)
          .toList(growable: false),
    );
  }

  final String currentBandCode;
  final String? targetBandCode;
  final int remainingMinutes;
  final List<PathModule> modules;
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
