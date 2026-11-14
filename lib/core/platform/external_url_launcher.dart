import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Abstraction for opening an external URL, overridable in tests.
abstract class UrlLauncherAdapter {
  /// Attempts the launch and reports whether it succeeded.
  ///
  /// Deliberately no `canLaunchUrl` pre-check: it returns false on Android 11+
  /// unless every scheme is declared in the manifest, and the package's own
  /// guidance is to attempt the launch and handle the failure.
  Future<bool> launchExternalUrl(String url);
}

typedef UrlLaunch = Future<bool> Function(Uri url);

/// Opens URLs in the device's browser.
///
/// The backend's mock gateway returns a root-relative checkout url, so a
/// relative path is resolved against the API host before launching.
class ExternalUrlLauncher implements UrlLauncherAdapter {
  const ExternalUrlLauncher({this.baseUrl, this.launch});

  final String? baseUrl;
  final UrlLaunch? launch;

  @override
  Future<bool> launchExternalUrl(String url) async {
    final resolved = _resolve(url);
    if (resolved == null) return false;
    try {
      return await (launch ?? launchUrl)(resolved);
    } catch (_) {
      return false;
    }
  }

  Uri? _resolve(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;

    final base = Uri.tryParse(baseUrl ?? AppConfig.baseUrl);
    if (base == null) return null;
    return base.resolve(trimmed);
  }
}

final urlLauncherAdapterProvider = Provider<UrlLauncherAdapter>(
  (ref) => const ExternalUrlLauncher(),
);
