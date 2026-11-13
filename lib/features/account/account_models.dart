import '../wallet/wallet_models.dart';

/// Learner personal profile returned by `GET /api/profile` and `PUT /api/profile`.
class LearnerProfile {
  const LearnerProfile({
    required this.userId,
    required this.email,
    required this.fullName,
    this.phone,
    required this.timeZoneId,
    required this.emailVerified,
  });

  final int userId;
  final String email;
  final String fullName;
  final String? phone;
  final String timeZoneId;
  final bool emailVerified;

  factory LearnerProfile.fromJson(Map<String, dynamic> json) {
    return LearnerProfile(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String?,
      timeZoneId: json['timeZoneId'] as String? ?? 'UTC',
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }
}

/// Subject categories eligible for a learner Complaint.
enum ComplaintSubjectCategory {
  booking('BOOKING'),
  attempt('ATTEMPT'),
  order('ORDER');

  const ComplaintSubjectCategory(this.label);
  final String label;
}

/// Server-defined `ComplaintStatusDto` values.
enum ComplaintStatus {
  open('OPEN'),
  reviewing('REVIEWING'),
  resolved('RESOLVED');

  const ComplaintStatus(this.label);
  final String label;

  static ComplaintStatus fromJson(String? raw) {
    return switch (raw?.toLowerCase()) {
      'reviewing' => ComplaintStatus.reviewing,
      'resolved' => ComplaintStatus.resolved,
      _ => ComplaintStatus.open,
    };
  }
}

/// Server-defined `ComplaintTypeDto` values, each bound to one subject category.
enum ComplaintType {
  mentorNoShow(
    apiValue: 'mentor_no_show',
    label: 'Mentor No-Show',
    category: ComplaintSubjectCategory.booking,
  ),
  mentorQuality(
    apiValue: 'mentor_quality',
    label: 'Mentor Quality',
    category: ComplaintSubjectCategory.booking,
  ),
  gradingIssue(
    apiValue: 'grading_issue',
    label: 'Grading Issue',
    category: ComplaintSubjectCategory.attempt,
  ),
  technicalError(
    apiValue: 'technical_error',
    label: 'Technical Error',
    category: ComplaintSubjectCategory.attempt,
  ),
  paymentIssue(
    apiValue: 'payment_issue',
    label: 'Payment Issue',
    category: ComplaintSubjectCategory.order,
  );

  const ComplaintType({
    required this.apiValue,
    required this.label,
    required this.category,
  });

  final String apiValue;
  final String label;
  final ComplaintSubjectCategory category;

  static List<ComplaintType> forCategory(ComplaintSubjectCategory category) {
    return ComplaintType.values
        .where((t) => t.category == category)
        .toList(growable: false);
  }

  static ComplaintType fromJson(String? raw) {
    for (final t in ComplaintType.values) {
      if (t.apiValue == raw) return t;
    }
    return ComplaintType.technicalError;
  }
}

/// Submitted learner Complaint returned by `GET /api/learner/complaints`.
///
/// Wire DTO: `LearnerComplaintDto` — the identifier arrives as `complaintId`.
class Complaint {
  const Complaint({
    required this.id,
    required this.type,
    required this.status,
    required this.reason,
    required this.subjectSummary,
    this.bookingId,
    this.attemptId,
    this.orderId,
    this.createdAt,
    this.resolvedAt,
    this.resolution,
    this.grantedCredits = 0,
  });

  final int id;
  final ComplaintType type;
  final ComplaintStatus status;
  final String reason;
  final String subjectSummary;
  final int? bookingId;
  final int? attemptId;
  final int? orderId;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolution;
  final int grantedCredits;

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final bookingId = (json['bookingId'] as num?)?.toInt();
    final attemptId = (json['attemptId'] as num?)?.toInt();
    final orderId = (json['orderId'] as num?)?.toInt();
    final rawSummary =
        json['subjectSummary'] as String? ?? json['subjectLabel'] as String?;

