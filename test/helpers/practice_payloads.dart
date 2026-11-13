/// Real-shaped practice session payload builders for widget tests.
///
/// These mirror the backend's own envelopes (`PracticeSessionTakeDto` composite,
/// `PracticeQuestionDto`, `GradedAnswerDto`, `RevealHintResponse`,
/// `PracticeSummaryDto`), so a test never mocks a shape the app could not
/// receive. The recorded bytes live in `test/contract/fixtures/` and are
/// asserted at the parse seam; this helper exists so interaction tests can vary
/// one question at a time.
library;

Map<String, dynamic> practiceSection({
  required int sectionId,
  required String code,
  required String name,
  String modality = 'reading',
  String skillCode = 'READ',
  String skillName = 'Reading',
  int availableQuestionCount = 5,
  int expectedQuestionCount = 10,
  int? accuracyPercentage,
  int answeredCount = 0,
  int displayOrder = 1,
  int categoriesInCooldown = 0,
  String? nextReviewDueAt,
}) {
  return {
    'sectionId': sectionId,
    'skillCode': skillCode,
    'skillName': skillName,
    'modality': modality,
    'code': code,
    'name': name,
    'optionCount': 4,
    'expectedQuestionCount': expectedQuestionCount,
    'availableQuestionCount': availableQuestionCount,
    'accuracyPercentage': accuracyPercentage,
    'answeredCount': answeredCount,
    'displayOrder': displayOrder,
    'totalCategoryCount': 1,
    'categoriesInCooldown': categoriesInCooldown,
    'nextReviewDueAt': nextReviewDueAt,
  };
}

/// Groups the given sections into the catalogue's modality buckets by their
/// own `modality`, exactly as the backend does.
Map<String, dynamic> practiceCatalogResponse({
  String code = 'TOEIC',
  String name = 'TOEIC Listening & Reading',
  String sectionNoun = 'Part',
  List<Map<String, dynamic>> sections = const [],
  Map<String, dynamic>? unfinishedSession,
  int? speakingPracticeExamId,
}) {
  List<Map<String, dynamic>> of(String modality) =>
      sections.where((s) => s['modality'] == modality).toList();

  return {
    'certificate': {'code': code, 'name': name, 'sectionNoun': sectionNoun},
    'listeningSections': of('listening'),
    'readingSections': of('reading'),
    'otherSections': [...of('writing')],
    'speakingSections': of('speaking'),
    'weakestSection': null,
    'unfinishedSession': unfinishedSession,
    'speakingPracticeExamId': speakingPracticeExamId,
  };
}

Map<String, dynamic> practiceCell({
  required int topicId,
  required String topicCode,
  required String topicName,
  required String levelCode,
  String modality = 'reading',
  int mastery = 0,
  bool isPrioritised = false,
  String? reopensAt,
  bool isResting = false,
}) {
  return {
    'topicId': topicId,
    'topicCode': topicCode,
    'topicName': topicName,
    'modality': modality,
    'levelCode': levelCode,
    'mastery': mastery,
    'isPrioritised': isPrioritised,
    'reopensAt': reopensAt,
    'isResting': isResting,
    'isRestingNow': isResting && reopensAt != null,
  };
}

Map<String, dynamic> practiceFreeDrillResponse({
  bool isUnlocked = true,
  bool cellUsedToday = false,
  String? lockNotice,
}) {
  return {
    'isUnlocked': isUnlocked,
    'incompleteSteps': <dynamic>[],
    'remainingMinutes': 0,
    'priorities': <dynamic>[],
    'cellUsedToday': cellUsedToday,
    'dailyCeilingReached': false,
    'answeredToday': 0,
    'dailyItemCeiling': 60,
    'lockNotice': lockNotice,
  };
}

/// `PracticeSessionDto`. A section drill names a section; a pool drill names a
/// topic and level with `sectionId` null. `title` is not a field on the wire:
/// the room composes it from the section code and name.
Map<String, dynamic> practiceSession({
  required int sessionId,
  int? sectionId,
  required String sectionCode,
  required String sectionName,
  String modality = 'reading',
  int questionCount = 1,
  int correctCount = 0,
  String status = 'in_progress',
  int? topicId,
  String? cefrLevelCode,
}) {
  return {
    'sessionId': sessionId,
    'sectionId': sectionId,
    'sectionCode': sectionCode,
    'sectionName': sectionName,
    'modality': modality,
    'questionCount': questionCount,
    'status': status,
    'correctCount': correctCount,
    'questionSource': 'all',
    'startedAt': '2026-11-13T18:03:28.8871271+00:00',
    'finishedAt': status == 'finished'
        ? '2026-11-13T18:09:00.0000000+00:00'
        : null,
    'topicId': topicId,
    'cefrLevelCode': cefrLevelCode,
    'isShort': sectionId == null && topicId != null && questionCount < 10,
  };
}

