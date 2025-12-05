import 'package:flutter/material.dart';
import '../common/item_dropper_item.dart';

/// Manages overlay visibility for multi-select dropdown
class MultiSelectOverlayManager {
  final OverlayPortalController controller;
  final VoidCallback onClearHighlights;

  MultiSelectOverlayManager({
    required this.controller,
    required this.onClearHighlights,
  });

  /// Check if overlay is currently showing
  bool get isShowing => controller.isShowing;

  /// Show overlay if not already showing
  void showIfNeeded() {
    if (!controller.isShowing) {
      onClearHighlights();
      controller.show();
    }
  }

  /// Hide overlay if currently showing
  void hideIfNeeded() {
    if (controller.isShowing) {
      controller.hide();
    }
  }

  /// Show overlay if conditions are met: focused and below max selection
  void showIfFocusedAndBelowMax<T>({
    required bool isFocused,
    required bool isBelowMax,
    required List<ItemDropperItem<T>> filteredItems,
  }) {
    if (isFocused && isBelowMax) {
      if (!controller.isShowing && filteredItems.isNotEmpty) {
        onClearHighlights();
        controller.show();
      }
    }
  }
}