    final fallbackSummary = bookingId != null
        ? 'Booking #$bookingId'
        : attemptId != null
            ? 'Attempt #$attemptId'
            : orderId != null
                ? 'Order #$orderId'
                : 'Complaint #${json['complaintId'] ?? ''}';

    return Complaint(
      id: (json['complaintId'] as num?)?.toInt() ?? 0,
      type: ComplaintType.fromJson(json['type'] as String?),
      status: ComplaintStatus.fromJson(json['status'] as String?),
      reason: json['reason'] as String? ?? '',
      subjectSummary: (rawSummary != null && rawSummary.isNotEmpty)
          ? rawSummary
          : fallbackSummary,
      bookingId: bookingId,
      attemptId: attemptId,
      orderId: orderId,
      createdAt: _parseDate(json['createdAt']),
      resolvedAt: _parseDate(json['resolvedAt']),
      resolution: json['resolution'] as String?,
      grantedCredits: (json['grantedCredits'] as num?)?.toInt() ?? 0,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// An owned Booking, Attempt, or Order eligible for filing a Complaint.
///
/// Wire DTO: `EligibleSubjectsDto` groups them as `bookings` / `attempts` /
/// `orders`. Each group names its own identifier (`bookingId`, `attemptId`,
/// `orderId`) and its own descriptive fields, so the summary and subtitle are
/// derived per category rather than read from a shared `summary` key.
class EligibleSubject {
  const EligibleSubject({
    required this.category,
    required this.id,
    required this.summary,
    this.subtitle,
  });

  final ComplaintSubjectCategory category;
  final int id;
  final String summary;
  final String? subtitle;

  Map<String, dynamic> toReferencePayload() => switch (category) {
        ComplaintSubjectCategory.booking => {'bookingId': id},
        ComplaintSubjectCategory.attempt => {'attemptId': id},
        ComplaintSubjectCategory.order => {'orderId': id},
      };

  static List<EligibleSubject> parseResponse(dynamic data) {
    if (data is! Map<String, dynamic>) return const [];
    final result = <EligibleSubject>[];
    _addGroup(result, data['bookings'], ComplaintSubjectCategory.booking);
    _addGroup(result, data['attempts'], ComplaintSubjectCategory.attempt);
    _addGroup(result, data['orders'], ComplaintSubjectCategory.order);
    return result;
  }

  static void _addGroup(
    List<EligibleSubject> out,
    dynamic raw,
    ComplaintSubjectCategory category,
  ) {
    if (raw is! List<dynamic>) return;
    for (final item in raw.whereType<Map<String, dynamic>>()) {
      final idKey = switch (category) {
        ComplaintSubjectCategory.booking => 'bookingId',
        ComplaintSubjectCategory.attempt => 'attemptId',
        ComplaintSubjectCategory.order => 'orderId',
      };
      final id = (item[idKey] as num?)?.toInt() ?? 0;
      out.add(
        switch (category) {
          ComplaintSubjectCategory.booking => EligibleSubject(
              category: category,
              id: id,
              summary: item['mentorName'] as String? ?? 'Booking #$id',
              subtitle: _describeDate(item['scheduledAt']),
            ),
          ComplaintSubjectCategory.attempt => EligibleSubject(
              category: category,
              id: id,
              summary: item['examTitle'] as String? ?? 'Attempt #$id',
              subtitle: _describeDate(item['startedAt']),
            ),
          ComplaintSubjectCategory.order => EligibleSubject(
              category: category,
              id: id,
              summary: [
                item['orderCode'] as String? ?? 'Order #$id',
                item['packageName'] as String?,
              ].nonNulls.join(' · '),
              subtitle: [
                if (item['amount'] is num)
                  formatVnd((item['amount'] as num).toInt()),
                _describeDate(item['createdAt']),
              ].nonNulls.join(' · '),
            ),
        },
      );
    }
  }
}

/// Renders a wire timestamp as a compact `YYYY-MM-DD HH:mm UTC` stamp.
String? _describeDate(dynamic value) {
  final parsed = _parseDate(value);
  if (parsed == null) return null;
  final utc = parsed.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)} UTC';
}

