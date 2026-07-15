import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  group('ItemDropperItem', () {
    test('uses value equality for matching fields', () {
      const first = ItemDropperItem<String>(value: 'a', label: 'Apple');
      const second = ItemDropperItem<String>(value: 'a', label: 'Apple');

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('treats different values as different items', () {
      const first = ItemDropperItem<String>(value: 'a', label: 'Apple');
      const second = ItemDropperItem<String>(value: 'b', label: 'Apple');

      expect(first, isNot(second));
    });

    test('treats different labels as different items', () {
      const first = ItemDropperItem<String>(value: 'a', label: 'Apple');
      const second = ItemDropperItem<String>(value: 'a', label: 'Apricot');

      expect(first, isNot(second));
    });

    test('includes behavior flags in equality', () {
      const normal = ItemDropperItem<String>(value: 'a', label: 'Apple');
      const disabled = ItemDropperItem<String>(
        value: 'a',
        label: 'Apple',
        isEnabled: false,
      );
      const groupHeader = ItemDropperItem<String>(
        value: 'a',
        label: 'Apple',
        isGroupHeader: true,
      );
      const deletable = ItemDropperItem<String>(
        value: 'a',
        label: 'Apple',
        isDeletable: true,
      );

      expect(normal, isNot(disabled));
      expect(normal, isNot(groupHeader));
      expect(normal, isNot(deletable));
    });

    test('does not treat add item sentinels as real items', () {
      const realItem = ItemDropperItem<String>(value: 'a', label: 'Apple');
      const addItem = ItemDropperItem<String>(
        value: 'a',
        label: 'Apple',
        isAddItem: true,
      );

      expect(realItem, isNot(addItem));
    });

    test('works as a set key', () {
      const first = ItemDropperItem<String>(value: 'a', label: 'Apple');
      const second = ItemDropperItem<String>(value: 'a', label: 'Apple');
      const third = ItemDropperItem<String>(value: 'b', label: 'Banana');

      final items = <ItemDropperItem<String>>{};
      items.add(first);
      items.add(second);
      items.add(third);

      expect(items.length, 2);
      expect(items.contains(second), isTrue);
    });
  });
}
