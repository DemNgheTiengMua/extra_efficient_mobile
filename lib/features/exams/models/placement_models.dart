/// Domain models for Placement attempts, Exam Room sittings, and AI Grading results.
class PlacementScopeOption {
  const PlacementScopeOption({
    required this.scope,
    required this.label,
    required this.credits,
  });

  factory PlacementScopeOption.fromJson(Map<String, dynamic> json) {
    return PlacementScopeOption(
      scope: (json['scope'] as String?) ?? 'all_skills',
      label: (json['label'] as String?) ?? 'All Skills',
      credits: (json['credits'] as num?)?.toInt() ?? 0,
    );
  }

  final String scope;
  final String label;
  final int credits;
}

class ReusableSkillMeasurement {
  const ReusableSkillMeasurement({
    required this.skill,
    required this.band,
    required this.expiresAt,
    required this.canReuse,
  });

  factory ReusableSkillMeasurement.fromJson(Map<String, dynamic> json) {
    return ReusableSkillMeasurement(
      skill: (json['skill'] as String?) ?? '',
      band: (json['band'] as String?) ?? '',
      expiresAt: DateTime.tryParse((json['expiresAt'] as String?) ?? ''),
      canReuse: (json['canReuse'] as bool?) ?? false,
    );
  }

  final String skill;
  final String band;
  final DateTime? expiresAt;
  final bool canReuse;
}

/// One placement exam offered by the catalogue.
class PlacementCatalogExam {
  const PlacementCatalogExam({
    required this.examId,
    required this.name,
    required this.durationMinutes,
    required this.questionCount,
    required this.isRecommended,
    this.description,
    this.activePlacementId,
  });

  factory PlacementCatalogExam.fromJson(Map<String, dynamic> json) {
    return PlacementCatalogExam(
      examId: (json['examId'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      isRecommended: (json['isRecommended'] as bool?) ?? false,
      activePlacementId: (json['activePlacementId'] as num?)?.toInt(),
    );
  }

  final int examId;
  final String name;
  final String? description;
  final int durationMinutes;
  final int questionCount;
  final bool isRecommended;
  final int? activePlacementId;
}

/// `GET /api/learner/placement` — the placement catalogue envelope.
///
/// The sitting in progress is `activePlacementId`; the exam list is `exams[]`.
class PlacementCatalog {
  const PlacementCatalog({
    required this.certificateCode,
    required this.certificateName,
    required this.exams,
    required this.isRetake,
    required this.allSkillsRetakeCredits,
    required this.listeningAndReadingRetakeCredits,
    this.currentBandCode,
    this.currentBandName,
    this.currentTotalScore,
    this.activePlacementId,
  });

  factory PlacementCatalog.fromJson(Map<String, dynamic> json) {
    final rawCert = json['activeCert'] as Map<String, dynamic>? ?? const {};
    final rawExams = json['exams'] as List<dynamic>? ?? const [];
    return PlacementCatalog(
      certificateCode: (rawCert['code'] as String?) ?? '',
      certificateName: (rawCert['name'] as String?) ?? '',
      currentBandCode: json['currentBandCode'] as String?,
      currentBandName: json['currentBandName'] as String?,
      currentTotalScore: (json['currentTotalScore'] as num?)?.toInt(),
      exams: rawExams
          .whereType<Map<String, dynamic>>()
          .map(PlacementCatalogExam.fromJson)
          .toList(),
      activePlacementId: (json['activePlacementId'] as num?)?.toInt(),
      isRetake: (json['isRetake'] as bool?) ?? false,
      allSkillsRetakeCredits:
          (json['allSkillsRetakeCredits'] as num?)?.toInt() ?? 0,
      listeningAndReadingRetakeCredits:
          (json['listeningAndReadingRetakeCredits'] as num?)?.toInt() ?? 0,
    );
  }

  final String certificateCode;
  final String certificateName;
  final String? currentBandCode;
  final String? currentBandName;
  final int? currentTotalScore;
  final List<PlacementCatalogExam> exams;
  final int? activePlacementId;
  final bool isRetake;
  final int allSkillsRetakeCredits;
  final int listeningAndReadingRetakeCredits;

  /// The exam the start control points at: the recommended one, else the first.
  ///
  /// Null means the backend published no placement exam, so there is nothing to
  /// start and the control must stay disabled.
  int? get startableExamId {
    if (exams.isEmpty) return null;
    for (final exam in exams) {
      if (exam.isRecommended) return exam.examId;
    }
    return exams.first.examId;
  }

  bool get hasInProgressAttempt => activePlacementId != null;

  /// Credits a retake costs for [scope], from the certificates's own figures.
  int retakeCreditsFor(String scope) => scope == 'listening_and_reading'
      ? listeningAndReadingRetakeCredits
      : allSkillsRetakeCredits;
}

class PlacementPreflight {
  const PlacementPreflight({
    required this.audioSampleUrl,
    required this.requiresMicrophone,
    required this.reusableSkills,
  });

  factory PlacementPreflight.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['reusableSkills'] as List<dynamic>? ?? const [];
    return PlacementPreflight(
      audioSampleUrl: (json['audioSampleUrl'] as String?) ?? '',
      requiresMicrophone: (json['requiresMicrophone'] as bool?) ?? false,
      reusableSkills: rawSkills
          .whereType<Map<String, dynamic>>()
          .map(ReusableSkillMeasurement.fromJson)
          .toList(),
    );
  }

  final String audioSampleUrl;
  final bool requiresMicrophone;
  final List<ReusableSkillMeasurement> reusableSkills;
}

class PlacementOption {
  const PlacementOption({
    required this.optionId,
    required this.label,
    required this.text,
  });

