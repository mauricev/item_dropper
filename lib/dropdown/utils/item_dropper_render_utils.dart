import 'package:flutter/material.dart';
import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';

/// Result of dropdown positioning calculation
class DropdownPositionResult {
  final bool shouldShowBelow;
  final double constrainedMaxHeight;
  final Offset offset;

  const DropdownPositionResult({
    required this.shouldShowBelow,
    required this.constrainedMaxHeight,
    required this.offset,
  });
}

/// Shared dropdown rendering utilities
class ItemDropperRenderUtils {
  /// Calculates dropdown positioning (above/below) and constraints
  /// 
  /// Returns positioning information including:
  /// - Whether to show below or above
  /// - The constrained max height based on available space
  /// - The offset for CompositedTransformFollower
  static DropdownPositionResult calculateDropdownPosition({
    required BuildContext context,
    required RenderBox inputBox,
    required double inputFieldHeight,
    required double maxDropdownHeight,
  }) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    // Get window size (client area)
    final double windowHeight = mediaQuery.size.height;
    final EdgeInsets viewInsets = mediaQuery.viewInsets;
    final EdgeInsets padding = mediaQuery.padding;
    
    // DEBUG: Get input field position in screen coordinates
    final Offset inputFieldScreenPos = inputBox.localToGlobal(Offset.zero);
    
    // DEBUG: Get the overlay's render object
    final RenderObject? overlayRenderObject = context.findRenderObject();
    debugPrint('=== COORDINATE DEBUG ===');
    debugPrint('Context type: ${context.runtimeType}');
    debugPrint('Overlay render object type: ${overlayRenderObject?.runtimeType}');
    debugPrint('Input field screen position: (${inputFieldScreenPos.dx.toStringAsFixed(1)}, ${inputFieldScreenPos.dy.toStringAsFixed(1)})');
    
    // DEBUG: Try to find the root render object
    final RenderObject? rootObject = context.findRootAncestorStateOfType<State<StatefulWidget>>()?.context.findRenderObject();
    debugPrint('Root render object type: ${rootObject?.runtimeType}');
    if (rootObject is RenderBox) {
      final Offset rootScreenPos = rootObject.localToGlobal(Offset.zero);
      debugPrint('Root screen position: (${rootScreenPos.dx.toStringAsFixed(1)}, ${rootScreenPos.dy.toStringAsFixed(1)})');
    }
    
    // DEBUG: Try to find Scaffold
    final ScaffoldState? scaffold = context.findAncestorStateOfType<ScaffoldState>();
    debugPrint('Scaffold found: ${scaffold != null}');
    if (scaffold != null && scaffold.mounted) {
      final RenderObject? scaffoldRenderObject = scaffold.context.findRenderObject();
      debugPrint('Scaffold render object type: ${scaffoldRenderObject?.runtimeType}');
      if (scaffoldRenderObject is RenderBox) {
        final Offset scaffoldScreenPos = scaffoldRenderObject.localToGlobal(Offset.zero);
        debugPrint('Scaffold screen position: (${scaffoldScreenPos.dx.toStringAsFixed(1)}, ${scaffoldScreenPos.dy.toStringAsFixed(1)})');
      }
    }
    
    // DEBUG: Try to find Scrollable
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    RenderBox? scrollRenderBox;
    debugPrint('Scrollable found: ${scrollable != null}');
    if (scrollable != null) {
      debugPrint('Scrollable offset: ${scrollable.position.pixels.toStringAsFixed(1)}');
      final RenderObject? scrollRenderObject = scrollable.context.findRenderObject();
      debugPrint('Scrollable render object type: ${scrollRenderObject?.runtimeType}');
      if (scrollRenderObject is RenderBox) {
        scrollRenderBox = scrollRenderObject;
        final Offset scrollScreenPos = scrollRenderBox.localToGlobal(Offset.zero);
        debugPrint('Scrollable screen position: (${scrollScreenPos.dx.toStringAsFixed(1)}, ${scrollScreenPos.dy.toStringAsFixed(1)})');
      }
    }
    
    // Get input field position relative to the window (not screen)
    // We need to get the position relative to the widget's ancestor that represents the window
    // The context should be the overlay's context, which is relative to the window
    final Offset inputFieldOffset = inputBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
    
    debugPrint('Input field offset (using ancestor): (${inputFieldOffset.dx.toStringAsFixed(1)}, ${inputFieldOffset.dy.toStringAsFixed(1)})');
    
