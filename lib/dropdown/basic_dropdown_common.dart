import 'package:flutter/material.dart';

/// Widget that measures its child's size and reports it via [onChange].
class MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;

  const MeasureSize({super.key, required this.child, required this.onChange});

  @override
  MeasureSizeState createState() => MeasureSizeState();
}

class MeasureSizeState extends State<MeasureSize> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderObject? renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        widget.onChange(renderObject.size);
      }
    });
    return widget.child;
  }
}

typedef DropDownItemCallback<T> = void Function(DropDownItem<T>? selected);

class DropDownItem<T> {
  final T value;
  final String label;

  const DropDownItem({required this.value, required this.label});
}

/// Shared suffix icon widget for dropdown fields
/// Displays clear and dropdown arrow buttons
class DropdownSuffixIcons extends StatelessWidget {
  final bool isDropdownShowing;
  final bool enabled;
  final VoidCallback onClearPressed;
  final VoidCallback onArrowPressed;
  final double iconSize;
  final double suffixIconWidth;
  final double iconButtonSize;
  final double clearButtonRightPosition;
  final double arrowButtonRightPosition;
  final double textSize;

  const DropdownSuffixIcons({
    super.key,
    required this.isDropdownShowing,
    required this.enabled,
    required this.onClearPressed,
    required this.onArrowPressed,
    this.iconSize = 16.0,
    this.suffixIconWidth = 60.0,
    this.iconButtonSize = 24.0,
    this.clearButtonRightPosition = 40.0,
    this.arrowButtonRightPosition = 10.0,
    this.textSize = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: suffixIconWidth,
      height: textSize * 3.2,
      child: Stack(
        alignment: Alignment.centerRight,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: clearButtonRightPosition,
            child: IconButton(
              icon: Icon(
                Icons.clear,
                size: iconSize,
                color: enabled ? Colors.black : Colors.grey,
              ),
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: iconButtonSize,
                height: iconButtonSize,
              ),
              onPressed: enabled ? onClearPressed : null,
            ),
          ),
          Positioned(
            right: arrowButtonRightPosition,
            child: IconButton(
              icon: Icon(
                isDropdownShowing
                    ? Icons.arrow_drop_up
                    : Icons.arrow_drop_down,
                size: iconSize,
                color: enabled ? Colors.black : Colors.grey,
              ),
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: iconButtonSize,
                height: iconButtonSize,
              ),
              onPressed: enabled ? onArrowPressed : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared UI constants for dropdown components
class DropdownConstants {
  // Layout constants
  static const double kDropdownItemHeight = 30.0;
  static const double kDropdownMargin = 4.0;
  static const double kDropdownElevation = 4.0;
  static const double kDropdownFontSize = 12.0;
  static const double kDropdownMaxHeightDivisor = 2.0;
  static const double kSelectedItemBackgroundAlpha = 0.12;
  static const int kNoHighlight = -1;

  // Scroll constants
  static const double kDefaultFallbackItemPadding = 16.0;
  static const double kFallbackItemTextMultiplier = 1.2;
  static const int kMaxScrollRetries = 10;
  static const Duration kScrollAnimationDuration = Duration(milliseconds: 200);
  static const Duration kScrollDebounceDelay = Duration(milliseconds: 150);
  static const double kCenteringDivisor = 2.0;
}

/// Shared widget that wraps dropdown input fields with overlay functionality
class DropdownWithOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final OverlayPortalController overlayController;
  final GlobalKey fieldKey;
  final Widget inputField;
  final Widget overlay;
  final VoidCallback onDismiss;

  const DropdownWithOverlay({
    super.key,
    required this.layerLink,
    required this.overlayController,
    required this.fieldKey,
    required this.inputField,
    required this.overlay,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: OverlayPortal(
        controller: overlayController,
        overlayChildBuilder: (context) =>
            Stack(
              children: [
                // Dismiss dropdown when clicking outside the text field
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      // Use the field's render box for dismissal detection
                      final RenderBox? renderBox =
                      fieldKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        final Offset offset = renderBox.localToGlobal(
                            Offset.zero);
                        final Size size = renderBox.size;
                        final Rect fieldRect = offset & size;
                        if (!fieldRect.contains(event.position)) {
                          onDismiss();
                        }
                      }
                    },
                  ),
                ),
                CompositedTransformFollower(
                  link: layerLink,
                  showWhenUnlinked: false,
                  offset: const Offset(0.0, 0.0), // Position relative to target
                  child: overlay,
                ),
              ],
            ),
        child: inputField,
      ),
    );
  }
}

