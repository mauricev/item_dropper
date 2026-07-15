import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/rebuild_scheduler.dart';

void main() {
  group('RebuildScheduler', () {
    test('does not rebuild when unmounted', () {
      final scheduler = RebuildScheduler();
      var rebuildCount = 0;
      var updateCount = 0;

      scheduler.request(
        mounted: false,
        rebuild: (update) {
          rebuildCount++;
          update();
        },
        update: () => updateCount++,
      );

      expect(rebuildCount, 0);
      expect(updateCount, 0);
    });

    test('runs update inside rebuild callback', () {
      final scheduler = RebuildScheduler();
      var rebuildCount = 0;
      var updateCount = 0;

      scheduler.request(
        mounted: true,
        rebuild: (update) {
          rebuildCount++;
          expect(scheduler.isRebuilding, isTrue);
          update();
        },
        update: () => updateCount++,
      );

      expect(rebuildCount, 1);
      expect(updateCount, 1);
      expect(scheduler.isRebuilding, isFalse);
    });

    test('coalesces nested update instead of dropping it', () {
      final scheduler = RebuildScheduler();
      final updates = <String>[];
      var rebuildCount = 0;

      scheduler.request(
        mounted: true,
        rebuild: (update) {
          rebuildCount++;
          update();
        },
        update: () {
          updates.add('first');
          scheduler.request(
            mounted: true,
            rebuild: (update) {
              rebuildCount++;
              update();
            },
            update: () => updates.add('nested'),
          );
        },
      );

      expect(rebuildCount, 1);
      expect(updates, ['first', 'nested']);
    });

    test('coalesces nested rebuild without an update', () {
      final scheduler = RebuildScheduler();
      final updates = <String>[];
      var rebuildCount = 0;

      scheduler.request(
        mounted: true,
        rebuild: (update) {
          rebuildCount++;
          update();
        },
        update: () {
          updates.add('first');
          scheduler.request(
            mounted: true,
            rebuild: (update) {
              rebuildCount++;
              update();
            },
          );
        },
      );

      expect(rebuildCount, 1);
      expect(updates, ['first']);
    });
  });
}
