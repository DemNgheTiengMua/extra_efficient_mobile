import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/practice/models/practice_models.dart';

import 'fixture_loader.dart';

/// Recorded-payload suite for the practice catalogue and grid. Every assertion
/// pins a **non-default** value: a renamed key yields a valid object holding
/// `0`, `''` or `[]`, which presence-only assertions would not catch.
void main() {
  group('GET /api/learner/practice/catalog', () {
    late PracticeCatalog catalog;

    setUpAll(() {
      catalog = PracticeCatalog.fromJson(
        loadFixture('practice_catalog') as Map<String, dynamic>,
      );
    });

    test('reads the section noun from the certificate, not a default', () {
      expect(catalog.certificate?.code, 'TOEIC');
      expect(catalog.certificate?.name, 'TOEIC Listening & Reading');
      expect(catalog.sectionNoun, 'Part');
    });

    test('reads real section names, codes and available counts', () {
      final first = catalog.listeningSections.first;
      expect(first.sectionId, 1);
      expect(first.code, 'P1');
      expect(first.name, 'Photographs');
      expect(first.skillName, 'Listening');
      expect(first.expectedQuestionCount, 6);
      expect(first.availableQuestionCount, 3);
      expect(first.isAvailable, isTrue);
    });

    test('keeps a section with zero questions but marks it unavailable', () {
      final empty = catalog.otherSections.firstWhere((s) => s.code == 'W3');
      expect(empty.availableQuestionCount, 0);
      expect(empty.isAvailable, isFalse);
    });

    test('groups sections by skill in catalogue order', () {
      final groups = catalog.skillGroups;
      expect(
        groups.map((g) => g.skillName),
        ['Listening', 'Reading', 'Writing', 'Speaking'],
      );
      expect(groups.first.sections, hasLength(4));
      expect(groups.last.isSpeaking, isTrue);
    });

    test('reads the unfinished session under the backend names', () {
      final unfinished = catalog.unfinishedSession;
      expect(unfinished, isNotNull);
      expect(unfinished!.sessionId, 4);
      expect(unfinished.sectionCode, 'P5');
      expect(unfinished.sectionName, 'Incomplete Sentences');
      expect(unfinished.questionCount, 9);
      expect(unfinished.modality, 'reading');
    });

    test('reads the speaking exam id rather than a typed speaking drill', () {
      expect(catalog.speakingPracticeExamId, 3);
      expect(catalog.speakingSections, isNotEmpty);
      expect(catalog.speakingSections.every((s) => s.isSpeaking), isTrue);
    });

    test('a null weakest section stays null', () {
      expect(catalog.weakestSection, isNull);
    });
  });

  group('GET /api/learner/practice/matrix', () {
    late PracticeMatrix matrix;

    setUpAll(() {
      matrix = PracticeMatrix.parse(
        loadFixture('practice_matrix') as List<dynamic>,
      );
    });

    test('pivots the flat cell list into topics carrying cells', () {
      expect(matrix.topics, hasLength(4));
      expect(matrix.topics.map((t) => t.code), [
        'L-DET',
        'R-DET',
        'S-DESC',
        'W-ARG',
      ]);
      final reading = matrix.topics.firstWhere((t) => t.code == 'R-DET');
      expect(reading.name, 'Local factual retrieval and paraphrase matching');
      expect(reading.cells, hasLength(3));
    });

    test('derives level columns from the data, in CEFR order', () {
      expect(matrix.levels, ['A2', 'B1', 'B2', 'C1']);
    });

    test('parses mastery as the wire integer, not a string', () {
      final cell = matrix.topics
          .firstWhere((t) => t.code == 'R-DET')
          .cellAt('B2');
      expect(cell, isNotNull);
      expect(cell!.mastery, PracticeMastery.learning);
      // A string or mis-set field would collapse every cell to untested.
      expect(
        matrix.topics
            .expand((t) => t.cells)
            .where((c) => c.mastery != PracticeMastery.untested),
        hasLength(1),
      );
    });

    test('reads resting state and reopen time per cell', () {
      for (final cell in matrix.topics.expand((t) => t.cells)) {
        expect(cell.levelCode, isNotEmpty);
        // The recorded seed has no resting cell; false must still be read as
        // false rather than defaulted from a missing key.
        expect(cell.isResting, isFalse);
        expect(cell.isRestingNow, isFalse);
        expect(cell.reopensAt, isNull);
      }
    });
  });

  group('GET /api/learner/practice/free-drill', () {
    test('an open cell reports unlocked with no notice', () {
      final state = PracticeFreeDrillState.fromJson(
        loadFixture('practice_free_drill') as Map<String, dynamic>,
      );
      expect(state.isUnlocked, isTrue);
      expect(state.lockNotice, isNull);
      expect(state.cellUsedToday, isFalse);
      expect(state.dailyItemCeiling, 60);
    });

    test('a cell used today reports locked with the backend sentence', () {
      final state = PracticeFreeDrillState.fromJson(
        loadFixture('practice_free_drill_locked') as Map<String, dynamic>,
      );
      expect(state.isUnlocked, isFalse);
      expect(state.cellUsedToday, isTrue);
      expect(state.reason, contains('already had their session today'));
    });
  });
}
