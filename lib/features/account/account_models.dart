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
                : 'Complaint #${json['id'] ?? ''}';

    return Complaint(
      id: (json['id'] as num?)?.toInt() ?? 0,
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
    final result = <EligibleSubject>[];
    if (data is Map<String, dynamic>) {
      _addGroup(result, data['bookings'], ComplaintSubjectCategory.booking);
      _addGroup(result, data['attempts'], ComplaintSubjectCategory.attempt);
      _addGroup(result, data['orders'], ComplaintSubjectCategory.order);
      if (data['items'] is List<dynamic>) {
        _addFlatList(result, data['items'] as List<dynamic>);
      }
    } else if (data is List<dynamic>) {
      _addFlatList(result, data);
    }
    return result;
  }

  static void _addGroup(
    List<EligibleSubject> out,
    dynamic raw,
    ComplaintSubjectCategory category,
  ) {
    if (raw is! List<dynamic>) return;
    for (final item in raw.whereType<Map<String, dynamic>>()) {
      final id = (item['id'] as num? ?? item['subjectId'] as num?)?.toInt() ?? 0;
      final summary = item['summary'] as String? ??
          item['label'] as String? ??
          item['title'] as String? ??
          '${category.label} #$id';
      final subtitle = item['subtitle'] as String? ?? item['date'] as String?;
      out.add(
        EligibleSubject(
          category: category,
          id: id,
          summary: summary,
          subtitle: subtitle,
        ),
      );
    }
  }

  static void _addFlatList(List<EligibleSubject> out, List<dynamic> items) {
    for (final item in items.whereType<Map<String, dynamic>>()) {
      final rawCat = (item['subjectType'] as String? ??
              item['category'] as String? ??
              item['type'] as String? ??
              '')
          .toLowerCase();
      final category = switch (rawCat) {
        'booking' => ComplaintSubjectCategory.booking,
        'order' => ComplaintSubjectCategory.order,
        _ => ComplaintSubjectCategory.attempt,
      };
      final id = (item['id'] as num? ?? item['subjectId'] as num?)?.toInt() ?? 0;
      final summary = item['summary'] as String? ??
          item['label'] as String? ??
          item['title'] as String? ??
          '${category.label} #$id';
      final subtitle = item['subtitle'] as String? ?? item['date'] as String?;
      out.add(
        EligibleSubject(
          category: category,
          id: id,
          summary: summary,
          subtitle: subtitle,
        ),
      );
    }
  }
}
