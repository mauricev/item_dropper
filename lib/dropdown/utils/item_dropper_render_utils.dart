import 'package:flutter/material.dart';
import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';

/// Shared dropdown rendering utilities
class ItemDropperRenderUtils {
  /// Builds a complete dropdown item with MouseRegion and hover handling
  /// This wraps buildDropdownItem with the standard hover behavior
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
    required Widget Function(BuildContext, ItemDropperItem<T>, bool) customBuilder,
    double? itemHeight, // Optional item height parameter
  }) {
    final int itemIndex = filteredItems.indexWhere(
          (x) => x.value == item.value,
    );
    
    // Group headers don't get hover effects
    if (item.isGroupHeader) {
      return buildDropdownItem<T>(
        context: context,
        item: item,
        isHovered: false,
        isKeyboardHighlighted: false,
        isSelected: false,
        isSingleItem: false,
        isGroupHeader: true,
        onTap: () {}, // Group headers are not clickable
        builder: customBuilder,
        itemHeight: itemHeight,
      );
    }
    
    return MouseRegion(
      onEnter: (_) {
        if (keyboardHighlightIndex == ItemDropperConstants.kNoHighlight) {
          safeSetState(() => setHoverIndex(itemIndex));
        }
      },
      onExit: (_) =>
          safeSetState(() => setHoverIndex(ItemDropperConstants.kNoHighlight)),
      child: buildDropdownItem<T>(
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
        itemHeight: itemHeight, // Pass the itemHeight parameter
      ),
    );
  }

  /// Renders a dropdown item with hover/selection/keyboard highlight states
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
    double? itemHeight, // Optional item height parameter
  }) {
    Widget w = builder(context, item, isSelected);
    Color? background;
    
    // Group headers have different styling - no hover/selection effects
    if (isGroupHeader) {
      background = Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(200);
    } else if (isKeyboardHighlighted || isHovered || isSingleItem) {
      background = Theme
          .of(context)
          .hoverColor;
    } else if (isSelected) {
      background = Theme
          .of(context)
          .colorScheme
          .secondary
          .withAlpha(
          (ItemDropperConstants.kSelectedItemBackgroundAlpha * 255).toInt());
    } else {
      background = null;
    }
    
    return InkWell(
      hoverColor: Colors.transparent,
      onTap: isGroupHeader ? null : onTap, // Group headers are not clickable
      child: Container(
        height: itemHeight ?? ItemDropperConstants.kDropdownItemHeight,
        color: background,
        child: w,
      ),
    );
  }

  /// Default popup row builder for dropdown items
  static Widget defaultDropdownPopupItemBuilder<T>(BuildContext context,
      ItemDropperItem<T> item,
      bool isSelected,) {
    // Group headers have different styling
    if (item.isGroupHeader) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          item.label,
          style: TextStyle(
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
          ),
        ),
      );
    }
    
    return Container(
      color: isSelected ? Colors.grey.shade200 : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        item.label,
        style: const TextStyle(fontSize: 10.0),
      ),
    );
  }

  /// Builds a dropdown overlay that follows the input field
  /// The builder callback receives (context, item, isSelected) and should return
  /// the complete item widget including MouseRegion and tap handling
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
    double scrollbarThickness = 6.0,
    double? itemHeight, // Optional item height parameter
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    // For positioning calculations, we need the input field's RenderBox
    // For width, we ONLY use the passed width parameter (never measure)
    final RenderBox? inputBox = context.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final EdgeInsets viewInsets = mediaQuery.viewInsets;
    final Offset inputFieldOffset = inputBox.localToGlobal(Offset.zero);
    final double inputFieldHeight = inputBox.size.height;

    final double availableSpaceBelow = screenHeight -
        viewInsets.bottom -
        (inputFieldOffset.dy + inputFieldHeight +
            ItemDropperConstants.kDropdownMargin);
    final double availableSpaceAbove =
        inputFieldOffset.dy - ItemDropperConstants.kDropdownMargin;
    final bool shouldShowBelow = availableSpaceBelow >
        maxDropdownHeight / ItemDropperConstants.kDropdownMaxHeightDivisor;
    final double constrainedMaxHeight = (shouldShowBelow
        ? availableSpaceBelow
        : availableSpaceAbove)
        .clamp(0.0, maxDropdownHeight);

    return CompositedTransformFollower(
      key: ValueKey<String>('follower_$inputFieldHeight\_$width'),
      link: layerLink,
      showWhenUnlinked: false,
      offset: shouldShowBelow
          ? Offset(0.0, inputFieldHeight + ItemDropperConstants.kDropdownMargin)
          : Offset(
          0.0, -constrainedMaxHeight - ItemDropperConstants.kDropdownMargin),
      child: SizedBox(
        width: width,
        child: FocusScope(
          canRequestFocus: false,
          child: Material(
            elevation: ItemDropperConstants.kDropdownElevation,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constrainedMaxHeight,
              ),
              child: DefaultTextStyle(
                style: Theme
                    .of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                  fontSize: ItemDropperConstants.kDropdownFontSize,
                ),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: showScrollbar,
                  thickness: scrollbarThickness,
                  child: ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemExtent: itemHeight ??
                        ItemDropperConstants.kDropdownItemHeight,
                    itemBuilder: (c, i) =>
                        builder(
                          context,
                          items[i],
                          isSelected(items[i]),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}