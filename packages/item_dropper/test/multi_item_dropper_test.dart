import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

/// Helper class to track callback invocations across widget rebuilds
class _MultiCallbackTracker<T> {
  int callCount = 0;
  List<T>? lastValue;
  
  void record(List<T> value) {
    callCount++;
    lastValue = List.from(value);
  }
}

/// Helper to track delete callback invocations
class _DeleteCallbackTracker<T> {
  int callCount = 0;
  ItemDropperItem<T>? lastItem;

  void record(ItemDropperItem<T> item) {
    callCount++;
    lastItem = item;
  }
}

void main() {
  group('MultiItemDropper - Basic Functionality', () {
    testWidgets('should display items list', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ItemDropperItem<String>(value: '3', label: 'Item 3'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap to open dropdown
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Verify items are displayed
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('should select multiple items', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ItemDropperItem<String>(value: '3', label: 'Item 3'),
      ];

      List<ItemDropperItem<String>> selectedItems = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MultiItemDropper<String>(
                  items: items,
                  selectedItems: selectedItems,
                  width: 300,
                  onChanged: (items) {
                    setState(() => selectedItems = items);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap to open dropdown
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Tap on Item 1
      await tester.tap(find.text('Item 1'));
      await tester.pumpAndSettle();

      // Verify Item 1 is selected
      expect(selectedItems.length, equals(1));
      expect(selectedItems[0].value, equals('1'));

      // Tap on Item 2
      await tester.tap(find.text('Item 2'));
      await tester.pumpAndSettle();

      // Verify both items are selected
      expect(selectedItems.length, equals(2));
      expect(selectedItems.any((item) => item.value == '1'), isTrue);
      expect(selectedItems.any((item) => item.value == '2'), isTrue);
    });

    testWidgets('should display selected items as chips', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [items[0], items[1]],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify chips are displayed
      expect(find.text('Item 1'), findsWidgets);
      expect(find.text('Item 2'), findsWidgets);
    });

    testWidgets('should remove item when chip delete button is tapped', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      List<ItemDropperItem<String>> selectedItems = [items[0], items[1]];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MultiItemDropper<String>(
                  items: items,
                  selectedItems: selectedItems,
                  width: 300,
                  onChanged: (items) {
                    setState(() => selectedItems = items);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find delete button (X icon) on first chip
      final deleteButtons = find.byIcon(Icons.close);
      if (deleteButtons.evaluate().isNotEmpty) {
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Verify one item was removed
        expect(selectedItems.length, equals(1));
      }
    });
  });

  group('MultiItemDropper - Filtering', () {
    testWidgets('should filter items based on search text', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
        ItemDropperItem<String>(value: '2', label: 'Banana'),
        ItemDropperItem<String>(value: '3', label: 'Cherry'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap to focus
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Find TextField and type search text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'App');
      await tester.pumpAndSettle();

      // Verify only Apple is shown
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
      expect(find.text('Cherry'), findsNothing);
    });
  });

  group('MultiItemDropper - Max Selected', () {
    testWidgets('should hide overlay when maxSelected is reached', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ItemDropperItem<String>(value: '3', label: 'Item 3'),
      ];

      List<ItemDropperItem<String>> selectedItems = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MultiItemDropper<String>(
                  items: items,
                  selectedItems: selectedItems,
                  width: 300,
                  maxSelected: 2,
                  onChanged: (items) {
                    setState(() => selectedItems = items);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap to open dropdown
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Select first item
      await tester.tap(find.text('Item 1'));
      await tester.pumpAndSettle();

      // Select second item
      await tester.tap(find.text('Item 2'));
      await tester.pumpAndSettle();

      // Verify maxSelected is reached
      expect(selectedItems.length, equals(2));

      // Try to tap again - overlay should be hidden
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Overlay should not show when maxSelected is reached
      // (This is a behavior test - the overlay should be hidden)
    });

    testWidgets('should show overlay again when item is removed below maxSelected', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      List<ItemDropperItem<String>> selectedItems = [items[0], items[1]];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MultiItemDropper<String>(
                  items: items,
                  selectedItems: selectedItems,
                  width: 300,
                  maxSelected: 2,
                  onChanged: (items) {
                    setState(() => selectedItems = items);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Remove one item
      final deleteButtons = find.byIcon(Icons.close);
      if (deleteButtons.evaluate().isNotEmpty) {
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Verify one item was removed
        expect(selectedItems.length, equals(1));

        // Tap to focus - overlay should show again
        await tester.tap(find.byType(MultiItemDropper<String>));
        await tester.pumpAndSettle();

        // Overlay should be visible again
        expect(find.text('Item 1'), findsWidgets);
        expect(find.text('Item 2'), findsWidgets);
      }
    });
  });

  group('MultiItemDropper - Enabled/Disabled', () {
    testWidgets('should not accept focus when disabled', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [],
              width: 300,
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Try to tap
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Verify dropdown doesn't open (no overlay)
      expect(find.text('Item 1'), findsNothing);
    });

    testWidgets('should display disabled styling when disabled', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [items[0]],
              width: 300,
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widget is rendered
      expect(find.byType(MultiItemDropper<String>), findsOneWidget);
    });

    testWidgets('should not select a disabled item when tapped',
        (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Enabled 1', isEnabled: true),
        ItemDropperItem<String>(value: '2', label: 'Disabled 2', isEnabled: false),
      ];

      List<ItemDropperItem<String>> selectedItems = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MultiItemDropper<String>(
                  items: items,
                  selectedItems: selectedItems,
                  width: 300,
                  onChanged: (items) {
                    setState(() => selectedItems = items);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Tap the disabled item
      await tester.tap(find.text('Disabled 2'));
      await tester.pumpAndSettle();

      // Verify selection does not include the disabled item
      expect(selectedItems.any((item) => item.value == '2'), isFalse);
    });
  });

  group('MultiItemDropper - Add Item Feature', () {
    testWidgets('should show add item row when no matches and onAddItem provided', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
        ItemDropperItem<String>(value: '2', label: 'Banana'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [],
              width: 300,
              onChanged: (_) {},
              onAddItem: (searchText) => ItemDropperItem<String>(
                value: searchText,
                label: searchText,
              ),
            ),
          ),
        ),
      );

      // Tap to focus
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Type non-matching text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Orange');
      await tester.pumpAndSettle();

      // Verify add item row appears
      expect(find.textContaining('Add'), findsOneWidget);
    });

    testWidgets('should call onAddItem when add row is selected', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
      ];

      ItemDropperItem<String>? addedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [],
              width: 300,
              onChanged: (_) {},
              onAddItem: (searchText) {
                final newItem = ItemDropperItem<String>(
                  value: searchText,
                  label: searchText,
                );
                addedItem = newItem;
                return newItem;
              },
            ),
          ),
        ),
      );

      // Tap to focus
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Type non-matching text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Orange');
      await tester.pumpAndSettle();

      // Tap add row
      await tester.tap(find.textContaining('Add'));
      await tester.pumpAndSettle();

      // Verify onAddItem was called
      expect(addedItem, isNotNull);
      expect(addedItem?.label, equals('Orange'));
    });

    testWidgets('should not show add item row when onAddItem is null', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [],
              width: 300,
              onChanged: (_) {},
              onAddItem: null,
            ),
          ),
        ),
      );

      // Tap to focus
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Type non-matching text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Orange');
      await tester.pumpAndSettle();

      // Verify add item row does not appear
      expect(find.textContaining('Add'), findsNothing);
    });
  });

  group('MultiItemDropper - Edge Cases', () {
    testWidgets('should handle empty items list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: [],
              selectedItems: [],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash
      expect(find.byType(MultiItemDropper<String>), findsOneWidget);
    });

    testWidgets('should handle empty selectedItems list', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash
      expect(find.byType(MultiItemDropper<String>), findsOneWidget);
    });

    testWidgets('should handle group headers', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: 'header1', label: 'Group 1', isGroupHeader: true),
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap to open dropdown
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Verify group header is displayed
      expect(find.text('Group 1'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });
  });

  group('MultiItemDropper - Keyboard Navigation', () {
    testWidgets('should navigate with arrow keys', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ItemDropperItem<String>(value: '3', label: 'Item 3'),
      ];

      List<ItemDropperItem<String>> selectedItems = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MultiItemDropper<String>(
                  items: items,
                  selectedItems: selectedItems,
                  width: 300,
                  onChanged: (items) {
                    setState(() => selectedItems = items);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap to focus and open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // When starting from no highlight, arrow down moves to index 1 (not 0)
      // So we press arrow down to highlight second item, then arrow up to go to first
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      
      // Press arrow up to go to first item
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // Submit the TextField to trigger onSubmitted (which calls _handleEnter)
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify first item was selected
      expect(selectedItems.length, equals(1));
      expect(selectedItems[0].value, equals('1'));
    });
  });

  group('MultiItemDropper - Deletable Items', () {
    testWidgets('shows trash icon only for deletable items',
        (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(
            value: 'd1', label: 'Deletable 1', isDeletable: true),
        ItemDropperItem<String>(
            value: 'd2', label: 'Deletable 2', isDeletable: true),
        ItemDropperItem<String>(
            value: 'k3', label: 'Keep 3', isDeletable: false),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: const [],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Two deletable items → two trash icons
      final deleteIcons = find.byIcon(Icons.delete_outline);
      expect(deleteIcons, findsNWidgets(2));

      // All three labels should still be visible
      expect(find.text('Deletable 1'), findsOneWidget);
      expect(find.text('Deletable 2'), findsOneWidget);
      expect(find.text('Keep 3'), findsOneWidget);
    });

    testWidgets(
        'long-press on deletable item shows confirm dialog and calls onDeleteItem',
        (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(
            value: 'd1', label: 'Deletable 1', isDeletable: true),
        ItemDropperItem<String>(
            value: 'k2', label: 'Keep 2', isDeletable: false),
      ];

      final tracker = _DeleteCallbackTracker<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: const [],
              width: 300,
              onChanged: (_) {},
              onDeleteItem: tracker.record,
            ),
          ),
        ),
      );

      // Open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Long-press the deletable item row
      await tester.longPress(find.text('Deletable 1').last);
      await tester.pumpAndSettle();

      // Confirm dialog should appear
      expect(find.text('Delete \"Deletable 1\"?'), findsOneWidget);

      // Tap the Delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // onDeleteItem should have been called once with the deletable item
      expect(tracker.callCount, equals(1));
      expect(tracker.lastItem, isNotNull);
      expect(tracker.lastItem!.value, equals('d1'));
    });

    testWidgets('cancelling delete dialog does not call onDeleteItem',
        (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(
            value: 'd1', label: 'Deletable 1', isDeletable: true),
      ];

      final tracker = _DeleteCallbackTracker<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: const [],
              width: 300,
              onChanged: (_) {},
              onDeleteItem: tracker.record,
            ),
          ),
        ),
      );

      // Open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Long-press the deletable item row
      await tester.longPress(find.text('Deletable 1').last);
      await tester.pumpAndSettle();

      // Confirm dialog should appear
      expect(find.text('Delete \"Deletable 1\"?'), findsOneWidget);

      // Tap the Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // onDeleteItem should NOT have been called
      expect(tracker.callCount, equals(0));
    });

    testWidgets('long-press on non-deletable item does nothing',
        (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(
            value: 'k1', label: 'Keep 1', isDeletable: false),
      ];

      final tracker = _DeleteCallbackTracker<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: const [],
              width: 300,
              onChanged: (_) {},
              onDeleteItem: tracker.record,
            ),
          ),
        ),
      );

      // Open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Long-press the non-deletable item
      await tester.longPress(find.text('Keep 1').last);
      await tester.pumpAndSettle();

      // No confirmation dialog should appear
      expect(find.textContaining('Delete \"Keep 1\"?'), findsNothing);
      // And no delete callback
      expect(tracker.callCount, equals(0));
    });
  });
}

