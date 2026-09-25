import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Waits until [provider] has data matching [until].
Future<T> waitFor<T>(
  ProviderContainer container,
  StreamProvider<T> provider,
  bool Function(T value) until,
) {
  final done = Completer<T>();
  late final ProviderSubscription<AsyncValue<T>> sub;
  void check(AsyncValue<T> v) {
    final value = v.value;
    if (!done.isCompleted && v.hasValue && until(value as T)) {
      done.complete(value);
    }
  }

  sub = container.listen(provider, (_, next) => check(next));
  check(sub.read());
  return done.future
      .timeout(const Duration(seconds: 5))
      .whenComplete(sub.close);
}
