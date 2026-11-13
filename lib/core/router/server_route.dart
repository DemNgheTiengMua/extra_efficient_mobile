/// Resolves a server-supplied navigation path onto a route this app registers.
///
/// The backend's `nextAction.actionUrl` (and the `redirectUrl` on a path step)
/// speak the *web* application's URL vocabulary, which is not this app's. Two
/// examples seen live:
///
///   /practice/30                 -> /practice/sessions/30
///   /speaking/take/1006          -> no equivalent screen in this app
///
/// Blindly pushing the server's string lands the learner on the unmatched-route
/// screen - a dead end, which is exactly what the spec forbids. So every
/// server-supplied path passes through here first, and an unmappable one falls
/// back to a destination the learner can act on.
library;

/// A resolved destination: the route to push, and whether it came from the
/// server verbatim.
class ResolvedDestination {
  const ResolvedDestination(this.route, {this.exact = true});

  /// The route this app registers.
  final String route;

  /// True when [route] is the server's own path, unchanged.
  final bool exact;
}

/// Maps [raw] onto a registered route, or returns null when there is no
/// equivalent screen here.
///
/// A sitting that has a device gate gains `/preflight`, because the sitting
/// itself answers `preflight_required` until the checks pass.
ResolvedDestination? resolveServerRoute(String raw) {
  final uri = Uri.tryParse(raw);
  final path = uri?.path ?? raw;
  if (path.isEmpty) return null;

  // The web vocabulary: /practice/{sessionId}. Checked BEFORE the registered
  // prefixes, because `/practice/30` starts with `/practice` and would
  // otherwise be taken as an app route verbatim.
  final practice = RegExp(r'^/practice/(\d+)$').firstMatch(path);
  if (practice != null) {
    return ResolvedDestination(
      _gated('/practice/sessions/${practice.group(1)}'),
      exact: false,
    );
  }

  // Already a route this app registers: honour it as-is.
  if (_registeredPrefixes.any(path.startsWith)) {
    return ResolvedDestination(_gated(path));
  }

  // /speaking/take/{attemptId} and /writing/take/{attemptId} have no screen in
  // this app: skill practice is reached from the practice catalogue, priced up
  // front. Deliberately unmapped so the caller can explain rather than dead-end.
  return null;
}

/// Prefixes of routes this app actually registers.
const _registeredPrefixes = <String>[
  '/placement',
  '/exams',
  '/practice/sessions',
  '/practice/skill-practice',
  '/practice',
  '/path',
  '/wallet',
  '/account',
];

/// A sitting that carries a device gate is entered through it.
const _gatedSitting = r'^/(placement/take|exams/attempts)/\d+$';
final _gatedPattern = RegExp(_gatedSitting);

String _gated(String path) =>
    _gatedPattern.hasMatch(path) ? '$path/preflight' : path;
