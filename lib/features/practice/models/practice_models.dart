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

/// `PracticeCatalogDto.UnfinishedSession` (`PracticeSessionDto`).
///
/// There is no answered count on this DTO: the room reads its own progress from
/// the take payload. The banner can only honestly state the section and size.
class UnfinishedPracticeSession {
  const UnfinishedPracticeSession({
    required this.sessionId,
    required this.sectionCode,
    required this.sectionName,
    required this.modality,
    required this.questionCount,
    required this.correctCount,
    this.topicId,
    this.cefrLevelCode,
  });

  factory UnfinishedPracticeSession.fromJson(Map<String, dynamic> json) {
    return UnfinishedPracticeSession(
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      sectionCode: json['sectionCode'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      modality: json['modality'] as String? ?? '',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      topicId: (json['topicId'] as num?)?.toInt(),
      cefrLevelCode: json['cefrLevelCode'] as String?,
    );
  }

  final int sessionId;
  final String sectionCode;
  final String sectionName;
  final String modality;
  final int questionCount;
  final int correctCount;
  final int? topicId;
  final String? cefrLevelCode;
}

/// `PracticeSectionDto`: one drillable section with its real availability.
class PracticeSection {
  const PracticeSection({
    required this.sectionId,
    required this.skillCode,
    required this.skillName,
    required this.modality,
    required this.code,
    required this.name,
    this.optionCount,
    required this.expectedQuestionCount,
    required this.availableQuestionCount,
    this.accuracyPercentage,
    required this.answeredCount,
    required this.displayOrder,
    this.totalCategoryCount = 0,
    this.categoriesInCooldown = 0,
    this.nextReviewDueAt,
  });

  factory PracticeSection.fromJson(Map<String, dynamic> json) {
    return PracticeSection(
      sectionId: (json['sectionId'] as num?)?.toInt() ?? 0,
      skillCode: json['skillCode'] as String? ?? '',
      skillName: json['skillName'] as String? ?? '',
      modality: json['modality'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      optionCount: (json['optionCount'] as num?)?.toInt(),
      expectedQuestionCount:
          (json['expectedQuestionCount'] as num?)?.toInt() ?? 0,
      availableQuestionCount:
          (json['availableQuestionCount'] as num?)?.toInt() ?? 0,
      accuracyPercentage: (json['accuracyPercentage'] as num?)?.toInt(),
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      totalCategoryCount: (json['totalCategoryCount'] as num?)?.toInt() ?? 0,
      categoriesInCooldown:
          (json['categoriesInCooldown'] as num?)?.toInt() ?? 0,
      nextReviewDueAt: json['nextReviewDueAt'] as String?,
    );
  }

  final int sectionId;
  final String skillCode;
  final String skillName;
  final String modality;
  final String code;
  final String name;
  final int? optionCount;
  final int expectedQuestionCount;
  final int availableQuestionCount;
  final int? accuracyPercentage;
  final int answeredCount;
  final int displayOrder;
  final int totalCategoryCount;
  final int categoriesInCooldown;
  final String? nextReviewDueAt;

  bool get isAvailable => availableQuestionCount > 0;

  /// Speaking is not a typed drill: it links to the recorded, AI-graded exam.
  bool get isSpeaking => modality == 'speaking';
}

/// One skill's sections, in the order the catalogue listed them.
class PracticeSkillGroup {
  const PracticeSkillGroup({
    required this.skillCode,
    required this.skillName,
    required this.sections,
    required this.isSpeaking,
  });

  final String skillCode;
  final String skillName;
  final List<PracticeSection> sections;
  final bool isSpeaking;
}

class PracticeCertificate {
  const PracticeCertificate({
    required this.code,
    required this.name,
    required this.sectionNoun,
  });

  factory PracticeCertificate.fromJson(Map<String, dynamic> json) {
    return PracticeCertificate(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sectionNoun: json['sectionNoun'] as String? ?? 'Section',
    );
  }

  final String code;
  final String name;

  /// The certificate's own word for a section ("Part", "Section", ...).
  final String sectionNoun;
}

/// `PracticeCatalogDto`: the catalogue arrives grouped by modality; this keeps
/// the groups and derives one ordered by-skill list for display.
class PracticeCatalog {
  const PracticeCatalog({
    this.certificate,
    this.listeningSections = const [],
    this.readingSections = const [],
    this.otherSections = const [],
    this.speakingSections = const [],
    this.weakestSection,
    this.unfinishedSession,
    this.speakingPracticeExamId,
  });

