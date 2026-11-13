/// Question source filter for starting a free Practice session.
enum PracticeQuestionSource {
  all('all', 'ALL'),
  wrong('wrong', 'WRONG ONLY'),
  unseen('unseen', 'UNSEEN');

  const PracticeQuestionSource(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Feedback timing mode for a Practice session.
enum PracticeFeedbackMode {
  immediate('immediate', 'IMMEDIATE'),
  end('end', 'END OF SESSION');

  const PracticeFeedbackMode(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class UnfinishedPracticeSession {
  const UnfinishedPracticeSession({
    required this.sessionId,
    required this.title,
    required this.answeredCount,
    required this.totalCount,
  });

  factory UnfinishedPracticeSession.fromJson(Map<String, dynamic> json) {
    return UnfinishedPracticeSession(
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Practice Session',
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
    );
  }

  final int sessionId;
  final String title;
  final int answeredCount;
  final int totalCount;
}

class PracticeSectionItem {
  const PracticeSectionItem({
    required this.sectionId,
    required this.title,
    required this.skill,
    this.accuracyPercent,
    this.cooldownActive = false,
    this.cooldownRemainingSeconds = 0,
    this.isSpeaking = false,
  });

  factory PracticeSectionItem.fromJson(Map<String, dynamic> json) {
    final skill = (json['skill'] as String? ?? '').toLowerCase();
    return PracticeSectionItem(
      sectionId: (json['sectionId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      skill: skill,
      accuracyPercent: (json['accuracyPercent'] as num?)?.toInt(),
      cooldownActive: json['cooldownActive'] as bool? ?? false,
      cooldownRemainingSeconds:
          (json['cooldownRemainingSeconds'] as num?)?.toInt() ?? 0,
      isSpeaking: json['isSpeaking'] as bool? ?? (skill == 'speaking'),
    );
  }

  final int sectionId;
  final String title;
  final String skill;
  final int? accuracyPercent;
  final bool cooldownActive;
  final int cooldownRemainingSeconds;
  final bool isSpeaking;
}

class PracticeCatalog {
  const PracticeCatalog({
    required this.sectionNoun,
    required this.sections,
    this.unfinishedSession,
  });

  factory PracticeCatalog.fromJson(Map<String, dynamic> json) {
    final unfinished = json['unfinishedSession'];
    final sectionsRaw = json['sections'] as List<dynamic>? ?? const [];
    return PracticeCatalog(
      sectionNoun: json['sectionNoun'] as String? ?? 'Section',
      unfinishedSession: unfinished is Map<String, dynamic>
          ? UnfinishedPracticeSession.fromJson(unfinished)
          : null,
      sections: sectionsRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeSectionItem.fromJson)
          .toList(),
    );
  }

  final String sectionNoun;
  final UnfinishedPracticeSession? unfinishedSession;
  final List<PracticeSectionItem> sections;
}

class PracticeMatrixCell {
  const PracticeMatrixCell({
    required this.cefrLevelCode,
    required this.questionCount,
    this.accuracyPercent,
  });

  factory PracticeMatrixCell.fromJson(Map<String, dynamic> json) {
    return PracticeMatrixCell(
      cefrLevelCode: json['cefrLevelCode'] as String? ?? '',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      accuracyPercent: (json['accuracyPercent'] as num?)?.toInt(),
    );
  }

  final String cefrLevelCode;
  final int questionCount;
  final int? accuracyPercent;
}

class PracticeMatrixTopic {
  const PracticeMatrixTopic({
    required this.topicId,
    required this.name,
    required this.cells,
  });

  factory PracticeMatrixTopic.fromJson(Map<String, dynamic> json) {
    final cellsRaw = json['cells'] as List<dynamic>? ?? const [];
    return PracticeMatrixTopic(
      topicId: (json['topicId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      cells: cellsRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeMatrixCell.fromJson)
          .toList(),
    );
  }

  final int topicId;
  final String name;
  final List<PracticeMatrixCell> cells;
}

class PracticeMatrix {
  const PracticeMatrix({
    required this.levels,
    required this.topics,
  });

  factory PracticeMatrix.fromJson(Map<String, dynamic> json) {
    final levelsRaw = json['levels'] as List<dynamic>? ?? const [];
    final topicsRaw = json['topics'] as List<dynamic>? ?? const [];
    return PracticeMatrix(
      levels: levelsRaw.whereType<String>().toList(),
      topics: topicsRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeMatrixTopic.fromJson)
          .toList(),
    );
  }

  final List<String> levels;
  final List<PracticeMatrixTopic> topics;
}

class PracticeOption {
  const PracticeOption({
    required this.optionId,
    required this.label,
    required this.text,
    this.rationale,
  });

  factory PracticeOption.fromJson(Map<String, dynamic> json) {
    return PracticeOption(
      optionId: (json['optionId'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      text: json['text'] as String? ?? '',
      rationale: json['rationale'] as String?,
    );
  }

  final int optionId;
  final String label;
  final String text;
  final String? rationale;
}

class PracticeQuestion {
  const PracticeQuestion({
    required this.questionId,
    required this.displayOrder,
    required this.questionType,
    required this.stem,
    this.passageText,
    this.audioUrl,
    this.clipStartMs,
    this.clipEndMs,
    this.options = const [],
    this.wordFloor,
    this.requiredKeywords = const [],
    this.savedQuestionId,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'] as List<dynamic>? ?? const [];
    final kwRaw = json['requiredKeywords'] as List<dynamic>? ?? const [];
    return PracticeQuestion(
      questionId: (json['questionId'] as num?)?.toInt() ?? 0,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      questionType: (json['questionType'] as String? ?? 'mcq').toLowerCase(),
      stem: json['stem'] as String? ?? '',
      passageText: json['passageText'] as String?,
      audioUrl: json['audioUrl'] as String?,
      clipStartMs: (json['clipStartMs'] as num?)?.toInt(),
      clipEndMs: (json['clipEndMs'] as num?)?.toInt(),
      options: optionsRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeOption.fromJson)
          .toList(),
      wordFloor: (json['wordFloor'] as num?)?.toInt(),
      requiredKeywords: kwRaw.whereType<String>().toList(),
      savedQuestionId: (json['savedQuestionId'] as num?)?.toInt(),
    );
  }

  final int questionId;
  final int displayOrder;
  final String questionType;
  final String stem;
  final String? passageText;
  final String? audioUrl;
  final int? clipStartMs;
  final int? clipEndMs;
  final List<PracticeOption> options;
  final int? wordFloor;
  final List<String> requiredKeywords;
  final int? savedQuestionId;

  bool get isWriting => questionType == 'writing' || wordFloor != null;
}

class PracticeSessionTake {
  const PracticeSessionTake({
    required this.sessionId,
    required this.title,
    required this.feedbackMode,
    required this.questions,
  });

  factory PracticeSessionTake.fromJson(Map<String, dynamic> json) {
    final qRaw = json['questions'] as List<dynamic>? ?? const [];
    final modeStr =
        (json['feedbackMode'] as String? ?? 'immediate').toLowerCase();
    return PracticeSessionTake(
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Practice Session',
      feedbackMode: modeStr == 'end'
          ? PracticeFeedbackMode.end
          : PracticeFeedbackMode.immediate,
      questions: qRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeQuestion.fromJson)
          .toList(),
    );
  }

  final int sessionId;
  final String title;
  final PracticeFeedbackMode feedbackMode;
  final List<PracticeQuestion> questions;
}

class PracticeAnswerResult {
  const PracticeAnswerResult({
    required this.isCorrect,
    this.correctOptionId,
    this.generalExplanation,
    this.selectedOptionRationale,
    this.wordCount,
    this.missingKeywords = const [],
  });

  factory PracticeAnswerResult.fromJson(Map<String, dynamic> json) {
    final missingRaw = json['missingKeywords'] as List<dynamic>? ?? const [];
    return PracticeAnswerResult(
      isCorrect: json['isCorrect'] as bool? ?? false,
      correctOptionId: (json['correctOptionId'] as num?)?.toInt(),
      generalExplanation: json['generalExplanation'] as String?,
      selectedOptionRationale: json['selectedOptionRationale'] as String?,
      wordCount: (json['wordCount'] as num?)?.toInt(),
      missingKeywords: missingRaw.whereType<String>().toList(),
    );
  }

  final bool isCorrect;
  final int? correctOptionId;
  final String? generalExplanation;
  final String? selectedOptionRationale;
  final int? wordCount;
  final List<String> missingKeywords;
}

class PracticeSummaryItem {
  const PracticeSummaryItem({
    required this.questionId,
    required this.stem,
    required this.isCorrect,
    this.generalExplanation,
  });

  factory PracticeSummaryItem.fromJson(Map<String, dynamic> json) {
    return PracticeSummaryItem(
      questionId: (json['questionId'] as num?)?.toInt() ?? 0,
      stem: json['stem'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
      generalExplanation: json['generalExplanation'] as String?,
    );
  }

  final int questionId;
  final String stem;
  final bool isCorrect;
  final String? generalExplanation;
}

class PracticeSummary {
  const PracticeSummary({
    required this.sessionId,
    required this.title,
    required this.correctCount,
    required this.totalCount,
    required this.accuracyPercent,
    required this.items,
  });

  factory PracticeSummary.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    return PracticeSummary(
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Practice Summary',
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      accuracyPercent: (json['accuracyPercent'] as num?)?.toInt() ?? 0,
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeSummaryItem.fromJson)
          .toList(),
    );
  }

  final int sessionId;
  final String title;
  final int correctCount;
  final int totalCount;
  final int accuracyPercent;
  final List<PracticeSummaryItem> items;
}

class PracticeInsight {
  const PracticeInsight({
    required this.status,
    this.narrative,
    this.errorMessage,
  });

  factory PracticeInsight.fromJson(Map<String, dynamic> json) {
    return PracticeInsight(
      status: (json['status'] as String? ?? 'none').toLowerCase(),
      narrative: json['narrative'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  final String status;
  final String? narrative;
  final String? errorMessage;
}

class SavedFilterOption {
  const SavedFilterOption({required this.id, required this.label});

  final int id;
  final String label;
}

class SavedQuestionItem {
  const SavedQuestionItem({
    required this.savedQuestionId,
    required this.questionId,
    this.sectionId,
    this.sectionTitle,
    this.categoryId,
    this.categoryName,
    required this.source,
    required this.stem,
  });

  factory SavedQuestionItem.fromJson(Map<String, dynamic> json) {
    return SavedQuestionItem(
      savedQuestionId: (json['savedQuestionId'] as num?)?.toInt() ?? 0,
      questionId: (json['questionId'] as num?)?.toInt() ?? 0,
      sectionId: (json['sectionId'] as num?)?.toInt(),
      sectionTitle: json['sectionTitle'] as String?,
      categoryId: (json['categoryId'] as num?)?.toInt(),
      categoryName: json['categoryName'] as String?,
      source: json['source'] as String? ?? 'manual',
      stem: json['stem'] as String? ?? '',
    );
  }

  final int savedQuestionId;
  final int questionId;
  final int? sectionId;
  final String? sectionTitle;
  final int? categoryId;
  final String? categoryName;
  final String source;
  final String stem;
}

class SavedQuestionsResponse {
  const SavedQuestionsResponse({
    required this.items,
    this.sections = const [],
    this.categories = const [],
  });

  factory SavedQuestionsResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    final sectionsRaw = json['sections'] as List<dynamic>? ?? const [];
    final categoriesRaw = json['categories'] as List<dynamic>? ?? const [];
    return SavedQuestionsResponse(
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(SavedQuestionItem.fromJson)
          .toList(),
      sections: sectionsRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => SavedFilterOption(
              id: (e['sectionId'] as num?)?.toInt() ?? 0,
              label: e['title'] as String? ?? '',
            ),
          )
          .toList(),
      categories: categoriesRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => SavedFilterOption(
              id: (e['categoryId'] as num?)?.toInt() ?? 0,
              label: e['name'] as String? ?? '',
            ),
          )
          .toList(),
    );
  }

  final List<SavedQuestionItem> items;
  final List<SavedFilterOption> sections;
  final List<SavedFilterOption> categories;
}

class SavedQuestionOption {
  const SavedQuestionOption({
    required this.optionId,
    required this.label,
    required this.text,
    this.isCorrect = false,
  });

  factory SavedQuestionOption.fromJson(Map<String, dynamic> json) {
    return SavedQuestionOption(
      optionId: (json['optionId'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      text: json['text'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
    );
  }

  final int optionId;
  final String label;
  final String text;
  final bool isCorrect;
}

class SavedQuestionDetail {
  const SavedQuestionDetail({
    required this.savedQuestionId,
    required this.stem,
    this.generalExplanation,
    this.transcript,
    this.audioUrl,
    this.clipStartMs,
    this.clipEndMs,
    this.options = const [],
  });

  factory SavedQuestionDetail.fromJson(Map<String, dynamic> json) {
    final optRaw = json['options'] as List<dynamic>? ?? const [];
    return SavedQuestionDetail(
      savedQuestionId: (json['savedQuestionId'] as num?)?.toInt() ?? 0,
      stem: json['stem'] as String? ?? '',
      generalExplanation: json['generalExplanation'] as String?,
      transcript: json['transcript'] as String?,
      audioUrl: json['audioUrl'] as String?,
      clipStartMs: (json['clipStartMs'] as num?)?.toInt(),
      clipEndMs: (json['clipEndMs'] as num?)?.toInt(),
      options: optRaw
          .whereType<Map<String, dynamic>>()
          .map(SavedQuestionOption.fromJson)
          .toList(),
    );
  }

  final int savedQuestionId;
  final String stem;
  final String? generalExplanation;
  final String? transcript;
  final String? audioUrl;
  final int? clipStartMs;
  final int? clipEndMs;
  final List<SavedQuestionOption> options;
}

class WeaknessBreakdownRow {
  const WeaknessBreakdownRow({
    required this.name,
    required this.accuracyPercent,
    required this.answeredCount,
    this.isWeakest = false,
    this.isStrongest = false,
  });

  factory WeaknessBreakdownRow.fromJson(Map<String, dynamic> json) {
    return WeaknessBreakdownRow(
      name: json['name'] as String? ?? '',
      accuracyPercent: (json['accuracyPercent'] as num?)?.toInt() ?? 0,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      isWeakest: json['isWeakest'] as bool? ?? false,
      isStrongest: json['isStrongest'] as bool? ?? false,
    );
  }

  final String name;
  final int accuracyPercent;
  final int answeredCount;
  final bool isWeakest;
  final bool isStrongest;
}

class WeaknessRecommendation {
  const WeaknessRecommendation({
    required this.recId,
    required this.title,
    this.description,
    this.resolved = false,
  });

  factory WeaknessRecommendation.fromJson(Map<String, dynamic> json) {
    return WeaknessRecommendation(
      recId: (json['recId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      resolved: json['resolved'] as bool? ?? false,
    );
  }

  final int recId;
  final String title;
  final String? description;
  final bool resolved;
}

class WeaknessAnalysisData {
  const WeaknessAnalysisData({
    required this.sections,
    required this.categories,
    required this.recommendations,
  });

  factory WeaknessAnalysisData.fromJson(Map<String, dynamic> json) {
    final secRaw = json['sections'] as List<dynamic>? ?? const [];
    final catRaw = json['categories'] as List<dynamic>? ?? const [];
    final recRaw = json['recommendations'] as List<dynamic>? ?? const [];
    return WeaknessAnalysisData(
      sections: secRaw
          .whereType<Map<String, dynamic>>()
          .map(WeaknessBreakdownRow.fromJson)
          .toList(),
      categories: catRaw
          .whereType<Map<String, dynamic>>()
          .map(WeaknessBreakdownRow.fromJson)
          .toList(),
      recommendations: recRaw
          .whereType<Map<String, dynamic>>()
          .map(WeaknessRecommendation.fromJson)
          .toList(),
    );
  }

  final List<WeaknessBreakdownRow> sections;
  final List<WeaknessBreakdownRow> categories;
  final List<WeaknessRecommendation> recommendations;
}
