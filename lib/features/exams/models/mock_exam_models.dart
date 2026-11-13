/// Domain models for Mock Exam catalog, instructions, preflight, and history.
class MockExamSummary {
  const MockExamSummary({
    required this.examId,
    required this.title,
    required this.durationMinutes,
    required this.questionCount,
    required this.credits,
    this.inProgressAttemptId,
  });

  factory MockExamSummary.fromJson(Map<String, dynamic> json) {
    return MockExamSummary(
      examId: (json['examId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      title: (json['title'] as String?) ?? 'Mock Exam',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      credits: (json['credits'] as num?)?.toInt() ??
          (json['creditCost'] as num?)?.toInt() ??
          0,
      inProgressAttemptId: (json['inProgressAttemptId'] as num?)?.toInt(),
    );
  }

  final int examId;
  final String title;
  final int durationMinutes;
  final int questionCount;
  final int credits;
  final int? inProgressAttemptId;
}

class MockExamSectionInfo {
  const MockExamSectionInfo({
    required this.name,
    required this.questionCount,
  });

  factory MockExamSectionInfo.fromJson(Map<String, dynamic> json) {
    return MockExamSectionInfo(
      name: (json['name'] as String?) ?? '',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String name;
  final int questionCount;
}

class MockExamInstructions {
  const MockExamInstructions({
    required this.examId,
    required this.title,
    required this.durationMinutes,
    required this.questionCount,
    required this.credits,
    required this.instructions,
    required this.sections,
  });

  factory MockExamInstructions.fromJson(Map<String, dynamic> json) {
    final rawInst = json['instructions'] as List<dynamic>? ?? const [];
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    return MockExamInstructions(
      examId: (json['examId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      title: (json['title'] as String?) ?? 'Mock Exam',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      credits: (json['credits'] as num?)?.toInt() ??
          (json['creditCost'] as num?)?.toInt() ??
          0,
      instructions: rawInst.map((e) => e.toString()).toList(),
      sections: rawSections
          .whereType<Map<String, dynamic>>()
          .map(MockExamSectionInfo.fromJson)
          .toList(),
    );
  }

  final int examId;
  final String title;
  final int durationMinutes;
  final int questionCount;
  final int credits;
  final List<String> instructions;
  final List<MockExamSectionInfo> sections;
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

class ExamHistoryItem {
  const ExamHistoryItem({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.status,
    this.totalScaledScore,
    this.overallBand,
    this.completedAt,
  });

  factory ExamHistoryItem.fromJson(Map<String, dynamic> json) {
    return ExamHistoryItem(
      attemptId: (json['attemptId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      examId: (json['examId'] as num?)?.toInt() ?? 0,
      examTitle: (json['examTitle'] as String?) ??
          (json['title'] as String?) ??
          'Mock Attempt',
      status: ((json['status'] as String?) ?? 'COMPLETED').toUpperCase(),
      totalScaledScore: (json['totalScaledScore'] as num?)?.toInt(),
      overallBand: json['overallBand'] as String?,
      completedAt: DateTime.tryParse((json['completedAt'] as String?) ?? ''),
    );
  }

  final int attemptId;
  final int examId;
  final String examTitle;
  final String status;
  final int? totalScaledScore;
  final String? overallBand;
  final DateTime? completedAt;

  bool get isInProgress =>
      status == 'IN_PROGRESS' || status == 'STARTED' || status == 'PAUSED';
}

class MockSkillBreakdown {
  const MockSkillBreakdown({
    required this.skill,
    required this.rawScore,
    required this.maxRawScore,
    required this.scaledScore,
  });

  factory MockSkillBreakdown.fromJson(Map<String, dynamic> json) {
    return MockSkillBreakdown(
      skill: (json['skill'] as String?) ?? '',
      rawScore: (json['rawScore'] as num?)?.toInt() ?? 0,
      maxRawScore: (json['maxRawScore'] as num?)?.toInt() ?? 0,
      scaledScore: (json['scaledScore'] as num?)?.toInt() ?? 0,
    );
  }

  final String skill;
  final int rawScore;
  final int maxRawScore;
  final int scaledScore;
}

class MockAttemptResult {
  const MockAttemptResult({
    required this.attemptId,
    required this.examTitle,
    required this.totalScaledScore,
    required this.overallBand,
    required this.cefrBand,
    required this.skillBreakdowns,
    this.scoreDelta,
  });

  factory MockAttemptResult.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['skillBreakdowns'] as List<dynamic>? ?? const [];
    return MockAttemptResult(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examTitle: (json['examTitle'] as String?) ?? 'Mock Result',
      totalScaledScore: (json['totalScaledScore'] as num?)?.toInt() ?? 0,
      overallBand: (json['overallBand'] as String?) ?? '-',
      cefrBand: (json['cefrBand'] as String?) ?? 'A1',
      scoreDelta: (json['scoreDelta'] as num?)?.toInt(),
      skillBreakdowns: rawSkills
          .whereType<Map<String, dynamic>>()
          .map(MockSkillBreakdown.fromJson)
          .toList(),
    );
  }

  final int attemptId;
  final String examTitle;
  final int totalScaledScore;
  final String overallBand;
  final String cefrBand;
  final int? scoreDelta;
  final List<MockSkillBreakdown> skillBreakdowns;
}

class ExamAiInsight {
  const ExamAiInsight({
    required this.status,
    this.narrative,
    this.errorMessage,
  });

  factory ExamAiInsight.fromJson(Map<String, dynamic> json) {
    return ExamAiInsight(
      status: ((json['status'] as String?) ?? 'COMPLETED').toUpperCase(),
      narrative: (json['narrative'] as String?) ?? (json['content'] as String?),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  final String status;
  final String? narrative;
  final String? errorMessage;

  bool get isFailed => status == 'FAILED' || status == 'ERROR';
}

class MockReviewQuestion {
  const MockReviewQuestion({
    required this.questionId,
    required this.index,
    required this.skill,
    required this.prompt,
    required this.isCorrect,
    required this.isFlagged,
    this.selectedOptionLabel,
    this.correctOptionLabel,
    this.wrongOptionRationale,
    this.explanation,
    this.transcript,
    this.audioUrl,
    this.audioStartMs,
    this.audioEndMs,
  });

  factory MockReviewQuestion.fromJson(
    Map<String, dynamic> json,
    int fallbackIdx,
  ) {
    return MockReviewQuestion(
      questionId: (json['questionId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      index: (json['index'] as num?)?.toInt() ?? fallbackIdx,
      skill: (json['skill'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? (json['stem'] as String?) ?? '',
      isCorrect: (json['isCorrect'] as bool?) ?? false,
      isFlagged: (json['isFlagged'] as bool?) ?? false,
      selectedOptionLabel: json['selectedOptionLabel'] as String?,
      correctOptionLabel: json['correctOptionLabel'] as String?,
      wrongOptionRationale: (json['wrongOptionRationale'] as String?) ??
          (json['selectedOptionRationale'] as String?),
      explanation: json['explanation'] as String?,
      transcript: json['transcript'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioStartMs: (json['audioStartMs'] as num?)?.toInt(),
      audioEndMs: (json['audioEndMs'] as num?)?.toInt(),
    );
  }

  final int questionId;
  final int index;
  final String skill;
  final String prompt;
  final bool isCorrect;
  final bool isFlagged;
  final String? selectedOptionLabel;
  final String? correctOptionLabel;
  final String? wrongOptionRationale;
  final String? explanation;
  final String? transcript;
  final String? audioUrl;
  final int? audioStartMs;
  final int? audioEndMs;
}

class MockAttemptReview {
  const MockAttemptReview({
    required this.attemptId,
    required this.examTitle,
    required this.questions,
  });

  factory MockAttemptReview.fromJson(Map<String, dynamic> json) {
    final raw = json['questions'] as List<dynamic>? ?? const [];
    final list = <MockReviewQuestion>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map<String, dynamic>) {
        list.add(MockReviewQuestion.fromJson(item, i));
      }
    }
    return MockAttemptReview(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examTitle: (json['examTitle'] as String?) ?? 'Answer Review',
      questions: list,
    );
  }

  final int attemptId;
  final String examTitle;
  final List<MockReviewQuestion> questions;
}