Map<String, dynamic> practiceOption({
  required int optionId,
  required String label,
  required String text,
}) {
  return {'optionId': optionId, 'label': label, 'text': text};
}

/// `PracticeQuestionDto`. Pass [questionId] only for a section drill; a pool item
/// leaves it null and is addressed by [itemVersionId], which is what the
/// `address` field repeats.
Map<String, dynamic> practiceQuestion({
  int? questionId,
  int? itemVersionId,
  int? address,
  int sessionId = 1,
  String sectionName = 'Part 2: Question-Response',
  required int displayOrder,
  int totalQuestions = 1,
  String questionType = 'mcq',
  required String stem,
  String? categoryName,
  String? hint,
  bool hintUsed = false,
  List<Map<String, dynamic>> options = const [],
  int? selectedOptionId,
  bool? isCorrect,
  int? correctOptionId,
  String? explanation,
  String? transcript,
  String? passage,
  String? audioPath,
  String? imagePath,
  String? imageAlt,
  bool isSaved = false,
  int? audioStartMs,
  int? audioEndMs,
  String? requiredKeywords,
  int? minWords,
  int? maxWords,
  int? savedQuestionId,
  String? cefrLevelCode,
}) {
  final resolvedItemVersion = itemVersionId ?? questionId;
  return {
    'sessionId': sessionId,
    'sectionName': sectionName,
    'questionId': questionId,
    'displayOrder': displayOrder,
    'totalQuestions': totalQuestions,
    'stem': stem,
    'categoryName': categoryName,
    'hint': hint,
    'hintUsed': hintUsed,
    'options': options,
    'selectedOptionId': selectedOptionId,
    'isCorrect': isCorrect,
    'correctOptionId': correctOptionId,
    'explanation': explanation,
    'transcript': transcript,
    'passage': passage,
    'audioPath': audioPath,
    'imagePath': imagePath,
    'imageAlt': imageAlt,
    'isSaved': isSaved,
    'audioStartMs': audioStartMs,
    'audioEndMs': audioEndMs,
    'questionType': questionType,
    'maxSelections': null,
    'allowNumber': true,
    'acceptedAnswersJson': null,
    'requiredKeywords': requiredKeywords,
    'minWords': minWords,
    'maxWords': maxWords,
    'responseText': null,
    'selectedOptionIds': <int>[],
    'selectedOptionIdsJson': null,
    'correctOptionIds': <int>[],
    'itemVersionId': resolvedItemVersion,
    'savedQuestionId': savedQuestionId,
    'cefrLevelCode': cefrLevelCode,
    // The server computes this; a pool item's address is its item version.
    'address': address ?? questionId ?? resolvedItemVersion,
  };
}

Map<String, dynamic> practiceNavigatorItem({
  int? questionId,
  int? itemVersionId,
  int? address,
  required int displayOrder,
  bool isAnswered = false,
  bool? isCorrect,
  bool isSaved = false,
  bool isCurrent = false,
  int? savedQuestionId,
}) {
  final resolved = itemVersionId ?? questionId;
  return {
    'questionId': questionId,
    'displayOrder': displayOrder,
    'isAnswered': isAnswered,
    'isCorrect': isCorrect,
    'isSaved': isSaved,
    'isCurrent': isCurrent,
    'itemVersionId': resolved,
    'savedQuestionId': savedQuestionId,
    'address': address ?? questionId ?? resolved,
  };
}

