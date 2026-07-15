import 'package:flutter/material.dart';

import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';

/// Builds the default visual contents for dropdown popup rows.
class ItemDropperPopupItemBuilder {
  const ItemDropperPopupItemBuilder._();

  /// Default popup row builder for dropdown items.
  static Widget build<T>(
    BuildContext context,
    ItemDropperItem<T> item,
    bool isSelected, {
    TextStyle? popupTextStyle,
    TextStyle? popupGroupHeaderStyle,
    bool hasPreviousItem = false,
    bool previousItemIsGroupHeader = false,
  }) {
    if (item.isGroupHeader) {
      final defaultGroupStyle = TextStyle(
        fontSize: ItemDropperConstants.kDropdownItemFontSize,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(
          ItemDropperConstants.kDropdownGroupHeaderAlpha,
        ),
      );

      final bool showSeparator = hasPreviousItem && !previousItemIsGroupHeader;

      final headerContent = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ItemDropperConstants.kDropdownItemHorizontalPadding,
          vertical: ItemDropperConstants.kDropdownGroupHeaderVerticalPadding,
        ),
        child: Text(
          item.label,
          style: popupGroupHeaderStyle ?? defaultGroupStyle,
        ),
      );

      if (showSeparator) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: ItemDropperConstants.kDropdownSeparatorWidth,
              child: Container(color: Colors.grey.shade300),
            ),
            headerContent,
          ],
        );
      }

      return headerContent;
    }

    final defaultItemStyle = const TextStyle(
      fontSize: ItemDropperConstants.kDropdownItemFontSize,
    );
    final TextStyle baseStyle = defaultItemStyle.merge(popupTextStyle);
    final bool isDisabled = !item.isEnabled;
    final TextStyle effectiveTextStyle = isDisabled
        ? baseStyle.copyWith(color: Colors.grey.shade400)
        : baseStyle;
    final bool isDeletable = item.isDeletable;

    return Container(
      color: isSelected ? Colors.grey.shade200 : null,
      padding: const EdgeInsets.symmetric(
        horizontal: ItemDropperConstants.kDropdownItemHorizontalPadding,
        vertical: 0,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              item.label,
              style: effectiveTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isDeletable) ...[
            const SizedBox(
              width: ItemDropperConstants.kDropdownTextToDeleteIconSpacing,
            ),
            Icon(
              Icons.delete_outline,
              size: ItemDropperConstants.kDropdownDeleteIconSize,
              color: Colors.redAccent.shade200,
            ),
          ],
        ],
      ),
    );
  }
}
