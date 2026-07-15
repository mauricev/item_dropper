import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/utils/item_dropper_items_utils.dart';

void main() {
  group('ItemDropperItemsUtils', () {
    ItemDropperItem<String> item(String value) {
      return ItemDropperItem<String>(value: value, label: value);
    }

    group('areItemsEqual', () {
      test('treats null and empty lists as equal', () {
        expect(ItemDropperItemsUtils.areItemsEqual<String>(null, []), isTrue);
      });

      test('ignores order when values and counts match', () {
        final first = [item('A'), item('A'), item('B')];
        final second = [item('B'), item('A'), item('A')];

        expect(ItemDropperItemsUtils.areItemsEqual(first, second), isTrue);
      });

      test('detects different duplicate counts in small lists', () {
        final first = [item('A'), item('A'), item('B')];
        final second = [item('A'), item('B'), item('B')];

        expect(ItemDropperItemsUtils.areItemsEqual(first, second), isFalse);
      });

      test('detects different duplicate counts in large lists', () {
        final first = [
          item('A'),
          item('A'),
          for (var index = 0; index < 10; index++) item('Item $index'),
        ];
        final second = [
          item('A'),
          item('Item 0'),
          for (var index = 0; index < 10; index++) item('Item $index'),
        ];

        expect(ItemDropperItemsUtils.areItemsEqual(first, second), isFalse);
      });
    });

    group('hasItemsChanged', () {
      test('detects changed duplicate counts', () {
        final oldItems = [item('A'), item('A'), item('B')];
        final newItems = [item('A'), item('B'), item('B')];

        expect(
          ItemDropperItemsUtils.hasItemsChanged(oldItems, newItems),
          isTrue,
        );
      });
    });
  });
}
