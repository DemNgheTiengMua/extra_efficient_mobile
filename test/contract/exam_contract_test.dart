import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/exams/models/mock_exam_models.dart';
import 'package:extra_efficient_mobile/features/exams/models/placement_models.dart';

import 'fixture_loader.dart';

/// Parse-seam assertions against payloads recorded from the running backend.
///
/// The defect class here is a wrong key that yields a *valid* object containing
/// a zero, so every check below asserts a **non-default** value.
void main() {
  group('GET /api/learner/placement — the catalogue envelope', () {
    late PlacementCatalog catalog;

    setUp(() {
      catalog = PlacementCatalog.fromJson(
        loadFixture('placement_catalog') as Map<String, dynamic>,
      );
    });

    test('reads the exam list from the envelope and keeps its real exam id',
        () {
      expect(catalog.exams, hasLength(1));
      final exam = catalog.exams.single;
      expect(exam.examId, 2);
      expect(exam.name, 'TOEIC Placement Test — Diagnostic');
      expect(exam.durationMinutes, 45);
      expect(exam.questionCount, 29);
      expect(exam.isRecommended, isTrue);
      expect(exam.activePlacementId, 1);
    });

    test('reads activePlacementId, so an unfinished placement is recognised',
        () {
      expect(catalog.activePlacementId, 1);
      expect(catalog.hasInProgressAttempt, isTrue);
    });

    test('the start surface is enabled because the envelope supplies an exam',
        () {
      expect(catalog.startableExamId, 2);
    });

    test('reads the certificate and retake pricing from the envelope', () {
      expect(catalog.certificateCode, 'TOEIC');
      expect(catalog.allSkillsRetakeCredits, 5);
      expect(catalog.listeningAndReadingRetakeCredits, 3);
      expect(catalog.isRetake, isFalse);
    });

    test('a catalogue with no exam yields no startable exam id', () {
      final empty = PlacementCatalog.fromJson(const {
        'activeCert': {'code': 'TOEIC', 'name': 'TOEIC', 'sectionNoun': 'Part'},
        'exams': <dynamic>[],
        'activePlacementId': null,
        'isRetake': true,
        'allSkillsRetakeCredits': 5,
        'listeningAndReadingRetakeCredits': 3,
      });
      expect(empty.startableExamId, isNull);
      expect(empty.hasInProgressAttempt, isFalse);
    });
  });

  group('GET /api/learner/exams — the mock catalogue envelope', () {
    late MockExamCatalogue catalogue;

    setUp(() {
      catalogue = MockExamCatalogue.fromJson(
        loadFixture('mock_exam_list') as Map<String, dynamic>,
      );
    });

    test('reads each exam name, duration, question count and credit cost', () {
      expect(catalogue.exams, hasLength(1));
      final exam = catalogue.exams.single;
      expect(exam.examId, 1);
      expect(exam.name, 'ETS 2024 — Test 1');
      expect(exam.durationMinutes, 120);
      expect(exam.questionCount, 200);
      expect(exam.creditCost, 1);
    });

    test('reads activeAttemptId, so an unfinished mock attempt is recognised',
        () {
      expect(catalogue.exams.single.activeAttemptId, 1005);
      expect(catalogue.creditBalance, 11);
      expect(catalogue.certificateCode, 'TOEIC');
    });

    test('an exam with no unfinished attempt exposes no active attempt', () {
      final idle = MockExamCatalogue.fromJson(const {
        'certificate': {'code': 'TOEIC', 'name': 'TOEIC', 'sectionNoun': 'Part'},
        'creditBalance': 3,
        'exams': [
          {
            'examId': 9,
            'name': 'Idle Mock',
            'durationMinutes': 60,
            'questionCount': 40,
            'creditCost': 2,
            'activeAttemptId': null,
          },
        ],
      });
      expect(idle.exams.single.activeAttemptId, isNull);
    });
  });

  group('GET /api/learner/exams/history — the history envelope', () {
    late ExamHistory history;

    setUp(() {
      history = ExamHistory.fromJson(
        loadFixture('exam_history') as Map<String, dynamic>,
      );
    });

    test('reads every attempt under the backend vocabulary', () {
      expect(history.attempts, hasLength(3));
      final graded = history.attempts.first;
      expect(graded.attemptId, 1004);
      expect(graded.examName, 'ETS 2024 — Test 1');
      expect(graded.totalScore, 10);
      expect(graded.bandCode, 'below_A1');
      expect(graded.bandName, 'Below A1');
      expect(graded.status, ExamAttemptStatus.graded);
      expect(graded.isInProgress, isFalse);
    });

    test('distinguishes in_progress from graded using the backend values', () {
      final live = ExamHistory.fromJson(const {
        'attempts': [
          {
            'attemptId': 77,
            'examId': 1,
            'examName': 'Running Mock',
            'totalScore': 0,
            'bandCode': null,
            'bandName': null,
            'status': 'in_progress',
          },
          {
            'attemptId': 78,
            'examId': 1,
            'examName': 'Finished Mock',
            'totalScore': 640,
            'bandCode': 'B1',
            'bandName': 'Intermediate',
            'status': 'graded',
          },
        ],
      });
      expect(live.attempts[0].status, ExamAttemptStatus.inProgress);
      expect(live.attempts[0].isInProgress, isTrue);
      expect(live.attempts[1].isInProgress, isFalse);
    });

    test('reads the summary figures', () {
      expect(history.totalAttempts, 3);
      expect(history.bestScore, 720);
      expect(history.averageScore, 460);
      expect(history.bestBandCode, 'B1');
    });
  });

  group('GET /api/learner/attempts/{id}/result', () {
    late MockAttemptResult result;

    setUp(() {
      result = MockAttemptResult.fromJson(
        loadFixture('attempt_result') as Map<String, dynamic>,
      );
    });

    test('shows the real exam name, total score and band', () {
      expect(result.attemptId, 1004);
      expect(result.examName, 'ETS 2024 — Test 1');
      expect(result.totalScore, 10);
      expect(result.bandCode, 'below_A1');
      expect(result.bandName, 'Below A1');
      expect(result.scoreDelta, -710);
    });

    test('divides the stored total by scoreDisplayFactor before printing', () {
      final scaled = MockAttemptResult.fromJson(const {
        'attemptId': 5,
        'examName': 'Scaled Paper',
        'totalScore': 900,
        'bandCode': 'B2',
        'bandName': 'Upper intermediate',
        'scoreDisplayFactor': 10,
        'skillScores': <dynamic>[],
      });
      expect(scaled.displayTotalScore, 90);
    });

    test('reads each skill row by the backend skill name', () {
      expect(result.skillScores, hasLength(2));
      final listening = result.skillScores.first;
      expect(listening.skillName, 'Listening');
      expect(listening.rawScore, 0);
      expect(listening.scaledScore, 5);
      expect(listening.totalQuestions, 4);
    });
  });

  group('GET /api/learner/attempts/{id}/review', () {
    late MockAttemptReview review;

    setUp(() {
      review = MockAttemptReview.fromJson(
        loadFixture('attempt_review') as Map<String, dynamic>,
      );
    });

    test('shows the real exam name and counted summary', () {
      expect(review.examName, 'ETS 2024 — Test 1');
      expect(review.totalQuestions, 9);
      expect(review.answeredCount, 0);
      expect(review.blankCount, 9);
    });

    test('reads each question stem, explanation and the correct option', () {
      final q = review.questions.first;
      expect(q.questionId, 3);
      expect(q.displayOrder, 1);
      expect(q.skillName, 'Listening');
      expect(q.stem, contains('Look at the photograph'));
      expect(q.explanation, contains('Option C correctly describes'));
      // A blank answer has no verdict: null is "not answered", not "wrong".
      expect(q.isCorrect, isNull);
      expect(q.selectedOptionLabel, isNull);
      expect(q.correctOptionLabel, 'C');
      expect(q.correctOptionText, 'A woman is writing on a whiteboard.');
      expect(q.options, hasLength(4));
    });

    test('review correctness comes from the per-option flags', () {
      final q = review.questions.first;
      final correct = q.options.where((o) => o.isCorrect).toList();
      expect(correct, hasLength(1));
      expect(correct.single.label, 'C');
      expect(q.options.first.isCorrect, isFalse);
    });

    test('a wrong answer surfaces its own label and the correct one', () {
      final answered = MockAttemptReview.fromJson(const {
        'attemptId': 9,
        'examName': 'Answered Mock',
        'questions': [
          {
            'questionId': 12,
            'displayOrder': 1,
            'skillName': 'Reading',
            'stem': 'Choose the best conjunction.',
            'explanation': 'Although introduces a contrast clause.',
            'selectedOptionId': 121,
            'isCorrect': false,
            'isFlagged': true,
            'options': [
              {
                'optionId': 121,
                'label': 'A',
                'text': 'Because',
                'isCorrect': false,
                'rationale': 'Wrong sense.',
              },
              {
                'optionId': 122,
                'label': 'B',
                'text': 'Although',
                'isCorrect': true,
                'rationale': null,
              },
            ],
          },
        ],
      });
      final q = answered.questions.single;
      expect(q.isCorrect, isFalse);
      expect(q.isFlagged, isTrue);
      expect(q.selectedOptionLabel, 'A');
      expect(q.correctOptionLabel, 'B');
      expect(q.wrongOptionRationale, 'Wrong sense.');
    });
  });

  group('GET /api/learner/placement/result/{id}', () {
    late PlacementResult result;

    setUp(() {
      result = PlacementResult.fromJson(
        loadFixture('placement_result') as Map<String, dynamic>,
      );
    });

    test('shows the real exam name, total score and skills', () {
      expect(result.placementId, 1);
      expect(result.examName, 'TOEIC Placement Test — Diagnostic');
      expect(result.totalScore, 340);
      expect(result.skillScores, hasLength(2));
      expect(result.skillScores.first.skillName, 'Listening');
      expect(result.skillScores.first.scaledScore, 130);
    });

    test('an empty band string reads as not yet banded, not an empty badge',
        () {
      expect(result.bandCode, '');
      expect(result.bandName, '');
      expect(result.isBanded, isFalse);
      expect(result.bandLabel, 'NOT YET BANDED');
      expect(result.skillScores.first.isBanded, isFalse);
    });

    test('a graded result reports its band and reaches the band bar', () {
      final graded = PlacementResult.fromJson(const {
        'placementId': 4,
        'examName': 'Placement',
        'totalScore': 650,
        'resultBandCode': 'B1',
        'resultBandName': 'Intermediate',
        'isGraded': true,
        'skillScores': [
          {
            'skillId': 1,
            'skillCode': 'LIST',
            'skillName': 'Listening',
            'rawScore': 70,
            'totalQuestions': 100,
            'scaledScore': 350,
            'bandCode': 'B1',
          },
        ],
      });
      expect(graded.isBanded, isTrue);
      expect(graded.bandLabel, 'B1 · INTERMEDIATE');
      expect(graded.skillScores.single.isBanded, isTrue);
    });

    test('the status endpoint reports grading still in flight', () {
      final status = PlacementResult.fromJson(
        loadFixture('placement_grading_status') as Map<String, dynamic>,
      );
      expect(status.isGraded, isFalse);
      expect(status.stageDescriptor, contains('coherence'));
      expect(status.hasFailedGrading, isFalse);
    });
  });
}
