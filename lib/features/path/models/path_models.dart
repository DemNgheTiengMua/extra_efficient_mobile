/// Domain models for the `PATH` tab: Dashboard, Insights, Target Band &
/// Calibration, Learning Path, and Lesson Player.
class NextActionInfo {
  const NextActionInfo({
    required this.type,
    required this.title,
    required this.description,
    required this.actionLabel,
    this.lessonId,
    this.stepId,
    this.attemptId,
    this.sessionId,
  });

  factory NextActionInfo.fromJson(Map<String, dynamic> json) {
    return NextActionInfo(
      type: json['type']?.toString() ?? 'info',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      actionLabel: json['actionLabel']?.toString() ?? 'CONTINUE',
      lessonId: _asInt(json['lessonId']),
      stepId: _asInt(json['stepId']),
      attemptId: _asInt(json['attemptId']),
      sessionId: _asInt(json['sessionId']),
    );
  }

  final String type;
  final String title;
  final String description;
  final String actionLabel;
  final int? lessonId;
  final int? stepId;
  final int? attemptId;
  final int? sessionId;
}

class SkillMeasurementSummary {
  const SkillMeasurementSummary({
    required this.skill,
    required this.status,
    this.bandCode,
    this.scaledScore,
  });

  factory SkillMeasurementSummary.fromJson(Map<String, dynamic> json) {
    return SkillMeasurementSummary(
      skill: json['skill']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'unmeasured',
      bandCode: json['bandCode']?.toString(),
      scaledScore: _asInt(json['scaledScore']),
    );
  }

  final String skill;
  final String status;
  final String? bandCode;
  final int? scaledScore;
}

class UnfinishedAttemptSummary {
  const UnfinishedAttemptSummary({
    required this.attemptId,
    required this.title,
    required this.purpose,
    this.remainingMinutes,
  });

  factory UnfinishedAttemptSummary.fromJson(Map<String, dynamic> json) {
    return UnfinishedAttemptSummary(
      attemptId: _asInt(json['attemptId']) ?? _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Unfinished Attempt',
      purpose: json['purpose']?.toString() ?? 'mock',
      remainingMinutes: _asInt(json['remainingMinutes']),
    );
  }

  final int attemptId;
  final String title;
  final String purpose;
  final int? remainingMinutes;
}

class UnfinishedPracticeSummary {
  const UnfinishedPracticeSummary({
    required this.sessionId,
    required this.title,
    this.answeredCount = 0,
    this.totalCount = 0,
  });

  factory UnfinishedPracticeSummary.fromJson(Map<String, dynamic> json) {
    return UnfinishedPracticeSummary(
      sessionId: _asInt(json['sessionId']) ?? _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Unfinished Practice Session',
      answeredCount: _asInt(json['answeredCount']) ?? 0,
      totalCount: _asInt(json['totalCount']) ?? 0,
    );
  }

  final int sessionId;
  final String title;
  final int answeredCount;
  final int totalCount;
}

class LearnerDashboard {
  const LearnerDashboard({
    this.currentBandCode = '<A1',
    this.targetBandCode,
    this.scaledScore,
    this.placementCompleted = false,
    this.hasLearningPath = false,
    this.nextAction,
    this.skillMeasurements = const [],
    this.unfinishedAttempt,
    this.unfinishedPractice,
  });

  factory LearnerDashboard.fromJson(Map<String, dynamic> json) {
    final nextActionRaw = json['nextAction'];
    final skillsRaw = json['skillMeasurements'] as List<dynamic>? ?? const [];
    final attemptRaw = json['unfinishedAttempt'];
    final practiceRaw = json['unfinishedPractice'];

    return LearnerDashboard(
      currentBandCode: json['currentBandCode']?.toString() ??
          json['currentBand']?.toString() ??
          '<A1',
      targetBandCode: json['targetBandCode']?.toString() ??
          json['targetBand']?.toString(),
      scaledScore: _asInt(json['scaledScore']),
      placementCompleted: json['placementCompleted'] == true,
      hasLearningPath: json['hasLearningPath'] == true,
      nextAction: nextActionRaw is Map<String, dynamic>
          ? NextActionInfo.fromJson(nextActionRaw)
          : null,
      skillMeasurements: skillsRaw
          .whereType<Map<String, dynamic>>()
          .map(SkillMeasurementSummary.fromJson)
          .toList(growable: false),
      unfinishedAttempt: attemptRaw is Map<String, dynamic>
          ? UnfinishedAttemptSummary.fromJson(attemptRaw)
          : null,
      unfinishedPractice: practiceRaw is Map<String, dynamic>
          ? UnfinishedPracticeSummary.fromJson(practiceRaw)
          : null,
    );
  }

  final String currentBandCode;
  final String? targetBandCode;
  final int? scaledScore;
  final bool placementCompleted;
  final bool hasLearningPath;
  final NextActionInfo? nextAction;
  final List<SkillMeasurementSummary> skillMeasurements;
  final UnfinishedAttemptSummary? unfinishedAttempt;
  final UnfinishedPracticeSummary? unfinishedPractice;
}

class AiInsight {
  const AiInsight({
    required this.status,
    required this.narrative,
    this.errorMessage,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      status: json['status']?.toString() ?? 'ready',
      narrative: json['narrative']?.toString() ??
          json['content']?.toString() ??
          json['summary']?.toString() ??
          '',
      errorMessage: json['errorMessage']?.toString(),
    );
  }

  final String status;
  final String narrative;
  final String? errorMessage;

  bool get isFailed => status.toLowerCase() == 'failed';
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
    final itemsRaw = json['items'] as List<dynamic>? ??
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
  const MicroCheckResult({
    required this.correct,
    this.explanation,
  });

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
