import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'basic_dropdown_common.dart';

/// Multi-select dropdown widget
/// Allows selecting multiple items with chip-based display
class MultiSearchDropdown<T> extends StatefulWidget {
  final GlobalKey<State<StatefulWidget>>? inputKey;
  final List<DropDownItem<T>> items;
  final List<DropDownItem<T>> selectedItems;
  final void Function(List<DropDownItem<T>>) onChanged;
  final Widget Function(BuildContext, DropDownItem<T>, bool)? popupItemBuilder;
  final InputDecoration decoration;
  final double width;
  final double? itemHeight; // Optional item height parameter
  final bool enabled;
  final double textSize;
  final int? maxSelected;
  final double? maxDropdownHeight; // Change back to maxDropdownHeight
  final bool showScrollbar;
  final double scrollbarThickness;
  final double? elevation;

  const MultiSearchDropdown({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
    required this.width,
    this.inputKey,
    this.decoration = const InputDecoration(),
    this.enabled = true,
    this.textSize = 10,
    this.maxDropdownHeight = 300, // Change back to maxDropdownHeight
    this.maxSelected,
    this.showScrollbar = true,
    this.scrollbarThickness = 6.0,
    this.itemHeight, // Optional item height
    this.popupItemBuilder,
    this.elevation,
  }) : assert(maxSelected == null ||
      maxSelected >= 2, 'maxSelected must be null or >= 2');

  @override
  State<MultiSearchDropdown<T>> createState() => _MultiSearchDropdownState<T>();
}

class _MultiSearchDropdownState<T> extends State<MultiSearchDropdown<T>> {
  // UI Layout Constants
  static const double _containerBorderRadius = 8.0;
  static const double _chipHorizontalPadding = 8.0;
  static const double _chipVerticalPadding = 6;
  static const double _chipSpacing = 4.0;
  static const double _chipDeleteIconSize = 18.0;
  static const double _chipBorderRadius = 6.0;
  static const double _chipMarginRight = 4.0;
  static const double _chipDeleteIconLeftPadding = 4.0;
  static const double _minTextFieldWidth = 100.0;

  final GlobalKey _fieldKey = GlobalKey();
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;

  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  List<DropDownItem<T>> _selected = [];
  int _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
  int _hoverIndex = DropdownConstants.kNoHighlight;
  
  // Overlay cache tracking
  Widget? _cachedOverlayWidget;
  _OverlayCacheKey? _overlayCacheKey;
  
