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
  final Widget Function(BuildContext, DropDownItem<
      T>, bool isSelected) popupItemBuilder;
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
    required this.popupItemBuilder,
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

  final GlobalKey internalFieldKey = GlobalKey();
  late final TextEditingController controller;
  late final ScrollController scrollController;
  late final FocusNode focusNode;
  double? measuredItemHeight;
  int hoverIndex = -1;
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
      _safeSetState(() {}); // #12
      return;
    }

    if (!overlayPortalController.isShowing) {
      showOverlay();
      return;
    }

    _safeSetState(() {}); // #12

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
            idx * itemExtent,
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
    overlayPortalController.show();
  }

  void dismissDropdown() {
    focusNode.unfocus();
    removeOverlay();
  }

  void removeOverlay() {
    if (overlayPortalController.isShowing) {
      overlayPortalController.hide();
    }
    hoverIndex = -1;
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

      final double target = (selectedIndex * itemExtent)
          .clamp(0.0, scrollController.position.maxScrollExtent);
      scrollController.jumpTo(target);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tryScroll();
    });
  }

  Widget buildDropdownOverlay() {
    final List<DropDownItem<T>> list = filtered;
    if (list.isEmpty) return const SizedBox.shrink();

    final RenderBox? inputBox = (widget.inputKey ?? internalFieldKey)
        .currentContext?.findRenderObject() as RenderBox?;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double bottomInset = mediaQuery.viewInsets.bottom;
    final Offset offset = inputBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final Size size = inputBox?.size ?? Size(widget.width, 40.0);

    // Calculate available space above and below (#13 - clear variable names)
    final double availableBelow = screenHeight - bottomInset -
        (offset.dy + size.height + _dropdownMargin);
    final double availableAbove = offset.dy - _dropdownMargin;
    final bool showBelow = availableBelow > widget.maxDropdownHeight / 2;
    final double maxHeight = (showBelow ? availableBelow : availableAbove)
        .clamp(0.0, widget.maxDropdownHeight);

    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      offset: showBelow
          ? Offset(0.0, size.height + _dropdownMargin)
          : Offset(0.0, -maxHeight - _dropdownMargin),
      child: FocusScope(
        canRequestFocus: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {},
          child: Material(
            elevation: widget.elevation,
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
                    .copyWith(fontSize: widget.textSize),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: measuredItemHeight == null
                      ? ListView.builder(
                    controller: scrollController,
                    prototypeItem: widget.popupItemBuilder(
                      context,
                      list.first,
                      list.first.value == _selected?.value,
                    ),
                    padding: EdgeInsets.zero,
                    itemCount: list.length,
                    itemBuilder: (BuildContext c, int i) => buildItem(list, i),
                  )
                      : ListView.builder(
                    controller: scrollController,
                    itemExtent: itemExtent,
                    padding: EdgeInsets.zero,
                    itemCount: list.length,
                    itemBuilder: (BuildContext c, int i) => buildItem(list, i),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildItem(List<DropDownItem<T>> list, int idx) {
    final DropDownItem<T> item = list[idx];
    final bool hover = idx == hoverIndex;
    final bool sel = item.value == _selected?.value;
    final bool isSingleItem = list.length == 1;

    Widget w = widget.popupItemBuilder(context, item, sel);
    if (idx == 0 && measuredItemHeight == null) {
      w = MeasureSize(
        child: w,
        onChange: (Size s) {
          _safeSetState(() => measuredItemHeight = s.height); // #12
        },
      );
    }

    return MouseRegion(
      onEnter: (_) {
        _safeSetState(() => hoverIndex = idx); // #12
      },
      onExit: (_) {
        _safeSetState(() => hoverIndex = -1); // #12
      },
      child: InkWell(
        hoverColor: Theme
            .of(context)
            .hoverColor,
        onTap: () {
          withSquelch(() {
            controller.text = item.label;
            controller.selection = const TextSelection.collapsed(offset: 0);
          });
          attemptSelectByInput(item.label);
          dismissDropdown();
        },
        child: Container(
          color: (hover || sel || isSingleItem) ? Theme
              .of(context)
              .hoverColor : null,
          child: w,
        ),
      ),
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
