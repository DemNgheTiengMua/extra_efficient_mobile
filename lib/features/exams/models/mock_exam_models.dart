/// Domain models for the mock-exam catalogue, instructions, history, result
/// and review.
///
/// Every parser reads the backend's own key names (`Contracts/Attempts/*.cs`);
/// a mismatch here is silent, so each field is asserted against a recorded
/// payload in `test/contract/exam_contract_test.dart`.
library;

/// Mirror of `AttemptStatusDto` — lowercase strings on the wire.
enum ExamAttemptStatus {
  inProgress,
  submitted,
  graded,
  abandoned;

  static ExamAttemptStatus fromWire(String? value) {
    return switch (value) {
      'in_progress' => ExamAttemptStatus.inProgress,
      'submitted' => ExamAttemptStatus.submitted,
      'graded' => ExamAttemptStatus.graded,
      'abandoned' => ExamAttemptStatus.abandoned,
      _ => ExamAttemptStatus.graded,
    };
  }

  /// The backend's own word, for display.
  String get wireName => switch (this) {
    ExamAttemptStatus.inProgress => 'in_progress',
    ExamAttemptStatus.submitted => 'submitted',
    ExamAttemptStatus.graded => 'graded',
    ExamAttemptStatus.abandoned => 'abandoned',
  };

  String get label => switch (this) {
    ExamAttemptStatus.inProgress => 'IN PROGRESS',
    ExamAttemptStatus.submitted => 'SUBMITTED',
    ExamAttemptStatus.graded => 'GRADED',
    ExamAttemptStatus.abandoned => 'ABANDONED',
  };

  /// Unfinished means the learner can still go back into the sitting.
  bool get isUnfinished =>
      this == ExamAttemptStatus.inProgress ||
      this == ExamAttemptStatus.submitted;
}

/// One row of `GET /api/learner/exams`.
class MockExamSummary {
  const MockExamSummary({
    required this.examId,
    required this.name,
    required this.durationMinutes,
    required this.creditCost,
    this.questionCount,
    this.description,
    this.activeAttemptId,
    this.completedAttemptScore,
    this.completedAttemptBand,
  });

