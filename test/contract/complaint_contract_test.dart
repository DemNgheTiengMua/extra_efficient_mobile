import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/account/account_models.dart';

import 'fixture_loader.dart';

/// Recorded-payload suite: every assertion parses real backend bytes and then
/// checks a **non-default** value. A wrong key yields a valid object holding
/// `0`, `''` or `[]`, so presence alone would pass the defect these guard.
void main() {
  group('GET /api/learner/complaints/eligible-subjects', () {
    late List<EligibleSubject> subjects;

    setUpAll(() {
      subjects = EligibleSubject.parseResponse(
        loadFixture('complaint_eligible_subjects'),
      );
    });

    test('parses every recorded subject with a real identifier', () {
      expect(subjects, hasLength(10));
      expect(subjects.map((s) => s.id), everyElement(isNonZero));
    });

    test('bookings read bookingId and derive mentorName + scheduledAt', () {
      final bookings =
          subjects.where((s) => s.category == ComplaintSubjectCategory.booking);
      expect(bookings, hasLength(2));

      final first = bookings.first;
      expect(first.id, 2);
      expect(first.summary, 'Dr. Trần Minh Khoa');
      expect(first.subtitle, contains('2026-11-12'));
      expect(first.toReferencePayload(), {'bookingId': 2});

      final second = bookings.last;
      expect(second.id, 1);
      expect(second.subtitle, contains('2026-11-05'));
      expect(second.toReferencePayload(), {'bookingId': 1});
    });

    test('attempts read attemptId and derive examTitle + startedAt', () {
      final attempts =
          subjects.where((s) => s.category == ComplaintSubjectCategory.attempt);
      expect(attempts, hasLength(5));

      final inProgress = attempts.firstWhere((s) => s.id == 1005);
      expect(inProgress.summary, 'ETS 2024 - Test 1');
      expect(inProgress.subtitle, contains('2026-11-13'));
      expect(inProgress.toReferencePayload(), {'attemptId': 1005});

      final placement = attempts.firstWhere((s) => s.id == 3);
      expect(placement.summary, 'TOEIC Placement Test - Diagnostic');
      expect(placement.toReferencePayload(), {'attemptId': 3});
    });

    test('orders read orderId and derive orderCode + packageName + amount', () {
      final orders =
          subjects.where((s) => s.category == ComplaintSubjectCategory.order);
      expect(orders, hasLength(3));

      final intensive = orders.firstWhere((s) => s.id == 1);
      expect(intensive.summary, contains('Intensive Pack'));
      expect(intensive.summary, contains('DH-20261014-0001'));
      expect(intensive.subtitle, contains('190,000'));
      expect(intensive.toReferencePayload(), {'orderId': 1});
    });

    test('two orders with different packages are visibly different', () {
      final byId = {
        for (final s in subjects.where(
          (s) => s.category == ComplaintSubjectCategory.order,
        ))
          s.id: s,
      };
      expect(byId[1]!.summary, isNot(byId[2]!.summary));
      expect(byId[1]!.subtitle, isNot(byId[2]!.subtitle));
    });

    test('every subject carries a distinct (category, id) pair', () {
      final keys = subjects.map((s) => '${s.category.name}:${s.id}').toList();
      expect(keys.toSet(), hasLength(keys.length));
    });
  });

  group('GET /api/learner/complaints', () {
    late List<Complaint> complaints;

    setUpAll(() {
      complaints = (loadFixture('learner_complaints') as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Complaint.fromJson)
          .toList();
    });

    test('reads complaintId rather than a generic id', () {
      expect(complaints.map((c) => c.id), [2, 1]);
    });

    test('reads type, status, reason and subject summary', () {
      final resolved = complaints.last;
      expect(resolved.id, 1);
      expect(resolved.type, ComplaintType.technicalError);
      expect(resolved.status, ComplaintStatus.resolved);
      expect(resolved.reason, contains('Audio stream froze'));
      expect(resolved.subjectSummary, 'Exam #2 (ETS 2024 - Test 1)');
      expect(resolved.attemptId, 2);
      expect(resolved.bookingId, isNull);
    });

    test('reads the credit make-good and resolution', () {
      final resolved = complaints.last;
      expect(resolved.grantedCredits, 1);
      expect(resolved.resolution, contains('make-good credit'));
      expect(resolved.resolvedAt, isNotNull);
    });

    test('two complaints carry distinct identifiers', () {
      expect(complaints[0].id, isNot(complaints[1].id));
      expect(complaints.map((c) => c.id), everyElement(isNonZero));
    });
  });
}

Matcher get isNonZero => predicate<num>((v) => v != 0, 'is non-zero');
