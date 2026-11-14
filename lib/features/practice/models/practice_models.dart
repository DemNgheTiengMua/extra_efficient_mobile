import 'dart:convert';

/// `PracticeSessionDto`: the catalog's `unfinishedSession`, the answer to a
/// start request, and the `session` inside the take composite.
///
/// `sectionId` is null for a pool drill (drawn from a topic and level); the
/// section code and name label the scope either way.
class PracticeSession {
  const PracticeSession({
    required this.sessionId,
    required this.sectionCode,
    required this.sectionName,
    required this.modality,
    required this.questionCount,
    required this.correctCount,
    this.sectionId,
    this.status = '',
    this.questionSource = '',
    this.startedAt,
    this.finishedAt,
    this.topicId,
    this.cefrLevelCode,
    this.isShort = false,
  });

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      sectionId: (json['sectionId'] as num?)?.toInt(),
      sectionCode: json['sectionCode'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      modality: json['modality'] as String? ?? '',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      questionSource: json['questionSource'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      finishedAt: DateTime.tryParse(json['finishedAt'] as String? ?? ''),
      topicId: (json['topicId'] as num?)?.toInt(),
      cefrLevelCode: json['cefrLevelCode'] as String?,
      isShort: json['isShort'] as bool? ?? false,
    );
  }

  final int sessionId;
  final String sectionCode;
  final String sectionName;
  final String modality;
  final int questionCount;
  final int correctCount;

  /// Null for a pool drill.
  final int? sectionId;

  /// `in_progress`, `finished`, `abandoned`.
  final String status;

  /// Always `all` in practice: the source is mastery state, not a choice.
  final String questionSource;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? topicId;
  final String? cefrLevelCode;

  /// A pool drill holding fewer items than a session asks for.
  final bool isShort;

  bool get isFinished => status == 'finished';
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
          ? PracticeSession.fromJson(unfinished)
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
  final PracticeSession? unfinishedSession;
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

/// `PracticeOptionDto` on the take payload: **no** `isCorrect` here, because the
/// answer key is not in the manifest.
class PracticeOption {
  const PracticeOption({
    required this.optionId,
    required this.label,
    required this.text,
  });

