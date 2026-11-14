import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/media/audio_media_adapter.dart';
import '../data/placement_repository.dart';
import '../models/exam_room_stop.dart';
import '../models/placement_models.dart';
import '../widgets/exam_room_helpers.dart';

enum AutosaveStatus { idle, saving, saved, failed }

class PlacementExamState {
  const PlacementExamState({
    this.isLoading = true,
    this.error,
    this.placementId = 0,
    this.expiresAt,
    this.remainingSeconds = 0,
    this.questions = const [],
    this.currentIndex = 0,
    this.autosaveStatus = AutosaveStatus.idle,
    this.isSubmitting = false,
    this.isCompleted = false,
    this.uploadedAudioQuestionIds = const <int>{},
    this.answeredCount = 0,
    this.stop,
    this.needsPreflight = false,
    this.audioError,
  });

  final bool isLoading;
  final String? error;

  /// Set when the current question's audio could not be loaded. The room stays
  /// usable: the learner can still answer, and can retry the audio.
  final String? audioError;
  final int placementId;
  final DateTime? expiresAt;
  final int remainingSeconds;
  final List<PlacementQuestion> questions;
  final int currentIndex;
  final AutosaveStatus autosaveStatus;
  final bool isSubmitting;
  final bool isCompleted;
  final Set<int> uploadedAudioQuestionIds;

  /// The server's count of answers it holds, for the resume banner.
  final int answeredCount;

  /// Set when the sitting cannot be opened at all; the room renders this and
  /// nothing else.
  final ExamRoomStop? stop;

  /// The backend refused the sitting with `preflight_required`, so this door is
  /// the wrong one and the device gate must run first.
  final bool needsPreflight;

  PlacementQuestion? get currentQuestion =>
      (currentIndex >= 0 && currentIndex < questions.length)
      ? questions[currentIndex]
      : null;

  PlacementExamState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? placementId,
    DateTime? expiresAt,
    int? remainingSeconds,
    List<PlacementQuestion>? questions,
    int? currentIndex,
    AutosaveStatus? autosaveStatus,
    bool? isSubmitting,
    bool? isCompleted,
    Set<int>? uploadedAudioQuestionIds,
    int? answeredCount,
    ExamRoomStop? stop,
    bool? needsPreflight,
    String? audioError,
    bool clearAudioError = false,
  }) {
    return PlacementExamState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      placementId: placementId ?? this.placementId,
      expiresAt: expiresAt ?? this.expiresAt,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      autosaveStatus: autosaveStatus ?? this.autosaveStatus,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCompleted: isCompleted ?? this.isCompleted,
      uploadedAudioQuestionIds:
          uploadedAudioQuestionIds ?? this.uploadedAudioQuestionIds,
      answeredCount: answeredCount ?? this.answeredCount,
      stop: stop ?? this.stop,
      needsPreflight: needsPreflight ?? this.needsPreflight,
      audioError: clearAudioError ? null : (audioError ?? this.audioError),
    );
  }
}

/// Controller for a single timed Placement Exam Room sitting.
class PlacementExamController extends ChangeNotifier {
  PlacementExamController({
    required this.placementId,
    required this.repository,
    required this.audioAdapter,
    this.onSubmitted,
  });

  final int placementId;
  final PlacementRepository repository;
  final AudioMediaAdapter audioAdapter;
  final VoidCallback? onSubmitted;

  PlacementExamState _state = const PlacementExamState();
  PlacementExamState get state => _state;

  Timer? _countdownTimer;
  Timer? _debounceTimer;
  bool _disposed = false;
  int? _loadedAudioQuestionId;

