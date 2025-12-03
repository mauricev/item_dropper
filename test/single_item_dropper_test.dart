import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropdown_tester/dropdown/item_dropper_single_select.dart';
import 'package:dropdown_tester/dropdown/common/item_dropper_item.dart';

/// Helper class to track callback invocations across widget rebuilds
class _CallbackTracker<T> {
  bool wasCalledWithNull = false;
  T? lastValue;
  int callCount = 0;
  
  void record(T? value) {
    callCount++;
    lastValue = value;
    wasCalledWithNull = (value == null);
  }
}

void main() {
  group('SingleItemDropper - Basic Functionality', () {
    testWidgets('should display items list', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ItemDropperItem<String>(value: '3', label: 'Item 3'),
      ];

      ItemDropperItem<String>? selectedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              onChanged: (item) => selectedItem = item,
            ),
          ),
        ),
      );

      // Tap to open dropdown
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Verify items are displayed
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('should select an item when tapped', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      ItemDropperItem<String>? selectedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              onChanged: (item) => selectedItem = item,
            ),
          ),
        ),
      );

      // Tap to open dropdown
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Tap on Item 1
      await tester.tap(find.text('Item 1'));
      await tester.pumpAndSettle();

      // Verify selection
      expect(selectedItem?.value, equals('1'));
      expect(selectedItem?.label, equals('Item 1'));
    });

    testWidgets('should display selected item in text field', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              selectedItem: items[0],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify selected item is displayed
      expect(find.text('Item 1'), findsWidgets);
    });

    testWidgets('should clear selection when clear button is tapped', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      ItemDropperItem<String>? selectedItem = items[0];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleItemDropper<String>(
                  items: items,
                  selectedItem: selectedItem,
                  width: 300,
                  onChanged: (item) {
                    setState(() => selectedItem = item);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state: TextField shows the selected item
      final textField = find.byType(TextField);
      expect(tester.widget<TextField>(textField).controller?.text, equals('Item 1'));
      
      // Focus the field first (clear button may need focus to be enabled)
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();
      
      // Find clear button
      final clearIcon = find.byIcon(Icons.clear);
      expect(clearIcon, findsOneWidget);
      
      final iconButtonFinder = find.ancestor(
        of: clearIcon,
        matching: find.byType(IconButton),
      );
      expect(iconButtonFinder, findsOneWidget);
      
      await tester.ensureVisible(iconButtonFinder);
      await tester.pumpAndSettle();
      
      // Verify button is enabled before invoking
      final iconButton = tester.widget<IconButton>(iconButtonFinder);
      if (iconButton.onPressed != null) {
        // Call the clear handler directly to avoid hit-test flakiness in tests
        iconButton.onPressed!();
        await tester.pumpAndSettle();

        // Verify observable UI change: TextField text is cleared
        final controllerText = tester.widget<TextField>(textField).controller?.text ?? '';
        expect(controllerText, isEmpty, 
          reason: 'TextField should be empty after tapping clear button. Current text: "$controllerText"');
      } else {
        // If button is disabled, call onPressed directly to test the functionality
        // This tests the clear logic even if the button state isn't correct in tests
        fail('Clear button should be enabled when an item is selected');
      }
    });
  });

  group('SingleItemDropper - Filtering', () {
    testWidgets('should filter items based on search text', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
        ItemDropperItem<String>(value: '2', label: 'Banana'),
        ItemDropperItem<String>(value: '3', label: 'Cherry'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              showKeyboard: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap to focus
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Type 'App' to filter
      await tester.enterText(find.byType(TextField), 'App');
      await tester.pumpAndSettle();

      // Verify only Apple is shown
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
      expect(find.text('Cherry'), findsNothing);
    });

    testWidgets('should show all items when search is cleared', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
        ItemDropperItem<String>(value: '2', label: 'Banana'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              showKeyboard: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap to focus
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Type search text
      await tester.enterText(find.byType(TextField), 'App');
      await tester.pumpAndSettle();

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Verify all items are shown
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
    });
  });

  group('SingleItemDropper - Enabled/Disabled', () {
    testWidgets('should not accept focus when disabled', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Try to tap
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Verify dropdown doesn't open (no overlay)
      // The overlay should not be built when disabled
      expect(find.text('Item 1'), findsNothing);
    });

    testWidgets('should display disabled styling when disabled', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              selectedItem: items[0],
              width: 300,
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widget is rendered (visual check would show greyed out)
      expect(find.byType(SingleItemDropper<String>), findsOneWidget);
    });
  });

  group('SingleItemDropper - Add Item Feature', () {
    testWidgets('should show add item row when no matches and onAddItem provided', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Apple'),
        ItemDropperItem<String>(value: '2', label: 'Banana'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              showKeyboard: true,
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
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Type non-matching text
      await tester.enterText(find.byType(TextField), 'Orange');
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
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              showKeyboard: true,
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
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Type non-matching text
      await tester.enterText(find.byType(TextField), 'Orange');
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
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              showKeyboard: true,
              onChanged: (_) {},
              onAddItem: null,
            ),
          ),
        ),
      );

      // Tap to focus
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Type non-matching text
      await tester.enterText(find.byType(TextField), 'Orange');
      await tester.pumpAndSettle();

      // Verify add item row does not appear
      expect(find.textContaining('Add'), findsNothing);
    });
  });

  group('SingleItemDropper - Edge Cases', () {
    testWidgets('should handle empty items list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: [],
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash
      expect(find.byType(SingleItemDropper<String>), findsOneWidget);
    });

    testWidgets('should handle null selectedItem', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: items,
              selectedItem: null,
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash
      expect(find.byType(SingleItemDropper<String>), findsOneWidget);
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
            body: SingleItemDropper<String>(
              items: items,
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap to open dropdown
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // Verify group header is displayed
      expect(find.text('Group 1'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });
  });

  group('SingleItemDropper - Keyboard Navigation', () {
    testWidgets('should navigate with arrow keys', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
        ItemDropperItem<String>(value: '3', label: 'Item 3'),
      ];

      ItemDropperItem<String>? selectedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleItemDropper<String>(
                  items: items,
                  width: 300,
                  showKeyboard: true,
                  onChanged: (item) {
                    setState(() => selectedItem = item);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap to focus and open overlay
      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      // When starting from no highlight, arrow down moves to index 1 (not 0)
      // So we press arrow down to highlight second item, then arrow up to go to first
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      
      // Press arrow up to go to first item
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // Submit the TextField to trigger onSubmitted (which calls _handleSubmit)
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify first item was selected
      expect(selectedItem?.value, equals('1'));
    });
  });
}