  factory PracticeOption.fromJson(Map<String, dynamic> json) {
    return PracticeOption(
      optionId: (json['optionId'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  final int optionId;
  final String label;
  final String text;
}

/// `PracticeQuestionDto`. The passage, the audio path, the audio slice bounds
/// and the word bounds carry the backend's own names.
class PracticeQuestion {
  const PracticeQuestion({
    required this.displayOrder,
    this.questionId,
    this.itemVersionId,
    this.wireAddress,
    this.sessionId = 0,
    this.sectionName = '',
    this.totalQuestions = 0,
    this.questionType = 'mcq',
    this.stem = '',
    this.categoryName,
    this.hint,
    this.hintUsed = false,
    this.options = const [],
    this.selectedOptionId,
    this.isCorrect,
    this.correctOptionId,
    this.explanation,
    this.transcript,
    this.passage,
    this.audioPath,
    this.imagePath,
    this.imageAlt,
    this.isSaved = false,
    this.audioStartMs,
    this.audioEndMs,
    this.maxSelections,
    this.allowNumber = true,
    this.acceptedAnswersJson,
    this.requiredKeywords = const [],
    this.minWords,
    this.maxWords,
    this.responseText,
    this.selectedOptionIds = const [],
    this.correctOptionIds = const [],
    this.savedQuestionId,
    this.cefrLevelCode,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'] as List<dynamic>? ?? const [];
    return PracticeQuestion(
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      questionId: (json['questionId'] as num?)?.toInt(),
      itemVersionId: (json['itemVersionId'] as num?)?.toInt(),
      wireAddress: (json['address'] as num?)?.toInt(),
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      sectionName: json['sectionName'] as String? ?? '',
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      questionType: (json['questionType'] as String? ?? 'mcq').toLowerCase(),
      stem: json['stem'] as String? ?? '',
      categoryName: json['categoryName'] as String?,
      hint: json['hint'] as String?,
      hintUsed: json['hintUsed'] as bool? ?? false,
      options: optionsRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeOption.fromJson)
          .toList(),
      selectedOptionId: (json['selectedOptionId'] as num?)?.toInt(),
      isCorrect: json['isCorrect'] as bool?,
      correctOptionId: (json['correctOptionId'] as num?)?.toInt(),
      explanation: json['explanation'] as String?,
      transcript: json['transcript'] as String?,
      passage: json['passage'] as String?,
      audioPath: json['audioPath'] as String?,
      imagePath: json['imagePath'] as String?,
      imageAlt: json['imageAlt'] as String?,
      isSaved: json['isSaved'] as bool? ?? false,
      audioStartMs: (json['audioStartMs'] as num?)?.toInt(),
      audioEndMs: (json['audioEndMs'] as num?)?.toInt(),
      maxSelections: (json['maxSelections'] as num?)?.toInt(),
      allowNumber: json['allowNumber'] as bool? ?? true,
      acceptedAnswersJson: json['acceptedAnswersJson'] as String?,
      requiredKeywords: _parseKeywords(json['requiredKeywords']),
      minWords: (json['minWords'] as num?)?.toInt(),
      maxWords: (json['maxWords'] as num?)?.toInt(),
      responseText: json['responseText'] as String?,
      selectedOptionIds: _parseIds(json['selectedOptionIds']),
      correctOptionIds: _parseIds(json['correctOptionIds']),
      savedQuestionId: (json['savedQuestionId'] as num?)?.toInt(),
      cefrLevelCode: json['cefrLevelCode'] as String?,
    );
  }

  /// Null for a pool item, which has no question row.
  final int? questionId;

  /// The pinned pool-item version; the address for a pool item.
  final int? itemVersionId;

  /// The address the backend computed (`questionId ?? itemVersionId`). Taken
  /// from the wire when present so the app and the server agree even if the
  /// precedence rule ever changes.
  final int? wireAddress;

  final int sessionId;
  final String sectionName;
  final int displayOrder;
  final int totalQuestions;
  final String questionType;
  final String stem;
  final String? categoryName;
  final String? hint;
  final bool hintUsed;
  final List<PracticeOption> options;
  final int? selectedOptionId;

  /// Null while unanswered: an unanswered question is not a wrong one.
  final bool? isCorrect;
  final int? correctOptionId;
  final String? explanation;
  final String? transcript;
  final String? passage;
  final String? audioPath;
  final String? imagePath;
  final String? imageAlt;
  final bool isSaved;
  final int? audioStartMs;
  final int? audioEndMs;
  final int? maxSelections;
  final bool allowNumber;
  final String? acceptedAnswersJson;
  final List<String> requiredKeywords;
  final int? minWords;
  final int? maxWords;
  final String? responseText;
  final List<int> selectedOptionIds;
  final List<int> correctOptionIds;
  final int? savedQuestionId;
  final String? cefrLevelCode;

  /// The handle every question-naming request uses: the wire address when the
  /// backend sent one, else the row id, else the pinned item version.
  int get address => wireAddress ?? questionId ?? itemVersionId ?? 0;

  bool get isAnswered => selectedOptionId != null ||
      responseText != null ||
      selectedOptionIds.isNotEmpty;

  bool get isWriting => questionType == 'free_response' || minWords != null;
}

/// `PracticeNavigatorItemDto`: one row of the answer navigator.
class PracticeNavigatorItem {
  const PracticeNavigatorItem({
    required this.displayOrder,
    this.questionId,
    this.itemVersionId,
    this.wireAddress,
    this.isAnswered = false,
    this.isCorrect,
    this.isSaved = false,
    this.isCurrent = false,
    this.savedQuestionId,
  });

  factory PracticeNavigatorItem.fromJson(Map<String, dynamic> json) {
    return PracticeNavigatorItem(
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      questionId: (json['questionId'] as num?)?.toInt(),
      itemVersionId: (json['itemVersionId'] as num?)?.toInt(),
      wireAddress: (json['address'] as num?)?.toInt(),
      isAnswered: json['isAnswered'] as bool? ?? false,
      isCorrect: json['isCorrect'] as bool?,
      isSaved: json['isSaved'] as bool? ?? false,
      isCurrent: json['isCurrent'] as bool? ?? false,
      savedQuestionId: (json['savedQuestionId'] as num?)?.toInt(),
    );
  }

  final int displayOrder;
  final int? questionId;
  final int? itemVersionId;
  final int? wireAddress;
  final bool isAnswered;
  final bool? isCorrect;
  final bool isSaved;
  final bool isCurrent;
  final int? savedQuestionId;

  int get address => wireAddress ?? questionId ?? itemVersionId ?? 0;
}

/// `PracticeSessionTakeDto`: a composite of the session, the current question,
/// every question and the navigator. They arrive together, so the room opens on
/// its first question.
class PracticeSessionTake {
  const PracticeSessionTake({
    required this.session,
    this.question,
    this.questions = const [],
    this.navigator = const [],
  });

  factory PracticeSessionTake.fromJson(Map<String, dynamic> json) {
    final sessionRaw = json['session'];
    final questionRaw = json['question'];
    final questionsRaw = json['questions'] as List<dynamic>? ?? const [];
    final navigatorRaw = json['navigator'] as List<dynamic>? ?? const [];
    return PracticeSessionTake(
      session: sessionRaw is Map<String, dynamic>
          ? PracticeSession.fromJson(sessionRaw)
          : const PracticeSession(
              sessionId: 0,
              sectionCode: '',
              sectionName: '',
              modality: '',
              questionCount: 0,
              correctCount: 0,
            ),
      question: questionRaw is Map<String, dynamic>
          ? PracticeQuestion.fromJson(questionRaw)
          : null,
      questions: questionsRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeQuestion.fromJson)
          .toList(),
      navigator: navigatorRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeNavigatorItem.fromJson)
          .toList(),
    );
  }

  final PracticeSession session;
  final PracticeQuestion? question;
  final List<PracticeQuestion> questions;
  final List<PracticeNavigatorItem> navigator;

  /// The question the room opens on: the server's current question, else the
  /// first one.
  PracticeQuestion? get openingQuestion {
    final current = question;
    if (current != null) {
      final index = questions.indexWhere(
        (q) => q.address == current.address,
      );
      if (index >= 0) return questions[index];
    }
    return questions.isEmpty ? null : questions.first;
  }
}

/// `GradedAnswerDto`.
class PracticeAnswerResult {
  const PracticeAnswerResult({
    this.isCorrect,
    this.selectedOptionId,
    this.correctOptionId,
    this.explanation,
    this.transcript,
    this.isSessionFinished = false,
    this.nextQuestionDisplayOrder,
    this.isSaved = false,
    this.correctOptionIds = const [],
    this.responseText,
    this.savedQuestionId,
    this.cefrLevelCode,
  });

  factory PracticeAnswerResult.fromJson(Map<String, dynamic> json) {
    return PracticeAnswerResult(
      isCorrect: json['isCorrect'] as bool?,
      selectedOptionId: (json['selectedOptionId'] as num?)?.toInt(),
      correctOptionId: (json['correctOptionId'] as num?)?.toInt(),
      explanation: json['explanation'] as String?,
      transcript: json['transcript'] as String?,
      isSessionFinished: json['isSessionFinished'] as bool? ?? false,
      nextQuestionDisplayOrder:
          (json['nextQuestionDisplayOrder'] as num?)?.toInt(),
      isSaved: json['isSaved'] as bool? ?? false,
      correctOptionIds: _parseIds(json['correctOptionIds']),
      responseText: json['responseText'] as String?,
      savedQuestionId: (json['savedQuestionId'] as num?)?.toInt(),
      cefrLevelCode: json['cefrLevelCode'] as String?,
    );
  }

  /// Null for a free-response answer that was not graded (yet).
  final bool? isCorrect;
  final int? selectedOptionId;
  final int? correctOptionId;
  final String? explanation;
  final String? transcript;
  final bool isSessionFinished;

  /// Null when the session just finished.
  final int? nextQuestionDisplayOrder;
  final bool isSaved;
  final List<int> correctOptionIds;
  final String? responseText;
  final int? savedQuestionId;
  final String? cefrLevelCode;
}

/// One row of `PracticeSummaryDto.Questions` (`QuestionOutcomeDto`).
class PracticeSummaryItem {
  const PracticeSummaryItem({
    required this.displayOrder,
    required this.stem,
    this.questionId,
    this.itemVersionId,
    this.categoryName,
    this.selectedOptionLabel,
    this.selectedOptionText,
    this.correctOptionLabel,
    this.correctOptionText,
    this.isCorrect,
    this.hintUsed = false,
    this.explanation,
    this.audioPath,
    this.audioStartMs,
    this.audioEndMs,
    this.transcript,
    this.questionType = 'mcq',
    this.responseText,
  });

  factory PracticeSummaryItem.fromJson(Map<String, dynamic> json) {
    return PracticeSummaryItem(
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      stem: json['stem'] as String? ?? '',
      questionId: (json['questionId'] as num?)?.toInt(),
      itemVersionId: (json['itemVersionId'] as num?)?.toInt(),
      categoryName: json['categoryName'] as String?,
      selectedOptionLabel: json['selectedOptionLabel'] as String?,
      selectedOptionText: json['selectedOptionText'] as String?,
      correctOptionLabel: json['correctOptionLabel'] as String?,
      correctOptionText: json['correctOptionText'] as String?,
      isCorrect: json['isCorrect'] as bool?,
      hintUsed: json['hintUsed'] as bool? ?? false,
      explanation: json['explanation'] as String?,
      audioPath: json['audioPath'] as String?,
      audioStartMs: (json['audioStartMs'] as num?)?.toInt(),
      audioEndMs: (json['audioEndMs'] as num?)?.toInt(),
      transcript: json['transcript'] as String?,
      questionType: (json['questionType'] as String? ?? 'mcq').toLowerCase(),
      responseText: json['responseText'] as String?,
    );
  }

  final int displayOrder;
  final String stem;
  final int? questionId;
  final int? itemVersionId;
  final String? categoryName;
  final String? selectedOptionLabel;
  final String? selectedOptionText;
  final String? correctOptionLabel;
  final String? correctOptionText;

  /// Null means "not answered", not "wrong": the key ships either way.
  final bool? isCorrect;
  final bool hintUsed;
  final String? explanation;
  final String? audioPath;
  final int? audioStartMs;
  final int? audioEndMs;
  final String? transcript;
  final String questionType;
  final String? responseText;

  bool get isAnswered => isCorrect != null;
}

/// `PracticeSummaryDto`.
class PracticeSummary {
  const PracticeSummary({
    required this.sessionId,
    required this.sectionCode,
    required this.sectionName,
    this.modality = '',
    this.startedAt,
    this.finishedAt,
    this.totalQuestions = 0,
    this.answeredCount = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.skippedCount = 0,
    this.accuracyPercentage = 0,
    this.hintUsedCount = 0,
    this.questions = const [],
  });

  factory PracticeSummary.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'] as List<dynamic>? ?? const [];
    return PracticeSummary(
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      sectionCode: json['sectionCode'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      modality: json['modality'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      finishedAt: DateTime.tryParse(json['finishedAt'] as String? ?? ''),
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      incorrectCount: (json['incorrectCount'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skippedCount'] as num?)?.toInt() ?? 0,
      accuracyPercentage: (json['accuracyPercentage'] as num?)?.toInt() ?? 0,
      hintUsedCount: (json['hintUsedCount'] as num?)?.toInt() ?? 0,
      questions: questionsRaw
          .whereType<Map<String, dynamic>>()
          .map(PracticeSummaryItem.fromJson)
          .toList(),
    );
  }

  final int sessionId;
  final String sectionCode;
  final String sectionName;
  final String modality;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final int incorrectCount;
  final int skippedCount;
  final int accuracyPercentage;
  final int hintUsedCount;
  final List<PracticeSummaryItem> questions;

  bool get isFinished => finishedAt != null;
}

/// `requiredKeywords` is a JSON array string on the wire (`["a","b"]`); the
/// scorer also tolerates a comma list, so accept both.
List<String> _parseKeywords(Object? raw) {
  if (raw is List) return raw.whereType<String>().toList();
  if (raw is! String || raw.trim().isEmpty) return const [];
  final text = raw.trim();
  if (text.startsWith('[')) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {
      // Fall through to the comma list below.
    }
  }
  return text
      .split(RegExp('[,;]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

List<int> _parseIds(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<num>()
      .map((e) => e.toInt())
      .toList();
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
      // The backend names the failure reason `failureReason`, not errorMessage.
      errorMessage: (json['failureReason'] ?? json['errorMessage']) as String?,
    );
  }

  final String status;
  final String? narrative;
  final String? errorMessage;

  /// `AiInsightStatusDto` is `pending | done | failed`.
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';
  bool get isDone => status == 'done';
}

/// One filter facet from `SavedQuestionsViewDto.Sections` / `.Categories`.
class SavedFilterOption {
  const SavedFilterOption({
    required this.id,
    required this.code,
    required this.label,
    required this.count,
  });

  final int id;
  final String code;
  final String label;
  final int count;
}

/// One bookmark (`SavedQuestionItemDto`). The list and GET-one return the same
/// shape, so there is one model for both.
class SavedQuestionItem {
  const SavedQuestionItem({
    required this.savedQuestionId,
    required this.questionId,
    required this.itemId,
    required this.itemVersionId,
    required this.isRetiredDefective,
    required this.source,
    required this.savedAt,
    required this.sectionId,
    required this.sectionCode,
    required this.sectionName,
    required this.topicCode,
    required this.topicName,
    required this.categoryId,
    required this.categoryName,
    required this.stem,
    required this.passage,
    required this.imagePath,
    required this.audioPath,
    required this.hint,
    required this.explanation,
    required this.transcript,
    required this.scopeCode,
    required this.scopeName,
    this.options = const [],
  });

  factory SavedQuestionItem.fromJson(Map<String, dynamic> json) {
    final optRaw = json['options'] as List<dynamic>? ?? const [];
    return SavedQuestionItem(
      savedQuestionId: (json['savedQuestionId'] as num?)?.toInt() ?? 0,
      questionId: (json['questionId'] as num?)?.toInt(),
      itemId: (json['itemId'] as num?)?.toInt(),
      itemVersionId: (json['itemVersionId'] as num?)?.toInt(),
      isRetiredDefective: json['isRetiredDefective'] as bool? ?? false,
      source: json['source'] as String? ?? 'manual',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? ''),
      sectionId: (json['sectionId'] as num?)?.toInt(),
      sectionCode: json['sectionCode'] as String?,
      sectionName: json['sectionName'] as String?,
      topicCode: json['topicCode'] as String?,
      topicName: json['topicName'] as String?,
      categoryId: (json['categoryId'] as num?)?.toInt(),
      categoryName: json['categoryName'] as String?,
      stem: json['stem'] as String? ?? '',
      passage: json['passage'] as String?,
      imagePath: json['imagePath'] as String?,
      audioPath: json['audioPath'] as String?,
      hint: json['hint'] as String?,
      explanation: json['explanation'] as String?,
      transcript: json['transcript'] as String?,
      // Derived on the server: a pool item has no section, only a topic.
      scopeCode: json['scopeCode'] as String? ??
          json['sectionCode'] as String? ??
          json['topicCode'] as String? ??
          '',
      scopeName: json['scopeName'] as String? ??
          json['sectionName'] as String? ??
          json['topicName'] as String? ??
          '',
      options: optRaw
          .whereType<Map<String, dynamic>>()
          .map(SavedQuestionOption.fromJson)
          .toList(),
    );
  }

  /// The row's own address — always present, and what GET-one/DELETE take.
  final int savedQuestionId;

  /// Null for a pool item, which is addressed by [itemVersionId] instead.
  final int? questionId;
  final int? itemId;
  final int? itemVersionId;
  final bool isRetiredDefective;
  final String source;
  final DateTime? savedAt;
  final int? sectionId;
  final String? sectionCode;
  final String? sectionName;
  final String? topicCode;
  final String? topicName;
  final int? categoryId;
  final String? categoryName;
  final String stem;
  final String? passage;
  final String? imagePath;
  final String? audioPath;
  final String? hint;
  final String? explanation;
  final String? transcript;
  final String scopeCode;
  final String scopeName;
  final List<SavedQuestionOption> options;

  bool get isPoolItem => questionId == null && itemVersionId != null;
}

class SavedQuestionsResponse {
  const SavedQuestionsResponse({
    this.items = const [],
    this.sectionNoun = 'Section',
    this.totalSavedCount = 0,
    this.manualSavedCount = 0,
    this.incorrectSavedCount = 0,
    this.sections = const [],
    this.categories = const [],
  });

  factory SavedQuestionsResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['questions'] as List<dynamic>? ?? const [];
    final sectionsRaw = json['sections'] as List<dynamic>? ?? const [];
    final categoriesRaw = json['categories'] as List<dynamic>? ?? const [];
    final cert = json['certificate'];
    return SavedQuestionsResponse(
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(SavedQuestionItem.fromJson)
          .toList(),
      sectionNoun: (cert is Map<String, dynamic>
              ? cert['sectionNoun'] as String?
              : null) ??
          'Section',
      totalSavedCount: (json['totalSavedCount'] as num?)?.toInt() ?? 0,
      manualSavedCount: (json['manualSavedCount'] as num?)?.toInt() ?? 0,
      incorrectSavedCount:
          (json['incorrectSavedCount'] as num?)?.toInt() ?? 0,
      sections: sectionsRaw.whereType<Map<String, dynamic>>().map((e) {
        return SavedFilterOption(
          id: (e['sectionId'] as num?)?.toInt() ?? 0,
          code: e['code'] as String? ?? '',
          label: e['name'] as String? ?? '',
          count: (e['count'] as num?)?.toInt() ?? 0,
        );
      }).toList(),
      categories: categoriesRaw.whereType<Map<String, dynamic>>().map((e) {
        return SavedFilterOption(
          id: (e['categoryId'] as num?)?.toInt() ?? 0,
          code: '',
          label: e['name'] as String? ?? '',
          count: (e['count'] as num?)?.toInt() ?? 0,
        );
      }).toList(),
    );
  }

  final List<SavedQuestionItem> items;
  final String sectionNoun;
  final int totalSavedCount;
  final int manualSavedCount;
  final int incorrectSavedCount;
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

/// `SaveQuestionResultDto` — the answer to both save routes and to DELETE
/// (which also answers 200, with `isSaved: false`).
class SavedQuestionResult {
  const SavedQuestionResult({
    required this.isSaved,
    this.source,
    this.savedAt,
    this.savedQuestionId,
  });

  factory SavedQuestionResult.fromJson(Map<String, dynamic> json) {
    return SavedQuestionResult(
      isSaved: json['isSaved'] as bool? ?? false,
      source: json['source'] as String?,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? ''),
      savedQuestionId: (json['savedQuestionId'] as num?)?.toInt(),
    );
  }

  final bool isSaved;
  final String? source;
  final DateTime? savedAt;
  final int? savedQuestionId;
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


