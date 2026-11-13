/// The app's single stance on Riverpod auto-retry.
///
/// Riverpod's default retries a non-`Error` failure ten times over ~38 s and
/// reports every attempt as `AsyncLoading`, so a 404 is indistinguishable from
/// a slow network for the whole wait. Every data provider here names this
/// function instead: a failure reaches the screen's error branch at once, and
/// the screen offers a RETRY of the learner's own choosing.
Duration? noProviderRetry(int retryCount, Object error) => null;