  // Measurement helper
  final _ChipMeasurementHelper _measurements = _ChipMeasurementHelper();

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
    print("_handleFocusChange called - hasFocus=${_focusNode.hasFocus}, isShowing=${_overlayController.isShowing}");
    if (_focusNode.hasFocus) {
      if (!_overlayController.isShowing && _filtered.isNotEmpty) {
        print("_handleFocusChange - calling setState to show overlay");
        _safeSetState(() {
          _clearHighlights();
        });
        _overlayController.show();
      }
    }
  }

  void _updateSelection(void Function() selectionUpdate) {
    print("_updateSelection1 - before setState, _selected.length=${_selected.length}");
    // Preserve keyboard highlight state - only reset if keyboard navigation was active
    final bool wasKeyboardActive = _keyboardHighlightIndex != DropdownConstants.kNoHighlight;
    final int previousHoverIndex = _hoverIndex;
    _safeSetState(() {
      selectionUpdate();
      final List<DropDownItem<T>> remainingFilteredItems = _filtered;
      if (remainingFilteredItems.isNotEmpty) {
        // Only reset keyboard highlight if keyboard navigation was active
        if (wasKeyboardActive) {
          _keyboardHighlightIndex = 0;
          _hoverIndex = DropdownConstants.kNoHighlight;
        } else {
          // Clear keyboard highlight so mouse hover can work
          _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
          // Don't clear hover index - preserve it so highlighting continues to work
          // MouseRegion's onEnter will naturally update it when mouse moves
          // If hover index becomes invalid (out of bounds), it just won't highlight anything
          // until mouse moves, which is acceptable
          if (previousHoverIndex >= 0 && previousHoverIndex < remainingFilteredItems.length) {
            // Hover index is still valid, keep it
            _hoverIndex = previousHoverIndex;
          } else {
            // Hover index is invalid, clear it
            _hoverIndex = DropdownConstants.kNoHighlight;
          }
        }
      } else {
        _clearHighlights();
        print("1");
        _overlayController.hide();
     }
    });
    // Notify parent of change and schedule overlay reposition after layout settles
    print("_updateSelection - calling widget.onChanged (deferred)");
    _scheduleOverlayReposition();
    print("_updateSelection - calling _focusNode.requestFocus()");
    _focusNode.requestFocus();
    print("_updateSelection - done");
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
    print("_removeChip called - calling setState");
    setState(() {
      _selected.removeWhere((selected) => selected.value == item.value);
      // After removal, clear highlights
      _clearHighlights();
    });
    // Notify parent of change and schedule overlay reposition after layout settles
    _scheduleOverlayReposition();
    // Focus the text field after layout settles, especially important for last chip removal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
    final List<DropDownItem<T>> filteredItems = _filtered;

    if (_keyboardHighlightIndex >= 0 &&
        _keyboardHighlightIndex < filteredItems.length) {
      // Keyboard navigation is active, select highlighted item
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
    print("_handleTextChanged called with value='$value'");
    _invalidateOverlayCache(); // Invalidate cache when search changes
    _safeSetState(() {
      _filterUtils.clearCache();
      _clearHighlights();
    });
    if (_filtered.isNotEmpty && !_overlayController.isShowing) {
      _overlayController.show();
    } else if (_filtered.isEmpty && _overlayController.isShowing) {
      print("2");
      _overlayController.hide();
    }
  }

  // Helper method to safely call setState
  void _safeSetState(void Function() fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // Invalidate overlay cache - call this whenever overlay needs to rebuild
  void _invalidateOverlayCache() {
    _cachedOverlayWidget = null;
    _overlayCacheKey = null;
  }

  // Schedule overlay reposition after parent rebuilds and layout settles
  // This ensures overlay repositions after input field has moved (e.g., when chips wrap/unwrap)
  void _scheduleOverlayReposition() {
    // First post-frame: notify parent of change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged(List.from(_selected));
      // Second post-frame: after parent rebuilds and layout settles, reposition overlay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _overlayController.isShowing) {
          _invalidateOverlayCache();
          _safeSetState(() {});
        }
      });
    });
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
  Widget build(BuildContext context) {
    print("build() called - _selected.length=${_selected.length}");
    return DropdownWithOverlay(
      layerLink: _layerLink,
      overlayController: _overlayController,
      fieldKey: widget.inputKey ?? _fieldKey,
      onDismiss: () {
        _focusNode.unfocus();
        if (_overlayController.isShowing) {
          print("3");
          _overlayController.hide();
        }
      },
      overlay: _getOverlay(),
      inputField: _buildInputField(),
    );
  }

  Widget _buildInputField({InputDecoration? previewDecoration}) {
    return Container(
      key: widget.inputKey ?? _fieldKey,
      width: widget.width, // Constrain to 500px
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableWidth = constraints.maxWidth;
                final double textFieldWidth = _calculateTextFieldWidth(
                    availableWidth);

                // Measure Wrap after render to detect wrapping and get actual remaining width
                _measurements.measureWrapAndTextField(
                  wrapContext: _measurements.wrapKey.currentContext,
                  textFieldContext: _measurements.textFieldKey.currentContext,
                  lastChipContext: _measurements.lastChipKey.currentContext,
                  selectedCount: _selected.length,
                  chipSpacing: _chipSpacing,
                  minTextFieldWidth: _minTextFieldWidth,
                  safeSetState: _safeSetState,
                );

                return Wrap(
                  key: _measurements.wrapKey,
                  spacing: _chipSpacing,
                  runSpacing: _chipSpacing,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Selected chips
                    ..._selected.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final DropDownItem<T> item = entry.value;
                      final bool isLastChip = index == _selected.length - 1;
                      return _buildChip(item, isLastChip ? _measurements.lastChipKey : null);
                    }),
                    // TextField with proper width based on available space
                    if (_selected.isNotEmpty)
                      Builder(
                        builder: (context) {
                          // Use measured remaining width if available (from previous render)
                          // Otherwise use a simple calculation as initial estimate
                          final double actualRemaining = _measurements.remainingWidth ?? 
                              (availableWidth * 0.5).clamp(_minTextFieldWidth, availableWidth);

                          return _buildTextFieldChip(actualRemaining);
                        },
                      )
                    else
                      SizedBox(
                        width: textFieldWidth,
                        child: _buildTextFieldChip(textFieldWidth),
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
      // No chips, TextField takes full available space for maximum click area
      return availableWidth; // Take 100% of available space
    }

    // Estimate chip widths more accurately
    const double estimatedChipWidth = 90.0; // Better estimate for actual chip width
    final double totalChipWidth = _selected.length * estimatedChipWidth;
    final double totalSpacing = (_selected.length - 1) * _chipSpacing;
    final double usedWidth = totalChipWidth + totalSpacing;

    // TextField gets remaining space, minimum 100px (will wrap if less)
    final double remainingWidth = availableWidth - usedWidth;

    return remainingWidth.clamp(
        100.0, double.infinity); // Min 100px, no max cap
  }

  double _calculateTextFieldHeight() {
    // Calculate height to match chip: max(textLineHeight, 24px icon) + 12px padding
    // This matches the chip structure exactly
    final double fontSize = widget.textSize;
    final double textLineHeight = fontSize * 1.2;
    const double iconHeight = 24.0;
    final double rowContentHeight = textLineHeight > iconHeight ? textLineHeight : iconHeight;
    final double verticalPadding = _chipVerticalPadding * 2; // 6px top + 6px bottom = 12px
    return rowContentHeight + verticalPadding;
  }

  Widget _buildChip(DropDownItem<T> item, [GlobalKey? chipKey]) {
    // Only measure the first chip (index 0) to avoid GlobalKey conflicts
    final bool isFirstChip = _selected.isNotEmpty && _selected.first.value == item.value;
    final GlobalKey? rowKey = isFirstChip ? _measurements.chipRowKey : null;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure chip dimensions after first render (only for first chip)
        if (isFirstChip && rowKey != null) {
          _measurements.measureChip(
            context: context,
            rowKey: rowKey,
            textSize: widget.textSize,
            chipVerticalPadding: _chipVerticalPadding,
            safeSetState: _safeSetState,
          );
        }
        
        return Container(
          key: chipKey, // Use provided key (for last chip) or null
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
            key: rowKey, // Only first chip gets the key
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                item.label,
                style: TextStyle(fontSize: widget.textSize,
                    color: widget.enabled ? Colors.black : Colors.grey.shade500),
              ),
              if (widget.enabled)
                Container(
                  width: 24.0, // Touch target width
                  height: 24.0, // Touch target height
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () => _removeChip(item),
                    child: Icon(Icons.close, size: _chipDeleteIconSize,
                        color: Colors.grey.shade700),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextFieldChip(double width) {
    // Use measured chip dimensions if available, otherwise fall back to calculation
    final double chipHeight = _measurements.chipHeight ?? _calculateTextFieldHeight();
    final double textLineHeight = widget.textSize * 1.2; // Approximate
    
    double textFieldPaddingTop;
    double textFieldPaddingBottom;
    
    if (_measurements.chipTextTop != null) {
      // Use measured chip text center position to align TextField text
      // chipTextTop is already the text center (rowTop + rowHeight/2)
      final double chipTextCenter = _measurements.chipTextTop!;
      // Adjust for TextField's text rendering - needs 6px offset upward
      textFieldPaddingTop = chipTextCenter - (textLineHeight / 2.0) - 6.0;
      textFieldPaddingBottom = chipHeight - textLineHeight - textFieldPaddingTop;
    } else {
      // Fallback: calculate same as chip structure (matches _calculateTextFieldHeight)
      // Chip text center = chipVerticalPadding (6px) + rowHeight/2
      // For fontSize 10: rowHeight = max(12, 24) = 24, so text center = 6 + 12 = 18
      const double iconHeight = 24.0;
      final double rowContentHeight = textLineHeight > iconHeight ? textLineHeight : iconHeight;
      final double chipTextCenter = _chipVerticalPadding + (rowContentHeight / 2.0);
      
      // Same adjustment as measured case
      textFieldPaddingTop = chipTextCenter - (textLineHeight / 2.0) - 6.0;
      textFieldPaddingBottom = chipHeight - textLineHeight - textFieldPaddingTop;
      
      debugPrint('TEXTFIELD ALIGNMENT (fallback):');
      debugPrint('  Calculated chip text center: $chipTextCenter');
      debugPrint('  TextField padding top: $textFieldPaddingTop');
      debugPrint('  TextField padding bottom: $textFieldPaddingBottom');
    }
    
    // Use Container with exact width - Wrap will use this for layout
    return Container(
      key: _measurements.textFieldKey, // Key to measure TextField position
      width: width, // Exact width - Wrap will use this
      height: chipHeight, // Use measured chip height
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: TextStyle(fontSize: widget.textSize),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(
            right: widget.textSize * 1.2,
            top: textFieldPaddingTop,
            bottom: textFieldPaddingBottom,
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

  Widget _getOverlay() {
    final List<DropDownItem<T>> filteredItems = _filtered;
    final _OverlayCacheKey currentKey = _OverlayCacheKey(
      filteredLength: filteredItems.length,
      selectedCount: _selected.length,
      hoverIndex: _hoverIndex,
      keyboardHighlightIndex: _keyboardHighlightIndex,
    );
    
    // Include hover and keyboard highlight in cache key so overlay rebuilds when they change
    // This ensures hover state is current, while stable keys prevent flicker
    if (_cachedOverlayWidget != null && _overlayCacheKey == currentKey) {
      print("_getOverlay: returning cached overlay, key=$currentKey");
      return _cachedOverlayWidget!;
    }
    
    print("_getOverlay: building new overlay, key=$currentKey");
    _cachedOverlayWidget = _buildOverlay();
    _overlayCacheKey = currentKey;
    return _cachedOverlayWidget!;
  }

  Widget _buildOverlay() {
    final List<DropDownItem<T>> filteredItems = _filtered;
    
    // Get the input field's context for proper positioning
    final BuildContext? inputContext = (widget.inputKey ?? _fieldKey)
        .currentContext;
    if (inputContext == null) {
      print("_buildOverlay: inputContext is null, returning cached or SizedBox.shrink");
      // Return cached overlay if available, otherwise empty
      return _cachedOverlayWidget ?? const SizedBox.shrink();
    }

    // Get current input field size for dynamic positioning
    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    final Size inputSize = inputBox?.size ?? Size.zero;

    if (filteredItems.isEmpty) {
      print("_buildOverlay: filteredItems is EMPTY - returning SizedBox.shrink");
      return const SizedBox.shrink();
    }

    final Widget Function(BuildContext, DropDownItem<T>, bool) itemBuilder =
        widget.popupItemBuilder ??
            DropdownRenderUtils.defaultDropdownPopupItemBuilder;

    // Use RepaintBoundary with stable key to prevent unnecessary rebuilds
    // The overlay content will update via the items list, but the widget tree structure stays stable
    return RepaintBoundary(
      key: const ValueKey<String>('overlay_stable'),
      child: Container(
        child: DropdownRenderUtils.buildDropdownOverlay(
          context: inputContext,
          items: filteredItems,
          maxDropdownHeight: widget.maxDropdownHeight ?? 200.0,
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
      ),
    );
  }
}

/// Helper class for managing chip and layout measurements
class _ChipMeasurementHelper {
  double? chipHeight;
  double? chipTextTop;
  double? chipTextHeight;
  double? chipWidth;
  double? remainingWidth;
  double wrapHeight = 34.0;
  
  final GlobalKey chipRowKey = GlobalKey();
  final GlobalKey lastChipKey = GlobalKey();
  final GlobalKey textFieldKey = GlobalKey();
  final GlobalKey wrapKey = GlobalKey();
  
  bool _isMeasuring = false;
  
  void measureChip({
    required BuildContext context,
    required GlobalKey rowKey,
    required double textSize,
    required double chipVerticalPadding,
    required void Function(void Function()) safeSetState,
  }) {
    if (_isMeasuring) return;
    _isMeasuring = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasuring = false;
      
      final RenderBox? chipBox = context.findRenderObject() as RenderBox?;
      final RenderBox? rowBox = rowKey.currentContext?.findRenderObject() as RenderBox?;
      
      if (chipBox != null && rowBox != null) {
        final double newChipHeight = chipBox.size.height;
        final double newChipWidth = chipBox.size.width;
        final double rowHeight = rowBox.size.height;
        final double rowTop = chipVerticalPadding;
        final double textCenter = rowTop + (rowHeight / 2.0);
        
        if (chipHeight != newChipHeight ||
            chipTextTop != textCenter ||
            chipTextHeight != rowHeight ||
            chipWidth != newChipWidth) {
          safeSetState(() {
            chipHeight = newChipHeight;
            chipTextTop = textCenter;
            chipTextHeight = rowHeight;
            chipWidth = newChipWidth;
          });
          
          debugPrint('CHIP MEASUREMENTS:');
          debugPrint('  Font size: $textSize');
          debugPrint('  Chip height: $newChipHeight');
          debugPrint('  Chip width: $newChipWidth');
          debugPrint('  Row top: $rowTop');
          debugPrint('  Row height: $rowHeight');
          debugPrint('  Text center: $textCenter');
        }
      }
    });
  }
  
  void measureWrapAndTextField({
    required BuildContext? wrapContext,
    required BuildContext? textFieldContext,
    required BuildContext? lastChipContext,
    required int selectedCount,
    required double chipSpacing,
    required double minTextFieldWidth,
    required void Function(void Function()) safeSetState,
  }) {
    if (_isMeasuring || wrapContext == null || selectedCount == 0) return;
    _isMeasuring = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasuring = false;
      
      final RenderBox? wrapBox = wrapContext.findRenderObject() as RenderBox?;
      if (wrapBox == null) return;
      
      final double newWrapHeight = wrapBox.size.height;
      final double wrapWidth = wrapBox.size.width;
      
      if (newWrapHeight != wrapHeight) {
        safeSetState(() {
          wrapHeight = newWrapHeight;
        });
      }
      
      final RenderBox? textFieldBox = textFieldContext?.findRenderObject() as RenderBox?;
      final RenderBox? lastChipBox = lastChipContext?.findRenderObject() as RenderBox?;
      
      if (textFieldBox != null && lastChipBox != null) {
        final Offset? textFieldPos = textFieldBox.localToGlobal(Offset.zero);
        final Offset? lastChipPos = lastChipBox.localToGlobal(Offset.zero);
        final Offset? wrapPos = wrapBox.localToGlobal(Offset.zero);
        
        if (textFieldPos != null && lastChipPos != null && wrapPos != null) {
          final double textFieldY = textFieldPos.dy - wrapPos.dy;
          final double lastChipY = lastChipPos.dy - wrapPos.dy;
          final bool isOnSameLine = (textFieldY - lastChipY).abs() < 5.0;
          
          if (isOnSameLine) {
            final double lastChipRight = lastChipPos.dx - wrapPos.dx + lastChipBox.size.width;
            final double actualRemaining = wrapWidth - lastChipRight - chipSpacing;
            
            if (actualRemaining > 0 && (remainingWidth == null ||
                (remainingWidth! - actualRemaining).abs() > 1.0)) {
              safeSetState(() {
                remainingWidth = actualRemaining.clamp(minTextFieldWidth, wrapWidth);
              });
            }
          } else {
            final double lastChipRight = lastChipPos.dx - wrapPos.dx + lastChipBox.size.width;
            final double firstLineRemaining = wrapWidth - lastChipRight - chipSpacing;
            
            if (firstLineRemaining > minTextFieldWidth) {
              safeSetState(() {
                remainingWidth = firstLineRemaining;
              });
            }
          }
        }
      }
    });
  }
}

/// Cache key for overlay widget to determine when to rebuild
class _OverlayCacheKey {
  final int filteredLength;
  final int selectedCount;
  final int hoverIndex;
  final int keyboardHighlightIndex;

  const _OverlayCacheKey({
    required this.filteredLength,
    required this.selectedCount,
    required this.hoverIndex,
    required this.keyboardHighlightIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _OverlayCacheKey &&
          runtimeType == other.runtimeType &&
          filteredLength == other.filteredLength &&
          selectedCount == other.selectedCount &&
          hoverIndex == other.hoverIndex &&
          keyboardHighlightIndex == other.keyboardHighlightIndex;

  @override
  int get hashCode =>
      filteredLength.hashCode ^
      selectedCount.hashCode ^
      hoverIndex.hashCode ^
      keyboardHighlightIndex.hashCode;

  @override
  String toString() =>
      'OverlayCacheKey(fl=$filteredLength, sc=$selectedCount, hi=$hoverIndex, khi=$keyboardHighlightIndex)';
}