/// Shared dropdown rendering utilities
class DropdownRenderUtils {
  /// Builds a complete dropdown item with MouseRegion and hover handling
  /// This wraps buildDropdownItem with the standard hover behavior
  static Widget buildDropdownItemWithHover<T>({
    required BuildContext context,
    required DropDownItem<T> item,
    required bool isSelected,
    required List<DropDownItem<T>> filteredItems,
    required int hoverIndex,
    required int keyboardHighlightIndex,
    required void Function(void Function()) safeSetState,
    required void Function(int) setHoverIndex,
    required VoidCallback onTap,
    required Widget Function(BuildContext, DropDownItem<T>, bool) customBuilder,
    double? itemHeight, // Optional item height parameter
  }) {
    final int itemIndex = filteredItems.indexWhere(
          (x) => x.value == item.value,
    );
    return MouseRegion(
      onEnter: (_) {
        if (keyboardHighlightIndex == DropdownConstants.kNoHighlight) {
          safeSetState(() => setHoverIndex(itemIndex));
        }
      },
      onExit: (_) =>
          safeSetState(() => setHoverIndex(DropdownConstants.kNoHighlight)),
      child: buildDropdownItem<T>(
        context: context,
        item: item,
        isHovered:
        itemIndex == hoverIndex &&
            keyboardHighlightIndex == DropdownConstants.kNoHighlight,
        isKeyboardHighlighted: itemIndex == keyboardHighlightIndex,
        isSelected: isSelected,
        isSingleItem: filteredItems.length == 1,
        onTap: onTap,
        builder: customBuilder,
        itemHeight: itemHeight, // Pass the itemHeight parameter
      ),
    );
  }