  factory PlacementOption.fromJson(Map<String, dynamic> json) {
    return PlacementOption(
      optionId:
          (json['optionId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      label: (json['label'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
    );
  }

  final int optionId;
  final String label;
  final String text;
}

class PlacementQuestion {
  const PlacementQuestion({
    required this.questionId,
    required this.index,
    required this.skill,
    required this.sectionName,
    required this.prompt,
    required this.options,
    this.passageText,
    this.audioUrl,
    this.audioStartMs,
    this.audioEndMs,
    this.selectedOptionId,
    this.selectedOptionIdsJson,
    this.responseText,
    this.isFlagged = false,
    this.prepSeconds,
    this.responseSeconds,
    this.wordFloor,
    this.skillId,
    this.unitNumber,
    this.groupId,
  });

  factory PlacementQuestion.fromJson(
    Map<String, dynamic> json,
    int fallbackIdx,
  ) {
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    return PlacementQuestion(
      questionId:
          (json['questionId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      index: (json['index'] as num?)?.toInt() ?? fallbackIdx,
      skill: ((json['skill'] as String?) ?? 'reading').toLowerCase(),
      sectionName: (json['sectionName'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? (json['stem'] as String?) ?? '',
      passageText: json['passageText'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioStartMs:
          (json['audioStartMs'] as num?)?.toInt() ??
          (json['startMs'] as num?)?.toInt(),
      audioEndMs:
          (json['audioEndMs'] as num?)?.toInt() ??
          (json['endMs'] as num?)?.toInt(),
      options: rawOptions
          .whereType<Map<String, dynamic>>()
          .map(PlacementOption.fromJson)
          .toList(),
      selectedOptionId: (json['selectedOptionId'] as num?)?.toInt(),
      selectedOptionIdsJson: json['selectedOptionIdsJson'] as String?,
      responseText: json['responseText'] as String?,
      isFlagged: (json['isFlagged'] as bool?) ?? false,
      prepSeconds: (json['prepSeconds'] as num?)?.toInt(),
      responseSeconds: (json['responseSeconds'] as num?)?.toInt(),
      wordFloor: (json['wordFloor'] as num?)?.toInt(),
      skillId: (json['skillId'] as num?)?.toInt(),
      unitNumber: (json['unitNumber'] as num?)?.toInt(),
      groupId: (json['groupId'] as num?)?.toInt(),
    );
  }

  PlacementQuestion copyWith({
    int? selectedOptionId,
    bool clearSelectedOptionId = false,
    String? selectedOptionIdsJson,
    String? responseText,
    bool? isFlagged,
  }) {
    return PlacementQuestion(
      questionId: questionId,
      index: index,
      skill: skill,
      sectionName: sectionName,
      prompt: prompt,
      passageText: passageText,
      audioUrl: audioUrl,
      audioStartMs: audioStartMs,
      audioEndMs: audioEndMs,
      options: options,
      selectedOptionId: clearSelectedOptionId
          ? null
          : (selectedOptionId ?? this.selectedOptionId),
      selectedOptionIdsJson:
          selectedOptionIdsJson ?? this.selectedOptionIdsJson,
      responseText: responseText ?? this.responseText,
      isFlagged: isFlagged ?? this.isFlagged,
      prepSeconds: prepSeconds,
      responseSeconds: responseSeconds,
      wordFloor: wordFloor,
      skillId: skillId,
      unitNumber: unitNumber,
      groupId: groupId,
    );
  }

  bool get isAnswered =>
      selectedOptionId != null ||
      (responseText != null && responseText!.trim().isNotEmpty) ||
      (selectedOptionIdsJson != null && selectedOptionIdsJson!.isNotEmpty);

  final int questionId;
  final int index;
  final String skill;
  final String sectionName;
  final String prompt;
  final String? passageText;
  final String? audioUrl;
  final int? audioStartMs;
  final int? audioEndMs;
  final List<PlacementOption> options;
  final int? selectedOptionId;
  final String? selectedOptionIdsJson;
  final String? responseText;
  final bool isFlagged;
  final int? prepSeconds;
  final int? responseSeconds;
  final int? wordFloor;
  final int? skillId;
  final int? unitNumber;
  final int? groupId;
}

class PlacementSitting {
  const PlacementSitting({
    required this.placementId,
    required this.expiresAt,
    required this.status,
    required this.questions,
    this.activeSkillId,
    this.activeUnitNumber,
    this.activeGroupId,
    this.phaseDeadlineAt,
  });

  factory PlacementSitting.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? const [];
    final questions = <PlacementQuestion>[];
    for (var i = 0; i < rawQuestions.length; i++) {
      final item = rawQuestions[i];
      if (item is Map<String, dynamic>) {
        questions.add(PlacementQuestion.fromJson(item, i));
      }
    }
    return PlacementSitting(
      placementId: (json['placementId'] as num?)?.toInt() ?? 0,
      expiresAt:
          DateTime.tryParse((json['expiresAt'] as String?) ?? '') ??
          DateTime.now().toUtc().add(const Duration(minutes: 20)),
      status: (json['status'] as String?) ?? 'in_progress',
      questions: questions,
      activeSkillId: (json['activeSkillId'] as num?)?.toInt(),
      activeUnitNumber: (json['activeUnitNumber'] as num?)?.toInt(),
      activeGroupId: (json['activeGroupId'] as num?)?.toInt(),
      phaseDeadlineAt: DateTime.tryParse(
        (json['phaseDeadlineAt'] as String?) ?? '',
      ),
    );
  }

  final int placementId;
  final DateTime expiresAt;
  final String status;
  final List<PlacementQuestion> questions;
  final int? activeSkillId;
  final int? activeUnitNumber;
  final int? activeGroupId;
  final DateTime? phaseDeadlineAt;
}

/// The sitting is over (already graded, abandoned or expired).
///
/// `GET .../take/{id}/resume` answers 400 `placement_not_active` for exactly
/// this case. It is a terminal state, never a retryable error.
class PlacementNotActiveException implements Exception {
  const PlacementNotActiveException(this.placementId);

  final int placementId;

  @override
  String toString() => 'Placement $placementId is no longer in progress.';
}

/// One skill's progress inside [PlacementResumeStatus].
class PlacementResumeSkill {
  const PlacementResumeSkill({
    required this.code,
    required this.name,
    required this.isDone,
    required this.isActive,
    required this.answeredCount,
    required this.totalQuestions,
  });

  factory PlacementResumeSkill.fromJson(Map<String, dynamic> json) {
    return PlacementResumeSkill(
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      isDone: (json['isDone'] as bool?) ?? false,
      isActive: (json['isActive'] as bool?) ?? false,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
    );
  }

  final String code;
  final String name;
  final bool isDone;
  final bool isActive;
  final int answeredCount;
  final int totalQuestions;
}

/// `GET /api/learner/placement/take/{placementId}/resume` — progress only.
///
/// The payload has no questions at all, so nothing may render a room from it.
/// Its job here is to answer "is this sitting still open?" and to say where the
/// learner had got to.
class PlacementResumeStatus {
  const PlacementResumeStatus({
    required this.placementId,
    required this.attemptId,
    required this.examName,
    required this.syncedAnswerCount,
    required this.totalQuestions,
    this.activeSkillName,
    this.activeStage,
    this.totalStages = 0,
    this.lastQuestionId,
  });

  factory PlacementResumeStatus.fromJson(Map<String, dynamic> json) {
    return PlacementResumeStatus(
      placementId: (json['placementId'] as num?)?.toInt() ?? 0,
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examName: (json['examName'] as String?) ?? '',
      activeSkillName: json['activeSkillName'] as String?,
      activeStage: (json['activeStage'] as num?)?.toInt(),
      totalStages: (json['totalStages'] as num?)?.toInt() ?? 0,
      syncedAnswerCount: (json['syncedAnswerCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      lastQuestionId: (json['lastQuestionId'] as num?)?.toInt(),
    );
  }

  final int placementId;
  final int attemptId;
  final String examName;
  final String? activeSkillName;
  final int? activeStage;
  final int totalStages;
  final int syncedAnswerCount;
  final int totalQuestions;
  final int? lastQuestionId;
}

/// One skill row of a finished placement.
class PlacementSkillScore {
  const PlacementSkillScore({
    required this.skillId,
    required this.skillCode,
    required this.skillName,
    required this.rawScore,
    required this.totalQuestions,
    required this.scaledScore,
    this.bandCode,
  });

  factory PlacementSkillScore.fromJson(Map<String, dynamic> json) {
    return PlacementSkillScore(
      skillId: (json['skillId'] as num?)?.toInt() ?? 0,
      skillCode: (json['skillCode'] as String?) ?? '',
      skillName: (json['skillName'] as String?) ?? '',
      rawScore: (json['rawScore'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      scaledScore: (json['scaledScore'] as num?)?.toInt() ?? 0,
      bandCode: json['bandCode'] as String?,
    );
  }

  final int skillId;
  final String skillCode;
  final String skillName;
  final int rawScore;
  final int totalQuestions;
  final int scaledScore;
  final String? bandCode;

  /// Unbanded is `""` on `/result` and `null` on `/result/status`.
  bool get isBanded => bandCode != null && bandCode!.isNotEmpty;

  String get bandLabel => isBanded ? bandCode! : 'NOT YET BANDED';
}

/// `GET /api/learner/placement/result/{placementId}`.
///
/// The same shape serves `/result/{id}/status`, where band fields are null while
/// grading and only the progress fields are meaningful.
class PlacementResult {
  const PlacementResult({
    required this.placementId,
    required this.examName,
    required this.bandCode,
    required this.bandName,
    required this.totalScore,
    required this.skillScores,
    required this.isGraded,
    this.scoreDisplayFactor = 1,
    this.stageDescriptor,
    this.failedFreeResponseCount = 0,
    this.weakerSkillName,
  });

  factory PlacementResult.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['skillScores'] as List<dynamic>? ?? const [];
    return PlacementResult(
      placementId: (json['placementId'] as num?)?.toInt() ?? 0,
      examName: (json['examName'] as String?) ?? '',
      bandCode:
          (json['resultBandCode'] as String?) ??
          (json['bandCode'] as String?) ??
          '',
      bandName:
          (json['resultBandName'] as String?) ??
          (json['bandName'] as String?) ??
          '',
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      scoreDisplayFactor: (json['scoreDisplayFactor'] as num?)?.toInt() ?? 1,
      skillScores: rawSkills
          .whereType<Map<String, dynamic>>()
          .map(PlacementSkillScore.fromJson)
          .toList(),
      // `/result` omits isGraded once finished; `/status` always sends it.
      isGraded: (json['isGraded'] as bool?) ?? true,
      stageDescriptor: json['stageDescriptor'] as String?,
      failedFreeResponseCount:
          (json['failedFreeResponseCount'] as num?)?.toInt() ?? 0,
      weakerSkillName: json['weakerSkillName'] as String?,
    );
  }

  final int placementId;
  final String examName;
  final String bandCode;
  final String bandName;
  final int totalScore;
  final List<PlacementSkillScore> skillScores;
  final bool isGraded;
  final int scoreDisplayFactor;
  final String? stageDescriptor;
  final int failedFreeResponseCount;
  final String? weakerSkillName;

  /// The score as the page prints it: stored units divided by the display factor.
  int get displayTotalScore =>
      scoreDisplayFactor > 1 ? totalScore ~/ scoreDisplayFactor : totalScore;

  /// Unbanded is `""` (or null) — render it as a state, never an empty badge.
  bool get isBanded => bandCode.isNotEmpty;

  String get bandLabel {
    if (!isBanded) return 'NOT YET BANDED';
    return bandName.isEmpty
        ? bandCode
        : '$bandCode · ${bandName.toUpperCase()}';
  }

  bool get hasFailedGrading => failedFreeResponseCount > 0;

  /// True while free-response grading is still in flight.
  bool get isPending => !isGraded;
}
