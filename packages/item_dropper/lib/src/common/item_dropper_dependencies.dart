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

class SingleItemDropperDependencies<T> {
  const SingleItemDropperDependencies();

  ItemDropperFilterUtils<T> createFilterUtils() {
    return ItemDropperFilterUtils<T>();
  }

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

  DecorationCacheManager createDecorationCacheManager() {
    return DecorationCacheManager();
  }

  LiveRegionManager createLiveRegionManager({required VoidCallback onUpdate}) {
    return LiveRegionManager(onUpdate: onUpdate);
  }
}

class MultiItemDropperDependencies<T> {
  const MultiItemDropperDependencies();

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

  DecorationCacheManager createDecorationCacheManager() {
    return DecorationCacheManager();
  }

  MultiSelectFilterController<T> createFilterController() {
    return MultiSelectFilterController<T>();
  }

  MultiSelectChipLayoutController createChipLayoutController() {
    return MultiSelectChipLayoutController();
  }

  MultiSelectChipFocusNodeController createChipFocusNodeController() {
    return MultiSelectChipFocusNodeController();
  }

  MultiSelectHighlightPolicy createHighlightPolicy() {
    return const MultiSelectHighlightPolicy();
  }

  LiveRegionManager createLiveRegionManager({required VoidCallback onUpdate}) {
    return LiveRegionManager(onUpdate: onUpdate);
  }
}