  factory PracticeCatalog.fromJson(Map<String, dynamic> json) {
    final cert = json['certificate'];
    final weakest = json['weakestSection'];
    final unfinished = json['unfinishedSession'];
    List<PracticeSection> parse(Object? raw) =>
        (raw as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PracticeSection.fromJson)
            .toList();

    return PracticeCatalog(
      certificate: cert is Map<String, dynamic>
          ? PracticeCertificate.fromJson(cert)
          : null,
      listeningSections: parse(json['listeningSections']),
      readingSections: parse(json['readingSections']),
      otherSections: parse(json['otherSections']),
      speakingSections: parse(json['speakingSections']),
      weakestSection:
          weakest is Map<String, dynamic> ? PracticeSection.fromJson(weakest) : null,
      unfinishedSession: unfinished is Map<String, dynamic>
          ? UnfinishedPracticeSession.fromJson(unfinished)
          : null,
      speakingPracticeExamId: (json['speakingPracticeExamId'] as num?)?.toInt(),
    );
  }

  final PracticeCertificate? certificate;
  final List<PracticeSection> listeningSections;
  final List<PracticeSection> readingSections;
  final List<PracticeSection> otherSections;
  final List<PracticeSection> speakingSections;
  final PracticeSection? weakestSection;
  final UnfinishedPracticeSession? unfinishedSession;
  final int? speakingPracticeExamId;

  /// The certificate's own section noun, never the app's invention.
  String get sectionNoun => certificate?.sectionNoun ?? 'Section';

  /// Sections grouped by skill, in catalogue order (listening, reading,
  /// other, speaking).
  List<PracticeSkillGroup> get skillGroups {
    final groups = <PracticeSkillGroup>[];
    for (final list in [
      listeningSections,
      readingSections,
      otherSections,
      speakingSections,
    ]) {
      for (final section in list) {
        final existing = groups.indexWhere(
          (g) => g.skillCode == section.skillCode,
        );
        if (existing >= 0) {
          groups[existing].sections.add(section);
        } else {
          groups.add(
            PracticeSkillGroup(
              skillCode: section.skillCode,
              skillName: section.skillName,
              sections: [section],
              isSpeaking: section.isSpeaking,
            ),
          );
        }
      }
    }
    return groups;
  }
}

/// `PracticeCellMasteryDto`: the wire carries the enum's integer (no string
/// converter), so `0..3` maps to untested/learning/reviewing/mastered.
enum PracticeMastery {
  untested('NEW'),
  learning('LEARN'),
  reviewing('REVIEW'),
  mastered('MSTR');

  const PracticeMastery(this.label);

  final String label;

  static PracticeMastery fromWire(Object? value) {
    final index = (value as num?)?.toInt() ?? 0;
    return index >= 0 && index < values.length ? values[index] : untested;
  }
}

/// One `(topic, level)` cell of `PracticeCellDto`.
class PracticeMatrixCell {
  const PracticeMatrixCell({
    required this.topicId,
    required this.topicCode,
    required this.topicName,
    required this.modality,
    required this.levelCode,
    required this.mastery,
    this.isPrioritised = false,
    this.reopensAt,
    this.isResting = false,
    this.isRestingNow = false,
  });

  factory PracticeMatrixCell.fromJson(Map<String, dynamic> json) {
    return PracticeMatrixCell(
      topicId: (json['topicId'] as num?)?.toInt() ?? 0,
      topicCode: json['topicCode'] as String? ?? '',
      topicName: json['topicName'] as String? ?? '',
      modality: json['modality'] as String? ?? '',
      levelCode: json['levelCode'] as String? ?? '',
      mastery: PracticeMastery.fromWire(json['mastery']),
      isPrioritised: json['isPrioritised'] as bool? ?? false,
      reopensAt: json['reopensAt'] as String?,
      isResting: json['isResting'] as bool? ?? false,
      // `isRestingNow` is a computed getter that does appear on the wire; fall
      // back to the stored pair when a consumer omits it.
      isRestingNow: json['isRestingNow'] as bool? ??
          ((json['isResting'] as bool? ?? false) &&
              json['reopensAt'] != null),
    );
  }

