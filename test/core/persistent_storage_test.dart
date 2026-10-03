// The VM (and Android) get the no-op stub; it must complete without throwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/persistent_storage.dart';

void main() {
  test('requestPersistentStorage is a harmless no-op off the web', () async {
    await expectLater(requestPersistentStorage(), completes);
  });
}
