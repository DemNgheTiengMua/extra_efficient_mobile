import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'helpers/fake_http_adapter.dart';

void main() {
  testWidgets('ExtraEfficientApp boots to Sign-in when unauthenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          httpClientAdapterProvider.overrideWithValue(
            FakeHttpClientAdapter(
              (_, _) async => FakeHttpClientAdapter.jsonResponse({}),
            ),
          ),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LEARNER SIGN IN'), findsOneWidget);
  });
}
