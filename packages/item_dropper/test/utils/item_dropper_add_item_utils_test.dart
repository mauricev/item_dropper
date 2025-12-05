import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/utils/item_dropper_add_item_utils.dart';

void main() {
  group('ItemDropperAddItemUtils', () {
    late List<ItemDropperItem<String>> testItems;

    setUp(() {
      testItems = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
        ItemDropperItem<String>(value: '2', label: 'Banana'),
        ItemDropperItem<String>(value: '3', label: 'Cherry'),
      ];
    });

    group('isAddItem', () {
      test('returns true for add item with correct format', () {
        final addItem = ItemDropperItem<String>(
          value: 'temp',
          label: 'Add "Orange"',
        );

        final result = ItemDropperAddItemUtils.isAddItem(addItem, testItems);

        expect(result, isTrue);
      });

      test('returns false for normal item', () {
        final normalItem = ItemDropperItem<String>(
          value: '1',
          label: 'Apple',
        );

        final result = ItemDropperAddItemUtils.isAddItem(normalItem, testItems);

        expect(result, isFalse);
      });

      test('returns false for item that starts with Add but wrong format', () {
        final item = ItemDropperItem<String>(
          value: 'temp',
          label: 'Add Item',
        );

        final result = ItemDropperAddItemUtils.isAddItem(item, testItems);

        expect(result, isFalse);
      });

      test(
          'returns false for item that has quotes but does not start with Add', () {
        final item = ItemDropperItem<String>(
          value: 'temp',
          label: 'Create "Orange"',
        );

        final result = ItemDropperAddItemUtils.isAddItem(item, testItems);

        expect(result, isFalse);
      });

      test('returns false if item exists in original list', () {
        final existingItem = testItems[0];

        final result = ItemDropperAddItemUtils.isAddItem(
            existingItem, testItems);

        expect(result, isFalse);
      });

      test(
          'returns false for add item format that exists in original list', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Add "Test"'),
        ];

        final item = ItemDropperItem<String>(
          value: '1',
          label: 'Add "Test"',
        );

        final result = ItemDropperAddItemUtils.isAddItem(item, items);

        expect(result, isFalse); // Item exists in original list
      });
    });

    group('extractSearchTextFromAddItem', () {
      test('extracts search text from add item', () {
        final addItem = ItemDropperItem<String>(
          value: 'temp',
          label: 'Add "Orange"',
        );

        final searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(
            addItem);

        expect(searchText, equals('Orange'));
      });

      test('extracts search text with spaces', () {
        final addItem = ItemDropperItem<String>(
          value: 'temp',
          label: 'Add "Passion Fruit"',
        );

        final searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(
            addItem);

        expect(searchText, equals('Passion Fruit'));
      });

      test('extracts search text with special characters', () {
        final addItem = ItemDropperItem<String>(
          value: 'temp',
          label: 'Add "Test@123"',
        );

        final searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(
            addItem);

        expect(searchText, equals('Test@123'));
      });

      test('returns empty string for invalid format', () {
        final item = ItemDropperItem<String>(
          value: 'temp',
          label: 'Add Item',
        );

        final searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(
            item);

        expect(searchText, isEmpty);
      });

      test('returns empty string for empty quotes', () {
        final item = ItemDropperItem<String>(
          value: 'temp',
          label: 'Add ""',
        );

        final searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(
            item);

        expect(searchText, isEmpty);
      });
    });

    group('createAddItem', () {
      test('creates add item with correct label format', () {
        final addItem = ItemDropperAddItemUtils.createAddItem<String>(
          'Orange',
          testItems,
        );

        expect(addItem.label, equals('Add "Orange"'));
      });

      test('creates add item with value from first item when items exist', () {
        final addItem = ItemDropperAddItemUtils.createAddItem<String>(
          'Orange',
          testItems,
        );

        expect(addItem.value, equals(testItems.first.value));
      });

      test('created item is not a group header', () {
        final addItem = ItemDropperAddItemUtils.createAddItem<String>(
          'Orange',
          testItems,
        );

        expect(addItem.isGroupHeader, isFalse);
      });

      test('handles empty items list by casting search text', () {
        final addItem = ItemDropperAddItemUtils.createAddItem<String>(
          'Orange',
          [],
        );

        expect(addItem.label, equals('Add "Orange"'));
        expect(addItem.value, equals('Orange'));
      });
    });

    group('addAddItemIfNeeded', () {
      test('adds add item when search text exists and callback provided', () {
        final filtered = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
        ];

        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: filtered,
          searchText: 'Orange',
          originalItems: testItems,
          hasOnAddItemCallback: () => true,
        );

        expect(result.length, equals(2));
        expect(result.first.label, equals('Add "Orange"'));
        expect(result[1].label, equals('Apple'));
      });

      test('does not add add item when search text is empty', () {
        final filtered = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
        ];

        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: filtered,
          searchText: '',
          originalItems: testItems,
          hasOnAddItemCallback: () => true,
        );

        expect(result.length, equals(1));
        expect(result.first.label, equals('Apple'));
      });

      test('does not add add item when callback not provided', () {
        final filtered = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
        ];

        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: filtered,
          searchText: 'Orange',
          originalItems: testItems,
          hasOnAddItemCallback: () => false,
        );

        expect(result.length, equals(1));
        expect(result.first.label, equals('Apple'));
      });

      test(
          'does not add add item when exact match exists (case insensitive)', () {
        final filtered = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
        ];

        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: filtered,
          searchText: 'apple',
          originalItems: testItems,
          hasOnAddItemCallback: () => true,
        );

        expect(result.length, equals(1)); // No add item added
        expect(result.first.label, equals('Apple'));
      });

      test(
          'does not add add item when exact match exists (with whitespace)', () {
        final filtered = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
        ];

        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: filtered,
          searchText: '  Apple  ',
          originalItems: testItems,
          hasOnAddItemCallback: () => true,
        );

        expect(result.length, equals(1)); // No add item added
      });

      test('adds add item when partial match exists but not exact', () {
        final filtered = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
        ];

        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: filtered,
          searchText: 'App',
          originalItems: testItems,
          hasOnAddItemCallback: () => true,
        );

        expect(result.length, equals(2)); // Add item is added
        expect(result.first.label, equals('Add "App"'));
      });

      test('ignores group headers when checking for exact match', () {
        final itemsWithHeader = [
          ItemDropperItem<String>(
              value: 'h1', label: 'Fruits', isGroupHeader: true),
          ItemDropperItem<String>(value: '1', label: 'Apple'),
        ];

        final filtered = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
        ];

        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: filtered,
          searchText: 'Fruits',
          originalItems: itemsWithHeader,
          hasOnAddItemCallback: () => true,
        );

        expect(result.length, equals(2)); // Add item is added (header ignored)
        expect(result.first.label, equals('Add "Fruits"'));
      });

      test('handles empty filtered items list', () {
        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: [],
          searchText: 'Orange',
          originalItems: testItems,
          hasOnAddItemCallback: () => true,
        );

        expect(result.length, equals(1));
        expect(result.first.label, equals('Add "Orange"'));
      });

      test('preserves order of filtered items', () {
        final filtered = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
          ItemDropperItem<String>(value: '2', label: 'Apricot'),
        ];

        final result = ItemDropperAddItemUtils.addAddItemIfNeeded<String>(
          filteredItems: filtered,
          searchText: 'Orange',
          originalItems: testItems,
          hasOnAddItemCallback: () => true,
        );

        expect(result.length, equals(3));
        expect(result[0].label, contains('Add')); // Add item first
        expect(result[1].label, equals('Apple'));
        expect(result[2].label, equals('Apricot'));
      });
    });

    group('Edge Cases', () {
      test('handles search text with quotes inside', () {
        final addItem = ItemDropperAddItemUtils.createAddItem<String>(
          'Test "quoted" text',
          testItems,
        );

        expect(addItem.label, equals('Add "Test "quoted" text"'));
      });

      test('handles very long search text', () {
        final longText = 'A' * 1000;
        final addItem = ItemDropperAddItemUtils.createAddItem<String>(
          longText,
          testItems,
        );

        expect(addItem.label, equals('Add "$longText"'));
      });

      test('handles unicode characters', () {
        final addItem = ItemDropperAddItemUtils.createAddItem<String>(
          '🍎 Apple',
          testItems,
        );

        expect(addItem.label, equals('Add "🍎 Apple"'));
      });
    });
  });
}