    // DEBUG: Calculate correct viewport position (but don't use it yet - just for debugging)
    if (scrollable != null && scrollRenderBox != null) {
      final Offset scrollScreenPos = scrollRenderBox.localToGlobal(Offset.zero);
      final double scrollOffset = scrollable.position.pixels;
      final double correctViewportY = inputFieldScreenPos.dy - scrollScreenPos.dy + scrollOffset;
      final double correctFieldBottom = correctViewportY + inputFieldHeight;
      
      // DEBUG: Get the actual Scrollable viewport height and bottom position
      final Size scrollBoxSize = scrollRenderBox.size;
      final double scrollableBottomScreen = scrollScreenPos.dy + scrollBoxSize.height;
      final double inputFieldBottomScreen = inputFieldScreenPos.dy + inputFieldHeight;
      
      debugPrint('  Scrollable viewportDimension: ${scrollable.position.hasContentDimensions ? scrollable.position.viewportDimension.toStringAsFixed(1) : "N/A"}');
      debugPrint('  MediaQuery windowHeight: ${windowHeight.toStringAsFixed(1)}');
      debugPrint('  Scrollable render box size: ${scrollBoxSize.width.toStringAsFixed(1)} x ${scrollBoxSize.height.toStringAsFixed(1)}');
      debugPrint('  Scrollable bottom (screen): ${scrollableBottomScreen.toStringAsFixed(1)}');
      debugPrint('  Input field bottom (screen): ${inputFieldBottomScreen.toStringAsFixed(1)}');
      
      // Calculate available space using screen coordinates
      // Available = Scrollable bottom - Input field bottom - margin - viewInsets
      final double correctAvailableSpaceBelow = scrollableBottomScreen - inputFieldBottomScreen - ItemDropperConstants.kDropdownMargin - viewInsets.bottom;
      final double correctConstrainedMaxHeight = correctAvailableSpaceBelow.clamp(0.0, maxDropdownHeight);
      final double overlayStartY = correctFieldBottom + ItemDropperConstants.kDropdownMargin;
      final double overlayEndY = overlayStartY + correctConstrainedMaxHeight;
      
      debugPrint('CORRECT CALCULATION (using screen coordinates):');
      debugPrint('  Input field screen Y: ${inputFieldScreenPos.dy.toStringAsFixed(1)}');
      debugPrint('  Input field bottom (screen): ${inputFieldBottomScreen.toStringAsFixed(1)}');
      debugPrint('  Scrollable screen Y: ${scrollScreenPos.dy.toStringAsFixed(1)}');
      debugPrint('  Scrollable bottom (screen): ${scrollableBottomScreen.toStringAsFixed(1)}');
      debugPrint('  Scroll offset: ${scrollOffset.toStringAsFixed(1)}');
      debugPrint('  Calculation breakdown (screen coordinates):');
      debugPrint('    Scrollable bottom: ${scrollableBottomScreen.toStringAsFixed(1)}');
      debugPrint('    - Input field bottom: ${inputFieldBottomScreen.toStringAsFixed(1)}');
      debugPrint('    - margin: ${ItemDropperConstants.kDropdownMargin.toStringAsFixed(1)}');
      debugPrint('    - viewInsets.bottom: ${viewInsets.bottom.toStringAsFixed(1)}');
      debugPrint('    = available: ${correctAvailableSpaceBelow.toStringAsFixed(1)}');
      debugPrint('  Without margin: ${(scrollableBottomScreen - inputFieldBottomScreen - viewInsets.bottom).toStringAsFixed(1)} pixels');
      debugPrint('  Available space below: ${correctAvailableSpaceBelow.toStringAsFixed(1)}');
      debugPrint('  Overlay would start at: ${overlayStartY.toStringAsFixed(1)}');
      debugPrint('  Overlay max height: ${correctConstrainedMaxHeight.toStringAsFixed(1)}');
      debugPrint('  Overlay would end at: ${overlayEndY.toStringAsFixed(1)}');
      debugPrint('  Viewport bottom: ${windowHeight.toStringAsFixed(1)}');
      debugPrint('  Would overflow by: ${(overlayEndY - windowHeight).toStringAsFixed(1)}');
      debugPrint('  Overlay needs: ${maxDropdownHeight.toStringAsFixed(1)} pixels');
      debugPrint('  Overlay has available (calculated): ${correctAvailableSpaceBelow.toStringAsFixed(1)} pixels');
      debugPrint('  User reports actual available: 140 pixels');
      debugPrint('  Difference: ${(correctAvailableSpaceBelow - 140).toStringAsFixed(1)} pixels unaccounted for');
      debugPrint('  Possible causes:');
      debugPrint('    - Additional padding/borders not in calculation');
      debugPrint('    - Other UI elements taking space');
      debugPrint('    - Viewport height mismatch (calculated: ${windowHeight.toStringAsFixed(1)}, actual visible: ?)');
    }
    
    debugPrint('MediaQuery size: ${mediaQuery.size}');
    debugPrint('MediaQuery padding: top=${padding.top}, bottom=${padding.bottom}, left=${padding.left}, right=${padding.right}');
    debugPrint('========================');
    
