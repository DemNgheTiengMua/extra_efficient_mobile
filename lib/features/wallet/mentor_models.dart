// Models for the Mentors directory, mentor detail and bookings.
//
// Field names are the backend's own (`MentorSummaryDto`, `DetailDto`,
// `MentorSlotDto`, `MentorReviewDto`, `MentorBookingDto`), verified against
// the running API.

/// A mentor row (`MentorSummaryDto`). `type` is the plain string `human` or
/// `ai`; on an AI mentor `avgRating` is null with `reviewCount` 0.
class MentorProfile {
  const MentorProfile({
    required this.id,
    required this.displayName,
    required this.headline,
    required this.expertise,
    required this.sessionMinutes,
    required this.priceCredits,
    required this.type,
    required this.reviewCount,
    this.avgRating,
  });

  factory MentorProfile.fromJson(Map<String, dynamic> json) {
    return MentorProfile(
      id: (json['mentorId'] as num?)?.toInt() ?? 0,
      displayName: json['displayName'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      expertise: json['expertise'] as String? ?? '',
      sessionMinutes: (json['sessionMinutes'] as num?)?.toInt() ?? 0,
      priceCredits: (json['priceCredits'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'human',
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      avgRating: (json['avgRating'] as num?)?.toDouble(),
    );
  }

  final int id;
  final String displayName;
  final String headline;
  final String expertise;
  final int sessionMinutes;
  final int priceCredits;
  final String type;
  final int reviewCount;

  /// Null when no learner has rated this mentor yet.
  final double? avgRating;

  bool get isAi => type.toLowerCase() == 'ai';

  /// `60 MIN · 1 CREDITS · ★ 5.0`, omitting the rating when unrated.
  String get summaryLabel =>
      '$sessionMinutes MIN · $priceCredits CREDITS'
      '${avgRating != null ? ' · ★ ${avgRating!.toStringAsFixed(1)}' : ''}';
}

/// A bookable time (`MentorSlotDto`). Status vocabulary: `open`, `booked`,
/// `closed` - only `open` can be booked.
class MentorSlot {
  const MentorSlot({
    required this.id,
    required this.mentorId,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  factory MentorSlot.fromJson(Map<String, dynamic> json) {
    return MentorSlot(
      id: (json['slotId'] as num?)?.toInt() ?? 0,
      mentorId: (json['mentorId'] as num?)?.toInt() ?? 0,
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      status: json['status'] as String? ?? 'open',
    );
  }

  final int id;
  final int mentorId;
  final DateTime startAt;
  final DateTime endAt;
  final String status;

  bool get isOpen => status.toLowerCase() == 'open';
}

/// One learner's review of a mentor (`MentorReviewDto`).
class MentorReview {
  const MentorReview({
    required this.id,
    required this.rating,
    required this.userDisplayName,
    required this.createdAt,
    this.text,
  });

  factory MentorReview.fromJson(Map<String, dynamic> json) {
    return MentorReview(
      id: (json['reviewId'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      text: json['text'] as String?,
      userDisplayName: json['userDisplayName'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int id;
  final int rating;
  final String? text;
  final String userDisplayName;
  final DateTime createdAt;
}

/// The mentor detail envelope (`MentorDetailDto`): the mentor, the slots that
/// are actually bookable, and the most recent reviews.
class MentorDetail {
  const MentorDetail({
    required this.mentor,
    required this.availableSlots,
    required this.reviews,
  });

  factory MentorDetail.fromJson(Map<String, dynamic> json) {
    final mentorJson = json['mentor'];
    if (mentorJson is! Map<String, dynamic>) {
      // Fail loudly: an absent envelope member would otherwise render as a
      // mentor with id 0 and a price of 0 credits.
      throw const FormatException('Mentor detail is missing its "mentor"');
    }
    return MentorDetail(
      mentor: MentorProfile.fromJson(mentorJson),
      availableSlots: (json['availableSlots'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MentorSlot.fromJson)
          .toList(growable: false),
      reviews: (json['reviews'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MentorReview.fromJson)
          .toList(growable: false),
    );
  }

  final MentorProfile mentor;

  /// Only slots with status `open`; the backend filters them already.
  final List<MentorSlot> availableSlots;
  final List<MentorReview> reviews;
}

/// Renders a slot in the device's local time, e.g. `2026-11-14 08:44-09:44`.
String describeSlotTime(MentorSlot slot) {
  final start = slot.startAt.toLocal();
  final end = slot.endAt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${start.year}-${two(start.month)}-${two(start.day)}';
  return '$date ${two(start.hour)}:${two(start.minute)}-'
      '${two(end.hour)}:${two(end.minute)}';
}

class MentorBooking {
  const MentorBooking({
    required this.id,
    required this.mentorId,
    required this.mentorName,
    required this.isAi,
    required this.status,
    required this.priceCredits,
    this.focusArea,
    this.slotStartsAt,
    this.meetLink,
    this.rating,
    this.reviewText,
  });

  factory MentorBooking.fromJson(Map<String, dynamic> json) {
    final review = json['review'] as Map<String, dynamic>?;
    return MentorBooking(
      id: (json['bookingId'] as num?)?.toInt() ?? 0,
      mentorId: (json['mentorId'] as num?)?.toInt() ?? 0,
      mentorName: json['mentorName'] as String? ?? 'Mentor',
      isAi: (json['mentorType'] as String?)?.toLowerCase() == 'ai',
      status: (json['status'] as String? ?? 'confirmed').toLowerCase(),
      priceCredits: (json['priceCredits'] as num?)?.toInt() ?? 0,
      focusArea: json['focusArea'] as String?,
      slotStartsAt: json['startAt'] as String?,
      meetLink: json['meetLink'] as String?,
      rating: (review?['rating'] as num?)?.toInt(),
      reviewText: review?['text'] as String?,
    );
  }

  final int id;
  final int mentorId;
  final String mentorName;
  final bool isAi;
  final String status;
  final int priceCredits;
  final String? focusArea;
  final String? slotStartsAt;
  final String? meetLink;
  final int? rating;
  final String? reviewText;

  bool get canCancel => status == 'confirmed' || status == 'pending';

  /// The backend's finished status is `done`.
  bool get canRate => status == 'done' && rating == null;
}
