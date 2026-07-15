import 'package:flutter/material.dart';

import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';

/// Renders individual dropdown rows and their interaction states.
class ItemDropperDropdownItemRenderer {
  const ItemDropperDropdownItemRenderer._();

  /// Builds a complete dropdown item with MouseRegion and hover handling.
  static Widget buildWithHover<T>({
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
    final int itemIndex = filteredItems.indexWhere(
      (x) => x.value == item.value,
    );

    if (item.isGroupHeader) {
      return build<T>(
        context: context,
        item: item,
        isHovered: false,
        isKeyboardHighlighted: false,
        isSelected: false,
        isSingleItem: false,
        isGroupHeader: true,
        onTap: () {},
        builder: customBuilder,
        itemHeight: itemHeight,
        onRequestDelete: null,
      );
    }

    return MouseRegion(
      onEnter: (event) {
        final int itemIndex = filteredItems.indexWhere(
          (i) => i.value == item.value,
        );
        if (keyboardHighlightIndex == ItemDropperConstants.kNoHighlight) {
          safeSetState(() => setHoverIndex(itemIndex));
        }
      },
      onExit: (_) =>
          safeSetState(() => setHoverIndex(ItemDropperConstants.kNoHighlight)),
      child: build<T>(
        context: context,
        item: item,
        isHovered:
            itemIndex == hoverIndex &&
            keyboardHighlightIndex == ItemDropperConstants.kNoHighlight,
        isKeyboardHighlighted: itemIndex == keyboardHighlightIndex,
        isSelected: isSelected,
        isSingleItem: filteredItems.length == 1,
        isGroupHeader: false,
        onTap: onTap,
        builder: customBuilder,
        itemHeight: itemHeight,
        onRequestDelete: onRequestDelete,
      ),
    );
  }

  /// Renders a dropdown item with hover/selection/keyboard highlight states.
  static Widget build<T>({
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
    Widget itemContent = builder(context, item, isSelected);
    Color? background;

    if (isGroupHeader) {
      background = null;
    } else if (!item.isEnabled) {
      background = null;
    } else if (isKeyboardHighlighted || isHovered || isSingleItem) {
      background = Theme.of(context).hoverColor;
    } else if (isSelected) {
      background = Theme.of(context).colorScheme.secondary.withAlpha(
        (ItemDropperConstants.kSelectedItemBackgroundAlpha * 255).toInt(),
      );
    } else {
      background = null;
    }

    final bool isEnabled = item.isEnabled && !isGroupHeader;

    return Semantics(
      label: item.label,
      button: !isGroupHeader,
      selected: isSelected,
      excludeSemantics: true,
      child: InkWell(
        hoverColor: Colors.transparent,
        onTap: isEnabled ? onTap : null,
        onSecondaryTap:
            (onRequestDelete != null &&
                item.isDeletable &&
                !isGroupHeader &&
                item.isEnabled)
            ? () => onRequestDelete(context, item)
            : null,
        onLongPress:
            (onRequestDelete != null &&
                item.isDeletable &&
                !isGroupHeader &&
                item.isEnabled)
            ? () => onRequestDelete(context, item)
            : null,
        child: SizedBox(
          height: itemHeight,
          child: ColoredBox(
            color: background ?? Colors.transparent,
            child: Align(alignment: Alignment.centerLeft, child: itemContent),
          ),
        ),
      ),
    );
  }
}
