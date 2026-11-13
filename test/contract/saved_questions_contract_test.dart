import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/practice/models/practice_models.dart';

import 'fixture_loader.dart';

/// Recorded-payload suite for SAVED. Every assertion parses real backend bytes
/// and then checks a **non-default** value: a wrong key yields a valid object
/// holding `0`, `''` or `[]`, which is exactly the defect this guards.
void main() {
  group('GET /api/learner/saved-questions', () {
    late SavedQuestionsResponse saved;

    setUpAll(() {
      saved = SavedQuestionsResponse.fromJson(
        loadFixture('saved_questions') as Map<String, dynamic>,
      );
    });

    test('reads the questions key, not an invented items key', () {
      expect(saved.items, hasLength(3));
      expect(saved.items.map((q) => q.savedQuestionId), [4, 3, 2]);
      expect(saved.items.map((q) => q.savedQuestionId), everyElement(isNonZero));
    });

    test('carries the backend counts and the certificate noun', () {
      expect(saved.totalSavedCount, 3);
      expect(saved.manualSavedCount, 2);
      expect(saved.incorrectSavedCount, 1);
      expect(saved.sectionNoun, 'Part');
    });

    test('a pool item has a null questionId and a real item version', () {
      final pool = saved.items.first;

      expect(pool.questionId, isNull);
      expect(pool.itemVersionId, 3);
      expect(pool.itemId, 3);
      expect(pool.isPoolItem, isTrue);
    });

    test('scope name comes from the topic when the section is null', () {
      final pool = saved.items.first;

      expect(pool.scopeCode, 'L-DET');
      expect(
        pool.scopeName,
        'Explicit factual detail and extraction',
      );
      expect(pool.categoryName, isNull);
    });

    test('reads explanation, audioPath, hint and imagePath under their names',
        () {
      final listening = saved.items.first;

      expect(
        listening.explanation,
        'Option C correctly describes the action: the woman is writing notes '
        'on the whiteboard.',
      );
      expect(listening.audioPath, '/audio/toeic/test1-p1.mp3');
      expect(listening.imagePath, '/img/part1-sample.svg');
      expect(
        listening.hint,
        'Focus on what the person in the centre is holding and doing.',
      );
      expect(listening.passage, isNull);
    });

    test('reads the option key and the correct-option flag', () {
      final listening = saved.items.first;

      expect(listening.options, hasLength(4));
      final correct = listening.options.where((o) => o.isCorrect).toList();
      expect(correct, hasLength(1));
      expect(correct.single.optionId, 33);
      expect(correct.single.label, 'C');
      expect(correct.single.text, 'A woman is writing on a whiteboard.');
    });

    test('the incorrect save keeps its source and transcript', () {
      final incorrect = saved.items.last;

      expect(incorrect.source, 'incorrect');
      expect(
        incorrect.savedAt,
        DateTime.parse('2026-11-07T01:44:02.8671889+07:00'),
      );
      expect(incorrect.transcript, contains('June 8th'));
      expect(incorrect.audioPath, '/audio/vstep/sample1-listening.mp3');
      expect(incorrect.options.where((o) => o.isCorrect).single.optionId, 12);
    });

    test('every row has a distinct saved address', () {
      final ids = saved.items.map((q) => q.savedQuestionId).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('the live filter facets are empty and parse as empty', () {
      expect(saved.sections, isEmpty);
      expect(saved.categories, isEmpty);
    });
  });

  group('GET /api/learner/saved-questions on an empty bank', () {
    test('reads zero counts and no questions', () {
      final saved = SavedQuestionsResponse.fromJson(
        loadFixture('saved_questions_empty') as Map<String, dynamic>,
      );

      expect(saved.items, isEmpty);
      expect(saved.totalSavedCount, 0);
      expect(saved.sections, isEmpty);
      expect(saved.categories, isEmpty);
    });
  });

  group('GET /api/learner/saved-questions/{id}', () {
    test('is one saved question, not a different detail shape', () {
      final detail = SavedQuestionItem.fromJson(
        loadFixture('saved_question_detail') as Map<String, dynamic>,
      );

      expect(detail.savedQuestionId, 4);
      expect(detail.itemVersionId, 3);
      expect(
        detail.explanation,
        startsWith('Option C correctly describes'),
      );
      expect(detail.audioPath, '/audio/toeic/test1-p1.mp3');
      expect(detail.scopeName, 'Explicit factual detail and extraction');
    });
  });

  group('POST /api/learner/saved-questions/item-versions/{id}', () {
    test('reads isSaved and the new saved address', () {
      final result = SavedQuestionResult.fromJson(
        loadFixture('save_question_result') as Map<String, dynamic>,
      );

      expect(result.isSaved, isTrue);
      expect(result.savedQuestionId, 6);
      expect(result.source, 'manual');
      expect(result.savedAt, isNotNull);
    });
  });

  group('DELETE /api/learner/saved-questions/{id}', () {
    test('answers 200 with isSaved false, not a 204 body', () {
      final result = SavedQuestionResult.fromJson(
        loadFixture('unsave_question_result') as Map<String, dynamic>,
      );

      expect(result.isSaved, isFalse);
      expect(result.savedQuestionId, isNull);
      expect(result.source, isNull);
    });
  });
}

Matcher get isNonZero => predicate<num>((v) => v != 0, 'is non-zero');