    // Calculate available space below the input field within the window
    final double inputFieldBottom = inputFieldOffset.dy + inputFieldHeight;
    final double availableSpaceBelow = windowHeight -
        inputFieldBottom -
        ItemDropperConstants.kDropdownMargin -
        viewInsets.bottom;
    
    // Calculate available space above the input field
    final double availableSpaceAbove = inputFieldOffset.dy -
        ItemDropperConstants.kDropdownMargin;
    
    // Only show below if there's enough space (at least half the max height)
    final bool shouldShowBelow = availableSpaceBelow >
        maxDropdownHeight / ItemDropperConstants.kDropdownMaxHeightDivisor;
    
    final double constrainedMaxHeight = (shouldShowBelow
        ? availableSpaceBelow
        : availableSpaceAbove)
        .clamp(0.0, maxDropdownHeight);
    
    final Offset offset = shouldShowBelow
        ? Offset(0.0, inputFieldHeight + ItemDropperConstants.kDropdownMargin)
        : Offset(0.0, -constrainedMaxHeight - ItemDropperConstants.kDropdownMargin);
    
    // Calculate overlay rect for debugging
    final double overlayTop = shouldShowBelow 
        ? inputFieldOffset.dy + inputFieldHeight + ItemDropperConstants.kDropdownMargin
        : inputFieldOffset.dy - constrainedMaxHeight - ItemDropperConstants.kDropdownMargin;
    final double overlayBottom = overlayTop + constrainedMaxHeight;
    final double screenBottom = windowHeight;
    final double distanceToScreenBottom = screenBottom - overlayBottom;
    
    // Debug output
    debugPrint('=== DROPDOWN POSITION DEBUG ===');
    debugPrint('Input field:');
    debugPrint('  - Viewport offset: (${inputFieldOffset.dx.toStringAsFixed(1)}, ${inputFieldOffset.dy.toStringAsFixed(1)})');
    debugPrint('  - Screen position: (${inputFieldScreenPos.dx.toStringAsFixed(1)}, ${inputFieldScreenPos.dy.toStringAsFixed(1)})');
    debugPrint('  - Height: ${inputFieldHeight.toStringAsFixed(1)}');
    debugPrint('  - Bottom (viewport): ${inputFieldBottom.toStringAsFixed(1)}');
    debugPrint('');
    debugPrint('Viewport:');
    debugPrint('  - Height: ${windowHeight.toStringAsFixed(1)}');
    debugPrint('  - Padding: top=${padding.top.toStringAsFixed(1)}, bottom=${padding.bottom.toStringAsFixed(1)}');
    debugPrint('  - ViewInsets: bottom=${viewInsets.bottom.toStringAsFixed(1)}');
    debugPrint('  - Screen bottom: ${screenBottom.toStringAsFixed(1)}');
    debugPrint('');
    debugPrint('Available space:');
    debugPrint('  - Below: ${availableSpaceBelow.toStringAsFixed(1)}');
    debugPrint('  - Above: ${availableSpaceAbove.toStringAsFixed(1)}');
    debugPrint('  - Threshold (maxHeight/2): ${(maxDropdownHeight / ItemDropperConstants.kDropdownMaxHeightDivisor).toStringAsFixed(1)}');
    debugPrint('');
    debugPrint('Overlay:');
    debugPrint('  - Direction: ${shouldShowBelow ? "BELOW" : "ABOVE"}');
    debugPrint('  - Constrained max height: ${constrainedMaxHeight.toStringAsFixed(1)}');
    debugPrint('  - Offset: (${offset.dx.toStringAsFixed(1)}, ${offset.dy.toStringAsFixed(1)})');
    debugPrint('  - Top (viewport): ${overlayTop.toStringAsFixed(1)}');
    debugPrint('  - Bottom (viewport): ${overlayBottom.toStringAsFixed(1)}');
    debugPrint('  - Distance to screen bottom: ${distanceToScreenBottom.toStringAsFixed(1)}');
    debugPrint('================================');
    
    return DropdownPositionResult(
      shouldShowBelow: shouldShowBelow,
      constrainedMaxHeight: constrainedMaxHeight,
      offset: offset,
    );
  }
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
    // For width, we ONLY use the passed width parameter (never measure)
    final RenderBox? inputBox = context.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    // Use preferredFieldHeight if available (from measurements), otherwise use actual field height
    // This prevents overlay flash when field height changes during chip removal
    final double inputFieldHeight = preferredFieldHeight ?? inputBox.size.height;
    
    final DropdownPositionResult position = calculateDropdownPosition(
      context: context,
      inputBox: inputBox,
      inputFieldHeight: inputFieldHeight,
      maxDropdownHeight: maxDropdownHeight,
    );

    return CompositedTransformFollower(
      key: ValueKey<String>('follower_$inputFieldHeight\_$width'),
      link: layerLink,
      showWhenUnlinked: false,
      offset: position.offset,
      child: SizedBox(
        width: width,
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