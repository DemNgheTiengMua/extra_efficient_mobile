import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../auth/auth_provider.dart';
import '../context/learner_context_provider.dart';
import 'account_models.dart';

/// Manages `GET /api/profile` and `PUT /api/profile`.
class ProfileNotifier extends AsyncNotifier<LearnerProfile?> {
  @override
  Future<LearnerProfile?> build() async {
    final authState = ref.watch(authNotifierProvider);
    if (!authState.isAuthenticated) {
      return null;
    }
    return _fetchProfile();
  }

  Future<LearnerProfile> _fetchProfile() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get<Map<String, dynamic>>('/api/profile');
    final data = response.data ?? const <String, dynamic>{};
    return LearnerProfile.fromJson(data);
  }

  Future<void> refreshProfile() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchProfile);
  }

  Future<LearnerProfile> updateProfile({
    required String fullName,
    String? phone,
    required String timeZoneId,
  }) async {
    final dio = ref.read(dioProvider);
    final trimmedPhone = phone?.trim();
    final response = await dio.put<Map<String, dynamic>>(
      '/api/profile',
      data: {
        'fullName': fullName.trim(),
        'phone': (trimmedPhone == null || trimmedPhone.isEmpty)
            ? null
            : trimmedPhone,
        'timeZoneId': timeZoneId.trim(),
      },
    );
    final data = response.data;
    final updated = data != null && data.isNotEmpty
        ? LearnerProfile.fromJson(data)
        : await _fetchProfile();
    state = AsyncData(updated);
    return updated;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final dio = ref.read(dioProvider);
    await dio.post<void>(
      '/api/profile/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, LearnerProfile?>(
  ProfileNotifier.new,
);

/// Manages `GET /api/learner/complaints` and `POST /api/learner/complaints`.
class ComplaintsNotifier extends AsyncNotifier<List<Complaint>> {
  @override
  Future<List<Complaint>> build() async {
    final authState = ref.watch(authNotifierProvider);
    if (!authState.isAuthenticated) {
      return const [];
    }
    return _fetchComplaints();
  }

  Future<List<Complaint>> _fetchComplaints() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get<dynamic>('/api/learner/complaints');
    final data = response.data;
    final List<dynamic> rawList;
    if (data is List<dynamic>) {
      rawList = data;
    } else if (data is Map<String, dynamic> && data['items'] is List<dynamic>) {
      rawList = data['items'] as List<dynamic>;
    } else {
      rawList = const [];
    }
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(Complaint.fromJson)
        .toList(growable: false);
  }

  Future<void> refreshComplaints() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchComplaints);
  }

  Future<void> fileComplaint({
    required ComplaintType type,
    required String reason,
    required EligibleSubject subject,
  }) async {
    final dio = ref.read(dioProvider);
    await dio.post<dynamic>(
      '/api/learner/complaints',
      data: {
        'type': type.apiValue,
        'reason': reason.trim(),
        ...subject.toReferencePayload(),
      },
    );
    await refreshComplaints();
    await ref.read(learnerContextProvider.notifier).refreshContext();
  }
}

final complaintsProvider =
    AsyncNotifierProvider<ComplaintsNotifier, List<Complaint>>(
  ComplaintsNotifier.new,
);

/// Fetches eligible owned subjects for filing a new Complaint.
final eligibleSubjectsProvider =
    FutureProvider.autoDispose<List<EligibleSubject>>((ref) async {
  final dio = ref.read(dioProvider);
  final response =
      await dio.get<dynamic>('/api/learner/complaints/eligible-subjects');
  return EligibleSubject.parseResponse(response.data);
});
