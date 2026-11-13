import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/wallet/mentor_models.dart';

import '../contract/fixture_loader.dart';

/// Recorded-payload suite for the mentors directory, mentor detail and slots.
/// Every assertion checks a **non-default** value: a wrong key yields a valid
/// object holding `0`, `''` or `[]`, which is exactly how the directory showed
/// blank names, 0 credits and no slots.
void main() {
  group('GET /api/mentors', () {
    late List<MentorProfile> mentors;

    setUpAll(() {
      mentors = (loadFixture('mentors') as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(MentorProfile.fromJson)
          .toList();
    });

    test('every row reads a non-zero id, session length and credit price', () {
      expect(mentors, hasLength(2));
      expect(mentors.map((m) => m.id), everyElement(isPositive));
      expect(mentors.map((m) => m.sessionMinutes), everyElement(isPositive));
      expect(mentors.map((m) => m.priceCredits), everyElement(isPositive));
    });

    test('the human mentor reads displayName, sessionMinutes, avgRating', () {
      final human = mentors.firstWhere((m) => m.id == 1);

      expect(human.displayName, 'Dr. Trần Minh Khoa');
      expect(human.sessionMinutes, 60);
      expect(human.priceCredits, 1);
      expect(human.avgRating, 5.0);
      expect(human.reviewCount, 1);
      expect(human.isAi, isFalse);
      expect(human.headline, isNotEmpty);
    });

    test('the AI mentor is typed ai and has no rating', () {
      final ai = mentors.firstWhere((m) => m.id == 2);

      expect(ai.displayName, 'AI Mentor — TOEIC Coach');
      expect(ai.isAi, isTrue);
      expect(ai.avgRating, isNull);
      expect(ai.reviewCount, 0);
      expect(ai.priceCredits, 1);
    });

    test('avgRating renders to one decimal place, not six', () {
      final human = mentors.firstWhere((m) => m.id == 1);

      expect(human.summaryLabel, '60 MIN · 1 CREDITS · ★ 5.0');
    });
  });

  group('GET /api/mentors/{id} - the detail envelope', () {
    late MentorDetail detail;

    setUpAll(() {
      detail = MentorDetail.fromJson(
        loadFixture('mentor_detail') as Map<String, dynamic>,
      );
    });

    test('the mentor id is the opened mentor, never 0', () {
      // 0 is what the flat parser produced from the envelope, which made the
      // booking POST to /api/mentors/0/book.
      expect(detail.mentor.id, 1);
      expect(detail.mentor.displayName, 'Dr. Trần Minh Khoa');
    });

    test('the credit cost is the mentor price, never 0', () {
      expect(detail.mentor.priceCredits, 1);
      expect(detail.mentor.sessionMinutes, 60);
    });

    test('availableSlots lists the real bookable times', () {
      expect(detail.availableSlots, hasLength(2));
      expect(
        detail.availableSlots.map((s) => s.id),
        containsAll(<int>[3, 4]),
      );
      final slot = detail.availableSlots.first;
      expect(slot.mentorId, 1);
      expect(slot.status, 'open');
      expect(slot.isOpen, isTrue);
      expect(slot.startAt.isBefore(slot.endAt), isTrue);
    });

    test('slot times render in local time with both bounds', () {
      final label = describeSlotTime(detail.availableSlots.first);

      expect(label, matches(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}-\d{2}:\d{2}$'));
    });

    test('reviews read rating, text and the reviewer', () {
      expect(detail.reviews, hasLength(1));
      final review = detail.reviews.single;
      expect(review.id, 1);
      expect(review.rating, 5);
      expect(review.text, contains('listening strategies'));
      expect(review.userDisplayName, 'Demo Learner');
    });
  });

  group('GET /api/mentors/{id} for an AI mentor', () {
    test('an AI mentor has no slots and books without one', () {
      final detail = MentorDetail.fromJson(
        loadFixture('mentor_detail_ai') as Map<String, dynamic>,
      );

      expect(detail.mentor.id, 2);
      expect(detail.mentor.isAi, isTrue);
      expect(detail.mentor.priceCredits, 1);
      expect(detail.availableSlots, isEmpty);
      expect(detail.reviews, isEmpty);
    });
  });

  group('GET /api/mentors/bookings', () {
    late List<MentorBooking> bookings;

    setUpAll(() {
      bookings = (loadFixture('mentor_bookings') as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(MentorBooking.fromJson)
          .toList();
    });

    test('every booking reads a distinct non-zero id and mentor', () {
      expect(bookings, hasLength(2));
      expect(bookings.map((b) => b.id).toSet(), hasLength(2));
      expect(bookings.map((b) => b.id), everyElement(isPositive));
      expect(bookings.map((b) => b.mentorId), everyElement(isPositive));
    });

    test('the finished booking is done and carries its review', () {
      final done = bookings.firstWhere((b) => b.id == 1);

      expect(done.status, 'done');
      expect(done.rating, 5);
      expect(done.reviewText, contains('listening strategies'));
      // The review is the nested object, not flat rating/reviewText keys.
      expect(done.review, isNotNull);
      expect(done.review!.id, 1);
      expect(done.review!.userDisplayName, 'Demo Learner');
      // A finished session carries no meeting link.
      expect(done.meetLink, isNull);
      // Already rated, so RATE SESSION must not be offered again.
      expect(done.canRate, isFalse);
      // Nor is a link offered to a room that has ended.
      expect(done.canJoinMeet, isFalse);
    });

    test('the confirmed booking carries its meet link and slot time', () {
      final confirmed = bookings.firstWhere((b) => b.id == 2);

      expect(confirmed.status, 'confirmed');
      expect(confirmed.canCancel, isTrue);
      expect(confirmed.canRate, isFalse);
      expect(confirmed.meetLink, startsWith('https://meet.google.com/'));
      expect(confirmed.canJoinMeet, isTrue);
      expect(confirmed.slotStartsAt, isNotNull);
      expect(confirmed.priceCredits, 1);
    });

    test('a finished but unrated booking is ratable', () {
      // `done` is the finished status, and the backend never emits
      // `completed` - reading the wrong string made rating unreachable.
      final unratedJson =
          Map<String, dynamic>.from(
            (loadFixture('mentor_bookings') as List<dynamic>)[0]
                as Map<String, dynamic>,
          )
            ..['status'] = 'done'
            ..['review'] = null
            ..['meetLink'] = null;
      final unrated = MentorBooking.fromJson(unratedJson);

      expect(unrated.canRate, isTrue);
      expect(unrated.rating, isNull);
      expect(unrated.review, isNull);
      expect(unrated.canJoinMeet, isFalse);
    });
  });

  group('POST /api/mentors/bookings/{id}/cancel', () {
    test('the refund the backend decided is read, not assumed', () {
      final result = CancelBookingResult.fromJson(
        loadFixture('mentor_cancel_result') as Map<String, dynamic>,
      );

      expect(result.bookingId, 3);
      expect(result.status, 'cancelled');
      expect(result.refundedCredits, 1);
      expect(result.cancelledAt, isNotNull);
    });
  });

  group('POST /api/mentors/bookings/{id}/rate', () {
    test('the response is a review, not a booking', () {
      final review = MentorReview.fromJson(
        (loadFixture('mentor_bookings') as List<dynamic>)[1]['review']
            as Map<String, dynamic>,
      );

      expect(review.id, 1);
      expect(review.rating, 5);
      expect(review.text, contains('listening strategies'));
    });
  });
}
