import 'package:dio/dio.dart';

/// The vocabulary of a room that cannot be opened, shared by both doors.

/// A sitting the backend will not serve, with the learner's way out.
///
/// Every terminal state carries exactly one action, and it is a navigation that
/// does not depend on another backend call.
class ExamRoomStop {
  const ExamRoomStop({
    required this.stamp,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionRoute,
  });

  final String stamp;
  final String title;
  final String description;
  final String actionLabel;
  final String actionRoute;
}

/// Classifies a loaded sitting: `null` means the room may open.
///
/// [status] is the backend's own lowercase word (`in_progress`, `done`,
/// `submitted`, `graded`, `abandoned`). Anything that is not `in_progress` is
/// over, and an in-progress sitting with no questions is a dead room.
///
/// Expiry is deliberately **not** decided here. The backend owns the clock: it
/// auto-submits a sitting whose deadline passed, and answers `attempt_expired` /
/// `placement_expired` itself. A local `now > expiresAt` guess would only race
/// the server and turn a live sitting into a false terminal state.
ExamRoomStop? stopForSitting({
  required String status,
  required int questionCount,
  required String resultRoute,
  required String hubRoute,
}) {
  if (status == 'abandoned') {
    return ExamRoomStop(
      stamp: 'ABANDONED',
      title: 'This sitting was abandoned',
      description: 'It was cancelled earlier, so there is nothing left to '
          'answer. Any completed sitting appears in your history.',
      actionLabel: 'BACK TO EXAMS',
      actionRoute: hubRoute,
    );
  }
  if (status != 'in_progress') {
    return ExamRoomStop(
      stamp: 'FINISHED',
      title: 'This sitting is over',
      description: 'It was submitted or graded, so it can no longer be '
          'answered. Your score is on the result placard.',
      actionLabel: 'VIEW RESULT',
      actionRoute: resultRoute,
    );
  }
  if (questionCount == 0) {
    return ExamRoomStop(
      stamp: 'EMPTY',
      title: 'This sitting has no questions',
      description: 'The paper came back empty, so there is nothing to answer. '
          'Nothing was lost — this attempt never had questions to show.',
      actionLabel: 'BACK TO EXAMS',
      actionRoute: hubRoute,
    );
  }
  return null;
}

/// The backend's `code` on a failed request, lowercased (the emitters disagree
/// on casing), or null when the failure carried no code.
String? apiErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code'] is String) {
      return (data['code'] as String).toLowerCase();
    }
  }
  return null;
}

const _sittingOverCodes = {
  'placement_not_active',
  'placement_expired',
  'placement_abandoned',
  'attempt_expired',
  'attempt_not_active',
};

const _sittingMissingCodes = {'placement_not_found', 'attempt_not_found'};

/// The sitting answered 400 `preflight_required`: the device gate must pass.
bool isPreflightRequired(Object error) =>
    apiErrorCode(error) == 'preflight_required';

/// The sitting is graded, expired or abandoned - a normal end, not a failure.
bool isSittingOver(Object error) =>
    _sittingOverCodes.contains(apiErrorCode(error));

bool isSittingMissing(Object error) =>
    _sittingMissingCodes.contains(apiErrorCode(error));
