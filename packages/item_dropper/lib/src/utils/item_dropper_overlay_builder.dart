import 'package:flutter/material.dart';

import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';
import 'dropdown_position_calculator.dart';
import 'item_dropper_overlay_content.dart';

/// Builds positioned dropdown overlays and their scrollable list chrome.
class ItemDropperOverlayBuilder {
  const ItemDropperOverlayBuilder._();

  /// Builds a dropdown overlay that follows the input field.
  static Widget build<T>({
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
    return buildContent<T>(
      context: context,
      content: ItemDropperListOverlayContent<T>(
        items: items,
        isSelected: isSelected,
        builder: builder,
        showScrollbar: showScrollbar,
        scrollbarThickness: scrollbarThickness,
        itemHeight: itemHeight,
      ),
      maxDropdownHeight: maxDropdownHeight,
      scrollController: scrollController,
      layerLink: layerLink,
      preferredFieldHeight: preferredFieldHeight,
    );
  }

  /// Builds a dropdown overlay with caller-provided content.
  static Widget buildContent<T>({
    required BuildContext context,
    required ItemDropperOverlayContent<T> content,
    required double maxDropdownHeight,
    required ScrollController scrollController,
    required LayerLink layerLink,
    double? preferredFieldHeight,
  }) {
    if (content.isEmpty) return const SizedBox.shrink();

    final RenderBox? inputBox = context.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final double inputFieldHeight =
        preferredFieldHeight ?? inputBox.size.height;
    final double actualFieldWidth = inputBox.size.width;
    final double adjustedMaxHeight = content.maxHeightFor(maxDropdownHeight);

    final DropdownPositionResult position =
        DropdownPositionCalculator.calculate(
          context: context,
          inputBox: inputBox,
          inputFieldHeight: inputFieldHeight,
          maxDropdownHeight: adjustedMaxHeight,
        );

    return CompositedTransformFollower(
      key: ValueKey<String>('follower_$actualFieldWidth'),
      link: layerLink,
      showWhenUnlinked: false,
      offset: position.offset,
      child: SizedBox(
        width: actualFieldWidth,
        child: FocusScope(
          canRequestFocus: false,
          child: Material(
            elevation: ItemDropperConstants.kDropdownElevation,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: position.constrainedMaxHeight,
              ),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: ItemDropperConstants.kDropdownItemFontSize,
                ),
                child: content.build(context, scrollController),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
