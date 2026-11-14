import 'package:dio/dio.dart';

import 'mentor_models.dart';

/// Repository for the mentors directory, mentor detail, and booking.
class MentorRepository {
  MentorRepository(this._dio);

  final Dio _dio;

  /// `GET /api/mentors` - a bare `MentorSummaryDto[]`.
  Future<List<MentorProfile>> getMentors({
    String? certCode,
    String? skill,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/mentors',
      queryParameters: {
        'certCode': ?certCode,
        'skill': ?skill,
      },
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MentorProfile.fromJson)
        .toList(growable: false);
  }

  /// `GET /api/mentors/{id}` - a `MentorDetailDto` envelope.
  Future<MentorDetail> getMentorDetail(int mentorId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/mentors/$mentorId',
    );
    return MentorDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// `POST /api/mentors/{id}/book`. AI mentors take no slot.
  Future<MentorBooking> bookMentor(
    int mentorId, {
    int? slotId,
    String? focusArea,
    int? examId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/mentors/$mentorId/book',
      data: {
        'slotId': slotId,
        'focusArea': focusArea,
        'examId': examId,
      },
    );
    return MentorBooking.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// `GET /api/mentors/bookings` - a bare `MentorBookingDto[]`.
  Future<List<MentorBooking>> getBookings() async {
    final response = await _dio.get<List<dynamic>>('/api/mentors/bookings');
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MentorBooking.fromJson)
        .toList(growable: false);
  }

  Future<MentorBooking> getBooking(int bookingId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/mentors/bookings/$bookingId',
    );
    return MentorBooking.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// `POST .../cancel` - returns the refund the backend decided.
  Future<CancelBookingResult> cancelBooking(int bookingId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/mentors/bookings/$bookingId/cancel',
    );
    return CancelBookingResult.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  /// `POST .../rate` - answers a `MentorReviewDto`, not the booking.
  Future<MentorReview> rateBooking(
    int bookingId, {
    required int rating,
    String? text,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/mentors/bookings/$bookingId/rate',
      data: {
        'rating': rating,
        'text': text,
      },
    );
    return MentorReview.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}
