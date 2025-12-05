import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/multi/multi_select_overlay_manager.dart';

void main() {
  group('MultiSelectOverlayManager', () {
    late OverlayPortalController controller;
    late MultiSelectOverlayManager manager;
    int onClearHighlightsCallCount = 0;

    setUp(() {
      controller = OverlayPortalController();
      onClearHighlightsCallCount = 0;
      manager = MultiSelectOverlayManager(
        controller: controller,
        onClearHighlights: () => onClearHighlightsCallCount++,
      );
    });

    group('isShowing', () {
      test('returns false initially', () {
        expect(manager.isShowing, isFalse);
      });

      test('returns true after show', () {
        controller.show();
        expect(manager.isShowing, isTrue);
      });

      test('returns false after hide', () {
        controller.show();
        controller.hide();
        expect(manager.isShowing, isFalse);
      });
    });

    group('showIfNeeded', () {
      test('shows overlay when not showing', () {
        manager.showIfNeeded();
        expect(manager.isShowing, isTrue);
      });

      test('clears highlights when showing', () {
        manager.showIfNeeded();
        expect(onClearHighlightsCallCount, equals(1));
      });

      test('does nothing if already showing', () {
        controller.show();
        onClearHighlightsCallCount = 0;

        manager.showIfNeeded();

        expect(onClearHighlightsCallCount, equals(0));
      });
    });

    group('hideIfNeeded', () {
      test('hides overlay when showing', () {
        controller.show();

        manager.hideIfNeeded();

        expect(manager.isShowing, isFalse);
      });

      test('does nothing if not showing', () {
        // Should not throw
        manager.hideIfNeeded();
        expect(manager.isShowing, isFalse);
      });
    });

    group('showIfFocusedAndBelowMax', () {
      final items = [
        ItemDropperItem<String>(value: '1', label: 'Item 1'),
        ItemDropperItem<String>(value: '2', label: 'Item 2'),
      ];

      test('shows when focused, below max, and has items', () {
        manager.showIfFocusedAndBelowMax<String>(
          isFocused: true,
          isBelowMax: true,
          filteredItems: items,
        );

        expect(manager.isShowing, isTrue);
      });

      test('clears highlights when showing', () {
        manager.showIfFocusedAndBelowMax<String>(
          isFocused: true,
          isBelowMax: true,
          filteredItems: items,
        );

        expect(onClearHighlightsCallCount, equals(1));
      });

      test('does not show when not focused', () {
        manager.showIfFocusedAndBelowMax<String>(
          isFocused: false,
          isBelowMax: true,
          filteredItems: items,
        );

        expect(manager.isShowing, isFalse);
      });

      test('does not show when max reached', () {
        manager.showIfFocusedAndBelowMax<String>(
          isFocused: true,
          isBelowMax: false,
          filteredItems: items,
        );

        expect(manager.isShowing, isFalse);
      });

      test('does not show when items list is empty', () {
        manager.showIfFocusedAndBelowMax<String>(
          isFocused: true,
          isBelowMax: true,
          filteredItems: [],
        );

        expect(manager.isShowing, isFalse);
      });

      test('does nothing if already showing', () {
        controller.show();
        onClearHighlightsCallCount = 0;

        manager.showIfFocusedAndBelowMax<String>(
          isFocused: true,
          isBelowMax: true,
          filteredItems: items,
        );

        expect(onClearHighlightsCallCount, equals(0));
      });
    });

    group('Complex state transitions', () {
      test('can show, hide, and show again', () {
        manager.showIfNeeded();
        expect(manager.isShowing, isTrue);

        manager.hideIfNeeded();
        expect(manager.isShowing, isFalse);

        manager.showIfNeeded();
        expect(manager.isShowing, isTrue);
      });

      test('multiple hide calls are safe', () {
        manager.showIfNeeded();
        manager.hideIfNeeded();
        manager.hideIfNeeded();
        manager.hideIfNeeded();

        expect(manager.isShowing, isFalse);
      });

      test('multiple show calls only clear highlights once', () {
        manager.showIfNeeded();
        onClearHighlightsCallCount = 0;

        manager.showIfNeeded();
        manager.showIfNeeded();

        expect(onClearHighlightsCallCount, equals(0));
      });
    });
  });
}
