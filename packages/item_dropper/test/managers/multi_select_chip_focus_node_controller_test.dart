import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/multi/multi_select_chip_focus_node_controller.dart';

void main() {
  group('MultiSelectChipFocusNodeController', () {
    late MultiSelectChipFocusNodeController controller;

    setUp(() {
      controller = MultiSelectChipFocusNodeController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('reuses focus node for the same chip index', () {
      final first = controller.nodeForIndex(0, enabled: true);
      final second = controller.nodeForIndex(0, enabled: true);

      expect(second, same(first));
      expect(controller.count, 1);
    });

    test('updates canRequestFocus when enabled changes', () {
      final node = controller.nodeForIndex(0, enabled: true);

      expect(node.canRequestFocus, isTrue);

      final updated = controller.nodeForIndex(0, enabled: false);

      expect(updated, same(node));
      expect(updated.canRequestFocus, isFalse);
    });

    test('retains only current chip indices', () {
      controller.nodeForIndex(0, enabled: true);
      controller.nodeForIndex(1, enabled: true);
      controller.nodeForIndex(2, enabled: true);

      controller.retainIndices([0, 2]);

      expect(controller.containsIndex(0), isTrue);
      expect(controller.containsIndex(1), isFalse);
      expect(controller.containsIndex(2), isTrue);
      expect(controller.count, 2);
    });

    test('dispose clears all tracked nodes', () {
      controller.nodeForIndex(0, enabled: true);
      controller.nodeForIndex(1, enabled: true);

      controller.dispose();

      expect(controller.count, 0);
    });
  });
}
