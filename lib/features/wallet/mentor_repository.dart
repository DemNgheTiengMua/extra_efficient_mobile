import 'package:dio/dio.dart';

import 'mentor_models.dart';

/// Repository for Mentors directory, booking, cancellation, and rating.
class MentorRepository {
  MentorRepository(this._dio);

  final Dio _dio;

  Future<List<MentorProfile>> getMentors({
    String? certCode,
    String? skill,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/mentors',
      queryParameters: {
        'certCode': ?certCode,
        'skill': ?skill,
      },
    );
    final data = response.data;
    final List<dynamic> list;
    if (data is List<dynamic>) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      list = (data['mentors'] ?? data['items'] ?? const <dynamic>[])
          as List<dynamic>;
    } else {
      list = const <dynamic>[];
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(MentorProfile.fromJson)
        .toList(growable: false);
  }

  Future<MentorProfile> getMentorDetail(int mentorId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/mentors/$mentorId');
    return MentorProfile.fromJson(response.data ?? const <String, dynamic>{});
  }

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
        'examId': ?examId,
      },
    );
    return MentorBooking.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<List<MentorBooking>> getBookings() async {
    final response = await _dio.get<dynamic>('/api/mentors/bookings');
    final data = response.data;
    final List<dynamic> list;
    if (data is List<dynamic>) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      list = (data['bookings'] ?? data['items'] ?? const <dynamic>[])
          as List<dynamic>;
    } else {
      list = const <dynamic>[];
    }
    return list
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

  Future<void> cancelBooking(int bookingId) async {
    await _dio.post<void>('/api/mentors/bookings/$bookingId/cancel');
  }

  Future<void> rateBooking(
    int bookingId, {
    required int rating,
    String? text,
  }) async {
    await _dio.post<void>(
      '/api/mentors/bookings/$bookingId/rate',
      data: {
        'rating': rating,
        'text': text,
      },
    );
  }
}
