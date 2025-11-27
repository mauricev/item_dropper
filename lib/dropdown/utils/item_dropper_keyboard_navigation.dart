import 'package:flutter/material.dart';
import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';

/// Shared keyboard navigation behavior for dropdowns
class ItemDropperKeyboardNavigation {
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
  /// Handle arrow down navigation
  /// 
  /// [items] is required to check for group headers and skip them.
  /// If [items] is null, falls back to old behavior (for backward compatibility).
  static int handleArrowDown<T>({
    required int currentIndex,
    required int hoverIndex,
    required int itemCount,
    List<ItemDropperItem<T>>? items,
  }) {
    if (itemCount == 0) return ItemDropperConstants.kNoHighlight;

    int nextIndex = currentIndex;

    // If no keyboard highlight but hover index exists, start from there
    if (nextIndex == ItemDropperConstants.kNoHighlight &&
        hoverIndex != ItemDropperConstants.kNoHighlight) {
      nextIndex = hoverIndex;
    }

    // If items list is provided, use new logic that skips group headers
    if (items != null) {
      // Ensure we start from a valid index
      if (nextIndex == ItemDropperConstants.kNoHighlight) {
        nextIndex = 0;
      }
      // Find next selectable item, skipping group headers
      return findNextSelectableIndex<T>(
        currentIndex: nextIndex,
        items: items,
        goingDown: true,
      );
    }

    // Fallback to old behavior (backward compatibility)
    // Move down (with wrapping to top)
    if (nextIndex < itemCount - 1) {
      nextIndex++;
    } else {
      nextIndex = 0;
    }

    return nextIndex;
  }

  /// Handle arrow up navigation
  /// 
  /// [items] is required to check for group headers and skip them.
  /// If [items] is null, falls back to old behavior (for backward compatibility).
  static int handleArrowUp<T>({
    required int currentIndex,
    required int hoverIndex,
    required int itemCount,
    List<ItemDropperItem<T>>? items,
  }) {
    if (itemCount == 0) return ItemDropperConstants.kNoHighlight;

    int nextIndex = currentIndex;

    // If no keyboard highlight but hover index exists, start from there
    if (nextIndex == ItemDropperConstants.kNoHighlight &&
        hoverIndex != ItemDropperConstants.kNoHighlight) {
      nextIndex = hoverIndex;
    }

    // If items list is provided, use new logic that skips group headers
    if (items != null) {
      // Ensure we start from a valid index
      if (nextIndex == ItemDropperConstants.kNoHighlight) {
        nextIndex = itemCount - 1;
      }
      // Find previous selectable item, skipping group headers
      return findNextSelectableIndex<T>(
        currentIndex: nextIndex,
        items: items,
        goingDown: false,
      );
    }

    // Fallback to old behavior (backward compatibility)
    // Move up (with wrapping to bottom)
    if (nextIndex > 0) {
      nextIndex--;
    } else {
      nextIndex = itemCount - 1;
    }

    return nextIndex;
  }

  /// Scroll to make the highlighted item visible
  static void scrollToHighlight({
    required int highlightIndex,
    required ScrollController scrollController,
    required bool mounted,
  }) {
    if (highlightIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        if (scrollController.hasClients &&
            scrollController.position.hasContentDimensions) {
          final double itemTop =
              highlightIndex * ItemDropperConstants.kDropdownItemHeight;
          final double itemBottom =
              itemTop + ItemDropperConstants.kDropdownItemHeight;
          final double viewportStart = scrollController.offset;
          final double viewportEnd =
              viewportStart + scrollController.position.viewportDimension;

          if (itemTop < viewportStart) {
            scrollController.animateTo(
              itemTop,
              duration: ItemDropperConstants.kScrollAnimationDuration,
              curve: Curves.easeInOut,
            );
          } else if (itemBottom > viewportEnd) {
            scrollController.animateTo(
              itemBottom - scrollController.position.viewportDimension,
              duration: ItemDropperConstants.kScrollAnimationDuration,
              curve: Curves.easeInOut,
            );
          }
        }
      } catch (e) {
        debugPrint('[KEYBOARD NAV] Scroll failed: $e');
      }
    });
  }
}