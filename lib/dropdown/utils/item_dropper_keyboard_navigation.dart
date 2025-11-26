import 'package:flutter/material.dart';
import '../common/item_dropper_constants.dart';

/// Shared keyboard navigation behavior for dropdowns
class ItemDropperKeyboardNavigation {
  /// Handle arrow down navigation
  static int handleArrowDown(int currentIndex,
      int hoverIndex,
      int itemCount,) {
    if (itemCount == 0) return ItemDropperConstants.kNoHighlight;

    int nextIndex = currentIndex;

    // If no keyboard highlight but hover index exists, start from there
    if (nextIndex == ItemDropperConstants.kNoHighlight &&
        hoverIndex != ItemDropperConstants.kNoHighlight) {
      nextIndex = hoverIndex;
    }

    // Move down (with wrapping to top)
    if (nextIndex < itemCount - 1) {
      nextIndex++;
    } else {
      nextIndex = 0;
    }

    return nextIndex;
  }

  /// Handle arrow up navigation
  static int handleArrowUp(int currentIndex,
      int hoverIndex,
      int itemCount,) {
    if (itemCount == 0) return ItemDropperConstants.kNoHighlight;

    int nextIndex = currentIndex;

    // If no keyboard highlight but hover index exists, start from there
    if (nextIndex == ItemDropperConstants.kNoHighlight &&
        hoverIndex != ItemDropperConstants.kNoHighlight) {
      nextIndex = hoverIndex;
    }

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