  final int topicId;
  final String topicCode;
  final String topicName;
  final String modality;
  final String levelCode;
  final PracticeMastery mastery;
  final bool isPrioritised;
  final String? reopensAt;
  final bool isResting;
  final bool isRestingNow;
}

class PracticeMatrixTopic {
  const PracticeMatrixTopic({
    required this.topicId,
    required this.code,
    required this.name,
    required this.modality,
    required this.cells,
  });

  final int topicId;
  final String code;
  final String name;
  final String modality;
  final List<PracticeMatrixCell> cells;

  PracticeMatrixCell? cellAt(String levelCode) {
    for (final cell in cells) {
      if (cell.levelCode == levelCode) return cell;
    }
    return null;
  }
}

/// `GET /practice/matrix` is a **bare array** of cells; the grid is the pivot
/// into topics carrying cells, with level columns derived from the data.
class PracticeMatrix {
  const PracticeMatrix({required this.levels, required this.topics});

  static const _cefrOrder = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  factory PracticeMatrix.parse(List<dynamic> raw) {
    final cells = raw
        .whereType<Map<String, dynamic>>()
        .map(PracticeMatrixCell.fromJson)
        .toList();

    final topics = <PracticeMatrixTopic>[];
    for (final cell in cells) {
      final existing = topics.indexWhere((t) => t.topicId == cell.topicId);
      if (existing >= 0) {
        topics[existing].cells.add(cell);
      } else {
        topics.add(
          PracticeMatrixTopic(
            topicId: cell.topicId,
            code: cell.topicCode,
            name: cell.topicName,
            modality: cell.modality,
            cells: [cell],
          ),
        );
      }
    }

    final levels = {for (final c in cells) c.levelCode}.toList()..sort((a, b) {
        final ai = _cefrOrder.indexOf(a);
        final bi = _cefrOrder.indexOf(b);
        if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
        if (ai >= 0) return -1;
        if (bi >= 0) return 1;
        return a.compareTo(b);
      });

    return PracticeMatrix(levels: levels, topics: topics);
  }

  final List<String> levels;
  final List<PracticeMatrixTopic> topics;

  bool get isEmpty => topics.isEmpty || levels.isEmpty;
}

/// `FreeDrillStateDto`: whether the backend will let this cell start at all.
class PracticeFreeDrillState {
  const PracticeFreeDrillState({
    required this.isUnlocked,
    this.lockNotice,
    this.cellUsedToday = false,
    this.dailyCeilingReached = false,
    this.answeredToday = 0,
    this.dailyItemCeiling = 0,
  });

  factory PracticeFreeDrillState.fromJson(Map<String, dynamic> json) {
    return PracticeFreeDrillState(
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      lockNotice: json['lockNotice'] as String?,
      cellUsedToday: json['cellUsedToday'] as bool? ?? false,
      dailyCeilingReached: json['dailyCeilingReached'] as bool? ?? false,
      answeredToday: (json['answeredToday'] as num?)?.toInt() ?? 0,
      dailyItemCeiling: (json['dailyItemCeiling'] as num?)?.toInt() ?? 0,
    );
  }

  final bool isUnlocked;
  final String? lockNotice;
  final bool cellUsedToday;
  final bool dailyCeilingReached;
  final int answeredToday;
  final int dailyItemCeiling;

  /// The sentence to show for a refusal; never an invented one.
  String get reason => lockNotice ?? 'This drill is not open right now.';
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

/// One row of `WeaknessAnalysisDto.Sections` (`SectionAccuracyDto`).
class WeaknessBreakdownRow {
  const WeaknessBreakdownRow({
    required this.sectionId,
    required this.code,
    required this.name,
    required this.answered,
    required this.correct,
    required this.accuracyPercentage,
    this.isWeakest = false,
    this.isStrongest = false,
  });

