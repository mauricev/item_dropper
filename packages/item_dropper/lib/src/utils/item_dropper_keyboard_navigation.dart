import 'package:flutter/services.dart';
import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';

/// Pure keyboard-navigation decisions for dropdowns.
///
/// This class does not mutate widget state, request rebuilds, or scroll. The
/// stateful [KeyboardNavigationManager] owns those side effects.
class ItemDropperKeyboardNavigation {
  /// Whether [logicalKey] is used to open a closed dropdown.
  static bool isOpenDropdownKey(LogicalKeyboardKey logicalKey) {
    return logicalKey == LogicalKeyboardKey.space ||
        logicalKey == LogicalKeyboardKey.enter;
  }

  /// Whether Space/Enter should open the dropdown instead of being handled by
  /// the text field.
  static bool shouldOpenDropdownOnKey({
    required LogicalKeyboardKey logicalKey,
    required bool isDropdownOpen,
    required String text,
    required TextSelection selection,
  }) {
    return !isDropdownOpen &&
        isOpenDropdownKey(logicalKey) &&
        (text.isEmpty || selection.baseOffset == 0);
  }

  /// Find the next selectable item index, skipping group headers
  static int findNextSelectableIndex<T>({
    required int currentIndex,
    required List<ItemDropperItem<T>> items,
    required bool goingDown,
  }) {
    if (items.isEmpty) return ItemDropperConstants.kNoHighlight;

    int nextIndex = currentIndex;
    final int itemCount = items.length;
    int attempts = 0;
    final int maxAttempts = itemCount; // Prevent infinite loop

    // Find next selectable item
    while (attempts < maxAttempts) {
      if (goingDown) {
        nextIndex = (nextIndex + 1) % itemCount; // Wrap around
      } else {
        nextIndex = (nextIndex - 1 + itemCount) % itemCount; // Wrap around
      }

      // If we found a selectable item, return it
      if (!items[nextIndex].isGroupHeader) {
        return nextIndex;
      }

      attempts++;
    }

    // If all items are group headers, return no highlight
    return ItemDropperConstants.kNoHighlight;
  }

  /// Returns the next highlighted index for arrow-down navigation.
  static int nextIndexForArrowDown<T>({
    required int currentIndex,
    required int hoverIndex,
    required List<ItemDropperItem<T>> items,
  }) {
    return _nextIndexForArrow<T>(
      currentIndex: currentIndex,
      hoverIndex: hoverIndex,
      itemCount: items.length,
      items: items,
      goingDown: true,
    );
  }

  /// Returns the next highlighted index for arrow-up navigation.
  static int nextIndexForArrowUp<T>({
    required int currentIndex,
    required int hoverIndex,
    required List<ItemDropperItem<T>> items,
  }) {
    return _nextIndexForArrow<T>(
      currentIndex: currentIndex,
      hoverIndex: hoverIndex,
      itemCount: items.length,
      items: items,
      goingDown: false,
    );
  }

  static int _nextIndexForArrow<T>({
    required int currentIndex,
    required int hoverIndex,
    required int itemCount,
    required List<ItemDropperItem<T>> items,
    required bool goingDown,
  }) {
    if (itemCount == 0) return ItemDropperConstants.kNoHighlight;

    int nextIndex = currentIndex;

    // If no keyboard highlight but hover index exists, start from there
    if (nextIndex == ItemDropperConstants.kNoHighlight &&
        hoverIndex != ItemDropperConstants.kNoHighlight) {
      nextIndex = hoverIndex;
    }

    if (nextIndex == ItemDropperConstants.kNoHighlight) {
      nextIndex = goingDown ? 0 : itemCount - 1;
    }

    return findNextSelectableIndex<T>(
      currentIndex: nextIndex,
      items: items,
      goingDown: goingDown,
    );
  }
}
