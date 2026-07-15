import 'package:flutter/material.dart';

import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';
import 'item_dropper_dropdown_item_renderer.dart';
import 'item_dropper_overlay_builder.dart';
import 'item_dropper_popup_item_builder.dart';

/// Backward-compatible facade for dropdown rendering utilities.
///
/// Rendering responsibilities are implemented by focused helpers:
/// [ItemDropperDropdownItemRenderer], [ItemDropperPopupItemBuilder], and
/// [ItemDropperOverlayBuilder].
class ItemDropperRenderUtils {
  const ItemDropperRenderUtils._();

  /// Builds a complete dropdown item with MouseRegion and hover handling.
  static Widget buildDropdownItemWithHover<T>({
    required BuildContext context,
    required ItemDropperItem<T> item,
    required bool isSelected,
    required List<ItemDropperItem<T>> filteredItems,
    required int hoverIndex,
    required int keyboardHighlightIndex,
    required void Function(void Function()) safeSetState,
    required void Function(int) setHoverIndex,
    required VoidCallback onTap,
    required Widget Function(BuildContext, ItemDropperItem<T>, bool)
    customBuilder,
    required double itemHeight,
    void Function(BuildContext context, ItemDropperItem<T> item)?
    onRequestDelete,
  }) {
    return ItemDropperDropdownItemRenderer.buildWithHover<T>(
      context: context,
      item: item,
      isSelected: isSelected,
      filteredItems: filteredItems,
      hoverIndex: hoverIndex,
      keyboardHighlightIndex: keyboardHighlightIndex,
      safeSetState: safeSetState,
      setHoverIndex: setHoverIndex,
      onTap: onTap,
      customBuilder: customBuilder,
      itemHeight: itemHeight,
      onRequestDelete: onRequestDelete,
    );
  }

  /// Renders a dropdown item with hover/selection/keyboard highlight states.
  static Widget buildDropdownItem<T>({
    required BuildContext context,
    required ItemDropperItem<T> item,
    required bool isHovered,
    required bool isKeyboardHighlighted,
    required bool isSelected,
    required bool isSingleItem,
    required bool isGroupHeader,
    required VoidCallback onTap,
    required Widget Function(BuildContext, ItemDropperItem<T>, bool) builder,
    required double itemHeight,
    void Function(BuildContext context, ItemDropperItem<T> item)?
    onRequestDelete,
  }) {
    return ItemDropperDropdownItemRenderer.build<T>(
      context: context,
      item: item,
      isHovered: isHovered,
      isKeyboardHighlighted: isKeyboardHighlighted,
      isSelected: isSelected,
      isSingleItem: isSingleItem,
      isGroupHeader: isGroupHeader,
      onTap: onTap,
      builder: builder,
      itemHeight: itemHeight,
      onRequestDelete: onRequestDelete,
    );
  }

  /// Default popup row builder for dropdown items.
  static Widget defaultDropdownPopupItemBuilder<T>(
    BuildContext context,
    ItemDropperItem<T> item,
    bool isSelected, {
    TextStyle? popupTextStyle,
    TextStyle? popupGroupHeaderStyle,
    bool hasPreviousItem = false,
    bool previousItemIsGroupHeader = false,
  }) {
    return ItemDropperPopupItemBuilder.build<T>(
      context,
      item,
      isSelected,
      popupTextStyle: popupTextStyle,
      popupGroupHeaderStyle: popupGroupHeaderStyle,
      hasPreviousItem: hasPreviousItem,
      previousItemIsGroupHeader: previousItemIsGroupHeader,
    );
  }

  /// Builds a dropdown overlay that follows the input field.
  static Widget buildDropdownOverlay<T>({
    required BuildContext context,
    required List<ItemDropperItem<T>> items,
    required double maxDropdownHeight,
    required double width,
    required OverlayPortalController controller,
    required ScrollController scrollController,
    required LayerLink layerLink,
    required bool Function(ItemDropperItem<T>) isSelected,
    required Widget Function(BuildContext, ItemDropperItem<T>, bool) builder,
    bool showScrollbar = true,
    double scrollbarThickness = ItemDropperConstants.kDefaultScrollbarThickness,
    required double itemHeight,
    double? preferredFieldHeight,
  }) {
    return ItemDropperOverlayBuilder.build<T>(
      context: context,
      items: items,
      maxDropdownHeight: maxDropdownHeight,
      width: width,
      controller: controller,
      scrollController: scrollController,
      layerLink: layerLink,
      isSelected: isSelected,
      builder: builder,
      showScrollbar: showScrollbar,
      scrollbarThickness: scrollbarThickness,
      itemHeight: itemHeight,
      preferredFieldHeight: preferredFieldHeight,
    );
  }
}
