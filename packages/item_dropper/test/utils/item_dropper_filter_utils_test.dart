import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/utils/item_dropper_filter_utils.dart';

void main() {
  group('ItemDropperFilterUtils', () {
    late ItemDropperFilterUtils<String> filterUtils;
    late List<ItemDropperItem<String>> testItems;

    setUp(() {
      filterUtils = ItemDropperFilterUtils<String>();
      testItems = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
        ItemDropperItem<String>(value: '2', label: 'Banana'),
        ItemDropperItem<String>(value: '3', label: 'Cherry'),
        ItemDropperItem<String>(value: '4', label: 'Date'),
        ItemDropperItem<String>(
            value: 'h1', label: 'Fruits', isGroupHeader: true),
        ItemDropperItem<String>(value: '5', label: 'Elderberry'),
      ];
      filterUtils.initializeItems(testItems);
    });

    group('Initialization', () {
      test('initializeItems normalizes labels', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: '  APPLE  '),
          ItemDropperItem<String>(value: '2', label: 'BaNaNa'),
        ];

        filterUtils.initializeItems(items);

        final filtered = filterUtils.getFiltered(
          items,
          'app',
          isUserEditing: true,
        );

        expect(filtered.length, equals(1));
        expect(
            filtered[0].label, equals('  APPLE  ')); // Original label preserved
      });
    });

    group('getFiltered - Not Editing', () {
      test('returns all items when not editing', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          'app',
          isUserEditing: false,
        );

        expect(filtered.length, equals(testItems.length));
      });

      test('returns all items when search text is empty', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          '',
          isUserEditing: true,
        );

        expect(filtered.length, equals(testItems.length));
      });
    });

    group('getFiltered - Basic Filtering', () {
      test('filters items by search text', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          'app',
          isUserEditing: true,
        );

        expect(filtered.length, equals(1));
        expect(filtered[0].label, equals('Apple'));
      });

      test('filtering is case insensitive', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          'APP',
          isUserEditing: true,
        );

        expect(filtered.length, equals(1));
        expect(filtered[0].label, equals('Apple'));
      });

      test('filtering trims whitespace', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          '  app  ',
          isUserEditing: true,
        );

        expect(filtered.length, equals(1));
        expect(filtered[0].label, equals('Apple'));
      });

      test('filters by partial match', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          'err',
          isUserEditing: true,
        );

        expect(filtered.length, equals(2));
        expect(filtered.any((item) => item.label == 'Cherry'), isTrue);
        expect(filtered.any((item) => item.label == 'Elderberry'), isTrue);
      });

      test('returns empty list when no matches', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          'xyz',
          isUserEditing: true,
        );

        expect(filtered, isEmpty);
      });
    });

    group('getFiltered - Group Headers', () {
      test('excludes group headers from search results', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          'fruit',
          isUserEditing: true,
        );

        expect(filtered, isEmpty);
      });

      test('includes group headers when not filtering', () {
        final filtered = filterUtils.getFiltered(
          testItems,
          '',
          isUserEditing: true,
        );

        expect(filtered.any((item) => item.isGroupHeader), isTrue);
      });
    });

    group('getFiltered - Exclude Values', () {
      test('excludes specified values', () {
        final excludeValues = {'1', '2'};

        final filtered = filterUtils.getFiltered(
          testItems,
          '',
          isUserEditing: true,
          excludeValues: excludeValues,
        );

        expect(filtered.any((item) => item.value == '1'), isFalse);
        expect(filtered.any((item) => item.value == '2'), isFalse);
        expect(filtered.any((item) => item.value == '3'), isTrue);
      });

      test('excludes values work with search text', () {
        final excludeValues = {'1'};

        final filtered = filterUtils.getFiltered(
          testItems,
          'a',
          isUserEditing: true,
          excludeValues: excludeValues,
        );

        // Should match 'Apple' and 'Banana' and 'Date', but exclude 'Apple' ('1')
        expect(filtered.any((item) => item.value == '1'), isFalse);
        expect(filtered.any((item) => item.value == '2'), isTrue); // Banana
        expect(filtered.any((item) => item.value == '4'), isTrue); // Date
      });

      test('always includes group headers regardless of exclude', () {
        final excludeValues = {'h1'};

        final filtered = filterUtils.getFiltered(
          testItems,
          '',
          isUserEditing: true,
          excludeValues: excludeValues,
        );

        // Group headers should be included
        expect(filtered.any((item) => item.isGroupHeader), isTrue);
      });
    });

    group('Caching', () {
      test('returns cached result for same search text', () {
        final filtered1 = filterUtils.getFiltered(
          testItems,
          'app',
          isUserEditing: true,
        );

        final filtered2 = filterUtils.getFiltered(
          testItems,
          'app',
          isUserEditing: true,
        );

        expect(identical(filtered1, filtered2), isTrue);
      });

      test('cache is invalidated when search text changes', () {
        final filtered1 = filterUtils.getFiltered(
          testItems,
          'app',
          isUserEditing: true,
        );

        final filtered2 = filterUtils.getFiltered(
          testItems,
          'ban',
          isUserEditing: true,
        );

        expect(identical(filtered1, filtered2), isFalse);
        expect(filtered2.length, equals(1));
        expect(filtered2[0].label, equals('Banana'));
      });

      test('cache is invalidated by clearCache', () {
        final filtered1 = filterUtils.getFiltered(
          testItems,
          'app',
          isUserEditing: true,
        );

        filterUtils.clearCache();

        final filtered2 = filterUtils.getFiltered(
          testItems,
          'app',
          isUserEditing: true,
        );

        expect(identical(filtered1, filtered2), isFalse);
        expect(filtered2.length, equals(1)); // Same content though
      });
    });

    group('Reference Equality Check', () {
      test('reinitializes when items reference changes', () {
        final newItems = [
          ItemDropperItem<String>(value: '1', label: 'Orange'),
          ItemDropperItem<String>(value: '2', label: 'Grape'),
        ];

        final filtered = filterUtils.getFiltered(
          newItems,
          'ora',
          isUserEditing: true,
        );

        expect(filtered.length, equals(1));
        expect(filtered[0].label, equals('Orange'));
      });

      test('does not reinitialize for same reference', () {
        filterUtils.getFiltered(testItems, 'app', isUserEditing: true);

        // Call again with same reference
        final filtered = filterUtils.getFiltered(
          testItems,
          'ban',
          isUserEditing: true,
        );

        expect(filtered.length, equals(1));
        expect(filtered[0].label, equals('Banana'));
      });
    });

    group('Edge Cases', () {
      test('handles empty items list', () {
        filterUtils.initializeItems([]);

        final filtered = filterUtils.getFiltered(
          [],
          'test',
          isUserEditing: true,
        );

        expect(filtered, isEmpty);
      });

      test('handles special characters in search', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Test (Item)'),
          ItemDropperItem<String>(value: '2', label: 'Test Item'),
        ];

        filterUtils.initializeItems(items);

        final filtered = filterUtils.getFiltered(
          items,
          '(item)',
          isUserEditing: true,
        );

        expect(filtered.length, equals(1));
        expect(filtered[0].label, equals('Test (Item)'));
      });

      test('handles items with same label', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Apple'),
          ItemDropperItem<String>(value: '2', label: 'Apple'),
        ];

        filterUtils.initializeItems(items);

        final filtered = filterUtils.getFiltered(
          items,
          'app',
          isUserEditing: true,
        );

        expect(filtered.length, equals(2));
      });
    });
  });
}