  factory MockExamSummary.fromJson(Map<String, dynamic> json) {
    return MockExamSummary(
      examId: (json['examId'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt(),
      creditCost: (json['creditCost'] as num?)?.toInt() ?? 0,
      activeAttemptId: (json['activeAttemptId'] as num?)?.toInt(),
      completedAttemptScore: (json['completedAttemptScore'] as num?)?.toInt(),
      completedAttemptBand: json['completedAttemptBand'] as String?,
    );
  }

  final int examId;
  final String name;
  final String? description;
  final int durationMinutes;

  /// Nullable by design: an exam whose questions are not yet authored.
  final int? questionCount;
  final int creditCost;

  /// The attempt already begun on this exam, under the backend's own name.
  final int? activeAttemptId;
  final int? completedAttemptScore;

  /// A band *code* (`below_A1`, `B1`), not a display name.
  final String? completedAttemptBand;

  bool get hasActiveAttempt => activeAttemptId != null;
}

/// `GET /api/learner/exams` — the mock catalogue envelope.
class MockExamCatalogue {
  const MockExamCatalogue({
    required this.certificateCode,
    required this.creditBalance,
    required this.exams,
  });

  factory MockExamCatalogue.fromJson(Map<String, dynamic> json) {
    final rawCert = json['certificate'] as Map<String, dynamic>? ?? const {};
    final rawExams = json['exams'] as List<dynamic>? ?? const [];
    return MockExamCatalogue(
      certificateCode: (rawCert['code'] as String?) ?? '',
      creditBalance: (json['creditBalance'] as num?)?.toInt() ?? 0,
      exams: rawExams
          .whereType<Map<String, dynamic>>()
          .map(MockExamSummary.fromJson)
          .toList(),
    );
  }

  final String certificateCode;
  final int creditBalance;
  final List<MockExamSummary> exams;
}

/// One section row of the instructions payload.
class MockExamSectionInfo {
  const MockExamSectionInfo({
    required this.name,
    required this.questionCount,
    this.durationMinutes,
  });

  factory MockExamSectionInfo.fromJson(Map<String, dynamic> json) {
    return MockExamSectionInfo(
      name: (json['sectionName'] as String?) ?? '',
      // The authored count; `expectedQuestionCount` is the blueprint target.
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    );
  }

  final String name;
  final int questionCount;
  final int? durationMinutes;
}

/// `GET /api/learner/exams/{examId}/instructions`.
class MockExamInstructions {
  const MockExamInstructions({
    required this.examId,
    required this.examName,
    required this.durationMinutes,
    required this.creditCost,
    required this.creditBalance,
    required this.sections,
    this.questionCount,
    this.description,
    this.activeAttemptId,
  });

  factory MockExamInstructions.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    return MockExamInstructions(
      examId: (json['examId'] as num?)?.toInt() ?? 0,
      examName: (json['examName'] as String?) ?? '',
      description: json['description'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt(),
      creditCost: (json['creditCost'] as num?)?.toInt() ?? 0,
      creditBalance: (json['creditBalance'] as num?)?.toInt() ?? 0,
      activeAttemptId: (json['activeAttemptId'] as num?)?.toInt(),
      sections: rawSections
          .whereType<Map<String, dynamic>>()
          .map(MockExamSectionInfo.fromJson)
          .toList(),
    );
  }

  final int examId;
  final String examName;
  final String? description;
  final int durationMinutes;
  final int? questionCount;
  final int creditCost;
  final int creditBalance;
  final int? activeAttemptId;
  final List<MockExamSectionInfo> sections;

  bool get hasActiveAttempt => activeAttemptId != null;
}

class MockPreflight {
  const MockPreflight({
    required this.attemptId,
    required this.audioSampleUrl,
    required this.requiresMicrophone,
  });

  factory MockPreflight.fromJson(Map<String, dynamic> json) {
    return MockPreflight(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      audioSampleUrl: (json['audioSampleUrl'] as String?) ?? '',
      requiresMicrophone: (json['requiresMicrophone'] as bool?) ?? false,
    );
  }

  final int attemptId;
  final String audioSampleUrl;
  final bool requiresMicrophone;
}

/// One row of `GET /api/learner/exams/history`'s `attempts[]`.
class ExamHistoryItem {
  const ExamHistoryItem({
    required this.attemptId,
    required this.examId,
    required this.examName,
    required this.totalScore,
    required this.status,
    this.bandCode,
    this.bandName,
    this.submittedAt,
  });

  factory ExamHistoryItem.fromJson(Map<String, dynamic> json) {
    return ExamHistoryItem(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examId: (json['examId'] as num?)?.toInt() ?? 0,
      examName: (json['examName'] as String?) ?? '',
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      bandCode: json['bandCode'] as String?,
      bandName: json['bandName'] as String?,
      submittedAt: DateTime.tryParse((json['submittedAt'] as String?) ?? ''),
      status: ExamAttemptStatus.fromWire(json['status'] as String?),
    );
  }

  final int attemptId;
  final int examId;
  final String examName;
  final int totalScore;
  final String? bandCode;
  final String? bandName;
  final DateTime? submittedAt;
  final ExamAttemptStatus status;

  bool get isInProgress => status == ExamAttemptStatus.inProgress;

  bool get isBanded => bandCode != null && bandCode!.isNotEmpty;

  String get bandLabel {
    if (!isBanded) return isInProgress ? 'IN PROGRESS' : 'NOT BANDED';
    return bandName == null ? bandCode! : '$bandCode · ${bandName!}';
  }
}

/// `GET /api/learner/exams/history` — the history envelope.
class ExamHistory {
  const ExamHistory({
    required this.totalAttempts,
    required this.attempts,
    this.bestScore,
    this.averageScore,
    this.bestBandCode,
    this.bestBandName,
  });

  factory ExamHistory.fromJson(Map<String, dynamic> json) {
    final rawAttempts = json['attempts'] as List<dynamic>? ?? const [];
    return ExamHistory(
      totalAttempts: (json['totalAttempts'] as num?)?.toInt() ?? 0,
      bestScore: (json['bestScore'] as num?)?.toInt(),
      averageScore: (json['averageScore'] as num?)?.toInt(),
      bestBandCode: json['bestScoreBandCode'] as String?,
      bestBandName: json['bestScoreBandName'] as String?,
      attempts: rawAttempts
          .whereType<Map<String, dynamic>>()
          .map(ExamHistoryItem.fromJson)
          .toList(),
    );
  }

  final int totalAttempts;
  final int? bestScore;
  final int? averageScore;
  final String? bestBandCode;
  final String? bestBandName;
  final List<ExamHistoryItem> attempts;
}

/// One skill row shared by the result and review payloads.
class AttemptSkillScore {
  const AttemptSkillScore({
    required this.skillName,
    required this.rawScore,
    required this.scaledScore,
    required this.totalQuestions,
  });

  factory AttemptSkillScore.fromJson(Map<String, dynamic> json) {
    return AttemptSkillScore(
      skillName: (json['skillName'] as String?) ?? '',
      rawScore: (json['rawScore'] as num?)?.toInt() ?? 0,
      scaledScore: (json['scaledScore'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
    );
  }

  final String skillName;
  final int rawScore;
  final int scaledScore;
  final int totalQuestions;
}

/// `GET /api/learner/attempts/{attemptId}/result`.
class MockAttemptResult {
  const MockAttemptResult({
    required this.attemptId,
    required this.examName,
    required this.totalScore,
    required this.skillScores,
    this.bandCode,
    this.bandName,
    this.scoreDelta,
    this.scoreDisplayFactor = 1,
  });

  factory MockAttemptResult.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['skillScores'] as List<dynamic>? ?? const [];
    return MockAttemptResult(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examName: (json['examName'] as String?) ?? '',
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      bandCode: json['bandCode'] as String?,
      bandName: json['bandName'] as String?,
      scoreDelta: (json['scoreDelta'] as num?)?.toInt(),
      scoreDisplayFactor: (json['scoreDisplayFactor'] as num?)?.toInt() ?? 1,
      skillScores: rawSkills
          .whereType<Map<String, dynamic>>()
          .map(AttemptSkillScore.fromJson)
          .toList(),
    );
  }

  final int attemptId;
  final String examName;
  final int totalScore;
  final String? bandCode;
  final String? bandName;
  final int? scoreDelta;

  /// Stored units per reported point (#152): divide before printing.
  final int scoreDisplayFactor;
  final List<AttemptSkillScore> skillScores;

  int get displayTotalScore =>
      scoreDisplayFactor > 1 ? totalScore ~/ scoreDisplayFactor : totalScore;

  bool get isBanded => bandCode != null && bandCode!.isNotEmpty;

  String get bandLabel {
    if (!isBanded) return 'NOT YET BANDED';
    return bandName == null ? bandCode! : '$bandCode · ${bandName!}';
  }
}

class ExamAiInsight {
  const ExamAiInsight({
    required this.status,
    this.narrative,
    this.failureReason,
  });

  factory ExamAiInsight.fromJson(Map<String, dynamic> json) {
    return ExamAiInsight(
      status: ((json['status'] as String?) ?? 'pending').toLowerCase(),
      narrative:
          (json['narrative'] as String?) ??
          (json['formattedNarrative'] as String?),
      failureReason: json['failureReason'] as String?,
    );
  }

  final String status;
  final String? narrative;
  final String? failureReason;

  bool get isFailed => status == 'failed';
}

/// One option of a reviewed question, carrying the backend's own correctness
/// flag and rationale.
class MockReviewOption {
  const MockReviewOption({
    required this.optionId,
    required this.label,
    required this.text,
    required this.isCorrect,
    this.rationale,
  });

  factory MockReviewOption.fromJson(Map<String, dynamic> json) {
    return MockReviewOption(
      optionId: (json['optionId'] as num?)?.toInt() ?? 0,
      label: (json['label'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      isCorrect: (json['isCorrect'] as bool?) ?? false,
      rationale: json['rationale'] as String?,
    );
  }

  final int optionId;
  final String label;
  final String text;
  final bool isCorrect;
  final String? rationale;
}

/// One question of `GET /api/learner/attempts/{attemptId}/review`.
///
/// Correctness is read from the per-option flags the backend nests inside each
/// option, not from a flat label.
class MockReviewQuestion {
  const MockReviewQuestion({
    required this.questionId,
    required this.displayOrder,
    required this.skillName,
    required this.stem,
    required this.options,
    required this.isFlagged,
    this.isCorrect,
    this.explanation,
    this.transcript,
    this.passage,
    this.audioPath,
    this.audioStartMs,
    this.audioEndMs,
    this.selectedOptionId,
  });

  factory MockReviewQuestion.fromJson(
    Map<String, dynamic> json,
    int fallbackOrder,
  ) {
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    return MockReviewQuestion(
      questionId: (json['questionId'] as num?)?.toInt() ?? 0,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? fallbackOrder,
      skillName: (json['skillName'] as String?) ?? '',
      stem: (json['stem'] as String?) ?? '',
      options: rawOptions
          .whereType<Map<String, dynamic>>()
          .map(MockReviewOption.fromJson)
          .toList(),
      // bool? because a blank answer has no verdict.
      isCorrect: json['isCorrect'] as bool?,
      isFlagged: (json['isFlagged'] as bool?) ?? false,
      explanation: json['explanation'] as String?,
      transcript: json['transcript'] as String?,
      passage: json['passage'] as String?,
      audioPath: json['audioPath'] as String?,
      audioStartMs: (json['audioStartMs'] as num?)?.toInt(),
      audioEndMs: (json['audioEndMs'] as num?)?.toInt(),
      selectedOptionId: (json['selectedOptionId'] as num?)?.toInt(),
    );
  }

  final int questionId;
  final int displayOrder;
  final String skillName;
  final String stem;
  final List<MockReviewOption> options;

  /// Null means the question was left blank — not that it was wrong.
  final bool? isCorrect;
  final bool isFlagged;
  final String? explanation;
  final String? transcript;
  final String? passage;
  final String? audioPath;
  final int? audioStartMs;
  final int? audioEndMs;
  final int? selectedOptionId;

  MockReviewOption? get selectedOption {
    for (final option in options) {
      if (option.optionId == selectedOptionId) return option;
    }
    return null;
  }

  MockReviewOption? get correctOption {
    for (final option in options) {
      if (option.isCorrect) return option;
    }
    return null;
  }

  String? get selectedOptionLabel => selectedOption?.label;

  String? get correctOptionLabel => correctOption?.label;

  String? get correctOptionText => correctOption?.text;

  /// The rationale of the option the learner picked, when it was wrong.
  String? get wrongOptionRationale {
    final chosen = selectedOption;
    if (chosen == null || chosen.isCorrect) return null;
    return chosen.rationale;
  }

  bool get isAnswered => selectedOptionId != null;
}

/// `GET /api/learner/attempts/{attemptId}/review`.
class MockAttemptReview {
  const MockAttemptReview({
    required this.attemptId,
    required this.examName,
    required this.questions,
    required this.totalQuestions,
    this.answeredCount = 0,
    this.correctCount = 0,
    this.blankCount = 0,
  });

  factory MockAttemptReview.fromJson(Map<String, dynamic> json) {
    final raw = json['questions'] as List<dynamic>? ?? const [];
    final list = <MockReviewQuestion>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map<String, dynamic>) {
        list.add(MockReviewQuestion.fromJson(item, i + 1));
      }
    }
    return MockAttemptReview(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examName: (json['examName'] as String?) ?? '',
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? list.length,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      blankCount: (json['blankCount'] as num?)?.toInt() ?? 0,
      questions: list,
    );
  }

  final int attemptId;
  final String examName;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final int blankCount;
  final List<MockReviewQuestion> questions;
}
