import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/controlled_value_sync.dart';

void main() {
  group('ControlledValueSync', () {
    test('does not sync matching values', () {
      final shouldSync = ControlledValueSync.shouldSync<int>(
        current: 1,
        incoming: 1,
        equals: (current, incoming) => current == incoming,
      );

      expect(shouldSync, isFalse);
    });

    test('syncs different values', () {
      final shouldSync = ControlledValueSync.shouldSync<int>(
        current: 1,
        incoming: 2,
        equals: (current, incoming) => current == incoming,
      );

      expect(shouldSync, isTrue);
    });

    test('uses caller-provided equality', () {
      final shouldSync = ControlledValueSync.shouldSync<String>(
        current: 'Apple',
        incoming: 'apple',
        equals: (current, incoming) =>
            current.toLowerCase() == incoming.toLowerCase(),
      );

      expect(shouldSync, isFalse);
    });
  });
}
