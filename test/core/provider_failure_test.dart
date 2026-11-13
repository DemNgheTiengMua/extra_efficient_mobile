import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/network/provider_retry.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/providers/mock_exam_providers.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import 'package:extra_efficient_mobile/widgets/signage_primitives.dart';

import '../helpers/fake_http_adapter.dart';

/// Riverpod 3 answers a failed provider with ten silent retries over ~38 s,
/// reporting every attempt as loading. These tests pin the app's opposite
/// stance: one attempt, then the error branch.
void main() {
  FakeHttpClientAdapter failingAdapter({void Function()? onRequest}) {
    return FakeHttpClientAdapter((options, body) async {
      onRequest?.call();
      return FakeHttpClientAdapter.jsonResponse(
        {
          'title': 'Exam error',
          'status': 500,
          'detail': 'The mock exam catalogue could not be read.',
          'code': 'UNEXPECTED',
        },
        statusCode: 500,
      );
    });
  }

  test('a failed read is attempted once and ends in an error, not a retry ladder',
      () async {
    final adapter = failingAdapter();
    final container = ProviderContainer.test(
      overrides: [
        httpClientAdapterProvider.overrideWithValue(adapter),
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      ],
    );
    container.listen(mockExamsProvider, (_, _) {});

    await expectLater(
      container.read(mockExamsProvider.future),
      throwsA(isA<DioException>()),
    );

    // One request: the default ladder would have issued a second 200 ms later.
    expect(adapter.requests, hasLength(1));
    expect(container.read(mockExamsProvider), isA<AsyncError<Object?>>());
  });

  test('the app-wide retry stance is disabled for every failure', () {
    expect(noProviderRetry(0, DioException(requestOptions: RequestOptions())),
        isNull);
    expect(noProviderRetry(9, StateError('boom')), isNull);
  });

  testWidgets('a failing screen load shows its error branch without waiting',
      (tester) async {
    final adapter = failingAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientAdapterProvider.overrideWithValue(adapter),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: false,
            scaffoldBackgroundColor: SignageColors.wall,
          ),
          builder: (context, child) => FTheme(
            data: buildSignageTheme(),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ref
                  .watch(mockExamsProvider)
                  .when(
                    loading: () => const Center(child: FCircularProgress()),
                    error: (err, _) => const StateBlock(
                      stamp: 'ERROR',
                      title: 'Could not load mock exams',
                      description: 'reached the error branch',
                    ),
                    data: (_) => const SizedBox.shrink(),
                  ),
            ),
          ),
        ),
      ),
    );

    // Two frames: the request fails, and the error branch is what renders.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('reached the error branch'), findsOneWidget);
    expect(find.byType(FCircularProgress), findsNothing);
    expect(adapter.requests, hasLength(1));
  });
}
