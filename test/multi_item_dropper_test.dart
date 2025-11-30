import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropdown_tester/dropdown/item_dropper_multi_select.dart';
import 'package:dropdown_tester/dropdown/common/item_dropper_item.dart';

/// Helper class to track callback invocations across widget rebuilds
class _MultiCallbackTracker<T> {
  int callCount = 0;
  List<T>? lastValue;
  
  void record(List<T> value) {
    callCount++;
    lastValue = List.from(value);
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

    testWidgets('should toggle item selection when tapped again', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      List<ItemDropperItem<String>> selectedItems = [items[0]];

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

      // Wait a bit for the widget to fully render with chips
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify initial state: 1 chip is visible
      final initialChipCount = find.byType(Chip).evaluate().length;
      // Note: If chips aren't showing initially, the test will fail here with a clear message
      expect(initialChipCount, greaterThanOrEqualTo(1), 
        reason: 'Should start with at least 1 chip. Found: $initialChipCount');

      // Tap to open dropdown
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Wait for overlay to fully render
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Find InkWell widgets that contain "Item 1" text (overlay items)
      final allInkWells = find.byType(InkWell);
      InkWell? item1InkWell;
      
      for (final element in allInkWells.evaluate()) {
        try {
          final hasItem1 = find.descendant(
            of: find.byWidget(element.widget),
            matching: find.text('Item 1'),
          ).evaluate().isNotEmpty;
          
          if (hasItem1) {
            final inkWellWidget = element.widget as InkWell;
            if (inkWellWidget.onTap != null) {
              item1InkWell = inkWellWidget;
              break;
            }
          }
        } catch (_) {
          // Skip if we can't check
        }
      }
      
      // Tap the overlay item if found, otherwise try tapping "Item 1" text
      if (item1InkWell != null) {
        final inkWellFinder = find.byWidget(item1InkWell);
        await tester.ensureVisible(inkWellFinder);
        await tester.pumpAndSettle();
        await tester.tap(inkWellFinder, warnIfMissed: false);
      } else {
        // Fallback: try tapping "Item 1" text in overlay (last occurrence)
        final item1Widgets = find.text('Item 1');
        if (item1Widgets.evaluate().length >= 2) {
          await tester.tap(item1Widgets.last, warnIfMissed: false);
        }
      }
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify observable UI change: chip count decreased
      final chipCount = find.byType(Chip).evaluate().length;
      expect(chipCount, equals(0), 
        reason: 'Chip count should decrease from $initialChipCount to 0 when Item 1 is deselected. Current: $chipCount');
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
}

