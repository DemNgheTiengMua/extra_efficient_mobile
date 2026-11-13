/// The device-check status shared by both sitting doors.
///
/// One DTO serves `GET /api/learner/attempts/{id}/preflight` and
/// `GET /api/learner/placement/take/{id}/preflight`
/// (`Contracts/Attempts/PreflightStatusDto.cs`). The sitting itself answers
/// 400 `preflight_required` until `POST .../preflight/verify` has succeeded, so
/// every door must read this first.
library;

class PreflightStatus {
  const PreflightStatus({
    required this.attemptId,
    required this.examId,
    required this.examName,
    required this.certName,
    required this.durationMinutes,
    required this.requiresPreflight,
    required this.requiresAudio,
    required this.requiresMicrophone,
    required this.isVerified,
    required this.audioUrls,
    this.verifiedAt,
  });

  factory PreflightStatus.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['audioUrls'] as List<dynamic>? ?? const [];
    return PreflightStatus(
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      examId: (json['examId'] as num?)?.toInt() ?? 0,
      examName: (json['examName'] as String?) ?? '',
      certName: (json['certName'] as String?) ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      requiresPreflight: (json['requiresPreflight'] as bool?) ?? false,
      requiresAudio: (json['requiresAudio'] as bool?) ?? false,
      requiresMicrophone: (json['requiresMicrophone'] as bool?) ?? false,
      isVerified: (json['isVerified'] as bool?) ?? false,
      verifiedAt: DateTime.tryParse((json['verifiedAt'] as String?) ?? ''),
      audioUrls: rawUrls.whereType<String>().toList(),
    );
  }

  final int attemptId;
  final int examId;
  final String examName;
  final String certName;
  final int durationMinutes;
  final bool requiresPreflight;
  final bool requiresAudio;
  final bool requiresMicrophone;
  final bool isVerified;
  final DateTime? verifiedAt;

  /// Root-relative app paths. They 404 on the current backend (pitfall d), so a
  /// missing sample must never block entry - the gate degrades to a UI-only
  /// confirmation instead.
  final List<String> audioUrls;

  /// The sample the gate tries first, or null when the backend supplied none.
  String? get audioSampleUrl => audioUrls.isEmpty ? null : audioUrls.first;

  /// Whether the learner has to pass device checks before the sitting opens.
  bool get needsChecks => !isVerified && (requiresAudio || requiresMicrophone);
}
