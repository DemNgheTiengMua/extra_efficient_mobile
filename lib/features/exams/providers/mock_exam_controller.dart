import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../data/mock_exam_repository.dart';
import '../models/exam_room_stop.dart';
import '../models/placement_models.dart';
import 'placement_exam_controller.dart';

class MockExamState {
  const MockExamState({
    this.isLoading = true,
    this.error,
    this.attemptId = 0,
    this.expiresAt,
    this.remainingSeconds = 0,
    this.questions = const [],
    this.currentIndex = 0,
    this.autosaveStatus = AutosaveStatus.idle,
    this.isSubmitting = false,
    this.isCompleted = false,
    this.activeSkillId,
    this.activeUnitNumber,
    this.activeGroupId,
    this.phaseDeadlineAt,
    this.isAudioReviewActive = false,
    this.audioReviewRemainingSeconds = 0,
    this.uploadedAudioQuestionIds = const <int>{},
    this.answeredCount = 0,
    this.stop,
    this.needsPreflight = false,
  });

  final bool isLoading;
  final String? error;
  final int attemptId;
  final DateTime? expiresAt;
  final int remainingSeconds;
  final List<PlacementQuestion> questions;
  final int currentIndex;
  final AutosaveStatus autosaveStatus;
  final bool isSubmitting;
  final bool isCompleted;
  final int? activeSkillId;
  final int? activeUnitNumber;
  final int? activeGroupId;
  final DateTime? phaseDeadlineAt;
  final bool isAudioReviewActive;
  final int audioReviewRemainingSeconds;
  final Set<int> uploadedAudioQuestionIds;

  /// The server's count of answers it holds.
  final int answeredCount;

  /// Set when the sitting cannot be opened at all.
  final ExamRoomStop? stop;

  /// The backend refused the sitting with `preflight_required`.
  final bool needsPreflight;

  PlacementQuestion? get currentQuestion =>
      (currentIndex >= 0 && currentIndex < questions.length)
          ? questions[currentIndex]
          : null;

  MockExamState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? attemptId,
    DateTime? expiresAt,
    int? remainingSeconds,
    List<PlacementQuestion>? questions,
    int? currentIndex,
    AutosaveStatus? autosaveStatus,
    bool? isSubmitting,
    bool? isCompleted,
    int? activeSkillId,
    int? activeUnitNumber,
    int? activeGroupId,
    DateTime? phaseDeadlineAt,
    bool? isAudioReviewActive,
    int? audioReviewRemainingSeconds,
    Set<int>? uploadedAudioQuestionIds,
    int? answeredCount,
    ExamRoomStop? stop,
    bool? needsPreflight,
  }) {
    return MockExamState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      attemptId: attemptId ?? this.attemptId,
      expiresAt: expiresAt ?? this.expiresAt,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      autosaveStatus: autosaveStatus ?? this.autosaveStatus,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCompleted: isCompleted ?? this.isCompleted,
      activeSkillId: activeSkillId ?? this.activeSkillId,
      activeUnitNumber: activeUnitNumber ?? this.activeUnitNumber,
      activeGroupId: activeGroupId ?? this.activeGroupId,
      phaseDeadlineAt: phaseDeadlineAt ?? this.phaseDeadlineAt,
      isAudioReviewActive: isAudioReviewActive ?? this.isAudioReviewActive,
      audioReviewRemainingSeconds:
          audioReviewRemainingSeconds ?? this.audioReviewRemainingSeconds,
      uploadedAudioQuestionIds:
          uploadedAudioQuestionIds ?? this.uploadedAudioQuestionIds,
      answeredCount: answeredCount ?? this.answeredCount,
      stop: stop ?? this.stop,
      needsPreflight: needsPreflight ?? this.needsPreflight,
    );
  }
}

/// Controller for a single timed Mock Attempt Exam Room.
class MockExamController extends ChangeNotifier {
  MockExamController({
    required this.attemptId,
    required this.repository,
    required this.audioAdapter,
    this.onSubmitted,
  });

  final int attemptId;
  final MockExamRepository repository;
  final AudioMediaAdapter audioAdapter;
  final VoidCallback? onSubmitted;

  MockExamState _state = const MockExamState();
  MockExamState get state => _state;

  Timer? _countdownTimer;
  Timer? _audioReviewTimer;
  Timer? _debounceTimer;
  bool _disposed = false;
  int? _loadedAudioQuestionId;

