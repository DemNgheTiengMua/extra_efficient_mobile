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

class PlacementOverview {
  const PlacementOverview({
    required this.examId,
    required this.examTitle,
    required this.certificateCode,
    required this.isFirstPlacement,
    required this.creditBalance,
    required this.scopes,
    this.inProgressPlacementId,
    this.latestPlacementId,
    this.latestBand,
    this.latestScore,
  });

  factory PlacementOverview.fromJson(Map<String, dynamic> json) {
    final rawScopes = json['scopes'] as List<dynamic>? ?? const [];
    final scopes = rawScopes
        .whereType<Map<String, dynamic>>()
        .map(PlacementScopeOption.fromJson)
        .toList();

    return PlacementOverview(
      examId: (json['examId'] as num?)?.toInt() ?? 0,
      examTitle: (json['examTitle'] as String?) ?? 'Placement Assessment',
      certificateCode: (json['certificateCode'] as String?) ?? '',
      isFirstPlacement: (json['isFirstPlacement'] as bool?) ??
          (json['isFree'] as bool?) ??
          true,
      creditBalance: (json['creditBalance'] as num?)?.toInt() ?? 0,
      inProgressPlacementId:
          (json['inProgressPlacementId'] as num?)?.toInt(),
      latestPlacementId: (json['latestPlacementId'] as num?)?.toInt(),
      latestBand: json['latestBand'] as String?,
      latestScore: (json['latestScore'] as num?)?.toInt(),
      scopes: scopes.isNotEmpty
          ? scopes
          : const [
              PlacementScopeOption(
                scope: 'all_skills',
                label: 'All 4 Skills',
                credits: 5,
              ),
              PlacementScopeOption(
                scope: 'listening_and_reading',
                label: 'Listening & Reading',
                credits: 3,
              ),
            ],
    );
  }

  final int examId;
  final String examTitle;
  final String certificateCode;
  final bool isFirstPlacement;
  final int creditBalance;
  final int? inProgressPlacementId;
  final int? latestPlacementId;
  final String? latestBand;
  final int? latestScore;
  final List<PlacementScopeOption> scopes;
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
      optionId: (json['optionId'] as num?)?.toInt() ??
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

  factory PlacementQuestion.fromJson(Map<String, dynamic> json, int fallbackIdx) {
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    return PlacementQuestion(
      questionId: (json['questionId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      index: (json['index'] as num?)?.toInt() ?? fallbackIdx,
      skill: ((json['skill'] as String?) ?? 'reading').toLowerCase(),
      sectionName: (json['sectionName'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? (json['stem'] as String?) ?? '',
      passageText: json['passageText'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioStartMs: (json['audioStartMs'] as num?)?.toInt() ??
          (json['startMs'] as num?)?.toInt(),
      audioEndMs: (json['audioEndMs'] as num?)?.toInt() ??
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
      expiresAt: DateTime.tryParse((json['expiresAt'] as String?) ?? '') ??
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

class PlacementSkillBreakdown {
  const PlacementSkillBreakdown({
    required this.skill,
    required this.band,
    required this.scaledScore,
    required this.rawScore,
    required this.gradingStatus,
    this.feedback,
  });

  factory PlacementSkillBreakdown.fromJson(Map<String, dynamic> json) {
    return PlacementSkillBreakdown(
      skill: (json['skill'] as String?) ?? '',
      band: (json['band'] as String?) ?? '-',
      scaledScore: (json['scaledScore'] as num?)?.toInt() ?? 0,
      rawScore: (json['rawScore'] as num?)?.toInt() ?? 0,
      gradingStatus: ((json['gradingStatus'] as String?) ?? 'completed').toUpperCase(),
      feedback: json['feedback'] as String?,
    );
  }

  final String skill;
  final String band;
  final int scaledScore;
  final int rawScore;
  final String gradingStatus;
  final String? feedback;
}

class PlacementResult {
  const PlacementResult({
    required this.placementId,
    required this.status,
    required this.overallBand,
    required this.totalScaledScore,
    required this.cefrBand,
    required this.skillBreakdowns,
    required this.canRetryGrading,
    required this.hasFailedGrading,
  });

  factory PlacementResult.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['skillBreakdowns'] as List<dynamic>? ?? const [];
    final status = ((json['status'] as String?) ?? 'PENDING').toUpperCase();
    return PlacementResult(
      placementId: (json['placementId'] as num?)?.toInt() ?? 0,
      status: status,
      overallBand: (json['overallBand'] as String?) ?? '-',
      totalScaledScore: (json['totalScaledScore'] as num?)?.toInt() ?? 0,
      cefrBand: (json['cefrBand'] as String?) ??
          (json['overallBand'] as String?) ??
          'A1',
      skillBreakdowns: rawSkills
          .whereType<Map<String, dynamic>>()
          .map(PlacementSkillBreakdown.fromJson)
          .toList(),
      canRetryGrading: (json['canRetryGrading'] as bool?) ?? (status == 'FAILED'),
      hasFailedGrading: (json['hasFailedGrading'] as bool?) ?? (status == 'FAILED'),
    );
  }

  bool get isPending => status == 'PENDING' || status == 'GRADING';
  bool get isFailed => status == 'FAILED' || hasFailedGrading;
  bool get isCompleted => !isPending && !isFailed;

  final int placementId;
  final String status;
  final String overallBand;
  final int totalScaledScore;
  final String cefrBand;
  final List<PlacementSkillBreakdown> skillBreakdowns;
  final bool canRetryGrading;
  final bool hasFailedGrading;
}
