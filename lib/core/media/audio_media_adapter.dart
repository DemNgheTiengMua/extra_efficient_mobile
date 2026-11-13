import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

/// Device-edge adapter wrapping audio playback (`just_audio`) and microphone
/// recording (`record`) so exam/practice widgets remain testable without hardware.
abstract interface class AudioMediaAdapter {
  Future<void> setAudioUrl(String url, {Duration? clipStart, Duration? clipEnd});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;

  Future<bool> hasRecordPermission();
  Future<void> startRecording(String outputPath);
  Future<String?> stopRecording();
  Future<void> dispose();
}

/// Production implementation backed by [AudioPlayer] and [AudioRecorder].
class DeviceAudioMediaAdapter implements AudioMediaAdapter {
  DeviceAudioMediaAdapter({
    AudioPlayer? player,
    AudioRecorder? recorder,
  })  : _player = player ?? AudioPlayer(),
        _recorder = recorder ?? AudioRecorder();

  final AudioPlayer _player;
  final AudioRecorder _recorder;

  @override
  Future<void> setAudioUrl(
    String url, {
    Duration? clipStart,
    Duration? clipEnd,
  }) async {
    if (clipStart != null || clipEnd != null) {
      await _player.setAudioSource(
        ClippingAudioSource(
          start: clipStart,
          end: clipEnd,
          child: AudioSource.uri(Uri.parse(url)),
        ),
      );
    } else {
      await _player.setUrl(url);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<bool> hasRecordPermission() => _recorder.hasPermission();

  @override
  Future<void> startRecording(String outputPath) =>
      _recorder.start(const RecordConfig(), path: outputPath);

  @override
  Future<String?> stopRecording() => _recorder.stop();

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _recorder.dispose();
  }
}

/// In-memory fake [AudioMediaAdapter] for widget and unit tests.
class FakeAudioMediaAdapter implements AudioMediaAdapter {
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();

  String? lastLoadedUrl;
  Duration? lastClipStart;
  Duration? lastClipEnd;
  bool isPlaying = false;
  bool isRecording = false;
  String? lastRecordedPath;
  bool recordPermissionGranted = true;

  @override
  Future<void> setAudioUrl(
    String url, {
    Duration? clipStart,
    Duration? clipEnd,
  }) async {
    lastLoadedUrl = url;
    lastClipStart = clipStart;
    lastClipEnd = clipEnd;
    _durationController.add(const Duration(seconds: 30));
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _playingController.add(false);
    _positionController.add(Duration.zero);
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Future<bool> hasRecordPermission() async => recordPermissionGranted;

  @override
  Future<void> startRecording(String outputPath) async {
    isRecording = true;
    lastRecordedPath = outputPath;
  }

  @override
  Future<String?> stopRecording() async {
    isRecording = false;
    return lastRecordedPath;
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
  }
}

/// Riverpod provider for [AudioMediaAdapter]. Override in tests with [FakeAudioMediaAdapter].
final audioMediaAdapterProvider = Provider<AudioMediaAdapter>((ref) {
  final adapter = DeviceAudioMediaAdapter();
  ref.onDispose(adapter.dispose);
  return adapter;
});