  Future<void> init() async {
    _update(_state.copyWith(isLoading: true, clearError: true));
    try {
      // The resume payload carries no questions by design. Questions always come
      // from the take endpoint, which is the authoritative view of the room -
      // and it is only readable once the device gate has been verified.
      final sitting = await repository.fetchSitting(placementId);

      final now = DateTime.now().toUtc();
      final remaining = sitting.expiresAt.toUtc().difference(now).inSeconds;
      final stop = stopForSitting(
        status: sitting.status,
        questionCount: sitting.questions.length,
        resultRoute: '/placement/result/$placementId',
        hubRoute: '/exams',
      );
      _update(
        _state.copyWith(
          isLoading: false,
          placementId: sitting.placementId,
          expiresAt: sitting.expiresAt,
          remainingSeconds: remaining > 0 ? remaining : 0,
          questions: sitting.questions,
          answeredCount: sitting.answeredCount,
          currentIndex: 0,
          stop: stop,
        ),
      );
      if (stop != null) return;
      _startCountdown();
      await _loadAudioForCurrentQuestion();
    } catch (e) {
      if (isPreflightRequired(e)) {
        // The door was the wrong one: the shared gate has to run first.
        _update(
          _state.copyWith(isLoading: false, needsPreflight: true),
        );
        return;
      }
      if (isSittingOver(e) || isSittingMissing(e)) {
        _update(
          _state.copyWith(
            isLoading: false,
            stop: terminalStopForError(
              e,
              resultRoute: '/placement/result/$placementId',
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
      final remaining = _state.expiresAt!
          .toUtc()
          .difference(DateTime.now().toUtc())
          .inSeconds;
      if (remaining <= 0) {
        _update(_state.copyWith(remainingSeconds: 0));
        _countdownTimer?.cancel();
        unawaited(submit(isAutoSubmit: true));
      } else {
        _update(_state.copyWith(remainingSeconds: remaining));
      }
    });
  }

  /// Preloads the current question's audio.
  ///
  /// A failure here must never abort the sitting: the question is still
  /// answerable, and on this stack a missing clip is far more likely than a
  /// broken exam. The room reports audio trouble separately and lets the learner
  /// retry, rather than replacing the whole room with an error.
  Future<void> _loadAudioForCurrentQuestion() async {
    final q = _state.currentQuestion;
    if (q == null || q.audioPath == null || q.audioPath!.isEmpty) {
      if (_loadedAudioQuestionId != null) {
        try {
          await audioAdapter.stop();
        } catch (_) {
          // Nothing to do: the clip is being replaced anyway.
        }
        _loadedAudioQuestionId = null;
      }
      return;
    }
    if (_loadedAudioQuestionId == q.questionId) return;
    _loadedAudioQuestionId = q.questionId;
    try {
      await audioAdapter.setAudioUrl(
        q.audioPath!,
        clipStart: q.audioStartMs != null
            ? Duration(milliseconds: q.audioStartMs!)
            : null,
        clipEnd: q.audioEndMs != null
            ? Duration(milliseconds: q.audioEndMs!)
            : null,
      );
      _update(_state.copyWith(clearAudioError: true));
    } catch (e) {
      // Keep the room usable and tell the learner the audio is unavailable.
      _update(_state.copyWith(audioError: describeAudioFailure(e)));
    }
  }

  Future<void> jumpToQuestion(int index) async {
    if (index < 0 || index >= _state.questions.length) return;
    _update(_state.copyWith(currentIndex: index));
    await _loadAudioForCurrentQuestion();
  }

  /// Re-attempts the current question's audio after a load failure.
  Future<void> retryAudio() async {
    _loadedAudioQuestionId = null;
    _update(_state.copyWith(clearAudioError: true));
    await _loadAudioForCurrentQuestion();
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
        await repository.saveAnswer(
          placementId,
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
        await repository.saveDraft(
          placementId,
          questionId: q.questionId,
          responseText: q.responseText ?? '',
        );
        _update(_state.copyWith(autosaveStatus: AutosaveStatus.saved));
      } catch (_) {
        _update(_state.copyWith(autosaveStatus: AutosaveStatus.failed));
      }
    });
  }

  Future<bool> saveSpeakingRecording(
    int questionId,
    String filePath,
    int durationMs,
  ) async {
    _update(_state.copyWith(autosaveStatus: AutosaveStatus.saving));
    try {
      await repository.uploadSpeakingAudio(
        placementId,
        questionId,
        filePath,
        durationMs: durationMs,
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

  Future<void> reportRecordingInterruption({
    required int questionId,
    required String sessionToken,
    required int capturedMs,
  }) async {
    await repository.reportRecordingInterruption(
      placementId,
      questionId: questionId,
      sessionToken: sessionToken,
      capturedMs: capturedMs,
    );
  }

  Future<bool> submit({bool isAutoSubmit = false}) async {
    if (_state.isSubmitting || _state.isCompleted) return false;
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    _update(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      await repository.submit(placementId, isAutoSubmit: isAutoSubmit);
      _update(_state.copyWith(isSubmitting: false, isCompleted: true));
      onSubmitted?.call();
      return true;
    } catch (e) {
      _update(_state.copyWith(isSubmitting: false, error: e.toString()));
      return false;
    }
  }

  /// The deliberate ABANDON action. Its failure is reported, but leaving the
  /// room is the screen's job and never waits on this answer.
  Future<bool> abandon() async {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    try {
      await repository.abandon(placementId);
      return true;
    } catch (e) {
      if (_disposed) return false;
      _update(_state.copyWith(error: e.toString()));
      return false;
    }
  }

  void _update(PlacementExamState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
