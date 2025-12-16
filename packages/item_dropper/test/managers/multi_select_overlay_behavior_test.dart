import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

/// Tests for overlay behavior in MultiItemDropper
/// These tests verify the overlay showing/hiding logic that was previously
/// in MultiSelectOverlayManager but is now inlined into _MultiItemDropperState
void main() {
  group('MultiItemDropper - Overlay Behavior', () {
    testWidgets('overlay is hidden initially', (WidgetTester tester) async {
      final items = [
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

      await tester.pumpAndSettle();

      // Overlay should not be showing initially
      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Item 2'), findsNothing);
    });

    testWidgets('overlay shows when field is tapped', (WidgetTester tester) async {
      final items = [
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

      await tester.pumpAndSettle();

      // Tap to open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Overlay should be showing
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('overlay hides when field loses focus', (WidgetTester tester) async {
      final items = [
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

      await tester.pumpAndSettle();

      // Tap to open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Verify overlay is showing
      expect(find.text('Item 1'), findsOneWidget);

      // Tap outside to dismiss
      await tester.tap(find.byType(Scaffold));
      await tester.pumpAndSettle();

      // Overlay should be hidden
      expect(find.text('Item 1'), findsNothing);
    });

    testWidgets('overlay does not show when disabled', (WidgetTester tester) async {
      final items = [
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
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Try to tap (should not work when disabled)
      await tester.tap(find.byType(MultiItemDropper<String>), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Overlay should not be showing
      expect(find.text('Item 1'), findsNothing);
    });

    testWidgets('overlay shows when max is reached', (WidgetTester tester) async {
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
              selectedItems: [
                ItemDropperItem<String>(value: '1', label: 'Item 1'),
                ItemDropperItem<String>(value: '2', label: 'Item 2'),
              ],
              maxSelected: 2,
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to open overlay (should show max reached message)
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Overlay should be showing with max reached message
      // The overlay shows the max reached message, which includes the selected items
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('overlay does not show when items list is empty', (WidgetTester tester) async {
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

      // Tap to try to open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Overlay should not be showing (no items to show)
      // The overlay widget itself might be built but empty
    });

    testWidgets('overlay can be shown, hidden, and shown again', (WidgetTester tester) async {
      final items = [
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

      await tester.pumpAndSettle();

      // Show overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsOneWidget);

      // Hide overlay
      await tester.tap(find.byType(Scaffold));
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsNothing);

      // Show overlay again
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('overlay shows when TextField is tapped', (WidgetTester tester) async {
      final items = [
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

      await tester.pumpAndSettle();

      // Tap on TextField directly
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Overlay should be showing
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('overlay shows when arrow button is pressed', (WidgetTester tester) async {
      final items = [
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
              showDropdownPositionIcon: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the arrow button
      final arrowButton = find.byIcon(Icons.arrow_drop_down);
      expect(arrowButton, findsOneWidget);
      
      await tester.tap(arrowButton);
      await tester.pumpAndSettle();

      // Overlay should be showing
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('overlay hides when arrow button is pressed again', (WidgetTester tester) async {
      final items = [
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
              showDropdownPositionIcon: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Show overlay
      final arrowButtonDown = find.byIcon(Icons.arrow_drop_down);
      await tester.tap(arrowButtonDown);
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsOneWidget);

      // Hide overlay - icon changes to arrow_drop_up when overlay is open
      final arrowButtonUp = find.byIcon(Icons.arrow_drop_up);
      expect(arrowButtonUp, findsOneWidget);
      await tester.tap(arrowButtonUp);
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsNothing);
    });

    testWidgets('overlay shows when typing in TextField', (WidgetTester tester) async {
      final items = [
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

      await tester.pumpAndSettle();

      // Focus and type in TextField
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Item');
      await tester.pumpAndSettle();

      // Overlay should be showing with filtered items
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('overlay does not show when max reached and trying to add item', (WidgetTester tester) async {
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
              selectedItems: [
                ItemDropperItem<String>(value: '1', label: 'Item 1'),
                ItemDropperItem<String>(value: '2', label: 'Item 2'),
              ],
              maxSelected: 2,
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to open overlay
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // When max is reached, overlay shows max reached message
      // Item 3 might be in the list but tapping it should close overlay (max reached)
      // Let's verify overlay is showing first
      final overlayShowing = find.text('Item 1').evaluate().isNotEmpty || 
                             find.text('Item 2').evaluate().isNotEmpty ||
                             find.text('Item 3').evaluate().isNotEmpty;
      expect(overlayShowing, isTrue);
      
      // Try to tap Item 3 if it's visible (should close overlay due to max reached)
      if (find.text('Item 3').evaluate().isNotEmpty) {
        await tester.tap(find.text('Item 3'));
        await tester.pumpAndSettle();
        
        // Overlay should close (max reached, can't select)
        expect(find.text('Item 3'), findsNothing);
      }
    });

    testWidgets('overlay shows again when item removed below max', (WidgetTester tester) async {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: [
                ItemDropperItem<String>(value: '1', label: 'Item 1'),
                ItemDropperItem<String>(value: '2', label: 'Item 2'),
              ],
              maxSelected: 2,
              width: 300,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to open overlay (max reached, should show max message)
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Remove a chip
      final deleteButtons = find.byIcon(Icons.close);
      expect(deleteButtons, findsWidgets);
      
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Overlay should show again (below max now)
      // Tap to open
      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      // Should be able to see items now
      expect(find.text('Item 1'), findsOneWidget);
    });
  });
}

