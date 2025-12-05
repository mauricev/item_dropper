import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/multi/multi_select_selection_manager.dart';

void main() {
  group('MultiSelectSelectionManager', () {
    late MultiSelectSelectionManager<String> manager;
    int onSelectionChangedCallCount = 0;
    int onFilterCacheInvalidatedCallCount = 0;

    setUp(() {
      onSelectionChangedCallCount = 0;
      onFilterCacheInvalidatedCallCount = 0;
      manager = MultiSelectSelectionManager<String>(
        maxSelected: null,
        onSelectionChanged: () => onSelectionChangedCallCount++,
        onFilterCacheInvalidated: () => onFilterCacheInvalidatedCallCount++,
      );
    });

    group('Basic Selection', () {
      test('starts with empty selection', () {
        expect(manager.selected, isEmpty);
        expect(manager.selectedCount, equals(0));
        expect(manager.selectedValues, isEmpty);
      });

      test('addItem adds item to selection', () {
        final item = ItemDropperItem<String>(value: 'a', label: 'A');

        manager.addItem(item);

        expect(manager.selected.length, equals(1));
        expect(manager.selected.first.value, equals('a'));
        expect(manager.selectedCount, equals(1));
        expect(manager.selectedValues.contains('a'), isTrue);
      });

      test('addItem notifies callbacks', () {
        final item = ItemDropperItem<String>(value: 'a', label: 'A');

        manager.addItem(item);

        expect(onSelectionChangedCallCount, equals(1));
        expect(onFilterCacheInvalidatedCallCount, equals(1));
      });

      test('addItem does not add duplicate', () {
        final item = ItemDropperItem<String>(value: 'a', label: 'A');

        manager.addItem(item);
        manager.addItem(item);

        expect(manager.selected.length, equals(1));
        // Only called once (duplicate ignored)
        expect(onSelectionChangedCallCount, equals(1));
      });

      test('addItem can add multiple different items', () {
        final item1 = ItemDropperItem<String>(value: 'a', label: 'A');
        final item2 = ItemDropperItem<String>(value: 'b', label: 'B');

        manager.addItem(item1);
        manager.addItem(item2);

        expect(manager.selected.length, equals(2));
        expect(manager.selectedValues.contains('a'), isTrue);
        expect(manager.selectedValues.contains('b'), isTrue);
      });

      test('isSelected returns true for selected item', () {
        final item = ItemDropperItem<String>(value: 'a', label: 'A');

        expect(manager.isSelected(item), isFalse);

        manager.addItem(item);

        expect(manager.isSelected(item), isTrue);
      });

      test('isSelected works with different item instances but same value', () {
        final item1 = ItemDropperItem<String>(value: 'a', label: 'A');
        final item2 = ItemDropperItem<String>(value: 'a', label: 'A');

        manager.addItem(item1);

        expect(manager.isSelected(item2), isTrue);
      });
    });

    group('Remove Item', () {
      test('removeItem removes item from selection', () {
        final item = ItemDropperItem<String>(value: 'a', label: 'A');
        manager.addItem(item);

        manager.removeItem('a');

        expect(manager.selected, isEmpty);
        expect(manager.selectedValues.contains('a'), isFalse);
      });

      test('removeItem notifies callbacks', () {
        final item = ItemDropperItem<String>(value: 'a', label: 'A');
        manager.addItem(item);
        onSelectionChangedCallCount = 0; // Reset counter
        onFilterCacheInvalidatedCallCount = 0;

        manager.removeItem('a');

        expect(onSelectionChangedCallCount, equals(1));
        expect(onFilterCacheInvalidatedCallCount, equals(1));
      });

      test('removeItem does nothing if value not in selection', () {
        manager.removeItem('nonexistent');

        expect(onSelectionChangedCallCount, equals(0));
        expect(onFilterCacheInvalidatedCallCount, equals(0));
      });

      test('removeItem only removes specified value', () {
        final item1 = ItemDropperItem<String>(value: 'a', label: 'A');
        final item2 = ItemDropperItem<String>(value: 'b', label: 'B');
        manager.addItem(item1);
        manager.addItem(item2);

        manager.removeItem('a');

        expect(manager.selected.length, equals(1));
        expect(manager.selected.first.value, equals('b'));
      });
    });

    group('Max Selection', () {
      test('isMaxReached returns false when no limit set', () {
        final item = ItemDropperItem<String>(value: 'a', label: 'A');
        manager.addItem(item);

        expect(manager.isMaxReached(), isFalse);
      });

      test('isMaxReached returns true when limit reached', () {
        final managerWithLimit = MultiSelectSelectionManager<String>(
          maxSelected: 2,
          onSelectionChanged: () {},
        );

        expect(managerWithLimit.isMaxReached(), isFalse);

        managerWithLimit.addItem(
            ItemDropperItem<String>(value: 'a', label: 'A'));
        expect(managerWithLimit.isMaxReached(), isFalse);

        managerWithLimit.addItem(
            ItemDropperItem<String>(value: 'b', label: 'B'));
        expect(managerWithLimit.isMaxReached(), isTrue);
      });

      test('isBelowMax returns true when below limit', () {
        final managerWithLimit = MultiSelectSelectionManager<String>(
          maxSelected: 2,
          onSelectionChanged: () {},
        );

        expect(managerWithLimit.isBelowMax(), isTrue);

        managerWithLimit.addItem(
            ItemDropperItem<String>(value: 'a', label: 'A'));
        expect(managerWithLimit.isBelowMax(), isTrue);

        managerWithLimit.addItem(
            ItemDropperItem<String>(value: 'b', label: 'B'));
        expect(managerWithLimit.isBelowMax(), isFalse);
      });

      test('isBelowMax returns true when no limit set', () {
        manager.addItem(ItemDropperItem<String>(value: 'a', label: 'A'));
        manager.addItem(ItemDropperItem<String>(value: 'b', label: 'B'));
        manager.addItem(ItemDropperItem<String>(value: 'c', label: 'C'));

        expect(manager.isBelowMax(), isTrue);
      });
    });

    group('Sync Items', () {
      test('syncItems updates selection from external source', () {
        final items = [
          ItemDropperItem<String>(value: 'a', label: 'A'),
          ItemDropperItem<String>(value: 'b', label: 'B'),
        ];

        manager.syncItems(items);

        expect(manager.selected.length, equals(2));
        expect(manager.selectedValues.contains('a'), isTrue);
        expect(manager.selectedValues.contains('b'), isTrue);
      });

      test('syncItems replaces existing selection', () {
        manager.addItem(ItemDropperItem<String>(value: 'old', label: 'Old'));

        final newItems = [
          ItemDropperItem<String>(value: 'new', label: 'New'),
        ];
        manager.syncItems(newItems);

        expect(manager.selected.length, equals(1));
        expect(manager.selected.first.value, equals('new'));
        expect(manager.selectedValues.contains('old'), isFalse);
      });

      test('syncItems keeps List and Set in sync', () {
        final items = [
          ItemDropperItem<String>(value: 'a', label: 'A'),
          ItemDropperItem<String>(value: 'b', label: 'B'),
          ItemDropperItem<String>(value: 'c', label: 'C'),
        ];

        manager.syncItems(items);

        expect(manager.selected.length, equals(manager.selectedValues.length));
        for (final item in manager.selected) {
          expect(manager.selectedValues.contains(item.value), isTrue);
        }
      });
    });

    group('Clear Selection', () {
      test('clear removes all selections', () {
        manager.addItem(ItemDropperItem<String>(value: 'a', label: 'A'));
        manager.addItem(ItemDropperItem<String>(value: 'b', label: 'B'));

        manager.clear();

        expect(manager.selected, isEmpty);
        expect(manager.selectedValues, isEmpty);
        expect(manager.selectedCount, equals(0));
      });

      test('clear notifies callbacks when items exist', () {
        manager.addItem(ItemDropperItem<String>(value: 'a', label: 'A'));
        onSelectionChangedCallCount = 0;
        onFilterCacheInvalidatedCallCount = 0;

        manager.clear();

        expect(onSelectionChangedCallCount, equals(1));
        expect(onFilterCacheInvalidatedCallCount, equals(1));
      });

      test('clear does not notify callbacks when already empty', () {
        manager.clear();

        expect(onSelectionChangedCallCount, equals(0));
        expect(onFilterCacheInvalidatedCallCount, equals(0));
      });
    });

    group('selectedValues returns unmodifiable Set', () {
      test('returned set cannot be modified', () {
        manager.addItem(ItemDropperItem<String>(value: 'a', label: 'A'));

        final values = manager.selectedValues;

        expect(() => values.add('b'), throwsUnsupportedError);
      });
    });

    group('selected returns unmodifiable List', () {
      test('returned list cannot be modified', () {
        manager.addItem(ItemDropperItem<String>(value: 'a', label: 'A'));

        final items = manager.selected;

        expect(
              () => items.add(ItemDropperItem<String>(value: 'b', label: 'B')),
          throwsUnsupportedError,
        );
      });
    });

    group('Selection order preservation', () {
      test('items are returned in order they were added', () {
        final item1 = ItemDropperItem<String>(value: 'a', label: 'A');
        final item2 = ItemDropperItem<String>(value: 'b', label: 'B');
        final item3 = ItemDropperItem<String>(value: 'c', label: 'C');

        manager.addItem(item1);
        manager.addItem(item2);
        manager.addItem(item3);

        expect(manager.selected[0].value, equals('a'));
        expect(manager.selected[1].value, equals('b'));
        expect(manager.selected[2].value, equals('c'));
      });

      test('remove and re-add changes order', () {
        final item1 = ItemDropperItem<String>(value: 'a', label: 'A');
        final item2 = ItemDropperItem<String>(value: 'b', label: 'B');
        final item3 = ItemDropperItem<String>(value: 'c', label: 'C');

        manager.addItem(item1);
        manager.addItem(item2);
        manager.addItem(item3);
        manager.removeItem('b');
        manager.addItem(item2);

        expect(manager.selected[0].value, equals('a'));
        expect(manager.selected[1].value, equals('c'));
        expect(manager.selected[2].value, equals('b'));
      });
    });
  });
}
