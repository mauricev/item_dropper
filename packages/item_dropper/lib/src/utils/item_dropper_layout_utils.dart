import 'package:flutter/material.dart';
import 'package:item_dropper/src/common/item_dropper_constants.dart';

/// Shared layout calculations for item dropper widgets.
class ItemDropperLayoutUtils {
  const ItemDropperLayoutUtils._();

  /// Calculates the effective popup item height from an explicit item height
  /// or the popup text style.
  static double calculateEffectiveItemHeight({
    required double? itemHeight,
    required TextStyle? popupTextStyle,
  }) {
    if (itemHeight != null) {
      return itemHeight;
    }

    final TextStyle resolvedStyle =
        popupTextStyle ??
        const TextStyle(fontSize: ItemDropperConstants.kDropdownItemFontSize);
    final double fontSize =
        resolvedStyle.fontSize ?? ItemDropperConstants.kDropdownItemFontSize;
    final double lineHeight =
        fontSize *
        (resolvedStyle.height ??
            ItemDropperConstants.kDropdownItemLineHeightMultiplier);
    return lineHeight + (ItemDropperConstants.kDropdownItemVerticalPadding * 2);
  }
}
