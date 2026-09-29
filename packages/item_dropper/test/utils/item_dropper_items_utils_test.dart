import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/utils/item_dropper_items_utils.dart';
import 'package:item_dropper/src/utils/item_dropper_add_item_utils.dart';

void main() {
  group('ItemDropperItemsUtils', () {
    ItemDropperItem<String> item(String value) {
      return ItemDropperItem<String>(value: value, label: value);
    }

    group('findItemIndex', () {
      test('finds a reconstructed add action without reading its value', () {
        final action = ItemDropperAddItemUtils.createAddItem<String>('A', []);
        final reconstructed = ItemDropperAddItemUtils.createAddItem<String>(
          'A',
          [],
        );
        expect(
          ItemDropperItemsUtils.findItemIndex([
            item('A'),
            action,
          ], reconstructed),
          1,
        );
        expect(ItemDropperItemsUtils.findItemIndex([action], item('A')), -1);
      });

      test('preserves the position of an identical duplicate', () {
        final first = item('A');
        final second = item('A');

        expect(ItemDropperItemsUtils.findItemIndex([first, second], second), 1);
      });

      test('finds a reconstructed item by value and role', () {
        final original = ItemDropperItem<String>(
          value: 'A',
          label: 'Original label',
        );
        final reconstructed = ItemDropperItem<String>(
          value: 'A',
          label: 'Mapped label',
        );

        expect(
          ItemDropperItemsUtils.findItemIndex([original], reconstructed),
          0,
        );
      });

      test('does not confuse an add sentinel with a normal item', () {
        final normal = item('A');
        final addItem = ItemDropperItem<String>(
          value: 'A',
          label: 'Add "A"',
          isAddItem: true,
        );
        final reconstructedAddItem = ItemDropperItem<String>(
          value: 'A',
          label: 'Create A',
          isAddItem: true,
        );

        expect(
          ItemDropperItemsUtils.findItemIndex([
            normal,
            addItem,
          ], reconstructedAddItem),
          1,
        );
      });

      test('does not confuse a group header with a normal item', () {
        final normal = item('A');
        final header = ItemDropperItem<String>(
          value: 'A',
          label: 'Group A',
          isGroupHeader: true,
        );
        final reconstructedHeader = ItemDropperItem<String>(
          value: 'A',
          label: 'Mapped group A',
          isGroupHeader: true,
        );

        expect(
          ItemDropperItemsUtils.findItemIndex([
            normal,
            header,
          ], reconstructedHeader),
          1,
        );
      });

      test('returns minus one when no value-and-role match exists', () {
        expect(ItemDropperItemsUtils.findItemIndex([item('A')], item('B')), -1);
      });
    });

    group('areItemsEqual', () {
      test('detects changed labels and row properties for the same value', () {
        const original = ItemDropperItem<String>(value: 'a', label: 'Apple');
        for (final changed in [
          const ItemDropperItem<String>(value: 'a', label: 'Apricot'),
          const ItemDropperItem<String>(
            value: 'a',
            label: 'Apple',
            isEnabled: false,
          ),
        ]) {
          expect(
            ItemDropperItemsUtils.areItemsEqual([original], [changed]),
            isFalse,
          );
        }
      });

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
      test('detects row property changes without changing values', () {
        const before = ItemDropperItem<String>(value: 'a', label: 'Apple');
        const after = ItemDropperItem<String>(
          value: 'a',
          label: 'Apple',
          isEnabled: false,
        );
        expect(
          ItemDropperItemsUtils.hasItemsChanged([before], [after]),
          isTrue,
        );
        expect(
          ItemDropperItemsUtils.hasItemsChanged([before], [before]),
          isFalse,
        );
      });

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
