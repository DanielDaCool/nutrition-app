/// Client-side sliding-window limiter so the app stays under an API's
/// published per-minute limits instead of collecting 429s.
class RateLimiter {
  RateLimiter({
    required this.maxRequests,
    this.window = const Duration(minutes: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxRequests;
  final Duration window;
  final DateTime Function() _clock;
  final List<DateTime> _sent = [];

  /// Records a request and returns null, or returns how long to wait when the
  /// limit is reached (nothing is recorded then).
  Duration? tryAcquire() {
    final now = _clock();
    _sent.removeWhere((t) => now.difference(t) >= window);
    if (_sent.length >= maxRequests) {
      return window - now.difference(_sent.first);
    }
    _sent.add(now);
    return null;
  }
}
