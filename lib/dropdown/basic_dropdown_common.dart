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
      final ro = context.findRenderObject();
      if (ro is RenderBox) {
        widget.onChange(ro.size);
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
  static const double _dropdownMargin = 4.0;
  static const double _defaultFallbackItemPadding = 16.0;
  static const double _fallbackItemTextMultiplier = 1.2;
  static const int _maxScrollRetries = 10;
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 200);
  static const Duration _scrollDebounceDelay = Duration(milliseconds: 150);
  static const double kDropdownItemHeight = 40.0;

  final GlobalKey internalFieldKey = GlobalKey();
  late final TextEditingController controller;
  late final ScrollController scrollController;
  late final FocusNode focusNode;
  double? measuredItemHeight;
  int hoverIndex = -1;
  int keyboardHighlightIndex = -1; // Track keyboard navigation highlight
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
    final result = _normalizedItems
        .where((entry) => entry.label.contains(input))
        .map((entry) => entry.item)
        .toList(growable: false);

    _lastFilterInput = input;
    _cachedFilteredItems = result;
    return result;
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
    keyboardHighlightIndex = -1;
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
      hoverIndex = -1;
      keyboardHighlightIndex = -1;
    });
    overlayPortalController.show();
  }

  void dismissDropdown() {
    focusNode.unfocus();
    removeOverlay();
    _safeSetState(() {
      hoverIndex = -1;
      keyboardHighlightIndex = -1;
    });
  }

  void removeOverlay() {
    if (overlayPortalController.isShowing) {
      overlayPortalController.hide();
    }
    hoverIndex = -1;
    keyboardHighlightIndex = -1;
  }

  void handleArrowDown() {
    final list = filtered;
    if (list.isEmpty) return;
    if (keyboardHighlightIndex == -1 && hoverIndex != -1) {
      keyboardHighlightIndex = hoverIndex;
    }
    _safeSetState(() {
      hoverIndex = -1;
      // Only move down if not at bottom
      if (keyboardHighlightIndex < list.length - 1) {
        keyboardHighlightIndex++;
      }
      // else do nothing (stop at bottom)
    });
    _scrollToKeyboardHighlight();
  }

  void handleArrowUp() {
    final list = filtered;
    if (list.isEmpty) return;
    if (keyboardHighlightIndex == -1 && hoverIndex != -1) {
      keyboardHighlightIndex = hoverIndex;
    }
    _safeSetState(() {
      hoverIndex = -1;
      // Only move up if not at top
      if (keyboardHighlightIndex > 0) {
        keyboardHighlightIndex--;
      }
      // else do nothing (stop at top)
    });
    _scrollToKeyboardHighlight();
  }

  void _scrollToKeyboardHighlight() {
    if (keyboardHighlightIndex < 0) return;

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
    final list = filtered;
    if (keyboardHighlightIndex >= 0 && keyboardHighlightIndex < list.length) {
      final item = list[keyboardHighlightIndex];
      withSquelch(() {
        controller.text = item.label;
        controller.selection = const TextSelection.collapsed(offset: 0);
      });
      attemptSelectByInput(item.label);
      dismissDropdown();
    }
  }

  void waitThenScrollToSelected() {
    final int selectedIndex = filtered.indexWhere((it) =>
    it.value == _selected?.value);
    if (selectedIndex < 0) return;

    int retryCount = 0;

    void tryScroll() {
      if (!mounted || retryCount >= _maxScrollRetries) {
        // #3 - Added retry limit to prevent infinite loop
        if (retryCount >= _maxScrollRetries) {
          debugPrint(
              '[SCROLL] Max retries reached, aborting scroll to selected');
        }
        return;
      }

      retryCount++;

      if (widget.itemHeight == null && measuredItemHeight == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
        return;
      }
      if (!scrollController.hasClients ||
          !scrollController.position.hasContentDimensions) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
        return;
      }

      final double target = (selectedIndex * kDropdownItemHeight)
          .clamp(0.0, scrollController.position.maxScrollExtent);
      scrollController.jumpTo(target);
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
          .withOpacity(0.12);
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
      child: Text(item.label),
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

    final RenderBox? inputBox = context.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final viewInsets = mediaQuery.viewInsets;
    final offset = inputBox.localToGlobal(Offset.zero);
    final size = inputBox.size;

    const dropdownMargin = 4.0;
    final availableBelow = screenHeight - viewInsets.bottom -
        (offset.dy + size.height + dropdownMargin);
    final availableAbove = offset.dy - dropdownMargin;
    final showBelow = availableBelow > maxDropdownHeight / 2;
    final maxHeight = (showBelow ? availableBelow : availableAbove).clamp(
        0.0, maxDropdownHeight);

    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      offset: showBelow
          ? Offset(0.0, size.height + dropdownMargin)
          : Offset(0.0, -maxHeight - dropdownMargin),
      child: FocusScope(
        canRequestFocus: false,
        child: Material(
          elevation: 4.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              minWidth: size.width,
              maxWidth: size.width,
            ),
            child: DefaultTextStyle(
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontSize: 12.0),
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
    final List<DropDownItem<T>> list = filtered;
    return SearchDropdownBaseState.sharedDropdownOverlay(
      context: context,
      items: list,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: overlayPortalController,
      scrollController: scrollController,
      layerLink: layerLink,
      hoverIndex: hoverIndex,
      keyboardHighlightIndex: keyboardHighlightIndex,
      onHover: (idx) => _safeSetState(() => hoverIndex = idx),
      onItemTap: (item) {
        withSquelch(() {
          controller.text = item.label;
          controller.selection = const TextSelection.collapsed(offset: 0);
        });
        attemptSelectByInput(item.label);
        dismissDropdown();
      },
      isSelected: (item) => item.value == _selected?.value,
      builder: (context, item, isSelected) {
        final idx = list.indexWhere((x) => x.value == item.value);
        return MouseRegion(
          onEnter: (_) {
            if (keyboardHighlightIndex == -1) {
              _safeSetState(() => hoverIndex = idx);
            }
          },
          onExit: (_) => _safeSetState(() => hoverIndex = -1),
          child: SearchDropdownBaseState.sharedDropdownItem(
            context: context,
            item: item,
            isHovered: idx == hoverIndex && keyboardHighlightIndex == -1,
            isKeyboardHighlighted: idx == keyboardHighlightIndex,
            isSelected: isSelected,
            isSingleItem: list.length == 1,
            onTap: () {
              withSquelch(() {
                controller.text = item.label;
                controller.selection = const TextSelection.collapsed(offset: 0);
              });
              attemptSelectByInput(item.label);
              dismissDropdown();
            },
            builder: widget.popupItemBuilder ??
                SearchDropdownBaseState.defaultDropdownPopupItemBuilder,
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
