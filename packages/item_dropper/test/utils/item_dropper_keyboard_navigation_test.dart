import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/utils/item_dropper_keyboard_navigation.dart';
import 'package:item_dropper/src/common/item_dropper_constants.dart';

void main() {
  group('ItemDropperKeyboardNavigation', () {
    late List<ItemDropperItem<String>> testItems;

    setUp(() {
      testItems = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ItemDropperItem<String>(value: '3', label: 'Item 3'),
      ];
    });

    group('findNextSelectableIndex', () {
      test('finds next selectable item going down', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Item 1'),
          ItemDropperItem<String>(
              value: 'h1', label: 'Header', isGroupHeader: true),
          ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ];

        final nextIndex = ItemDropperKeyboardNavigation.findNextSelectableIndex<
            String>(
          currentIndex: 0,
          items: items,
          goingDown: true,
        );

        expect(nextIndex, equals(2)); // Skips group header at index 1
      });

      test('finds next selectable item going up', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Item 1'),
          ItemDropperItem<String>(
              value: 'h1', label: 'Header', isGroupHeader: true),
          ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ];

        final nextIndex = ItemDropperKeyboardNavigation.findNextSelectableIndex<
            String>(
          currentIndex: 2,
          items: items,
          goingDown: false,
        );

        expect(nextIndex, equals(0)); // Skips group header at index 1
      });

      test('wraps around when going down past last item', () {
        final nextIndex = ItemDropperKeyboardNavigation.findNextSelectableIndex<
            String>(
          currentIndex: 2,
          items: testItems,
          goingDown: true,
        );

        expect(nextIndex, equals(0)); // Wraps to first item
      });

      test('wraps around when going up past first item', () {
        final nextIndex = ItemDropperKeyboardNavigation.findNextSelectableIndex<
            String>(
          currentIndex: 0,
          items: testItems,
          goingDown: false,
        );

        expect(nextIndex, equals(2)); // Wraps to last item
      });

      test('returns kNoHighlight when all items are group headers', () {
        final items = [
          ItemDropperItem<String>(
              value: 'h1', label: 'Header 1', isGroupHeader: true),
          ItemDropperItem<String>(
              value: 'h2', label: 'Header 2', isGroupHeader: true),
        ];

        final nextIndex = ItemDropperKeyboardNavigation.findNextSelectableIndex<
            String>(
          currentIndex: 0,
          items: items,
          goingDown: true,
        );

        expect(nextIndex, equals(ItemDropperConstants.kNoHighlight));
      });

      test('returns kNoHighlight when items list is empty', () {
        final nextIndex = ItemDropperKeyboardNavigation.findNextSelectableIndex<
            String>(
          currentIndex: 0,
          items: [],
          goingDown: true,
        );

        expect(nextIndex, equals(ItemDropperConstants.kNoHighlight));
      });

      test('skips multiple consecutive group headers', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Item 1'),
          ItemDropperItem<String>(
              value: 'h1', label: 'Header 1', isGroupHeader: true),
          ItemDropperItem<String>(
              value: 'h2', label: 'Header 2', isGroupHeader: true),
          ItemDropperItem<String>(
              value: 'h3', label: 'Header 3', isGroupHeader: true),
          ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ];

        final nextIndex = ItemDropperKeyboardNavigation.findNextSelectableIndex<
            String>(
          currentIndex: 0,
          items: items,
          goingDown: true,
        );

        expect(nextIndex, equals(4)); // Skips all three headers
      });
    });

    group('handleArrowDown', () {
      test('moves to next item', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: 0,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: testItems.length,
          items: testItems,
        );

        expect(nextIndex, equals(1));
      });

      test('wraps to first item when at end', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: 2,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: testItems.length,
          items: testItems,
        );

        expect(nextIndex, equals(0));
      });

      test('starts from hover index when no keyboard highlight', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: ItemDropperConstants.kNoHighlight,
          hoverIndex: 1,
          itemCount: testItems.length,
          items: testItems,
        );

        expect(nextIndex, equals(2));
      });

      test('skips group headers', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Item 1'),
          ItemDropperItem<String>(
              value: 'h1', label: 'Header', isGroupHeader: true),
          ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ];

        final nextIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: 0,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: items.length,
          items: items,
        );

        expect(nextIndex, equals(2)); // Skips header at index 1
      });

      test('returns kNoHighlight when itemCount is 0', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: ItemDropperConstants.kNoHighlight,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: 0,
          items: [],
        );

        expect(nextIndex, equals(ItemDropperConstants.kNoHighlight));
      });

      test('fallback behavior when items is null (backward compatibility)', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: 0,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: testItems.length,
          items: null, // Old API
        );

        expect(nextIndex, equals(1)); // Simple increment
      });
    });

    group('handleArrowUp', () {
      test('moves to previous item', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowUp<String>(
          currentIndex: 2,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: testItems.length,
          items: testItems,
        );

        expect(nextIndex, equals(1));
      });

      test('wraps to last item when at beginning', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowUp<String>(
          currentIndex: 0,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: testItems.length,
          items: testItems,
        );

        expect(nextIndex, equals(2));
      });

      test('starts from hover index when no keyboard highlight', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowUp<String>(
          currentIndex: ItemDropperConstants.kNoHighlight,
          hoverIndex: 1,
          itemCount: testItems.length,
          items: testItems,
        );

        expect(nextIndex, equals(0));
      });

      test('skips group headers', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Item 1'),
          ItemDropperItem<String>(
              value: 'h1', label: 'Header', isGroupHeader: true),
          ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ];

        final nextIndex = ItemDropperKeyboardNavigation.handleArrowUp<String>(
          currentIndex: 2,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: items.length,
          items: items,
        );

        expect(nextIndex, equals(0)); // Skips header at index 1
      });

      test('returns kNoHighlight when itemCount is 0', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowUp<String>(
          currentIndex: ItemDropperConstants.kNoHighlight,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: 0,
          items: [],
        );

        expect(nextIndex, equals(ItemDropperConstants.kNoHighlight));
      });

      test('fallback behavior when items is null (backward compatibility)', () {
        final nextIndex = ItemDropperKeyboardNavigation.handleArrowUp<String>(
          currentIndex: 2,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: testItems.length,
          items: null, // Old API
        );

        expect(nextIndex, equals(1)); // Simple decrement
      });
    });

    group('Edge Cases', () {
      test('handles single item list', () {
        final singleItem = [
          ItemDropperItem<String>(value: '1', label: 'Only Item'),
        ];

        final downIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: 0,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: singleItem.length,
          items: singleItem,
        );

        final upIndex = ItemDropperKeyboardNavigation.handleArrowUp<String>(
          currentIndex: 0,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: singleItem.length,
          items: singleItem,
        );

        // Both should return 0 (wraps to self)
        expect(downIndex, equals(0));
        expect(upIndex, equals(0));
      });

      test('handles alternating group headers and items', () {
        final items = [
          ItemDropperItem<String>(value: '1', label: 'Item 1'),
          ItemDropperItem<String>(
              value: 'h1', label: 'Header 1', isGroupHeader: true),
          ItemDropperItem<String>(value: '2', label: 'Item 2'),
          ItemDropperItem<String>(
              value: 'h2', label: 'Header 2', isGroupHeader: true),
          ItemDropperItem<String>(value: '3', label: 'Item 3'),
        ];

        // Navigate down: 0 -> 2 -> 4 -> 0
        int currentIndex = 0;
        currentIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: currentIndex,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: items.length,
          items: items,
        );
        expect(currentIndex, equals(2));

        currentIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: currentIndex,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: items.length,
          items: items,
        );
        expect(currentIndex, equals(4));

        currentIndex = ItemDropperKeyboardNavigation.handleArrowDown<String>(
          currentIndex: currentIndex,
          hoverIndex: ItemDropperConstants.kNoHighlight,
          itemCount: items.length,
          items: items,
        );
        expect(currentIndex, equals(0)); // Wraps around
      });
    });
  });
}
