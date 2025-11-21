import 'dart:async';
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
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: suffixIconWidth,
      height: kMinInteractiveDimension,
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

abstract class SearchDropdownBase<T> extends StatefulWidget {
  final GlobalKey? inputKey;
  final List<DropDownItem<T>> items;
  final DropDownItem<T>? selectedItem;
  final DropDownItemCallback<T> onChanged;
  final Widget Function(BuildContext, DropDownItem<T>, bool)? popupItemBuilder;
  final InputDecoration decoration;
  final double width;
  final double maxDropdownHeight;
  final double elevation;
  final bool showKeyboard;
  final double textSize;
  final double? itemHeight;
  final bool enabled;

  const SearchDropdownBase({
    super.key,
    this.inputKey,
    required this.items,
    this.selectedItem,
    required this.onChanged,
    this.popupItemBuilder,
    required this.decoration,
    required this.width,
    this.maxDropdownHeight = 200.0,
    this.elevation = 4.0,
    this.showKeyboard = false,
    this.textSize = 12.0,
    this.itemHeight,
    this.enabled = true,
  });
}

/// Dropdown interaction state
enum DropdownInteractionState {
  /// User is not actively editing the text field
  idle,

  /// User is actively typing/editing to search
  editing,
}

abstract class SearchDropdownBaseState<T, W extends SearchDropdownBase<T>>
    extends State<W> {
  // Constants for UI measurements (#6)
  static const double _defaultFallbackItemPadding = 16.0;
  static const double _fallbackItemTextMultiplier = 1.2;
  static const int _maxScrollRetries = 10;
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 200);
  static const Duration _scrollDebounceDelay = Duration(milliseconds: 150);
  static const double kDropdownItemHeight = 40.0;
  static const double kCenteringDivisor = 2.0;
  static const double kDropdownMargin = 4.0;
  static const double kDropdownElevation = 4.0;
  static const double kDropdownFontSize = 12.0;
  static const double kDropdownMaxHeightDivisor = 2.0;
  static const double kSelectedItemBackgroundAlpha = 0.12;

  // Shared highlight index constants
  static const int kNoHighlight = -1;

  final GlobalKey internalFieldKey = GlobalKey();
  late final TextEditingController controller;
  late final ScrollController scrollController;
  late final FocusNode focusNode;
  double? measuredItemHeight;
  int hoverIndex = kNoHighlight;
  int keyboardHighlightIndex = kNoHighlight; // Track keyboard navigation highlight
  final LayerLink layerLink = LayerLink();
  final OverlayPortalController overlayPortalController = OverlayPortalController();

  double get fallbackItemExtent =>
      widget.textSize * _fallbackItemTextMultiplier +
          _defaultFallbackItemPadding;

  double get itemExtent =>
      widget.itemHeight ?? measuredItemHeight ?? fallbackItemExtent;

  // State management (#15 - simplified with enum)
  DropdownInteractionState _interactionState = DropdownInteractionState.idle;

  bool get isUserEditing =>
      _interactionState == DropdownInteractionState.editing;

  set isUserEditing(bool value) {
    _interactionState = value
        ? DropdownInteractionState.editing
        : DropdownInteractionState.idle;
  }

  // Internal selection state (source of truth)
  DropDownItem<T>? _selected;
  bool _squelchOnChanged = false;

  // Expose controlled access for subclasses in other files
  DropDownItem<T>? get internalSelected => _selected;

  void setInternalSelection(DropDownItem<T>? item) => _selected = item;

  void withSquelch(void Function() action) {
    _squelchOnChanged = true;
    try {
      action();
    } finally {
      _squelchOnChanged = false;
    }
  }

  bool get squelching => _squelchOnChanged;

  String get selectedLabelText => _selected?.label ?? '';

  // Optimized filtering (#8)
  late List<({String label, DropDownItem<T> item})> _normalizedItems;
  List<DropDownItem<T>>? _lastItemsRef;
  List<DropDownItem<T>>? _cachedFilteredItems;
  String _lastFilterInput = '';

  List<DropDownItem<T>> get filtered {
    final String input = controller.text.trim().toLowerCase();

    if (!identical(_lastItemsRef, widget.items)) {
      _initializeNormalizedItems();
      _cachedFilteredItems = null;
      _lastFilterInput = '';
    }

    if (!isUserEditing || input.isEmpty) {
      return widget.items;
    }

    // Return cached result if input hasn't changed (#8)
    if (_lastFilterInput == input && _cachedFilteredItems != null) {
      return _cachedFilteredItems!;
    }

    // Compute and cache filtered list
    final List<DropDownItem<T>> filteredResult = _normalizedItems
        .where((entry) => entry.label.contains(input))
        .map((entry) => entry.item)
        .toList(growable: false);

    _lastFilterInput = input;
    _cachedFilteredItems = filteredResult;
    return filteredResult;
  }

  void _initializeNormalizedItems() {
    _lastItemsRef = widget.items;
    _normalizedItems = widget.items
        .map((item) => (label: item.label.trim().toLowerCase(), item: item))
        .toList(growable: false);
  }

  // Scroll debouncing (#9)
  Timer? _scrollDebounceTimer;

  @override
  void initState() {
    super.initState();

    controller = TextEditingController(text: widget.selectedItem?.label ?? '');
    scrollController = ScrollController();
    focusNode = FocusNode()
      ..addListener(handleFocus);

    _selected = widget.selectedItem;
    _initializeNormalizedItems();

    controller.addListener(() {
      if (focusNode.hasFocus) {
        if (!isUserEditing) isUserEditing = true;
        handleSearch();
      }
    });
  }

  void _setSelected(DropDownItem<T>? newVal) {
    if (_selected?.value != newVal?.value) {
      _selected = newVal;
      widget.onChanged(newVal);
    }
  }

  void attemptSelectByInput(String input) {
    final String trimmedInput = input.trim().toLowerCase();

    // Find exact match
    DropDownItem<T>? match;
    for (final item in widget.items) {
      if (item.label.trim().toLowerCase() == trimmedInput) {
        match = item;
        break;
      }
    }

    final String currentSelected = _selected?.label.trim().toLowerCase() ?? '';

    // Case 1: Exact match → select
    if (match != null) {
      if (_selected?.value != match.value) {
        _setSelected(match);
      }
      if (isUserEditing) {
        isUserEditing = false;
        _safeSetState(() {}); // #12
      }
      return;
    }

    // Case 2: Empty input → clear selection
    if (trimmedInput.isEmpty) {
      _setSelected(null);
      return;
    }

    // Case 3: Partial backspace of selected value (prefix-aware)
    if (_selected != null &&
        currentSelected.isNotEmpty &&
        trimmedInput.length < currentSelected.length &&
        currentSelected.startsWith(trimmedInput)) {
      controller.clear();
      _setSelected(null);
      return;
    }

    // Case 4: Invalid input while a selection exists → clear selection
    if (_selected != null && trimmedInput.isNotEmpty) {
      _setSelected(null);
      return;
    }

    // Case 5: No match, no selection → clear stray text only if not editing
    if (_selected == null && trimmedInput.isNotEmpty && !isUserEditing) {
      controller.clear();
    }
  }

  void clearInvalid() {
    attemptSelectByInput(controller.text.trim());
  }

  void handleFocus() {
    if (focusNode.hasFocus) {
      if (!overlayPortalController.isShowing) {
        showOverlay();
      }
    } else {
      isUserEditing = false;
      clearInvalid();
    }
  }

  void handleSearch() {
    if (!focusNode.hasFocus) return;

    // Auto-hide if list becomes empty while typing
    if (filtered.isEmpty) {
      if (overlayPortalController.isShowing) removeOverlay();
      _safeSetState(() {});
      return;
    }

    if (!overlayPortalController.isShowing) {
      showOverlay();
      return;
    }

    // Reset keyboard highlight when search results change
    keyboardHighlightIndex = kNoHighlight;
    _safeSetState(() {});

    // Debounced scroll animation (#9)
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(_scrollDebounceDelay, () {
      _performScrollToMatch();
    });
  }

  void _performScrollToMatch() {
    if (!mounted) return;

    try {
      if (scrollController.hasClients &&
          scrollController.position.hasContentDimensions) {
        final String input = controller.text.trim().toLowerCase();
        final int idx = filtered.indexWhere((item) =>
            item.label.toLowerCase().contains(input));
        if (idx >= 0) {
          scrollController.animateTo(
            idx * kDropdownItemHeight,
            duration: _scrollAnimationDuration,
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      debugPrint('[SEARCH] Scroll failed: $e');
    }
  }

  void showOverlay() {
    if (overlayPortalController.isShowing) return;
    if (filtered.isEmpty) return;
    waitThenScrollToSelected();
    _safeSetState(() {
      hoverIndex = kNoHighlight;
      keyboardHighlightIndex = kNoHighlight;
    });
    overlayPortalController.show();
  }

  void dismissDropdown() {
    focusNode.unfocus();
    removeOverlay();
    _safeSetState(() {
      hoverIndex = kNoHighlight;
      keyboardHighlightIndex = kNoHighlight;
    });
  }

  void removeOverlay() {
    if (overlayPortalController.isShowing) {
      overlayPortalController.hide();
    }
    hoverIndex = kNoHighlight;
    keyboardHighlightIndex = kNoHighlight;
  }

  void handleArrowDown() {
    final List<DropDownItem<T>> filteredItems = filtered;
    if (filteredItems.isEmpty) return;
    if (keyboardHighlightIndex == kNoHighlight && hoverIndex != kNoHighlight) {
      keyboardHighlightIndex = hoverIndex;
    }
    _safeSetState(() {
      hoverIndex = kNoHighlight;
      // Only move down if not at bottom
      if (keyboardHighlightIndex < filteredItems.length - 1) {
        keyboardHighlightIndex++;
      }
      // else do nothing (stop at bottom)
    });
    _scrollToKeyboardHighlight();
  }

  void handleArrowUp() {
    final List<DropDownItem<T>> filteredItems = filtered;
    if (filteredItems.isEmpty) return;
    if (keyboardHighlightIndex == kNoHighlight && hoverIndex != kNoHighlight) {
      keyboardHighlightIndex = hoverIndex;
    }
    _safeSetState(() {
      hoverIndex = kNoHighlight;
      // Only move up if not at top
      if (keyboardHighlightIndex > 0) {
        keyboardHighlightIndex--;
      }
      // else do nothing (stop at top)
    });
    _scrollToKeyboardHighlight();
  }

  void _scrollToKeyboardHighlight() {
    if (keyboardHighlightIndex == kNoHighlight) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        if (scrollController.hasClients &&
            scrollController.position.hasContentDimensions) {
          final double itemTop = keyboardHighlightIndex * kDropdownItemHeight;
          final double itemBottom = itemTop + kDropdownItemHeight;
          final double viewportStart = scrollController.offset;
          final double viewportEnd = viewportStart +
              scrollController.position.viewportDimension;

          if (itemTop < viewportStart) {
            scrollController.animateTo(
              itemTop,
              duration: _scrollAnimationDuration,
              curve: Curves.easeInOut,
            );
          } else if (itemBottom > viewportEnd) {
            scrollController.animateTo(
              itemBottom - scrollController.position.viewportDimension,
              duration: _scrollAnimationDuration,
              curve: Curves.easeInOut,
            );
          }
        }
      } catch (e) {
        debugPrint('[KEYBOARD NAV] Scroll failed: $e');
      }
    });
  }

  void selectKeyboardHighlightedItem() {
    final List<DropDownItem<T>> filteredItems = filtered;
    if (keyboardHighlightIndex >= 0 &&
        keyboardHighlightIndex < filteredItems.length) {
      final DropDownItem<
          T> selectedItem = filteredItems[keyboardHighlightIndex];
      withSquelch(() {
        controller.text = selectedItem.label;
        controller.selection = const TextSelection.collapsed(offset: 0);
      });
      attemptSelectByInput(selectedItem.label);
      dismissDropdown();
    }
  }

  void waitThenScrollToSelected() {
    if (_selected == null) return;

    final int selectedIndex = filtered.indexWhere((it) =>
    it.value == _selected?.value);
    if (selectedIndex < 0) return;

    int retryCount = 0;

    void tryScroll() {
      if (!mounted || retryCount >= _maxScrollRetries) {
        if (retryCount >= _maxScrollRetries) {
          debugPrint(
              '[SCROLL] Max retries reached, aborting scroll to selected');
        }
        return;
      }

      retryCount++;

      // Always use kDropdownItemHeight since it's a constant
      if (!scrollController.hasClients ||
          !scrollController.position.hasContentDimensions) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
        return;
      }

      // Center the selected item in the viewport if possible
      final double itemTop = selectedIndex * kDropdownItemHeight;
      final double viewportHeight = scrollController.position.viewportDimension;
      final double centeredOffset = (itemTop - (viewportHeight /
          kCenteringDivisor) +
          (kDropdownItemHeight / kCenteringDivisor))
          .clamp(0.0, scrollController.position.maxScrollExtent);

      scrollController.jumpTo(centeredOffset);
      debugPrint(
          '[SCROLL] Scrolled to selected item at index $selectedIndex, offset: $centeredOffset');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tryScroll();
    });
  }

  static Widget sharedDropdownItem<T>({
    required BuildContext context,
    required DropDownItem<T> item,
    required bool isHovered,
    required bool isKeyboardHighlighted,
    required bool isSelected,
    required bool isSingleItem,
    required VoidCallback onTap,
    required Widget Function(BuildContext, DropDownItem<T>, bool) builder,
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
          .withValues(alpha: kSelectedItemBackgroundAlpha);
    } else {
      background = null;
    }
    return InkWell(
      hoverColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        height: kDropdownItemHeight,
        color: background,
        child: w,
      ),
    );
  }

  /// Shared default popup row builder for dropdown items
  /// This is always used for both single and multi when a builder is not passed.
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

  static Widget sharedDropdownOverlay<T>({
    required BuildContext context,
    required List<DropDownItem<T>> items,
    required double maxDropdownHeight,
    required double width,
    required OverlayPortalController controller,
    required ScrollController scrollController,
    required LayerLink layerLink,
    required int hoverIndex,
    required int keyboardHighlightIndex,
    required void Function(int idx) onHover,
    required void Function(DropDownItem<T>) onItemTap,
    required bool Function(DropDownItem<T>) isSelected,
    required Widget Function(BuildContext, DropDownItem<T>, bool) builder,
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

    final double availableSpaceBelow = screenHeight - viewInsets.bottom -
        (inputFieldOffset.dy + inputFieldHeight + kDropdownMargin);
    final double availableSpaceAbove = inputFieldOffset.dy - kDropdownMargin;
    final bool shouldShowBelow = availableSpaceBelow >
        maxDropdownHeight / kDropdownMaxHeightDivisor;
    final double constrainedMaxHeight = (shouldShowBelow
        ? availableSpaceBelow
        : availableSpaceAbove).clamp(
        0.0, maxDropdownHeight);

    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      offset: shouldShowBelow
          ? Offset(0.0, inputFieldHeight + kDropdownMargin)
          : Offset(0.0, -constrainedMaxHeight - kDropdownMargin),
      child: FocusScope(
        canRequestFocus: false,
        child: Material(
          elevation: kDropdownElevation,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constrainedMaxHeight,
              minWidth: width,
              maxWidth: width,
            ),
            child: DefaultTextStyle(
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontSize: kDropdownFontSize),
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemExtent: kDropdownItemHeight,
                  itemBuilder: (c, i) =>
                      sharedDropdownItem(
                        context: context,
                        item: items[i],
                        isHovered: i == hoverIndex,
                        isKeyboardHighlighted: i == keyboardHighlightIndex,
                        isSelected: isSelected(items[i]),
                        isSingleItem: items.length == 1,
                        onTap: () => onItemTap(items[i]),
                        builder: builder,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDropdownOverlay() {
    final List<DropDownItem<T>> filteredItems = filtered;
    return SearchDropdownBaseState.sharedDropdownOverlay(
      context: context,
      items: filteredItems,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: overlayPortalController,
      scrollController: scrollController,
      layerLink: layerLink,
      hoverIndex: hoverIndex,
      keyboardHighlightIndex: keyboardHighlightIndex,
      onHover: (int itemIndex) => _safeSetState(() => hoverIndex = itemIndex),
      onItemTap: (DropDownItem<T> item) {
        withSquelch(() {
          controller.text = item.label;
          controller.selection = const TextSelection.collapsed(offset: 0);
        });
        attemptSelectByInput(item.label);
        dismissDropdown();
      },
      isSelected: (DropDownItem<T> item) => item.value == _selected?.value,
      builder: (BuildContext builderContext, DropDownItem<T> item,
          bool isSelected) {
        final int itemIndex = filteredItems.indexWhere((x) =>
        x.value == item.value);
        return MouseRegion(
          onEnter: (_) {
            if (keyboardHighlightIndex == kNoHighlight) {
              _safeSetState(() => hoverIndex = itemIndex);
            }
          },
          onExit: (_) => _safeSetState(() => hoverIndex = kNoHighlight),
          child: SearchDropdownBaseState.sharedDropdownItem<T>(
            context: builderContext,
            item: item,
            isHovered: itemIndex == hoverIndex && keyboardHighlightIndex ==
                kNoHighlight,
            isKeyboardHighlighted: itemIndex == keyboardHighlightIndex,
            isSelected: isSelected,
            isSingleItem: filteredItems.length == 1,
            onTap: () {
              withSquelch(() {
                controller.text = item.label;
                controller.selection = const TextSelection.collapsed(offset: 0);
              });
              attemptSelectByInput(item.label);
              dismissDropdown();
            },
            builder: widget.popupItemBuilder ??
                SearchDropdownBaseState.defaultDropdownPopupItemBuilder<T>,
          ),
        );
      },
    );
  }

  // Helper method to safely call setState (#12)
  void _safeSetState(void Function() fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel(); // #9 - Clean up timer
    removeOverlay();
    focusNode.removeListener(handleFocus);
    focusNode.dispose();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