/// `PracticeSessionTakeDto`: the session, the current question, every question
/// and the navigator, arriving together.
Map<String, dynamic> practiceTakeResponse({
  required Map<String, dynamic> session,
  required List<Map<String, dynamic>> questions,
  List<Map<String, dynamic>>? navigator,
  int currentIndex = 0,
}) {
  final nav = navigator ??
      [
        for (var i = 0; i < questions.length; i++)
          practiceNavigatorItem(
            questionId: questions[i]['questionId'] as int?,
            itemVersionId: questions[i]['itemVersionId'] as int?,
            address: questions[i]['address'] as int?,
            displayOrder: questions[i]['displayOrder'] as int,
            isCurrent: i == currentIndex,
            isAnswered: questions[i]['isCorrect'] != null,
            isCorrect: questions[i]['isCorrect'] as bool?,
            isSaved: questions[i]['isSaved'] as bool? ?? false,
            savedQuestionId: questions[i]['savedQuestionId'] as int?,
          ),
      ];
  return {
    'session': session,
    'question': questions.isEmpty ? null : questions[currentIndex],
    'questions': questions,
    'navigator': nav,
  };
}

/// `GradedAnswerDto`.
Map<String, dynamic> practiceGradedAnswer({
  required bool? isCorrect,
  int? selectedOptionId,
  int? correctOptionId,
  String? explanation,
  String? transcript,
  bool isSessionFinished = false,
  int? nextQuestionDisplayOrder,
  bool isSaved = false,
  List<int>? correctOptionIds,
  String? responseText,
  int? savedQuestionId,
}) {
  return {
    'isCorrect': isCorrect,
    'selectedOptionId': selectedOptionId,
    'correctOptionId': correctOptionId,
    'explanation': explanation,
    'transcript': transcript,
    'isSessionFinished': isSessionFinished,
    'nextQuestionDisplayOrder': nextQuestionDisplayOrder,
    'isSaved': isSaved,
    'acceptedAnswersJson': null,
    'correctOptionIds':
        correctOptionIds ?? (correctOptionId == null ? <int>[] : [correctOptionId]),
    'responseText': responseText,
    'selectedOptionIdsJson': null,
    'savedQuestionId': savedQuestionId,
    'cefrLevelCode': null,
  };
}

/// `RevealHintResponse`.
Map<String, dynamic> practiceHintResponse(String? hint) {
  return {'hint': hint, 'hintUsed': true};
}

/// `PracticeSummaryDto`.
Map<String, dynamic> practiceSummaryResponse({
  int sessionId = 1,
  String sectionCode = 'P2',
  String sectionName = 'Question-Response',
  String modality = 'reading',
  bool finished = true,
  required int totalQuestions,
  required int answeredCount,
  required int correctCount,
  required int incorrectCount,
  int skippedCount = 0,
  required int accuracyPercentage,
  int hintUsedCount = 0,
  List<Map<String, dynamic>> questions = const [],
}) {
  return {
    'sessionId': sessionId,
    'sectionCode': sectionCode,
    'sectionName': sectionName,
    'modality': modality,
    'startedAt': '2026-11-13T18:03:28.8871271+00:00',
    'finishedAt':
        finished ? '2026-11-13T18:09:00.0000000+00:00' : null,
    'totalQuestions': totalQuestions,
    'answeredCount': answeredCount,
    'correctCount': correctCount,
    'incorrectCount': incorrectCount,
    'skippedCount': skippedCount,
    'accuracyPercentage': accuracyPercentage,
    'hintUsedCount': hintUsedCount,
    'correctWithHintCount': 0,
    'incorrectWithHintCount': 0,
    'questions': questions,
  };
}

/// `QuestionOutcomeDto`.
Map<String, dynamic> practiceSummaryItem({
  required int displayOrder,
  int? questionId,
  int? itemVersionId,
  required String stem,
  String? selectedOptionLabel,
  String? selectedOptionText,
  String? correctOptionLabel,
  String? correctOptionText,
  bool? isCorrect,
  bool hintUsed = false,
  String? explanation,
  String questionType = 'mcq',
}) {
  return {
    'displayOrder': displayOrder,
    'questionId': questionId,
    'itemVersionId': itemVersionId ?? questionId,
    'categoryName': null,
    'stem': stem,
    'selectedOptionLabel': selectedOptionLabel,
    'selectedOptionText': selectedOptionText,
    'correctOptionLabel': correctOptionLabel,
    'correctOptionText': correctOptionText,
    'isCorrect': isCorrect,
    'hintUsed': hintUsed,
    'explanation': explanation,
    'audioPath': null,
    'audioStartMs': null,
    'audioEndMs': null,
    'transcript': null,
    'questionType': questionType,
    'responseText': null,
    'selectedOptionIdsJson': null,
    'acceptedAnswersJson': null,
  };
}
