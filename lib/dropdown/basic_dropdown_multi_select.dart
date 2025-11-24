import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'basic_dropdown_common.dart';

/// Multi-select dropdown widget
/// Allows selecting multiple items with chip-based display
class MultiSearchDropdown<T> extends StatefulWidget {
  final GlobalKey? inputKey;
  final List<DropDownItem<T>> items;
  final List<DropDownItem<T>> selectedItems;
  final void Function(List<DropDownItem<T>>) onChanged;
  final Widget Function(BuildContext, DropDownItem<T>, bool)? popupItemBuilder;
  final InputDecoration decoration;
  final double width;
  final double maxDropdownHeight;
  final double elevation;
  final double textSize;
  final double? itemHeight;
  final bool enabled;

  /// Optional maximum number of selected items. If set, must be >=2. Null means unlimited.
  final int? maxSelected;

  const MultiSearchDropdown({
    super.key,
    this.inputKey,
    required this.items,
    this.selectedItems = const [],
    required this.onChanged,
    this.popupItemBuilder,
    required this.decoration,
    required this.width,
    this.maxDropdownHeight = 200.0,
    this.elevation = 4.0,
    this.textSize = 12.0,
    this.itemHeight,
    this.enabled = true,
    this.maxSelected,
  }) : assert(maxSelected == null ||
      maxSelected >= 2, 'maxSelected must be null or >= 2');

  @override
  State<MultiSearchDropdown<T>> createState() => _MultiSearchDropdownState<T>();
}

class _MultiSearchDropdownState<T> extends State<MultiSearchDropdown<T>> {
  // UI Layout Constants
  static const double _containerBorderRadius = 8.0;
  static const double _chipHorizontalPadding = 8.0;
  static const double _chipVerticalPadding = 9.5; // Fine-tuned for exactly 46px total height
  static const double _chipSpacing = 4.0;
  static const double _chipDeleteIconSize = 14.0;
  static const double _chipBorderRadius = 6.0;
  static const double _chipMarginRight = 4.0;
  static const double _chipDeleteIconLeftPadding = 4.0;

  final GlobalKey _fieldKey = GlobalKey();
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;

  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  List<DropDownItem<T>> _selected = [];
  double _measuredWrapHeight = 34.0; // Store measured Wrap height
  int _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
  int _hoverIndex = DropdownConstants.kNoHighlight;

  // Use shared filter utils
  final DropdownFilterUtils<T> _filterUtils = DropdownFilterUtils<T>();

  final GlobalKey _wrapKey = GlobalKey(); // Key to query Wrap render object

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _focusNode = FocusNode()
      ..addListener(_handleFocusChange);

    _selected = List.from(widget.selectedItems);
    _filterUtils.initializeItems(widget.items);

