import 'placement_models.dart';

class SkillPracticeExamSummary {
  const SkillPracticeExamSummary({
    required this.examId,
    required this.title,
    required this.credits,
    required this.questionCount,
  });

  factory SkillPracticeExamSummary.fromJson(Map<String, dynamic> json) {
    return SkillPracticeExamSummary(
      examId: (json['examId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      title: (json['title'] as String?) ?? 'Skill Practice',
      credits: (json['credits'] as num?)?.toInt() ??
          (json['creditCost'] as num?)?.toInt() ??
          1,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 1,
    );
  }

  final int examId;
  final String title;
  final int credits;
  final int questionCount;
}

class SkillPracticeAttempt {
  const SkillPracticeAttempt({
    required this.attemptId,
    required this.examTitle,
    required this.questions,
  });

  factory SkillPracticeAttempt.fromJson(Map<String, dynamic> json) {
    final raw = json['questions'] as List<dynamic>? ?? const [];
    final list = <PlacementQuestion>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map<String, dynamic>) {
        list.add(PlacementQuestion.fromJson(item, i));
      }
    }
    return SkillPracticeAttempt(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examTitle: (json['examTitle'] as String?) ?? 'Skill Practice Attempt',
      questions: list,
    );
  }

  final int attemptId;
  final String examTitle;
  final List<PlacementQuestion> questions;
}

class SkillPracticePendingStatus {
  const SkillPracticePendingStatus({
    required this.status,
    this.errorMessage,
  });

  factory SkillPracticePendingStatus.fromJson(Map<String, dynamic> json) {
    return SkillPracticePendingStatus(
      status: ((json['status'] as String?) ?? 'PENDING').toUpperCase(),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  final String status;
  final String? errorMessage;

  bool get isPending =>
      status == 'PENDING' || status == 'QUEUED' || status == 'GRADING';
  bool get isFailed => status == 'FAILED' || status == 'ERROR';
  bool get isCompleted => status == 'COMPLETED' || status == 'GRADED';
}

class RubricCriterionReview {
  const RubricCriterionReview({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.comment,
  });

  factory RubricCriterionReview.fromJson(Map<String, dynamic> json) {
    return RubricCriterionReview(
      name: (json['name'] as String?) ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
      comment: (json['comment'] as String?) ?? '',
    );
  }

  final String name;
  final double score;
  final double maxScore;
  final String comment;
}

class SkillPracticeReview {
  const SkillPracticeReview({
    required this.attemptId,
    required this.examTitle,
    required this.estimatedBand,
    required this.totalScore,
    required this.maxScore,
    required this.criteria,
  });

  factory SkillPracticeReview.fromJson(Map<String, dynamic> json) {
    final rawCriteria = json['criteria'] as List<dynamic>? ?? const [];
    return SkillPracticeReview(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examTitle: (json['examTitle'] as String?) ?? 'Skill Practice Review',
      estimatedBand: (json['estimatedBand'] as String?) ?? '-',
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
      criteria: rawCriteria
          .whereType<Map<String, dynamic>>()
          .map(RubricCriterionReview.fromJson)
          .toList(),
    );
  }

  final int attemptId;
  final String examTitle;
  final String estimatedBand;
  final double totalScore;
  final double maxScore;
  final List<RubricCriterionReview> criteria;
}
