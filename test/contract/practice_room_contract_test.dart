import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/practice/models/practice_models.dart';

import 'fixture_loader.dart';

/// Recorded-payload suite for the practice room: the composite take payload, a
/// revealed hint, two graded replies and the session summary. Every assertion
/// pins a **non-default** value, because a renamed key parses into a valid
/// object holding `0`, `''`, `null` or `[]`.
void main() {
  group('GET /practice/sessions/{id}/take', () {
    late PracticeSessionTake take;

    setUpAll(() {
      take = PracticeSessionTake.fromJson(
        loadFixture('practice_take') as Map<String, dynamic>,
      );
    });

    test('reads the session out of the composite, not the top level', () {
      expect(take.session.sessionId, 17);
      expect(take.session.sectionId, 2);
      expect(take.session.sectionCode, 'P2');
      expect(take.session.sectionName, 'Question-Response');
      expect(take.session.modality, 'listening');
      expect(take.session.questionCount, 5);
      expect(take.session.status, 'in_progress');
      expect(take.session.questionSource, 'all');
      expect(take.session.isShort, isFalse);
      expect(take.session.startedAt, isNotNull);
      expect(take.session.finishedAt, isNull);
    });

    test('carries the current question, every question and the navigator', () {
      expect(take.question, isNotNull);
      expect(take.question!.displayOrder, 1);
      expect(take.questions, hasLength(5));
      expect(take.navigator, hasLength(5));
      expect(take.navigator.first.isCurrent, isTrue);
      expect(take.navigator.skip(1).every((n) => !n.isCurrent), isTrue);
      // The room opens on the server's current question, not blindly on the
      // first row.
      expect(take.openingQuestion?.address, 4);
    });

    test('opens on the question the server names current, not the first row',
        () {
      final json = loadFixture('practice_take') as Map<String, dynamic>;
      final questions = (json['questions'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();
      // A resumed sitting: the server's current question is the third.
      final resumed = PracticeSessionTake.fromJson({
        ...json,
        'question': questions[2],
        'questions': questions,
      });
      expect(resumed.question!.displayOrder, 3);
      expect(resumed.openingQuestion?.address, 15);
      expect(resumed.openingQuestion?.stem, 'Why was the shipment delayed?');
    });

    test('a pool question has no row id and is addressed by its item version',
        () {
      for (final question in take.questions) {
        // Live proof: every question is a pool item, so `questionId` is null.
        expect(question.questionId, isNull);
        expect(question.itemVersionId, isNotNull);
        expect(question.itemVersionId, isNot(0));
        // A collapsed `questionId ?? 0` would address every item as 0.
        expect(question.address, question.itemVersionId);
        expect(question.address, isNot(0));
      }
      final addresses = take.questions.map((q) => q.address).toList();
      expect(addresses, [4, 14, 15, 16, 17]);
      expect(addresses.toSet(), hasLength(addresses.length));
      expect(
        take.navigator.map((n) => n.address),
        addresses,
      );
    });

    test('reads the passage, audio path, audio slice and word bounds under the '
        'backend names', () {
      final written = PracticeQuestion.fromJson({
        'questionId': 900,
        'displayOrder': 1,
        'questionType': 'free_response',
        'stem': 'Reply to the client.',
        'passage': 'Dear client, ...',
        'audioPath': '/audio/toeic/w.mp3',
        'audioStartMs': 1200,
        'audioEndMs': 4500,
        'minWords': 25,
        'maxWords': 60,
        'requiredKeywords': '["schedule","confirm"]',
        'options': <dynamic>[],
      });
      expect(written.passage, 'Dear client, ...');
      expect(written.audioPath, '/audio/toeic/w.mp3');
      expect(written.audioStartMs, 1200);
      expect(written.audioEndMs, 4500);
      expect(written.minWords, 25);
      expect(written.maxWords, 60);
      expect(written.requiredKeywords, ['schedule', 'confirm']);
      expect(written.isWriting, isTrue);
      // A row id is the address when there is one.
      expect(written.address, 900);
    });

    test('reads the recorded MCQ options and an unanswered state', () {
      final first = take.questions.first;
      expect(first.stem, 'Where did you leave the project folders?');
      expect(first.options, hasLength(4));
      expect(first.options.first.label, 'A');
      expect(first.options.first.text, 'Yes, I folded them neatly.');
      expect(first.selectedOptionId, isNull);
      expect(first.isCorrect, isNull);
      expect(first.correctOptionId, isNull);
      expect(first.explanation, isNull);
      expect(first.isSaved, isFalse);
      expect(first.savedQuestionId, isNull);
      expect(first.isWriting, isFalse);
    });

    test('an answered question carries its key, explanation and saved id', () {
      final answered = PracticeQuestion.fromJson({
        'questionId': null,
        'itemVersionId': 1,
        'displayOrder': 1,
        'questionType': 'mcq',
        'stem': 'On what date will the festival open?',
        'isCorrect': true,
        'correctOptionId': 12,
        'selectedOptionId': 12,
        'explanation': 'The speaker explicitly states June 8th.',
        'savedQuestionId': 2,
        'isSaved': true,
        'options': <dynamic>[],
      });
      expect(answered.isCorrect, isTrue);
      expect(answered.correctOptionId, 12);
      expect(answered.explanation, 'The speaker explicitly states June 8th.');
      expect(answered.isSaved, isTrue);
      expect(answered.savedQuestionId, 2);
    });
  });

  group('POST .../questions/{address}/hint', () {
    test('reads the hint sentence and the used flag', () {
      final json = loadFixture('practice_hint') as Map<String, dynamic>;
      expect(json['hint'], 'Listen for a location word that answers "Where".');
      expect(json['hintUsed'], isTrue);
    });
  });

  group('POST .../questions/{address}/answer', () {
    test('the wrong reply names the correct option and explains it', () {
      final result = PracticeAnswerResult.fromJson(
        loadFixture('practice_answer_wrong') as Map<String, dynamic>,
      );
      expect(result.isCorrect, isFalse);
      expect(result.selectedOptionId, 41);
      expect(result.correctOptionId, 42);
      expect(
        result.explanation,
        'Option B directly answers where the folders are placed.',
      );
      expect(result.isSessionFinished, isFalse);
      expect(result.nextQuestionDisplayOrder, 2);
      expect(result.isSaved, isTrue);
      expect(result.savedQuestionId, 8);
      expect(result.correctOptionIds, [42]);
    });

    test('the right reply reads isCorrect true and carries the same key', () {
      final result = PracticeAnswerResult.fromJson(
        loadFixture('practice_answer_right') as Map<String, dynamic>,
      );
      expect(result.isCorrect, isTrue);
      expect(result.selectedOptionId, 161);
      expect(result.correctOptionId, 161);
      expect(result.explanation, contains('recommendation'));
      expect(result.nextQuestionDisplayOrder, 5);
      expect(result.savedQuestionId, isNull);
    });
  });

  group('GET /practice/sessions/{id}/summary', () {
    late PracticeSummary summary;

    setUpAll(() {
      summary = PracticeSummary.fromJson(
        loadFixture('practice_summary') as Map<String, dynamic>,
      );
    });

    test('reads the score under the backend names', () {
      expect(summary.sessionId, 17);
      expect(summary.sectionCode, 'P2');
      expect(summary.sectionName, 'Question-Response');
      expect(summary.totalQuestions, 5);
      expect(summary.answeredCount, 5);
      expect(summary.correctCount, 1);
      expect(summary.incorrectCount, 4);
      expect(summary.skippedCount, 0);
      // `accuracyPercent` / `totalCount` would both be 0 / 0 here.
      expect(summary.accuracyPercentage, 20);
      expect(summary.hintUsedCount, 1);
      expect(summary.finishedAt, isNotNull);
    });

    test('reads one breakdown row per question with both option sides', () {
      expect(summary.questions, hasLength(5));
      final first = summary.questions.first;
      expect(first.displayOrder, 1);
      expect(first.questionId, isNull);
      expect(first.itemVersionId, 4);
      expect(first.selectedOptionLabel, 'A');
      expect(first.selectedOptionText, 'Yes, I folded them neatly.');
      expect(first.correctOptionLabel, 'B');
      expect(first.correctOptionText, 'On the conference room table.');
      expect(first.isCorrect, isFalse);
      expect(first.hintUsed, isTrue);
      expect(first.explanation, isNotNull);
      expect(summary.questions[3].isCorrect, isTrue);
    });

    test('a null isCorrect is "not answered", not "wrong"', () {
      final json = loadFixture('practice_summary') as Map<String, dynamic>;
      final questions = (json['questions'] as List<dynamic>).toList();
      (questions[2] as Map<String, dynamic>)['isCorrect'] = null;
      (questions[2] as Map<String, dynamic>)['selectedOptionLabel'] = null;
      (questions[2] as Map<String, dynamic>)['selectedOptionText'] = null;
      final parsed = PracticeSummary.fromJson({
        ...json,
        'questions': questions,
      });
      expect(parsed.questions[2].isCorrect, isNull);
      expect(parsed.questions[2].isAnswered, isFalse);
      // The key and explanation still ship for an unanswered row.
      expect(parsed.questions[2].correctOptionLabel, isNotNull);
      expect(parsed.questions[2].explanation, isNotNull);
    });
  });
}
