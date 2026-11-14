import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/exams/models/exam_room_stop.dart';
import 'package:extra_efficient_mobile/features/exams/models/placement_models.dart';
import 'package:extra_efficient_mobile/features/exams/models/preflight_models.dart';

import 'fixture_loader.dart';

/// Parse-seam assertions for the exam room's entry gate, terminal states and
/// listening media.
///
/// Every fixture is recorded from the running backend. As elsewhere the defect
/// class is a wrong key yielding a **valid** object full of defaults, so each
/// check asserts a non-default value.
void main() {
  group('PreflightStatus — the device gate both doors read', () {
    test('placement preflight reads the real DTO, not a generic sample URL', () {
      final status = PreflightStatus.fromJson(
        loadFixture('placement_preflight_status') as Map<String, dynamic>,
      );
      expect(status.attemptId, 3);
      expect(status.examId, 2);
      expect(status.examName, 'TOEIC Placement Test — Diagnostic');
      expect(status.certName, 'TOEIC Listening & Reading');
      expect(status.durationMinutes, 45);
      expect(status.requiresAudio, isTrue);
      expect(status.requiresMicrophone, isTrue);
      expect(status.isVerified, isTrue);
      expect(status.verifiedAt, isNotNull);
      // The audio sample comes from `audioUrls`, the only field that carries
      // one. `audioSampleUrl` is not a key on this DTO at all.
      expect(status.audioUrls, hasLength(4));
      expect(status.audioSampleUrl, '/audio/toeic/placement-p1.mp3');
      expect(status.needsChecks, isFalse);
    });

    test('an unverified attempt reports that the gate still has to run', () {
      final status = PreflightStatus.fromJson(
        loadFixture('attempt_preflight_status') as Map<String, dynamic>,
      );
      expect(status.attemptId, 1);
      expect(status.isVerified, isFalse);
      expect(status.verifiedAt, isNull);
      expect(status.requiresAudio, isTrue);
      expect(status.needsChecks, isTrue);
    });

    test('a sitting needing no checks never blocks entry', () {
      final status = PreflightStatus.fromJson(const {
        'attemptId': 9,
        'requiresPreflight': false,
        'requiresAudio': false,
        'requiresMicrophone': false,
        'isVerified': true,
        'audioUrls': <dynamic>[],
      });
      expect(status.needsChecks, isFalse);
      expect(status.audioSampleUrl, isNull);
    });

    test('a missing audio list yields no sample rather than a fake path', () {
      final status = PreflightStatus.fromJson(const {
        'attemptId': 9,
        'requiresAudio': true,
        'audioUrls': <dynamic>[],
      });
      expect(status.audioSampleUrl, isNull);
    });
  });

  group('PlacementSitting — the room\'s questions', () {
    late PlacementSitting sitting;

    setUp(() {
      sitting = PlacementSitting.fromJson(
        loadFixture('placement_take') as Map<String, dynamic>,
      );
    });

    test('reads the answered count the resume banner needs', () {
      expect(sitting.placementId, 1);
      expect(sitting.totalQuestions, 29);
      expect(sitting.answeredCount, 24);
      expect(sitting.status, 'in_progress');
      expect(sitting.isOpen, isTrue);
      expect(sitting.questions, hasLength(29));
    });

    test('reads listening audio under the backend\'s real names', () {
      final listening = sitting.questions.firstWhere(
        (q) => q.audioPath != null,
      );
      // `audioPath`, not `audioUrl` — and it is the seeded app path, which does
      // not resolve on this backend. The room plays it when it does.
      expect(listening.audioPath, '/audio/toeic/placement-p1.mp3');
      expect(listening.skill, 'listening');
      expect(listening.sectionName, 'Photographs');
    });

    test('reads the audio slice bounds from audioStartMs/audioEndMs', () {
      final sliced = PlacementQuestion.fromJson(const {
        'questionId': 8,
        'displayOrder': 3,
        'modality': 'listening',
        'stem': 'Listen.',
        'audioPath': '/audio/toeic/test1-p3.mp3',
        'audioStartMs': 5000,
        'audioEndMs': 18500,
        'options': <dynamic>[],
      }, 0);
      expect(sliced.audioPath, '/audio/toeic/test1-p3.mp3');
      expect(sliced.audioStartMs, 5000);
      expect(sliced.audioEndMs, 18500);
    });

    test('reads the stem, passage and options under their real names', () {
      final q = sitting.questions.first;
      expect(q.prompt, contains('Look at the photograph'));
      expect(q.options, hasLength(4));
      expect(q.options.first.label, 'A');
      expect(q.options.first.text, 'A woman is writing on a whiteboard.');

      final reading = sitting.questions.firstWhere(
        (question) => question.passageText != null,
      );
      expect(reading.passageText, contains('Attention all shoppers'));
      expect(reading.skill, 'speaking');
      expect(reading.prepSeconds, 45);
      expect(reading.responseSeconds, 45);
    });

    test('reads displayOrder as the question position, not an invented index',
        () {
      expect(sitting.questions.first.index, 1);
      expect(sitting.questions[1].questionId, 13);
    });

    test('returns a free-response question with no options', () {
      final freeResponse = sitting.questions.firstWhere(
        (q) => q.skill == 'writing',
      );
      expect(freeResponse.questionId, 120);
      expect(freeResponse.options, isEmpty);
      // The word floor is the backend's `minWords`.
      expect(freeResponse.wordFloor, 8);
      expect(freeResponse.prompt, contains('Write ONE sentence'));
    });
  });

  group('PlacementResumeStatus — progress facts only', () {
    test('reads the answered/synced counts and the active skill', () {
      final resume = PlacementResumeStatus.fromJson(
        loadFixture('placement_resume') as Map<String, dynamic>,
      );
      expect(resume.placementId, 2);
      expect(resume.attemptId, 1003);
      expect(resume.examName, 'TOEIC Placement Test — Diagnostic');
      expect(resume.activeSkillName, 'Listening');
      expect(resume.totalStages, 4);
      expect(resume.totalQuestions, 29);
      expect(resume.lastQuestionId, 12);
      expect(resume.syncedAnswerCount, 0);
      expect(resume.activeStage, 1);
    });
  });

  group('PlacementPreflight — the pre-start capability view', () {
    late PlacementPreflight preflight;

    setUp(() {
      preflight = PlacementPreflight.fromJson(
        loadFixture('placement_preflight_offers') as Map<String, dynamic>,
      );
    });

    test('reads the offers, not the invented reusableSkills list', () {
      expect(preflight.offers, hasLength(4));
      final listening = preflight.offers.first;
      expect(listening.skillCode, 'LIST');
      expect(listening.skillName, 'Listening');
      expect(listening.modality, 'listening');
      expect(listening.requiresAudio, isTrue);
      expect(listening.requiresMicrophone, isFalse);
    });

    test('reads the certificate-level microphone requirement', () {
      expect(preflight.requiresMicrophone, isTrue);
      expect(preflight.requiresAudio, isTrue);
      expect(preflight.isStartable, isTrue);
      expect(preflight.hasReusableSkills, isFalse);
      expect(preflight.reusableSkills, isEmpty);
    });

    test('only an offer the backend calls reusable is carried over', () {
      final reusable = PlacementPreflight.fromJson(const {
        'offers': [
          {
            'skillCode': 'LIST',
            'skillName': 'Listening',
            'modality': 'listening',
            'canReuse': true,
            'levelCode': 'A2',
          },
          {
            'skillCode': 'SPEA',
            'skillName': 'Speaking',
            'modality': 'speaking',
            'canReuse': false,
            'levelCode': null,
          },
        ],
        'hasReusableSkills': true,
      });
      expect(reusable.reusableSkills, hasLength(1));
      expect(reusable.reusableSkills.single.levelCode, 'A2');
    });
  });

  group('ExamRoomStop — a room that cannot be opened', () {
    ExamRoomStop? stop(String status, int questions) => stopForSitting(
          status: status,
          questionCount: questions,
          resultRoute: '/placement/result/7',
          hubRoute: '/exams',
        );

    test('a live sitting with questions opens', () {
      expect(stop('in_progress', 29), isNull);
    });

    test('a submitted or graded sitting is over and routes to the result', () {
      for (final status in ['submitted', 'graded', 'done']) {
        final s = stop(status, 29);
        expect(s, isNotNull, reason: status);
        expect(s!.stamp, 'FINISHED');
        expect(s.actionRoute, '/placement/result/7');
      }
    });

    test('an abandoned sitting explains itself and offers the hub', () {
      final s = stop('abandoned', 29);
      expect(s, isNotNull);
      expect(s!.stamp, 'ABANDONED');
      expect(s.actionRoute, '/exams');
      expect(s.description, contains('cancelled'));
    });

    test('a sitting with no questions is a terminal state, not a blank room',
        () {
      final s = stop('in_progress', 0);
      expect(s, isNotNull);
      expect(s!.stamp, 'EMPTY');
      expect(s.actionRoute, '/exams');
    });
  });

  group('error classification — a normal end is not a failure', () {
    DioException problem(int status, String code) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: status,
            data: {'code': code, 'title': 'x'},
          ),
        );

    test('preflight_required is the device gate, matched case-insensitively',
        () {
      expect(isPreflightRequired(problem(400, 'preflight_required')), isTrue);
      expect(
        isPreflightRequired(problem(400, 'PREFLIGHT_REQUIRED')),
        isTrue,
      );
      expect(isPreflightRequired(problem(400, 'validation')), isFalse);
    });

    test('a finished or missing sitting is told apart from a real error', () {
      expect(isSittingOver(problem(400, 'placement_not_active')), isTrue);
      expect(isSittingOver(problem(410, 'placement_expired')), isTrue);
      expect(isSittingOver(problem(400, 'ATTEMPT_NOT_ACTIVE')), isTrue);
      expect(isSittingMissing(problem(404, 'placement_not_found')), isTrue);
      expect(isSittingMissing(problem(404, 'ATTEMPT_NOT_FOUND')), isTrue);
      expect(isSittingOver(problem(500, 'UNEXPECTED')), isFalse);
    });

    test('a non-Dio error carries no code', () {
      expect(apiErrorCode(StateError('boom')), isNull);
      expect(isPreflightRequired(StateError('boom')), isFalse);
    });
  });
}