  factory WeaknessBreakdownRow.fromJson(Map<String, dynamic> json) {
    return WeaknessBreakdownRow(
      sectionId: (json['sectionId'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      answered: (json['answered'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      accuracyPercentage:
          (json['accuracyPercentage'] as num?)?.toInt() ?? 0,
      isWeakest: json['isWeakest'] as bool? ?? false,
      isStrongest: json['isStrongest'] as bool? ?? false,
    );
  }

  final int sectionId;
  final String code;
  final String name;
  final int answered;
  final int correct;
  final int accuracyPercentage;
  final bool isWeakest;
  final bool isStrongest;
}

/// One row of `WeaknessAnalysisDto.Topics` / `FrequentlyMissedTopics`
/// (`TopicAccuracyDto`) — the topic axis, ranked per `(topic, level)`.
class WeaknessTopicRow {
  const WeaknessTopicRow({
    required this.topicId,
    required this.topicCode,
    required this.topicName,
    required this.modality,
    required this.levelCode,
    required this.answered,
    required this.correct,
    required this.accuracyPercent,
    this.isWeakest = false,
    required this.observationFloor,
    this.lessonId,
  });

  factory WeaknessTopicRow.fromJson(Map<String, dynamic> json) {
    return WeaknessTopicRow(
      topicId: (json['topicId'] as num?)?.toInt() ?? 0,
      topicCode: json['topicCode'] as String? ?? '',
      topicName: json['topicName'] as String? ?? '',
      modality: json['modality'] as String? ?? '',
      levelCode: json['levelCode'] as String? ?? '',
      answered: (json['answered'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      accuracyPercent: (json['accuracyPercent'] as num?)?.toInt() ?? 0,
      isWeakest: json['isWeakest'] as bool? ?? false,
      observationFloor: (json['observationFloor'] as num?)?.toInt() ?? 0,
      lessonId: (json['lessonId'] as num?)?.toInt(),
    );
  }

  final int topicId;
  final String topicCode;
  final String topicName;
  final String modality;
  final String levelCode;
  final int answered;
  final int correct;
  final int accuracyPercent;
  final bool isWeakest;
  final int observationFloor;
  final int? lessonId;

  /// A cell below PLC-68's `n_min` is listed but not yet rankable.
  bool get isRankable => answered >= observationFloor;
}

/// `RecommendationItemDto`: the backend's own one text field plus its severity and skill.
class WeaknessRecommendation {
  const WeaknessRecommendation({
    required this.recId,
    required this.text,
    required this.severity,
    this.targetBandCode,
    this.skillName,
    required this.createdAt,
    this.isResolved = false,
  });

  factory WeaknessRecommendation.fromJson(Map<String, dynamic> json) {
    return WeaknessRecommendation(
      recId: (json['recId'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      targetBandCode: json['targetBandCode'] as String?,
      skillName: json['skillName'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      isResolved: json['isResolved'] as bool? ?? false,
    );
  }

  final int recId;
  final String text;
  final String severity;
  final String? targetBandCode;
  final String? skillName;
  final String createdAt;
  final bool isResolved;
}

class WeaknessAnalysisData {
  const WeaknessAnalysisData({
    required this.hasData,
    required this.sections,
    required this.topics,
    required this.recommendations,
    this.sectionNoun = 'Section',
    this.overallAccuracyPercentage = 0,
    this.totalAnswered = 0,
  });

  factory WeaknessAnalysisData.fromJson(Map<String, dynamic> json) {
    final cert = json['certificate'];
    final secRaw = json['sections'] as List<dynamic>? ?? const [];
    final topicRaw = json['topics'] as List<dynamic>? ?? const [];
    final recRaw = json['recommendations'] as List<dynamic>? ?? const [];
    return WeaknessAnalysisData(
      hasData: json['hasData'] as bool? ?? false,
      sectionNoun: cert is Map<String, dynamic>
          ? (cert['sectionNoun'] as String? ?? 'Section')
          : 'Section',
      overallAccuracyPercentage:
          (json['overallAccuracyPercentage'] as num?)?.toInt() ?? 0,
      totalAnswered: (json['totalAnswered'] as num?)?.toInt() ?? 0,
      sections: secRaw
          .whereType<Map<String, dynamic>>()
          .map(WeaknessBreakdownRow.fromJson)
          .toList(),
      topics: topicRaw
          .whereType<Map<String, dynamic>>()
          .map(WeaknessTopicRow.fromJson)
          .toList(),
      recommendations: recRaw
          .whereType<Map<String, dynamic>>()
          .map(WeaknessRecommendation.fromJson)
          .toList(),
    );
  }

  final bool hasData;
  final String sectionNoun;
  final int overallAccuracyPercentage;
  final int totalAnswered;
  final List<WeaknessBreakdownRow> sections;
  final List<WeaknessTopicRow> topics;
  final List<WeaknessRecommendation> recommendations;
}
