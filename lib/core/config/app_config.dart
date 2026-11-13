import 'package:flutter/foundation.dart';

/// Environment-aware configuration for the Extra Efficient mobile client.
abstract final class AppConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Resolves the backend API base URL for the current platform.
  ///
  /// Android Emulator reaches the host Docker container via `10.0.2.2:5001`,
  /// while Windows, iOS Simulator, macOS, and `adb reverse` setups use
  /// `localhost:5001`.
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5001';
    }
    return 'http://localhost:5001';
  }
}
