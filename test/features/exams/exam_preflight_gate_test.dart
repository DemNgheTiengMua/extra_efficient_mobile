import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/providers/exam_room_gate_providers.dart';
import 'package:extra_efficient_mobile/features/exams/screens/exam_preflight_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';

import '../../helpers/fake_http_adapter.dart';

/// The shared device gate.
///
/// The audio criterion is implemented as a deviation, and these tests pin it:
/// every media path on this backend 404s, so a missing sample must degrade to an
/// explicit confirmation and never block entry by throwing.
void main() {
  Widget buildApp({
    required FakeHttpClientAdapter adapter,
    required FakeAudioMediaAdapter audio,
    SittingKind kind = SittingKind.placement,
    int sittingId = 555,
  }) {
    final path = kind == SittingKind.placement
        ? '/placement/take/$sittingId/preflight'
        : '/exams/attempts/$sittingId/preflight';
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(
          path: path,
          builder: (context, state) => ExamPreflightScreen(
            kind: kind,
            sittingId: sittingId,
          ),
        ),
        GoRoute(
          path: '/placement/take/:placementId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('PLACEMENT ROOM #${state.pathParameters['placementId']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/exams/attempts/:attemptId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('MOCK ROOM #${state.pathParameters['attemptId']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/exams',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('EXAMS HUB')),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage(initialToken: 'valid-jwt'),
        ),
        httpClientAdapterProvider.overrideWithValue(adapter),
        audioMediaAdapterProvider.overrideWithValue(audio),
      ],
      child: MaterialApp.router(
        theme: ThemeData(
          useMaterial3: false,
          scaffoldBackgroundColor: SignageColors.wall,
        ),
        builder: (context, child) => FTheme(
          data: buildSignageTheme(),
          child: child ?? const SizedBox.shrink(),
        ),
        routerConfig: router,
      ),
    );
  }

  Map<String, dynamic> status({
    bool requiresAudio = true,
    bool requiresMicrophone = false,
    bool isVerified = false,
    List<String> audioUrls = const ['/audio/toeic/placement-p1.mp3'],
  }) => {
    'attemptId': 3,
    'examId': 2,
    'examName': 'TOEIC Placement Test — Diagnostic',
    'certCode': 'TOEIC',
    'certName': 'TOEIC Listening & Reading',
    'durationMinutes': 45,
    'requiresPreflight': true,
    'requiresAudio': requiresAudio,
    'requiresMicrophone': requiresMicrophone,
    'isVerified': isVerified,
    'verifiedAt': isVerified ? '2026-11-13T10:33:17Z' : null,
    'audioUrls': audioUrls,
  };

  testWidgets(
      'the gate verifies the device checks and then opens the placement room',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    var verified = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/take/555/preflight') {
        return FakeHttpClientAdapter.jsonResponse(status());
      }
      if (options.path == '/api/learner/attempts/3/preflight/verify') {
        // A placement verifies through its adapted attempt's route.
        verified = true;
        return FakeHttpClientAdapter.jsonResponse(status(isVerified: true));
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      buildApp(adapter: adapter, audio: audio),
    );
    await tester.pumpAndSettle();

    // The clock has not started: the enter control is refused until the checks
    // pass, which is the whole point of a gate.
    await tester.tap(find.byKey(const Key('enter-room-btn')));
    await tester.pumpAndSettle();
    expect(verified, isFalse);

    await tester.tap(find.byKey(const Key('preflight-audio-check-btn')));
    await tester.pumpAndSettle();
    expect(audio.lastLoadedUrl, '/audio/toeic/placement-p1.mp3');

    await tester.scrollUntilVisible(
      find.byKey(const Key('enter-room-btn')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('enter-room-btn')));
    await tester.pumpAndSettle();

    expect(verified, isTrue);
    expect(find.text('PLACEMENT ROOM #555'), findsOneWidget);
  });

  testWidgets(
      'a missing audio sample is an explicit confirmation, never a failed check',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    var verified = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/take/555/preflight') {
        // No sample at all - the shape this backend's media routes force.
        return FakeHttpClientAdapter.jsonResponse(
          status(audioUrls: const []),
        );
      }
      if (options.path == '/api/learner/attempts/3/preflight/verify') {
        verified = true;
        return FakeHttpClientAdapter.jsonResponse(status(isVerified: true));
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      buildApp(adapter: adapter, audio: audio),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('preflight-audio-check-btn')));
    await tester.pumpAndSettle();

    // Nothing was loaded, no 404 fallback literal exists, and the learner was
    // told the sample is unavailable.
    expect(audio.lastLoadedUrl, isNull);
    expect(find.textContaining('no playable sample'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('enter-room-btn')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('enter-room-btn')));
    await tester.pumpAndSettle();

    expect(verified, isTrue);
    expect(find.text('PLACEMENT ROOM #555'), findsOneWidget);
  });

  testWidgets('a microphone requirement is checked separately', (tester) async {
    final audio = FakeAudioMediaAdapter()..recordPermissionGranted = false;
    var micGateShown = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/take/555/preflight') {
        return FakeHttpClientAdapter.jsonResponse(
          status(audioUrls: const [], requiresMicrophone: true),
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      buildApp(adapter: adapter, audio: audio),
    );
    await tester.pumpAndSettle();

    micGateShown = find.byKey(const Key('preflight-mic-check-btn'))
        .evaluate()
        .isNotEmpty;
    expect(micGateShown, isTrue);

    await tester.tap(find.byKey(const Key('preflight-mic-check-btn')));
    await tester.pumpAndSettle();
    expect(find.text('DENIED'), findsOneWidget);
  });

  testWidgets('an already-verified sitting opens without repeating the checks',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/attempts/3/preflight') {
        return FakeHttpClientAdapter.jsonResponse(status(isVerified: true));
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      buildApp(
        adapter: adapter,
        audio: audio,
        kind: SittingKind.attempt,
        sittingId: 3,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('already complete'), findsOneWidget);
    await tester.tap(find.byKey(const Key('enter-room-btn')));
    await tester.pumpAndSettle();
    expect(find.text('MOCK ROOM #3'), findsOneWidget);
  });

  testWidgets('a gate that cannot be read still offers a way out',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    final adapter = FakeHttpClientAdapter((options, body) async {
      return FakeHttpClientAdapter.jsonResponse(
        {
          'title': 'Placement test not active',
          'status': 400,
          'detail': 'This exam attempt is no longer in progress.',
          'code': 'placement_not_active',
        },
        statusCode: 400,
      );
    });

    await tester.pumpWidget(
      buildApp(adapter: adapter, audio: audio),
    );
    await tester.pumpAndSettle();

    // A finished sitting is a normal end, not an error card.
    expect(find.text('This sitting is over'), findsOneWidget);
    expect(find.byKey(const Key('preflight-terminal-btn')), findsOneWidget);

    // And the secondary control leaves unconditionally.
    await tester.tap(find.text('BACK TO EXAMS').last);
    await tester.pumpAndSettle();
    expect(find.text('EXAMS HUB'), findsOneWidget);
  });

  testWidgets('the gate can always be left', (tester) async {
    final audio = FakeAudioMediaAdapter();
    final adapter = FakeHttpClientAdapter((options, body) async {
      return FakeHttpClientAdapter.jsonResponse(
        {'status': 500, 'code': 'UNEXPECTED'},
        statusCode: 500,
      );
    });

    await tester.pumpWidget(
      buildApp(adapter: adapter, audio: audio),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('preflight-leave-btn')));
    await tester.pumpAndSettle();
    expect(find.text('EXAMS HUB'), findsOneWidget);
  });
}
