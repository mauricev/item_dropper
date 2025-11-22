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
  final Widget Function(BuildContext, DropDownItem<
      T>, bool isSelected)? popupItemBuilder;
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
  static const double _chipVerticalPadding = 10.0;
  static const double _chipSpacing = 4.0;
  static const double _iconSize = 16.0;
  static const double _chipDeleteIconSize = 14.0;
  static const double _chipBorderRadius = 6.0;
  static const double _chipMarginRight = 4.0;
  static const double _chipDeleteIconLeftPadding = 4.0;
  static const double _textFieldVerticalPadding = 2.0;
  static const double _textFieldHorizontalPadding = 12.0;
  static const double _suffixIconWidth = 60.0;
  static const double _iconButtonSize = 24.0;
  static const double _clearButtonRightPosition = 40.0;
  static const double _arrowButtonRightPosition = 10.0;

  final GlobalKey _fieldKey = GlobalKey();
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;

  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  List<DropDownItem<T>> _selected = [];
  int _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
  int _hoverIndex = DropdownConstants.kNoHighlight;

  // Use shared filter utils
  final DropdownFilterUtils<T> _filterUtils = DropdownFilterUtils<T>();

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
    return _filterUtils.getFiltered(
      widget.items,
      _searchController.text,
      isUserEditing: true, // always filter in multi-select
      excludeValues: excludeValues,
    );
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
    } else {
      // Don't hide overlay here - let explicit dismiss handle it
      // This prevents the overlay from closing when clicking on items
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
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _handleEnter();
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
    final List<DropDownItem<T>> filteredItems = _filtered;
    if (_keyboardHighlightIndex >= 0 &&
        _keyboardHighlightIndex < filteredItems.length) {
      _toggleItem(filteredItems[_keyboardHighlightIndex]);
      // highlight will be set in _toggleItem
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
      setState(() {
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
    final bool hasChips = _selected.isNotEmpty;

    // Always calculate chip area height for consistent debugging
    final double chipAreaHeight = _calculateChipAreaHeight();

    debugPrint(
        'MULTI: _buildInputField - hasChips: $hasChips, chipAreaHeight: $chipAreaHeight');

    return Container(
      key: widget.inputKey ?? _fieldKey,
      width: widget.width,
      // Let content determine height naturally
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chips area with vertical wrapping (always present for consistent height)
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 4.0),
            child: hasChips
                ? Wrap(
              spacing: _chipSpacing,
              runSpacing: _chipSpacing,
              alignment: WrapAlignment.start,
              children: _selected.map((item) => _buildChip(item)).toList(),
            )
                : SizedBox(
                height: _calculateChipAreaHeight()), // Reserve space when empty
          ),

          // Subtle separator when chips are present
          if (hasChips)
            Container(
              height: 1.0,
              margin: const EdgeInsets.symmetric(horizontal: 12.0),
              color: _focusNode.hasFocus
                  ? Colors.blue.shade100
                  : Colors.grey.shade200,
            ),

          // Text input area
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 8.0),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              style: TextStyle(fontSize: widget.textSize),
              decoration: previewDecoration ?? widget.decoration.copyWith(
                hintText: hasChips ? null : widget.decoration.hintText,
                contentPadding: const EdgeInsets.only(
                  left: 15.0,
                  right: 12.0,
                  top: 8.0,
                  bottom: 8.0,
                ),
                isDense: true,
                suffixIconConstraints: const BoxConstraints.tightFor(
                  width: _suffixIconWidth,
                  height: kMinInteractiveDimension,
                ),
                suffixIcon: DropdownSuffixIcons(
                  isDropdownShowing: _overlayController.isShowing,
                  enabled: widget.enabled,
                  onClearPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selected.clear();
                      _filterUtils.clearCache();
                      widget.onChanged([]);
                    });
                  },
                  onArrowPressed: () {
                    if (_overlayController.isShowing) {
                      _focusNode.unfocus();
                    } else {
                      _focusNode.requestFocus();
                    }
                  },
                  iconSize: _iconSize,
                  suffixIconWidth: _suffixIconWidth,
                  iconButtonSize: _iconButtonSize,
                  clearButtonRightPosition: _clearButtonRightPosition,
                  arrowButtonRightPosition: _arrowButtonRightPosition,
                ),
              ),
              enabled: widget.enabled,
            ),
          ),
        ],
      ),
    );
  }

  // Calculate minimum height based on content
  double _calculateMinHeight() {
    if (_selected.isEmpty) {
      return 56.0; // Standard TextField height when no chips
    }

    // Use the chip area height plus other components
    final double chipAreaHeight = _calculateChipAreaHeight();
    final double separatorHeight = 1.0;
    final double textFieldHeight = 40.0;
    final double topPadding = 8.0;
    final double bottomPadding = 8.0;

    final double totalHeight = topPadding + chipAreaHeight + separatorHeight +
        textFieldHeight + bottomPadding;

    final double result = totalHeight.clamp(56.0, 200.0); // Min 56, max 200

    return result;
  }

  // Calculate height needed for chip area only
  double _calculateChipAreaHeight() {
    // Always calculate, even with no chips, for consistent debugging
    final double fontSize = widget.textSize;
    final double textHeight = fontSize * 1.2; // Rough line height estimate
    final double verticalPadding = _chipVerticalPadding *
        2; // Top + bottom padding
    final double topMargin = 3.0; // Top margin from chip
    final double chipHeight = textHeight + verticalPadding + topMargin;

    final double availableWidth = widget.width -
        24.0; // Account for left/right padding
    final double estimatedChipWidth = 80.0; // Rough estimate per chip
    final int chipsPerRow = (availableWidth / estimatedChipWidth).floor();

    final int rows = _selected.isEmpty
        ? 1
        : ((_selected.length + chipsPerRow - 1) / chipsPerRow).floor();
    final double runSpacing = _chipSpacing; // Vertical spacing between rows
    final double totalHeight = rows == 0 ? 0 : (rows * chipHeight) +
        ((rows - 1) * runSpacing);

    debugPrint(
        'MULTI: _calculateChipAreaHeight - fontSize: $fontSize, textHeight: $textHeight, verticalPadding: $verticalPadding, topMargin: $topMargin');
    debugPrint(
        'MULTI: _calculateChipAreaHeight - chipHeight: $chipHeight, availableWidth: $availableWidth, estimatedChipWidth: $estimatedChipWidth');
    debugPrint(
        'MULTI: _calculateChipAreaHeight - chipsPerRow: $chipsPerRow, selectedCount: ${_selected
            .length}, rows: $rows, runSpacing: $runSpacing, totalHeight: $totalHeight');

    return totalHeight;
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
      margin: const EdgeInsets.only(right: _chipMarginRight, top: 3),
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
