/// Real-shaped practice payload builders for widget tests.
///
/// These mirror the backend's own envelopes (`PracticeCatalogDto` grouping,
/// the bare matrix array, `FreeDrillStateDto`), so a test never mocks a shape
/// the app could not receive. The recorded bytes live in
/// `test/contract/fixtures/` and are asserted at the parse seam; this helper
/// exists so interaction tests can vary one section at a time.
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
