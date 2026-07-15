import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/item_dropper_common.dart';
import 'package:item_dropper/src/multi/multi_select_highlight_policy.dart';

void main() {
  group('MultiSelectHighlightPolicy', () {
    const policy = MultiSelectHighlightPolicy();

    test(
      'clears highlights and hides overlay when no filtered items remain',
      () {
        final result = policy.afterSelectionChange(
          wasKeyboardActive: false,
          previousHoverIndex: 0,
          remainingFilteredItemCount: 0,
        );

        expect(result.clearHighlights, isTrue);
        expect(result.hoverIndex, isNull);
        expect(result.hideOverlay, isTrue);
      },
    );

    test('clears highlights when keyboard navigation was active', () {
      final result = policy.afterSelectionChange(
        wasKeyboardActive: true,
        previousHoverIndex: 0,
        remainingFilteredItemCount: 3,
      );

      expect(result.clearHighlights, isTrue);
      expect(result.hoverIndex, isNull);
      expect(result.hideOverlay, isFalse);
    });

    test(
      'preserves valid hover index when keyboard navigation was inactive',
      () {
        final result = policy.afterSelectionChange(
          wasKeyboardActive: false,
          previousHoverIndex: 1,
          remainingFilteredItemCount: 3,
        );

        expect(result.clearHighlights, isFalse);
        expect(result.hoverIndex, 1);
        expect(result.hideOverlay, isFalse);
      },
    );

    test('clears stale hover index', () {
      final result = policy.afterSelectionChange(
        wasKeyboardActive: false,
        previousHoverIndex: 3,
        remainingFilteredItemCount: 3,
      );

      expect(result.clearHighlights, isTrue);
      expect(result.hoverIndex, isNull);
      expect(result.hideOverlay, isFalse);
    });

    test('identifies keyboard active sentinel', () {
      expect(
        policy.isKeyboardActive(ItemDropperConstants.kNoHighlight),
        isFalse,
      );
      expect(policy.isKeyboardActive(0), isTrue);
    });
  });
}
