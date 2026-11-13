// Models for Mentors, Mentor Slots, and Mentor Bookings.

int _readInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

int? _readNullableInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _readNullableDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }
  return fallback;
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }
  return null;
}

class MentorSlot {
  const MentorSlot({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.isAvailable,
  });

  factory MentorSlot.fromJson(Map<String, dynamic> json) {
    final available = json['isAvailable'] ??
        (json['isBooked'] != null ? !(json['isBooked'] as bool) : true);
    return MentorSlot(
      id: _readInt(json, ['id', 'slotId']),
      startsAt: _readString(json, ['startsAt', 'startTime']),
      endsAt: _readString(json, ['endsAt', 'endTime']),
      isAvailable: available == true,
    );
  }

  final int id;
  final String startsAt;
  final String endsAt;
  final bool isAvailable;
}

class MentorProfile {
  const MentorProfile({
    required this.id,
    required this.name,
    required this.headline,
    required this.expertise,
    required this.sessionLengthMinutes,
    required this.priceCredits,
    required this.isAi,
    this.averageRating,
    this.slots = const [],
  });

  factory MentorProfile.fromJson(Map<String, dynamic> json) {
    final typeStr = _readNullableString(json, ['mentorType', 'type']);
    final isAi = (json['isAi'] == true) ||
        (typeStr?.toLowerCase() == 'ai');
    final slotsList = json['slots'] as List<dynamic>?;

    return MentorProfile(
      id: _readInt(json, ['id', 'mentorId']),
      name: _readString(json, ['name', 'fullName'], fallback: 'Mentor'),
      headline: _readString(json, ['headline', 'bio']),
      expertise: _readString(json, ['expertise', 'skills']),
      sessionLengthMinutes: _readInt(
        json,
        ['sessionLengthMinutes', 'durationMinutes'],
        fallback: 30,
      ),
      priceCredits: _readInt(json, ['priceCredits', 'credits']),
      isAi: isAi,
      averageRating: _readNullableDouble(json, ['averageRating', 'rating']),
      slots: slotsList == null
          ? const []
          : slotsList
              .whereType<Map<String, dynamic>>()
              .map(MentorSlot.fromJson)
              .toList(growable: false),
    );
  }

  final int id;
  final String name;
  final String headline;
  final String expertise;
  final int sessionLengthMinutes;
  final int priceCredits;
  final bool isAi;
  final double? averageRating;
  final List<MentorSlot> slots;
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
    final typeStr = _readNullableString(json, ['mentorType', 'type']);
    final isAi = (json['isAi'] == true) ||
        (typeStr?.toLowerCase() == 'ai');
    return MentorBooking(
      id: _readInt(json, ['id', 'bookingId']),
      mentorId: _readInt(json, ['mentorId']),
      mentorName: _readString(json, ['mentorName'], fallback: 'Mentor'),
      isAi: isAi,
      status: _readString(json, ['status'], fallback: 'confirmed').toLowerCase(),
      priceCredits: _readInt(json, ['priceCredits', 'credits']),
      focusArea: _readNullableString(json, ['focusArea']),
      slotStartsAt: _readNullableString(json, ['slotStartsAt', 'startsAt']),
      meetLink: _readNullableString(
        json,
        ['meetLink', 'googleMeetUrl', 'meetingUrl'],
      ),
      rating: _readNullableInt(json, ['rating']),
      reviewText: _readNullableString(json, ['reviewText', 'text']),
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
  bool get canRate => status == 'completed' && rating == null;
}
