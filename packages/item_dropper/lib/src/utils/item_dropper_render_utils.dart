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
    void Function(BuildContext context, ItemDropperItem<T> item)?
        onRequestDelete, // Optional delete handler (right-click/long-press)
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
        onRequestDelete: null, // Group headers are never deletable
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
        isHovered: itemIndex == hoverIndex &&
            keyboardHighlightIndex == ItemDropperConstants.kNoHighlight,
        isKeyboardHighlighted: itemIndex == keyboardHighlightIndex,
        isSelected: isSelected,
        isSingleItem: filteredItems.length == 1,
        isGroupHeader: false,
        onTap: onTap,
        builder: customBuilder,
        itemHeight: itemHeight, // Pass the itemHeight parameter
        onRequestDelete: onRequestDelete,
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
    void Function(BuildContext context, ItemDropperItem<T> item)?
        onRequestDelete, // Optional delete handler (right-click/long-press)
  }) {
    Widget itemContent = builder(context, item, isSelected);
    Color? background;
    
    // Group headers have different styling - no hover/selection effects, no background
    if (isGroupHeader) {
      background = null; // No background for group headers
    } else if (!item.isEnabled) {
      // Disabled items: no hover/selection background, rely on greyed-out text only
      background = null;
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
    
    final bool isEnabled = item.isEnabled && !isGroupHeader;

    return InkWell(
      hoverColor: Colors.transparent,
      onTap: isEnabled
          ? () {
              onTap();
            }
          : null, // Group headers and disabled items are not clickable
      // Desktop/web: right-click to request delete (if handler provided & item is deletable)
      onSecondaryTap: (onRequestDelete != null &&
              item.isDeletable &&
              !isGroupHeader &&
              item.isEnabled)
          ? () => onRequestDelete(context, item)
          : null,
      // Mobile: long-press to request delete (if handler provided & item is deletable)
      onLongPress: (onRequestDelete != null &&
              item.isDeletable &&
              !isGroupHeader &&
              item.isEnabled)
          ? () => onRequestDelete(context, item)
          : null,
      child: SizedBox(
        height: itemHeight ?? ItemDropperConstants.kDropdownItemHeight,
        child: ColoredBox(
          color: background ?? Colors.transparent,
          child: Align(
            alignment: Alignment.centerLeft,
            child: itemContent,
          ),
        ),
      ),
    );
  }

  /// Default popup row builder for dropdown items
  /// 
  /// [popupTextStyle] - TextStyle for normal items. If null, defaults to fontSize 10.
  /// [popupGroupHeaderStyle] - TextStyle for group headers. If null, defaults to fontSize 10, bold, reduced opacity.
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
        fontSize: ItemDropperConstants.kDropdownItemFontSize,
        fontWeight: FontWeight.bold,
        color: Theme
            .of(context)
            .colorScheme
            .onSurface
            .withAlpha(ItemDropperConstants.kDropdownGroupHeaderAlpha),
      );
      
      // Add separator line above group header if there's a previous item that's not a group header
      final bool showSeparator = hasPreviousItem && !previousItemIsGroupHeader;
      
      return Container(
        decoration: showSeparator
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade300,
                    width: ItemDropperConstants.kDropdownSeparatorWidth,
                  ),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(
            horizontal: ItemDropperConstants.kDropdownItemHorizontalPadding,
            vertical: ItemDropperConstants.kDropdownGroupHeaderVerticalPadding),
        child: Text(
          item.label,
          style: popupGroupHeaderStyle ?? defaultGroupStyle,
        ),
      );
    }

    final defaultItemStyle = const TextStyle(
        fontSize: ItemDropperConstants.kDropdownItemFontSize);
    // Merge user's style with defaults - user's non-null values take precedence,
    // but we ensure fontSize is always set
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
          vertical: 0),
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
                width: ItemDropperConstants.kDropdownTextToDeleteIconSpacing),
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

    // Calculate the effective item height
    final double effectiveItemHeight = itemHeight ??
        ItemDropperConstants.kDropdownItemHeight;

    // Calculate the ideal max height:
    // 1. Start with maxDropdownHeight (or 200 if not provided)
    // 2. Adjust to be a multiple of itemHeight
    // 3. Truncate if there are fewer items than would fill the height
    final double requestedMaxHeight = maxDropdownHeight;
    final int maxVisibleItems = (requestedMaxHeight / effectiveItemHeight)
        .floor();
    final int actualVisibleItems = maxVisibleItems < items.length
        ? maxVisibleItems
        : items.length;
    final double adjustedMaxHeight = actualVisibleItems * effectiveItemHeight;

    final DropdownPositionResult position = DropdownPositionCalculator
        .calculate(
      context: context,
      inputBox: inputBox,
      inputFieldHeight: inputFieldHeight,
      maxDropdownHeight: adjustedMaxHeight,
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
                  fontSize: ItemDropperConstants.kDropdownItemFontSize,
                ),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: showScrollbar,
                  thickness: scrollbarThickness,
                  child: ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemExtent: effectiveItemHeight,
                    itemBuilder: (c, i) {
                      final item = items[i];

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