    _focusNode.onKeyEvent = _handleKeyEvent;
  }

  List<DropDownItem<T>> get _filtered {
    // Filter out already selected items
    final Set<T> excludeValues = _selected.map((item) => item.value).toSet();
    final result = _filterUtils.getFiltered(
      widget.items,
      _searchController.text,
      isUserEditing: true, // always filter in multi-select
      excludeValues: excludeValues,
    );

    return result;
  }

  bool _isSelected(DropDownItem<T> item) {
    return _selected.any((selected) => selected.value == item.value);
  }

  void _clearHighlights() {
    _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
    _hoverIndex = DropdownConstants.kNoHighlight;
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      if (!_overlayController.isShowing && _filtered.isNotEmpty) {
        _safeSetState(() {
          _clearHighlights();
        });
        _overlayController.show();
      }
    }
  }

  void _updateSelection(void Function() selectionUpdate) {
    setState(() {
      selectionUpdate();
      final List<DropDownItem<T>> remainingFilteredItems = _filtered;
      if (remainingFilteredItems.isNotEmpty) {
        _keyboardHighlightIndex = 0;
        _hoverIndex = DropdownConstants.kNoHighlight;
      } else {
        _clearHighlights();
        _overlayController.hide();
      }
    });
    widget.onChanged(List.from(_selected));
    _focusNode.requestFocus();
  }

  void _toggleItem(DropDownItem<T> item) {
    // If maxSelected is set and already reached, ignore further additions.
    if (widget.maxSelected != null && _selected.length >= widget.maxSelected!) {
      return;
    }
    _updateSelection(() {
      if (!_isSelected(item)) {
        _selected.add(item);
        // Clear search text after selection for continued searching
        _searchController.clear();
      }
      // After selection, clear highlights
      _clearHighlights();
    });
  }

  void _removeChip(DropDownItem<T> item) {
    setState(() {
      _selected.removeWhere((selected) => selected.value == item.value);
      // After removal, clear highlights
      _clearHighlights();
    });
    widget.onChanged(List.from(_selected));
    // Don't request focus when removing chips - this prevents dropdown from showing
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _handleArrowDown();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _handleArrowUp();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handleArrowDown() {
    _keyboardHighlightIndex = DropdownKeyboardNavigation.handleArrowDown(
      _keyboardHighlightIndex,
      _hoverIndex,
      _filtered.length,
    );
    _safeSetState(() {
      _hoverIndex = DropdownConstants.kNoHighlight;
    });
    DropdownKeyboardNavigation.scrollToHighlight(
      highlightIndex: _keyboardHighlightIndex,
      scrollController: _scrollController,
      mounted: mounted,
    );
  }

  void _handleArrowUp() {
    _keyboardHighlightIndex = DropdownKeyboardNavigation.handleArrowUp(
      _keyboardHighlightIndex,
      _hoverIndex,
      _filtered.length,
    );
    _safeSetState(() {
      _hoverIndex = DropdownConstants.kNoHighlight;
    });
    DropdownKeyboardNavigation.scrollToHighlight(
      highlightIndex: _keyboardHighlightIndex,
      scrollController: _scrollController,
      mounted: mounted,
    );
  }

  void _handleEnter() {
    debugPrint(
        'MULTI: _handleEnter called, keyboardHighlightIndex: $_keyboardHighlightIndex, filteredCount: ${_filtered
            .length}');
    final List<DropDownItem<T>> filteredItems = _filtered;

    if (_keyboardHighlightIndex >= 0 &&
        _keyboardHighlightIndex < filteredItems.length) {
      // Keyboard navigation is active, select highlighted item
      debugPrint(
          'MULTI: Selecting highlighted item at index $_keyboardHighlightIndex');
      _toggleItem(filteredItems[_keyboardHighlightIndex]);
    } else if (filteredItems.length == 1) {
      // No keyboard navigation, but exactly 1 item - auto-select it
      debugPrint('MULTI: Auto-selecting single item');
      _toggleItem(filteredItems[0]);
    } else {
      debugPrint('MULTI: No valid item to select');
    }
  }

  void _handleTextChanged(String value) {
    _safeSetState(() {
      _filterUtils.clearCache();
      _clearHighlights();
    });
    if (_filtered.isNotEmpty && !_overlayController.isShowing) {
      _overlayController.show();
    } else if (_filtered.isEmpty && _overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  // Helper method to safely call setState
  void _safeSetState(void Function() fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MultiSearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync _selected if the parent (user) updates selectedItems externally
    if (widget.selectedItems != oldWidget.selectedItems) {
      _safeSetState(() {
        _selected = List.from(widget.selectedItems);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownWithOverlay(
      layerLink: _layerLink,
      overlayController: _overlayController,
      fieldKey: widget.inputKey ?? _fieldKey,
      onDismiss: () {
        _focusNode.unfocus();
        if (_overlayController.isShowing) {
          _overlayController.hide();
        }
      },
      overlay: _buildOverlay(),
      inputField: _buildInputField(),
    );
  }

  Widget _buildInputField({InputDecoration? previewDecoration}) {
    return Container(
      key: widget.inputKey ?? _fieldKey,
      width: widget.width,
      // Let content determine height naturally to prevent overflow
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: _focusNode.hasFocus ? Colors.blue : Colors.grey.shade400,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(_containerBorderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Fill available space instead of min
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Integrated chips and text field area
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 5.0, 12.0, 3.0),
            // Consistent 12px padding
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableWidth = constraints.maxWidth;
                final double textFieldWidth = _calculateTextFieldWidth(
                    availableWidth);

                // Query Wrap for its actual rendered height after layout
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final RenderBox? wrapBox = _wrapKey.currentContext
                      ?.findRenderObject() as RenderBox?;
                  if (wrapBox != null) {
                    final double wrapHeight = wrapBox.size.height;
                    if (wrapHeight != _measuredWrapHeight) {
                      _safeSetState(() {
                        _measuredWrapHeight = wrapHeight;
                      });
                    }
                  }
                });

                return Wrap(
                  key: _wrapKey,
                  spacing: _chipSpacing,
                  runSpacing: _chipSpacing,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Selected chips
                    ..._selected.map((item) => _buildChip(item)),
                    // TextField as the last "chip" with calculated width
                    SizedBox(
                      width: textFieldWidth,
                      child: _buildTextFieldChip(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTextFieldWidth(double availableWidth) {
    if (_selected.isEmpty) {
      // No chips, TextField can take almost full available space
      return availableWidth * 0.95; // Take 95% of available space
    }

    // Estimate chip widths more accurately
    const double estimatedChipWidth = 80.0; // Rough estimate per chip
    final double totalChipWidth = _selected.length * estimatedChipWidth;
    final double totalSpacing = (_selected.length - 1) * _chipSpacing;
    final double usedWidth = totalChipWidth + totalSpacing;

    // TextField gets remaining space, but at least minimum width
    final double remainingWidth = availableWidth - usedWidth;
    return remainingWidth.clamp(100.0, double.infinity);
  }

  double _calculateChipHeight() {
    // Calculate single chip height
    final double fontSize = widget.textSize;
    final double textHeight = fontSize * 1.0; // Rough line height estimate
    final double verticalPadding = _chipVerticalPadding *
        2; // Top + bottom symmetric padding
    final double topMargin = 3.0; // Top margin from chip
    return textHeight + verticalPadding + topMargin;
  }

  Widget _buildChip(DropDownItem<T> item) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade100,
            Colors.blue.shade200,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(_chipBorderRadius),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _chipHorizontalPadding,
        vertical: _chipVerticalPadding,
      ),
      margin: const EdgeInsets.only(right: _chipMarginRight,),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            item.label,
            style: TextStyle(fontSize: widget.textSize,
                color: widget.enabled ? Colors.black : Colors.grey.shade500),
          ),
          if (widget.enabled)
            GestureDetector(
              onTap: () => _removeChip(item),
              child: Padding(
                padding: const EdgeInsets.only(
                    left: _chipDeleteIconLeftPadding),
                child: Icon(Icons.close, size: _chipDeleteIconSize,
                    color: Colors.grey.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextFieldChip() {
    return Container(
      height: _calculateChipHeight(), // Working height
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 1.0), // Temporary border
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: TextStyle(fontSize: widget.textSize),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(
            left: widget.textSize * 1.5, // 10 * 1.5 = 15
            right: widget.textSize * 1.2, // 10 * 1.2 = 12
            top: widget.textSize * 0.75, // 10 * 0.75 = 7.5
            bottom: widget.textSize * 1.75, // 10 * 1.75 = 17.5
          ),
          border: InputBorder.none,
          hintText: 'Search',
        ),
        onChanged: (value) => _handleTextChanged(value),
        onSubmitted: (value) => _handleEnter(),
        enabled: widget.enabled,
      ),
    );
  }

  Widget _buildOverlay() {
    final List<DropDownItem<T>> filteredItems = _filtered;
    final Widget Function(BuildContext, DropDownItem<T>, bool) itemBuilder =
        widget.popupItemBuilder ??
            DropdownRenderUtils.defaultDropdownPopupItemBuilder;

    // Get the input field's context for proper positioning
    final BuildContext? inputContext = (widget.inputKey ?? _fieldKey)
        .currentContext;
    if (inputContext == null) return const SizedBox.shrink();

    // Get current input field size for dynamic positioning
    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    final Size inputSize = inputBox?.size ?? Size.zero;

    return Container(
      key: ValueKey<String>(
          'overlay_${_selected.length}_${inputSize.height}_${inputSize.width}'),
      child: DropdownRenderUtils.buildDropdownOverlay(
        context: inputContext,
        items: filteredItems,
        maxDropdownHeight: widget.maxDropdownHeight,
        width: widget.width,
        controller: _overlayController,
        scrollController: _scrollController,
        layerLink: _layerLink,
        isSelected: (DropDownItem<T> item) =>
            _selected.any((x) => x.value == item.value),
        builder: (BuildContext builderContext, DropDownItem<T> item,
            bool isSelected) {
          return DropdownRenderUtils.buildDropdownItemWithHover<T>(
            context: builderContext,
            item: item,
            isSelected: isSelected,
            filteredItems: filteredItems,
            hoverIndex: _hoverIndex,
            keyboardHighlightIndex: _keyboardHighlightIndex,
            safeSetState: _safeSetState,
            setHoverIndex: (index) => _hoverIndex = index,
            onTap: () {
              _toggleItem(item);
            },
            customBuilder: itemBuilder,
          );
        },
      ),
    );
  }
}
