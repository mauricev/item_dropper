import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'item_dropper_common.dart';

/// Manages keyboard navigation state and event handling for dropdown widgets.
/// 
/// Handles arrow key navigation, highlight state, and keyboard event processing.
/// Provides a unified interface for both single-select and multi-select dropdowns.
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

  KeyboardNavigationManager({
    required this.onRequestRebuild,
    required this.onEscape,
  });

  /// Current keyboard highlight index (read-only)
  int get keyboardHighlightIndex => _keyboardHighlightIndex;

  /// Handles keyboard events (Arrow keys, Escape)
  /// 
  /// Returns [KeyEventResult.handled] if the key was processed,
  /// [KeyEventResult.ignored] otherwise.
  KeyEventResult handleKeyEvent({
    required KeyEvent event,
    required List<ItemDropperItem<T>> filteredItems,
    required ScrollController scrollController,
    required bool mounted,
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
    }

    return KeyEventResult.ignored;
  }

  /// Handles arrow down key press
  void handleArrowDown({
    required List<ItemDropperItem<T>> filteredItems,
    required ScrollController scrollController,
    required bool mounted,
  }) {
    _keyboardHighlightIndex = ItemDropperKeyboardNavigation.handleArrowDown<T>(
      currentIndex: _keyboardHighlightIndex,
      hoverIndex: hoverIndex,
      itemCount: filteredItems.length,
      items: filteredItems,
    );

    // Clear hover when keyboard nav becomes active
    hoverIndex = ItemDropperConstants.kNoHighlight;
    onRequestRebuild();

    // Scroll to highlighted item
    ItemDropperKeyboardNavigation.scrollToHighlight(
      highlightIndex: _keyboardHighlightIndex,
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
    _keyboardHighlightIndex = ItemDropperKeyboardNavigation.handleArrowUp<T>(
      currentIndex: _keyboardHighlightIndex,
      hoverIndex: hoverIndex,
      itemCount: filteredItems.length,
      items: filteredItems,
    );

    // Clear hover when keyboard nav becomes active
    hoverIndex = ItemDropperConstants.kNoHighlight;
    onRequestRebuild();

    // Scroll to highlighted item
    ItemDropperKeyboardNavigation.scrollToHighlight(
      highlightIndex: _keyboardHighlightIndex,
      scrollController: scrollController,
      mounted: mounted,
    );
  }

  /// Clears both keyboard and hover highlights
  void clearHighlights() {
    _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
    hoverIndex = ItemDropperConstants.kNoHighlight;
  }
}