  Future<void> init() async {
    _update(_state.copyWith(isLoading: true, clearError: true));
    try {
      final attemptState = await repository.fetchAttemptState(attemptId);
      final now = DateTime.now().toUtc();
      final remaining =
          attemptState.expiresAt.toUtc().difference(now).inSeconds;
      final stop = stopForSitting(
        status: attemptState.status,
        questionCount: attemptState.questions.length,
        resultRoute: '/exams/attempts/$attemptId/result',
        hubRoute: '/exams',
      );
      _update(
        _state.copyWith(
          isLoading: false,
          attemptId: attemptId,
          expiresAt: attemptState.expiresAt,
          remainingSeconds: remaining > 0 ? remaining : 0,
          questions: attemptState.questions,
          answeredCount: attemptState.answeredCount,
          currentIndex: 0,
          activeSkillId: attemptState.activeSkillId,
          activeUnitNumber: attemptState.activeUnitNumber,
          activeGroupId: attemptState.activeGroupId,
          phaseDeadlineAt: attemptState.phaseDeadlineAt,
          stop: stop,
        ),
      );
      if (stop != null) return;
      _startCountdown();
      await _loadAudioForCurrentQuestion();
    } catch (e) {
      if (isPreflightRequired(e)) {
        _update(_state.copyWith(isLoading: false, needsPreflight: true));
        return;
      }
      if (isSittingOver(e) || isSittingMissing(e)) {
        final missing = isSittingMissing(e);
        _update(
          _state.copyWith(
            isLoading: false,
            stop: ExamRoomStop(
              stamp: missing ? 'NOT FOUND' : 'FINISHED',
              title: missing
                  ? 'This attempt no longer exists'
                  : 'This attempt is over',
              description: missing
                  ? 'The backend does not recognise it, so there is nothing to '
                      'open.'
                  : 'It was submitted, graded or expired, so it can no longer be '
                      'answered. Open RESULT on the exams hub to see the score.',
              actionLabel: missing ? 'BACK TO EXAMS' : 'VIEW RESULT',
              actionRoute: missing
                  ? '/exams'
                  : '/exams/attempts/$attemptId/result',
            ),
          ),
        );
        return;
      }
      _update(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _state.expiresAt == null || _state.isCompleted) return;
      final remaining =
          _state.expiresAt!.toUtc().difference(DateTime.now().toUtc()).inSeconds;
      if (remaining <= 0) {
        _update(_state.copyWith(remainingSeconds: 0));
        _countdownTimer?.cancel();
        unawaited(submit());
      } else {
        _update(_state.copyWith(remainingSeconds: remaining));
      }
    });
  }

  Future<void> _loadAudioForCurrentQuestion() async {
    final q = _state.currentQuestion;
    if (q == null || q.audioPath == null || q.audioPath!.isEmpty) {
      if (_loadedAudioQuestionId != null) {
        await audioAdapter.stop();
        _loadedAudioQuestionId = null;
      }
      return;
    }
    if (_loadedAudioQuestionId == q.questionId) return;
    _loadedAudioQuestionId = q.questionId;
    await audioAdapter.setAudioUrl(
      q.audioPath!,
      clipStart:
          q.audioStartMs != null ? Duration(milliseconds: q.audioStartMs!) : null,
      clipEnd:
          q.audioEndMs != null ? Duration(milliseconds: q.audioEndMs!) : null,
    );
  }

  Future<void> jumpToQuestion(int index) async {
    if (index < 0 || index >= _state.questions.length) return;
    final current = _state.currentQuestion;
    final target = _state.questions[index];
    if (target.unitNumber != null &&
        target.unitNumber != current?.unitNumber &&
        target.unitNumber != _state.activeUnitNumber) {
      await transitionUnit(target.unitNumber!);
    }
    if (target.groupId != null &&
        target.groupId != current?.groupId &&
        target.groupId != _state.activeGroupId) {
      await transitionGroup(target.groupId!);
    }
    _update(_state.copyWith(currentIndex: index));
    await _loadAudioForCurrentQuestion();
  }

  Future<bool> transitionSkill() async {
    _debounceTimer?.cancel();
    try {
      final res = await repository.transitionSkill(attemptId);
      final nextSkillId = (res['activeSkillId'] as num?)?.toInt();
      final nextUnit = (res['activeUnitNumber'] as num?)?.toInt();
      final nextGroup = (res['activeGroupId'] as num?)?.toInt();
      final deadline = DateTime.tryParse(
        (res['phaseDeadlineAt'] as String?) ?? '',
      );
      final isSubmitted = (res['isSubmitted'] as bool?) ?? false;
      var targetIdx = _state.currentIndex;
      if (nextSkillId != null) {
        final found = _state.questions.indexWhere(
          (q) => q.skillId == nextSkillId,
        );
        if (found != -1) targetIdx = found;
      }
      _update(
        _state.copyWith(
          activeSkillId: nextSkillId,
          activeUnitNumber: nextUnit,
          activeGroupId: nextGroup,
          phaseDeadlineAt: deadline,
          currentIndex: targetIdx,
          isCompleted: isSubmitted,
        ),
      );
      if (isSubmitted) {
        onSubmitted?.call();
      } else {
        await _loadAudioForCurrentQuestion();
      }
      return true;
    } catch (e) {
      _update(_state.copyWith(error: e.toString()));
      return false;
    }
  }

  Future<bool> transitionUnit(int targetUnitNumber) async {
    try {
      final res = await repository.transitionUnit(attemptId, targetUnitNumber);
      _update(
        _state.copyWith(
          activeUnitNumber:
              (res['activeUnitNumber'] as num?)?.toInt() ?? targetUnitNumber,
          activeGroupId: (res['activeGroupId'] as num?)?.toInt(),
          phaseDeadlineAt: DateTime.tryParse(
            (res['phaseDeadlineAt'] as String?) ?? '',
          ),
        ),
      );
      return true;
    } catch (e) {
      _update(_state.copyWith(error: e.toString()));
      return false;
    }
  }

  Future<bool> transitionGroup(int targetGroupId) async {
    try {
      final res = await repository.transitionGroup(attemptId, targetGroupId);
      _update(
        _state.copyWith(
          activeGroupId:
              (res['activeGroupId'] as num?)?.toInt() ?? targetGroupId,
          phaseDeadlineAt: DateTime.tryParse(
            (res['phaseDeadlineAt'] as String?) ?? '',
          ),
        ),
      );
      return true;
    } catch (e) {
      _update(_state.copyWith(error: e.toString()));
      return false;
    }
  }

  Future<void> startAudioReview() async {
    if (_state.isAudioReviewActive) return;
    try {
      final res = await repository.startAudioReview(attemptId);
      final remaining = (res['remainingSeconds'] as num?)?.toInt() ?? 120;
      _audioReviewTimer?.cancel();
      _update(
        _state.copyWith(
          isAudioReviewActive: true,
          audioReviewRemainingSeconds: remaining > 0 ? remaining : 120,
        ),
      );
      _audioReviewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_disposed || !_state.isAudioReviewActive) {
          timer.cancel();
          return;
        }
        if (_state.audioReviewRemainingSeconds > 1) {
          _update(
            _state.copyWith(
              audioReviewRemainingSeconds:
                  _state.audioReviewRemainingSeconds - 1,
            ),
          );
        } else {
          timer.cancel();
          _update(
            _state.copyWith(
              isAudioReviewActive: false,
              audioReviewRemainingSeconds: 0,
            ),
          );
        }
      });
    } catch (e) {
      _update(_state.copyWith(error: e.toString()));
    }
  }

  Future<bool> saveSpeakingRecording(
    int questionId,
    String filePath,
    int durationMs,
  ) async {
    _update(_state.copyWith(autosaveStatus: AutosaveStatus.saving));
    try {
      await repository.uploadSpeakingAudio(
        attemptId,
        questionId,
        filePath,
        durationMs: durationMs,
      );
      final idx = _state.questions.indexWhere((q) => q.questionId == questionId);
      final q = idx != -1 ? _state.questions[idx] : null;
      await repository.saveAttemptAnswer(
        attemptId,
        questionId,
        selectedOptionId: null,
        isFlagged: q?.isFlagged ?? false,
        responseText: q?.responseText,
      );
      final nextUploaded = Set<int>.from(_state.uploadedAudioQuestionIds)
        ..add(questionId);
      _update(
        _state.copyWith(
          autosaveStatus: AutosaveStatus.saved,
          uploadedAudioQuestionIds: nextUploaded,
        ),
      );
      return true;
    } catch (e) {
      _update(
        _state.copyWith(
          autosaveStatus: AutosaveStatus.failed,
          error: e.toString(),
        ),
      );
      return false;
    }
  }

  void selectMcqOption(int optionId) {
    final q = _state.currentQuestion;
    if (q == null) return;
    final updated = q.copyWith(selectedOptionId: optionId);
    _replaceQuestion(updated);
    _scheduleAnswerSave(updated);
  }

  void toggleFlag() {
    final q = _state.currentQuestion;
    if (q == null) return;
    final updated = q.copyWith(isFlagged: !q.isFlagged);
    _replaceQuestion(updated);
    _scheduleAnswerSave(updated);
  }

  void updateWritingDraft(String text) {
    final q = _state.currentQuestion;
    if (q == null) return;
    final updated = q.copyWith(responseText: text);
    _replaceQuestion(updated);
    _scheduleDraftSave(updated);
  }

  void _replaceQuestion(PlacementQuestion updated) {
    final nextList = List<PlacementQuestion>.from(_state.questions);
    final idx = nextList.indexWhere((e) => e.questionId == updated.questionId);
    if (idx != -1) {
      nextList[idx] = updated;
      _update(_state.copyWith(questions: nextList));
    }
  }

  void _scheduleAnswerSave(PlacementQuestion q) {
    _debounceTimer?.cancel();
    _update(_state.copyWith(autosaveStatus: AutosaveStatus.saving));
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        await repository.saveAttemptAnswer(
          attemptId,
          q.questionId,
          selectedOptionId: q.selectedOptionId,
          isFlagged: q.isFlagged,
          responseText: q.responseText,
          selectedOptionIdsJson: q.selectedOptionIdsJson,
        );
        _update(_state.copyWith(autosaveStatus: AutosaveStatus.saved));
      } catch (_) {
        _update(_state.copyWith(autosaveStatus: AutosaveStatus.failed));
      }
    });
  }

  void _scheduleDraftSave(PlacementQuestion q) {
    _debounceTimer?.cancel();
    _update(_state.copyWith(autosaveStatus: AutosaveStatus.saving));
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        await repository.saveAttemptDraft(
          attemptId,
          questionId: q.questionId,
          responseText: q.responseText,
        );
        _update(_state.copyWith(autosaveStatus: AutosaveStatus.saved));
      } catch (_) {
        _update(_state.copyWith(autosaveStatus: AutosaveStatus.failed));
      }
    });
  }

  Future<void> syncNow() async {
    _update(_state.copyWith(autosaveStatus: AutosaveStatus.saving));
    try {
      await repository.syncSitting(
        attemptId,
        lastQuestionId: _state.currentQuestion?.questionId,
      );
      _update(_state.copyWith(autosaveStatus: AutosaveStatus.saved));
    } catch (_) {
      _update(_state.copyWith(autosaveStatus: AutosaveStatus.failed));
    }
  }

  Future<bool> submit() async {
    if (_state.isSubmitting || _state.isCompleted) return false;
    _debounceTimer?.cancel();
    _update(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final drafts = _state.questions
          .where((q) => q.responseText != null && q.responseText!.isNotEmpty)
          .map((q) => {
                'questionId': q.questionId,
                'responseText': q.responseText,
              })
          .toList();
      if (drafts.isNotEmpty) {
        await repository.submitAttemptWithDrafts(attemptId, drafts);
      } else {
        await repository.submitAttempt(attemptId);
      }
      _countdownTimer?.cancel();
      _update(_state.copyWith(isSubmitting: false, isCompleted: true));
      onSubmitted?.call();
      return true;
    } catch (e) {
      _update(_state.copyWith(isSubmitting: false, error: e.toString()));
      return false;
    }
  }

  /// The deliberate CANCEL action. Its failure is reported — cancelling is a
  /// transaction — but leaving the room is the screen's job and never waits for
  /// this answer, because a graded or expired attempt refuses cancellation.
  Future<bool> cancel() async {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    try {
      await repository.cancelAttempt(attemptId);
      return true;
    } catch (e) {
      if (_disposed) return false;
      _update(_state.copyWith(error: e.toString()));
      return false;
    }
  }

  void _update(MockExamState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _audioReviewTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
