import 'package:flutter/material.dart';

import '../multi/multi_select_chip_focus_node_controller.dart';
import '../multi/multi_select_chip_layout_controller.dart';
import '../multi/multi_select_filter_controller.dart';
import '../multi/multi_select_focus_manager.dart';
import '../multi/multi_select_highlight_policy.dart';
import '../multi/multi_select_selection_manager.dart';
import '../utils/item_dropper_filter_utils.dart';
import 'decoration_cache_manager.dart';
import 'item_dropper_item.dart';
import 'keyboard_navigation_manager.dart';
import 'live_region_manager.dart';

/// Factory hooks used to construct `SingleItemDropper` collaborators.
///
/// Applications normally use the defaults. Subclass this type to replace a
/// collaborator in focused tests or advanced integrations.
class SingleItemDropperDependencies<T> {
  const SingleItemDropperDependencies();

  /// Creates the filtering utility.
  ItemDropperFilterUtils<T> createFilterUtils() {
    return ItemDropperFilterUtils<T>();
  }

  /// Creates the keyboard-navigation manager.
  KeyboardNavigationManager<T> createKeyboardNavigationManager({
    required VoidCallback onRequestRebuild,
    required VoidCallback onEscape,
    required VoidCallback onOpenDropdown,
  }) {
    return KeyboardNavigationManager<T>(
      onRequestRebuild: onRequestRebuild,
      onEscape: onEscape,
      onOpenDropdown: onOpenDropdown,
    );
  }

  /// Creates the field-decoration cache.
  DecorationCacheManager createDecorationCacheManager() {
    return DecorationCacheManager();
  }

  /// Creates the accessibility live-region manager.
  LiveRegionManager createLiveRegionManager({required VoidCallback onUpdate}) {
    return LiveRegionManager(onUpdate: onUpdate);
  }
}

/// Factory hooks used to construct `MultiItemDropper` collaborators.
///
/// Applications normally use the defaults. Subclass this type to replace a
/// collaborator in focused tests or advanced integrations.
class MultiItemDropperDependencies<T> {
  const MultiItemDropperDependencies();

  /// Creates the text-field and chip focus manager.
  MultiSelectFocusManager<T> createFocusManager({
    required FocusNode focusNode,
    required VoidCallback onFocusVisualStateChanged,
    required VoidCallback onFocusChanged,
    required void Function(ItemDropperItem<T> item) onRemoveChip,
  }) {
    return MultiSelectFocusManager<T>(
      focusNode: focusNode,
      onFocusVisualStateChanged: onFocusVisualStateChanged,
      onFocusChanged: onFocusChanged,
      onRemoveChip: onRemoveChip,
    );
  }

  /// Creates the selected-item state manager.
  MultiSelectSelectionManager<T> createSelectionManager({
    required int? maxSelected,
    required VoidCallback onSelectionChanged,
    required VoidCallback onFilterCacheInvalidated,
  }) {
    return MultiSelectSelectionManager<T>(
      maxSelected: maxSelected,
      onSelectionChanged: onSelectionChanged,
      onFilterCacheInvalidated: onFilterCacheInvalidated,
    );
  }

  /// Creates the keyboard-navigation manager.
  KeyboardNavigationManager<T> createKeyboardNavigationManager({
    required VoidCallback onRequestRebuild,
    required VoidCallback onEscape,
    required VoidCallback onOpenDropdown,
  }) {
    return KeyboardNavigationManager<T>(
      onRequestRebuild: onRequestRebuild,
      onEscape: onEscape,
      onOpenDropdown: onOpenDropdown,
    );
  }

  /// Creates the field-decoration cache.
  DecorationCacheManager createDecorationCacheManager() {
    return DecorationCacheManager();
  }

  /// Creates the composed multi-select filter controller.
  MultiSelectFilterController<T> createFilterController() {
    return MultiSelectFilterController<T>();
  }

  /// Creates the chip measurement and layout controller.
  MultiSelectChipLayoutController createChipLayoutController() {
    return MultiSelectChipLayoutController();
  }

  /// Creates the owner of chip focus nodes.
  MultiSelectChipFocusNodeController createChipFocusNodeController() {
    return MultiSelectChipFocusNodeController();
  }

  /// Creates the post-selection highlight policy.
  MultiSelectHighlightPolicy createHighlightPolicy() {
    return const MultiSelectHighlightPolicy();
  }

  /// Creates the accessibility live-region manager.
  LiveRegionManager createLiveRegionManager({required VoidCallback onUpdate}) {
    return LiveRegionManager(onUpdate: onUpdate);
  }
}