  /// Renders a dropdown item with hover/selection/keyboard highlight states
  static Widget buildDropdownItem<T>({
    required BuildContext context,
    required DropDownItem<T> item,
    required bool isHovered,
    required bool isKeyboardHighlighted,
    required bool isSelected,
    required bool isSingleItem,
    required VoidCallback onTap,
    required Widget Function(BuildContext, DropDownItem<T>, bool) builder,
    double? itemHeight, // Optional item height parameter
  }) {
    Widget w = builder(context, item, isSelected);
    Color? background;
    if (isKeyboardHighlighted || isHovered || isSingleItem) {
      background = Theme
          .of(context)
          .hoverColor;
    } else if (isSelected) {
      background = Theme
          .of(context)
          .colorScheme
          .secondary
          .withAlpha(
          (DropdownConstants.kSelectedItemBackgroundAlpha * 255).toInt());
    } else {
      background = null;
    }
    return InkWell(
      hoverColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        height: itemHeight ?? DropdownConstants.kDropdownItemHeight,
        color: background,
        child: w,
      ),
    );
  }

  /// Default popup row builder for dropdown items
  static Widget defaultDropdownPopupItemBuilder<T>(BuildContext context,
      DropDownItem<T> item,
      bool isSelected,) {
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
    required List<DropDownItem<T>> items,
    required double maxDropdownHeight,
    required double width,
    required OverlayPortalController controller,
    required ScrollController scrollController,
    required LayerLink layerLink,
    required bool Function(DropDownItem<T>) isSelected,
    required Widget Function(BuildContext, DropDownItem<T>, bool) builder,
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
            DropdownConstants.kDropdownMargin);
    final double availableSpaceAbove =
        inputFieldOffset.dy - DropdownConstants.kDropdownMargin;
    final bool shouldShowBelow = availableSpaceBelow >
        maxDropdownHeight / DropdownConstants.kDropdownMaxHeightDivisor;
    final double constrainedMaxHeight = (shouldShowBelow
        ? availableSpaceBelow
        : availableSpaceAbove)
        .clamp(0.0, maxDropdownHeight);

    return CompositedTransformFollower(
      key: ValueKey<String>('follower_${inputFieldHeight}_${width}'),
      link: layerLink,
      showWhenUnlinked: false,
      offset: shouldShowBelow
          ? Offset(0.0, inputFieldHeight + DropdownConstants.kDropdownMargin)
          : Offset(
          0.0, -constrainedMaxHeight - DropdownConstants.kDropdownMargin),
      child: SizedBox(
        width: width,
        child: FocusScope(
          canRequestFocus: false,
          child: Material(
            elevation: DropdownConstants.kDropdownElevation,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constrainedMaxHeight,
              ),
              child: DefaultTextStyle(
                style: Theme
                    .of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: DropdownConstants.kDropdownFontSize,
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
                        (10.0 * 3.0),
                    // 10pt → 30px mapping, independent of actual font size
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

/// Shared filtering behavior for dropdown items
class DropdownFilterUtils<T> {
  List<({String label, DropDownItem<T> item})> _normalizedItems = [];
  List<DropDownItem<T>>? _lastItemsRef;
  List<DropDownItem<T>>? _cachedFilteredItems;
  String _lastFilterInput = '';

  /// Initialize normalized items for fast filtering
  void initializeItems(List<DropDownItem<T>> items) {
    _lastItemsRef = items;
    _normalizedItems = items
        .map((item) => (label: item.label.trim().toLowerCase(), item: item))
        .toList(growable: false);
  }

  /// Get filtered items based on search text
  List<DropDownItem<T>> getFiltered(List<DropDownItem<T>> items,
      String searchText, {
        bool isUserEditing = false,
        Set<T>? excludeValues,
      }) {
    final String input = searchText.trim().toLowerCase();

    // Reinitialize if items reference changed
    if (!identical(_lastItemsRef, items)) {
      initializeItems(items);
      _cachedFilteredItems = null;
      _lastFilterInput = '';
    }

    // No filtering if not editing or empty input
    if (!isUserEditing || input.isEmpty) {
      if (excludeValues == null || excludeValues.isEmpty) {
        return items;
      }
      return items
          .where((item) => !excludeValues.contains(item.value))
          .toList();
    }

    // Return cached result if input hasn't changed
    if (_lastFilterInput == input && _cachedFilteredItems != null) {
      return _cachedFilteredItems!;
    }

    // Compute and cache filtered list
    final List<DropDownItem<T>> filteredResult = _normalizedItems
        .where((entry) =>
    entry.label.contains(input) &&
        (excludeValues == null || !excludeValues.contains(entry.item.value)))
        .map((entry) => entry.item)
        .toList(growable: false);

    _lastFilterInput = input;
    _cachedFilteredItems = filteredResult;
    return filteredResult;
  }

  /// Clear the filter cache
  void clearCache() {
    _cachedFilteredItems = null;
    _lastFilterInput = '';
  }
}

/// Shared keyboard navigation behavior for dropdowns
class DropdownKeyboardNavigation {
  /// Handle arrow down navigation
  static int handleArrowDown(int currentIndex,
      int hoverIndex,
      int itemCount,) {
    if (itemCount == 0) return DropdownConstants.kNoHighlight;

    int nextIndex = currentIndex;

    // If no keyboard highlight but hover index exists, start from there
    if (nextIndex == DropdownConstants.kNoHighlight &&
        hoverIndex != DropdownConstants.kNoHighlight) {
      nextIndex = hoverIndex;
    }

    // Move down (with wrapping to top)
    if (nextIndex < itemCount - 1) {
      nextIndex++;
    } else {
      nextIndex = 0;
    }

    return nextIndex;
  }

  /// Handle arrow up navigation
  static int handleArrowUp(int currentIndex,
      int hoverIndex,
      int itemCount,) {
    if (itemCount == 0) return DropdownConstants.kNoHighlight;

    int nextIndex = currentIndex;

    // If no keyboard highlight but hover index exists, start from there
    if (nextIndex == DropdownConstants.kNoHighlight &&
        hoverIndex != DropdownConstants.kNoHighlight) {
      nextIndex = hoverIndex;
    }

    // Move up (with wrapping to bottom)
    if (nextIndex > 0) {
      nextIndex--;
    } else {
      nextIndex = itemCount - 1;
    }

    return nextIndex;
  }

  /// Scroll to make the highlighted item visible
  static void scrollToHighlight({
    required int highlightIndex,
    required ScrollController scrollController,
    required bool mounted,
  }) {
    if (highlightIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        if (scrollController.hasClients &&
            scrollController.position.hasContentDimensions) {
          final double itemTop =
              highlightIndex * DropdownConstants.kDropdownItemHeight;
          final double itemBottom =
              itemTop + DropdownConstants.kDropdownItemHeight;
          final double viewportStart = scrollController.offset;
          final double viewportEnd =
              viewportStart + scrollController.position.viewportDimension;

          if (itemTop < viewportStart) {
            scrollController.animateTo(
              itemTop,
              duration: DropdownConstants.kScrollAnimationDuration,
              curve: Curves.easeInOut,
            );
          } else if (itemBottom > viewportEnd) {
            scrollController.animateTo(
              itemBottom - scrollController.position.viewportDimension,
              duration: DropdownConstants.kScrollAnimationDuration,
              curve: Curves.easeInOut,
            );
          }
        }
      } catch (e) {
        debugPrint('[KEYBOARD NAV] Scroll failed: $e');
      }
    });
  }
}
