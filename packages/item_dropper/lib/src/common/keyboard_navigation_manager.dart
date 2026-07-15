import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'item_dropper_common.dart';

/// Manages keyboard navigation state, event dispatch, and scroll side effects.
///
/// Pure key/index decisions live in [ItemDropperKeyboardNavigation]. This
/// manager stores the current highlight/hover state, invokes callbacks, and
/// keeps the highlighted row in view.
///
/// Example usage:
/// ```dart
/// final manager = KeyboardNavigationManager(
///   onRequestRebuild: () => setState(() {}),
///   onEscape: () => _focusNode.unfocus(),
/// );
///
/// // In initState:
/// _focusNode.onKeyEvent = manager.handleKeyEvent;
///
/// // Access state:
/// final highlightedIndex = manager.keyboardHighlightIndex;
/// ```
class KeyboardNavigationManager<T> {
  /// Current keyboard-highlighted item index (-1 if none)
  int _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;

  /// Current hover-highlighted item index (-1 if none)
  ///
  /// Can be read and written by external code to track mouse hover state.
  int hoverIndex = ItemDropperConstants.kNoHighlight;

  /// Callback to trigger widget rebuild
  final VoidCallback onRequestRebuild;

  /// Callback when Escape key is pressed
  final VoidCallback onEscape;

  /// Callback when Space or Enter is pressed (for opening dropdown)
  final VoidCallback? onOpenDropdown;

  KeyboardNavigationManager({
    required this.onRequestRebuild,
    required this.onEscape,
    this.onOpenDropdown,
  });

  /// Current keyboard highlight index (read-only)
  int get keyboardHighlightIndex => _keyboardHighlightIndex;

  /// Handles keyboard events (Arrow keys, Escape, Space, Enter)
  ///
  /// Returns [KeyEventResult.handled] if the key was processed,
  /// [KeyEventResult.ignored] otherwise.
  KeyEventResult handleKeyEvent({
    required KeyEvent event,
    required List<ItemDropperItem<T>> filteredItems,
    required ScrollController scrollController,
    required bool mounted,
    required bool isDropdownOpen,
  }) {
    // Handle both KeyDownEvent (initial press) and KeyRepeatEvent (auto-repeat when held)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      handleArrowDown(
        filteredItems: filteredItems,
        scrollController: scrollController,
        mounted: mounted,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      handleArrowUp(
        filteredItems: filteredItems,
        scrollController: scrollController,
        mounted: mounted,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      onEscape();
      return KeyEventResult.handled;
    } else if (ItemDropperKeyboardNavigation.isOpenDropdownKey(
          event.logicalKey,
        ) &&
        !isDropdownOpen &&
        onOpenDropdown != null) {
      // Space or Enter to open dropdown when closed
      // Only handle if text is empty or cursor is at start (to allow normal text input)
      // Note: This check should be done by the caller before calling handleKeyEvent
      onOpenDropdown!();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Handles arrow down key press
  void handleArrowDown({
    required List<ItemDropperItem<T>> filteredItems,
    required ScrollController scrollController,
    required bool mounted,
  }) {
    _keyboardHighlightIndex =
        ItemDropperKeyboardNavigation.nextIndexForArrowDown<T>(
          currentIndex: _keyboardHighlightIndex,
          hoverIndex: hoverIndex,
          items: filteredItems,
        );

    _afterHighlightChanged(
      scrollController: scrollController,
      mounted: mounted,
    );
  }

  /// Handles arrow up key press
  void handleArrowUp({
    required List<ItemDropperItem<T>> filteredItems,
    required ScrollController scrollController,
    required bool mounted,
  }) {
    _keyboardHighlightIndex =
        ItemDropperKeyboardNavigation.nextIndexForArrowUp<T>(
          currentIndex: _keyboardHighlightIndex,
          hoverIndex: hoverIndex,
          items: filteredItems,
        );

    _afterHighlightChanged(
      scrollController: scrollController,
      mounted: mounted,
    );
  }

  void _afterHighlightChanged({
    required ScrollController scrollController,
    required bool mounted,
  }) {
    hoverIndex = ItemDropperConstants.kNoHighlight;
    onRequestRebuild();
    _scrollToHighlight(scrollController: scrollController, mounted: mounted);
  }

  void _scrollToHighlight({
    required ScrollController scrollController,
    required bool mounted,
  }) {
    if (_keyboardHighlightIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        if (scrollController.hasClients &&
            scrollController.position.hasContentDimensions) {
          final double itemTop =
              _keyboardHighlightIndex *
              ItemDropperConstants.kDropdownItemHeight;
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

  /// Clears both keyboard and hover highlights
  void clearHighlights() {
    _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
    hoverIndex = ItemDropperConstants.kNoHighlight;
  }
}
