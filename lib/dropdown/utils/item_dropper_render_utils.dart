import 'package:flutter/material.dart';
import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';
import 'dropdown_position_calculator.dart';

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
      onEnter: (event) {
        final int itemIndex = filteredItems.indexWhere((i) => i.value == item.value);
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
    
    // Group headers have different styling - no hover/selection effects, no background
    if (isGroupHeader) {
      background = null; // No background for group headers
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
      onTap: isGroupHeader ? null : () {
        onTap();
      }, // Group headers are not clickable
      child: Container(
        height: itemHeight ?? ItemDropperConstants.kDropdownItemHeight,
        color: background,
        child: w,
      ),
    );
  }

  /// Default popup row builder for dropdown items
  /// 
  /// [popupTextStyle] - TextStyle for normal items. If null, defaults to fontSize 10.
  /// [popupGroupHeaderStyle] - TextStyle for group headers. If null, defaults to fontSize 9, bold, reduced opacity.
  /// [hasPreviousItem] - Whether there is a previous item (used to determine if separator should be shown above group header).
  /// [previousItemIsGroupHeader] - Whether the previous item is a group header (used to determine if separator should be shown).
  static Widget defaultDropdownPopupItemBuilder<T>(
    BuildContext context,
    ItemDropperItem<T> item,
    bool isSelected, {
    TextStyle? popupTextStyle,
    TextStyle? popupGroupHeaderStyle,
    bool hasPreviousItem = false,
    bool previousItemIsGroupHeader = false,
  }) {
    // Group headers have different styling
    if (item.isGroupHeader) {
      final defaultGroupStyle = TextStyle(
        fontSize: 9.0,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
      );
      
      // Add separator line above group header if there's a previous item that's not a group header
      final bool showSeparator = hasPreviousItem && !previousItemIsGroupHeader;
      
      return Container(
        decoration: showSeparator
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1.0,
                  ),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          item.label,
          style: popupGroupHeaderStyle ?? defaultGroupStyle,
        ),
      );
    }
    
    final defaultItemStyle = const TextStyle(fontSize: 10.0);
    return Container(
      color: isSelected ? Colors.grey.shade200 : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        item.label,
        style: popupTextStyle ?? defaultItemStyle,
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
    double? preferredFieldHeight, // Use this height if provided (for accurate positioning during layout changes)
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    // For positioning calculations, we need the input field's RenderBox
    final RenderBox? inputBox = context.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    // Use preferredFieldHeight if available (from measurements), otherwise use actual field height
    // This prevents overlay flash when field height changes during chip removal
    final double inputFieldHeight = preferredFieldHeight ?? inputBox.size.height;
    
    // Use actual measured field width to ensure overlay matches field width exactly
    // This accounts for borders, padding, and any layout differences
    final double actualFieldWidth = inputBox.size.width;
    
    final DropdownPositionResult position = DropdownPositionCalculator.calculate(
      context: context,
      inputBox: inputBox,
      inputFieldHeight: inputFieldHeight,
      maxDropdownHeight: maxDropdownHeight,
    );

    return CompositedTransformFollower(
      // Use stable key based on width only - height changes shouldn't recreate the ListView
      // This preserves scroll position when field height changes (e.g., chips wrapping)
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
                    itemBuilder: (c, i) {
                      final item = items[i];
                      final hasPrevious = i > 0;
                      final previousIsGroupHeader = hasPrevious && items[i - 1].isGroupHeader;
                      
                      
                      // Call builder - if it's the default builder, it will use the separator info
                      // We need to wrap the builder call to pass separator info
                      // Since we can't modify the builder signature, we'll handle separators
                      // by wrapping the result for group headers
                      return builder(context, item, isSelected(item));
                    },
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