import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'item_dropper_common.dart';

/// Multi-select dropdown widget
/// Allows selecting multiple items with chip-based display
class MultiItemDropper<T> extends StatefulWidget {
  /// Optional GlobalKey for the input field container.
  /// 
  /// If provided, allows external access to the input field for:
  /// - Programmatic focus control
  /// - Integration with form libraries
  /// - Testing and widget finding
  /// - Layout measurement and positioning
  /// 
  /// If not provided, an internal key is used automatically.
  /// 
  /// Example usage:
  /// ```dart
  /// final key = GlobalKey();
  /// MultiItemDropper(
  ///   inputKey: key,
  ///   // ... other parameters
  /// );
  /// // Later, access the input field:
  /// final context = key.currentContext;
  /// ```
  final GlobalKey<State<StatefulWidget>>? inputKey;
  final List<ItemDropperItem<T>> items;
  final List<ItemDropperItem<T>> selectedItems;
  final void Function(List<ItemDropperItem<T>>) onChanged;
  final Widget Function(BuildContext, ItemDropperItem<T>, bool)? popupItemBuilder;
  final double width;
  final double? itemHeight; // Optional item height parameter
  final bool enabled;
  /// TextStyle for input field text and chips.
  /// If null, defaults to fontSize 10 with black color.
  final TextStyle? fieldTextStyle;
  /// TextStyle for popup dropdown items (used by default popupItemBuilder).
  /// If null, defaults to fontSize 10.
  /// Ignored if custom popupItemBuilder is provided.
  final TextStyle? popupTextStyle;
  /// TextStyle for group headers in popup (used by default popupItemBuilder).
  /// If null, defaults to fontSize 9, bold, with reduced opacity.
  /// Ignored if custom popupItemBuilder is provided.
  final TextStyle? popupGroupHeaderStyle;
  final int? maxSelected;
  final double? maxDropdownHeight; // Change back to maxDropdownHeight
  final bool showScrollbar;
  final double scrollbarThickness;
  final double? elevation;

  const MultiItemDropper({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
    required this.width,
    this.inputKey,
    this.enabled = true,
    this.fieldTextStyle,
    this.popupTextStyle,
    this.popupGroupHeaderStyle,
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
  State<MultiItemDropper<T>> createState() => _MultiItemDropperState<T>();
}

class _MultiItemDropperState<T> extends State<MultiItemDropper<T>> {
  // UI Layout Constants
  static const double _containerBorderRadius = 8.0;
  static const double _chipHorizontalPadding = 8.0;
  static const double _chipVerticalPadding = 6;
  static const double _chipSpacing = 4.0;
  static const double _chipDeleteIconSize = 18.0;
  static const double _chipBorderRadius = 6.0;
  static const double _chipMarginRight = 4.0;
  static const double _minTextFieldWidth = 100.0;

  final GlobalKey _fieldKey = GlobalKey();
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;

  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  List<ItemDropperItem<T>> _selected = [];
  int _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
  int _hoverIndex = ItemDropperConstants.kNoHighlight;
  
  // Overlay cache tracking
  Widget? _cachedOverlayWidget;
  _OverlayCacheKey? _overlayCacheKey;
  
  // Measurement helper
  final _ChipMeasurementHelper _measurements = _ChipMeasurementHelper();

  // Use shared filter utils
  final ItemDropperFilterUtils<T> _filterUtils = ItemDropperFilterUtils<T>();

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

  List<ItemDropperItem<T>> get _filtered {
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

  bool _isSelected(ItemDropperItem<T> item) {
    return _selected.any((selected) => selected.value == item.value);
  }

  void _clearHighlights() {
    _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
    _hoverIndex = ItemDropperConstants.kNoHighlight;
  }

  void _handleFocusChange() {
    print("_handleFocusChange called - hasFocus=${_focusNode.hasFocus}, isShowing=${_overlayController.isShowing}");
    if (_focusNode.hasFocus) {
      // Don't show overlay if maxSelected is reached
      if (widget.maxSelected != null && 
          _selected.length >= widget.maxSelected!) {
        print("_handleFocusChange - maxSelected reached, not showing overlay");
        return;
      }
      
      // Show overlay when focused if there are any filtered items available
      // Use a post-frame callback to ensure input context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusNode.hasFocus) {
          print("_handleFocusChange - post-frame: not mounted or lost focus");
          return;
        }
        
        // Check again if maxSelected is reached (might have changed)
        if (widget.maxSelected != null && 
            _selected.length >= widget.maxSelected!) {
          print("_handleFocusChange - post-frame: maxSelected reached, not showing overlay");
          return;
        }
        
        // Check if input context is now available
        final BuildContext? inputContext = (widget.inputKey ?? _fieldKey).currentContext;
        if (inputContext == null) {
          print("_handleFocusChange - post-frame: inputContext still null, waiting another frame");
          // Try again next frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_focusNode.hasFocus) return;
            // Check maxSelected again
            if (widget.maxSelected != null && 
                _selected.length >= widget.maxSelected!) {
              return;
            }
            final filtered = _filtered;
            if (!_overlayController.isShowing && filtered.isNotEmpty) {
              _invalidateOverlayCache();
              _clearHighlights();
              _overlayController.show();
            }
          });
          return;
        }
        final filtered = _filtered;
        print("_handleFocusChange - post-frame: filtered.length=${filtered.length}, isShowing=${_overlayController.isShowing}");
        if (!_overlayController.isShowing && filtered.isNotEmpty) {
          print("_handleFocusChange - showing overlay in post-frame");
          // Invalidate cache to ensure overlay is rebuilt with valid context
          _invalidateOverlayCache();
          _clearHighlights();
          _overlayController.show();
          print("_handleFocusChange - overlay.show() called, isShowing=${_overlayController.isShowing}");
        }
      });
    } else {
      print("_handleFocusChange - focus lost, isShowing=${_overlayController.isShowing}");
    }
  }

  void _updateSelection(void Function() selectionUpdate) {
    print("_updateSelection1 - before setState, _selected.length=${_selected.length}");
    // Preserve keyboard highlight state - only reset if keyboard navigation was active
    final bool wasKeyboardActive = _keyboardHighlightIndex != ItemDropperConstants.kNoHighlight;
    final int previousHoverIndex = _hoverIndex;
    _safeSetState(() {
      selectionUpdate();
      final List<ItemDropperItem<T>> remainingFilteredItems = _filtered;
      if (remainingFilteredItems.isNotEmpty) {
        // Only reset keyboard highlight if keyboard navigation was active
        if (wasKeyboardActive) {
          _keyboardHighlightIndex = 0;
          _hoverIndex = ItemDropperConstants.kNoHighlight;
        } else {
          // Clear keyboard highlight so mouse hover can work
          _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
          // Don't clear hover index - preserve it so highlighting continues to work
          // MouseRegion's onEnter will naturally update it when mouse moves
          // If hover index becomes invalid (out of bounds), it just won't highlight anything
          // until mouse moves, which is acceptable
          if (previousHoverIndex >= 0 && previousHoverIndex < remainingFilteredItems.length) {
            // Hover index is still valid, keep it
            _hoverIndex = previousHoverIndex;
          } else {
            // Hover index is invalid, clear it
            _hoverIndex = ItemDropperConstants.kNoHighlight;
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

  void _toggleItem(ItemDropperItem<T> item) {
    // Group headers cannot be selected
    if (item.isGroupHeader) {
      return;
    }
    
    final bool isCurrentlySelected = _isSelected(item);
    
    // If maxSelected is set and already reached, only allow removal (toggle off)
    if (widget.maxSelected != null && 
        _selected.length >= widget.maxSelected! && 
        !isCurrentlySelected) {
      // Block adding new items when max is reached
      // Close the overlay and keep it closed
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
      return;
    }
    // Allow removing items even when max is reached (toggle behavior)
    
    _updateSelection(() {
      final bool wasAtMax = widget.maxSelected != null && 
          _selected.length >= widget.maxSelected!;
      
      if (!isCurrentlySelected) {
        _selected.add(item);
        // Clear search text after selection for continued searching
        _searchController.clear();
        
        // If we just reached the max, close the overlay
        if (widget.maxSelected != null && 
            _selected.length >= widget.maxSelected! &&
            _overlayController.isShowing) {
          _overlayController.hide();
        }
      } else {
        // Item is already selected, remove it (toggle off)
        _selected.removeWhere((selected) => selected.value == item.value);
      }
      // After selection change, clear highlights
      _clearHighlights();
    });
  }

  void _removeChip(ItemDropperItem<T> item) {
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
    final filtered = _filtered;
    _keyboardHighlightIndex = ItemDropperKeyboardNavigation.handleArrowDown<T>(
      currentIndex: _keyboardHighlightIndex,
      hoverIndex: _hoverIndex,
      itemCount: filtered.length,
      items: filtered,
    );
    _safeSetState(() {
      _hoverIndex = ItemDropperConstants.kNoHighlight;
    });
    ItemDropperKeyboardNavigation.scrollToHighlight(
      highlightIndex: _keyboardHighlightIndex,
      scrollController: _scrollController,
      mounted: mounted,
    );
  }

  void _handleArrowUp() {
    final filtered = _filtered;
    _keyboardHighlightIndex = ItemDropperKeyboardNavigation.handleArrowUp<T>(
      currentIndex: _keyboardHighlightIndex,
      hoverIndex: _hoverIndex,
      itemCount: filtered.length,
      items: filtered,
    );
    _safeSetState(() {
      _hoverIndex = ItemDropperConstants.kNoHighlight;
    });
    ItemDropperKeyboardNavigation.scrollToHighlight(
      highlightIndex: _keyboardHighlightIndex,
      scrollController: _scrollController,
      mounted: mounted,
    );
  }

  void _handleEnter() {
    final List<ItemDropperItem<T>> filteredItems = _filtered;

    if (_keyboardHighlightIndex >= 0 &&
        _keyboardHighlightIndex < filteredItems.length) {
      // Keyboard navigation is active, select highlighted item
      final item = filteredItems[_keyboardHighlightIndex];
      // Skip group headers
      if (!item.isGroupHeader) {
        _toggleItem(item);
      }
    } else {
      // Find first selectable item for auto-select
      final selectableItems = filteredItems.where((item) => !item.isGroupHeader).toList();
      if (selectableItems.length == 1) {
        // No keyboard navigation, but exactly 1 selectable item - auto-select it
        debugPrint('MULTI: Auto-selecting single item');
        _toggleItem(selectableItems[0]);
      } else {
        debugPrint('MULTI: No valid item to select');
      }
    }
  }

  void _handleTextChanged(String value) {
    print("_handleTextChanged called with value='$value'");
    
    // Don't show overlay if maxSelected is reached
    if (widget.maxSelected != null && 
        _selected.length >= widget.maxSelected!) {
      // Hide overlay if it's showing
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
      return;
    }
    
    _invalidateOverlayCache(); // Invalidate cache when search changes
    _safeSetState(() {
      _filterUtils.clearCache();
      _clearHighlights();
    });
    // Show overlay if there are filtered items OR if user is searching (to show empty state)
    if (_focusNode.hasFocus) {
      if (!_overlayController.isShowing) {
        _overlayController.show();
      }
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
  void didUpdateWidget(covariant MultiItemDropper<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sync selected items if parent changed them
    if (widget.selectedItems.length != _selected.length ||
        !widget.selectedItems.every((item) => _isSelected(item))) {
      _selected = List.from(widget.selectedItems);
    }
    
    // Invalidate filter cache if items list changed
    if (widget.items.length != oldWidget.items.length ||
        !_areItemsEqual(widget.items, oldWidget.items)) {
      _filterUtils.initializeItems(widget.items);
      _invalidateOverlayCache();
      _safeSetState(() {
        _filterUtils.clearCache();
      });
    }
  }
  
  // Helper to check if two item lists are equal (by value)
  bool _areItemsEqual(List<ItemDropperItem<T>> a, List<ItemDropperItem<T>> b) {
    if (a.length != b.length) return false;
    final Set<T> aValues = a.map((item) => item.value).toSet();
    final Set<T> bValues = b.map((item) => item.value).toSet();
    return aValues.length == bValues.length && 
           aValues.every((value) => bValues.contains(value));
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
    return ItemDropperWithOverlay(
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
                      final ItemDropperItem<T> item = entry.value;
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
    final double fontSize = widget.fieldTextStyle?.fontSize ?? 10.0;
    final double textLineHeight = fontSize * 1.2;
    const double iconHeight = 24.0;
    final double rowContentHeight = textLineHeight > iconHeight ? textLineHeight : iconHeight;
    final double verticalPadding = _chipVerticalPadding * 2; // 6px top + 6px bottom = 12px
    return rowContentHeight + verticalPadding;
  }

  Widget _buildChip(ItemDropperItem<T> item, [GlobalKey? chipKey]) {
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
            textSize: widget.fieldTextStyle?.fontSize ?? 10.0,
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
                style: (widget.fieldTextStyle ?? const TextStyle(fontSize: 10.0)).copyWith(
                  color: widget.enabled 
                      ? (widget.fieldTextStyle?.color ?? Colors.black)
                      : Colors.grey.shade500,
                ),
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
    final double fontSize = widget.fieldTextStyle?.fontSize ?? 10.0;
    final double textLineHeight = fontSize * 1.2; // Approximate
    
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
        style: widget.fieldTextStyle ?? const TextStyle(fontSize: 10.0),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(
            right: fontSize * 1.2,
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
    final List<ItemDropperItem<T>> filteredItems = _filtered;
    final _OverlayCacheKey currentKey = _OverlayCacheKey(
      filteredLength: filteredItems.length,
      selectedCount: _selected.length,
      hoverIndex: _hoverIndex,
      keyboardHighlightIndex: _keyboardHighlightIndex,
    );
    
    // Check if input context is available - don't cache if it's not
    final BuildContext? inputContext = (widget.inputKey ?? _fieldKey).currentContext;
    final bool hasValidContext = inputContext != null;
    
    // Include hover and keyboard highlight in cache key so overlay rebuilds when they change
    // This ensures hover state is current, while stable keys prevent flicker
    // Only use cache if we have a valid context (otherwise overlay will be empty)
    if (_cachedOverlayWidget != null && 
        _overlayCacheKey == currentKey && 
        hasValidContext) {
      print("_getOverlay: returning cached overlay, key=$currentKey");
      return _cachedOverlayWidget!;
    }
    
    print("_getOverlay: building new overlay, key=$currentKey, hasValidContext=$hasValidContext");
    final Widget overlay = _buildOverlay();
    
    // Only cache if we have a valid context
    if (hasValidContext) {
      _cachedOverlayWidget = overlay;
      _overlayCacheKey = currentKey;
    } else {
      // Don't cache empty overlays - they'll be rebuilt when context is available
      print("_getOverlay: not caching overlay (no valid context)");
    }
    
    return overlay;
  }

  Widget _buildOverlay() {
    final List<ItemDropperItem<T>> filteredItems = _filtered;
    print("_buildOverlay called: filteredItems.length=${filteredItems.length}");
    
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
    print("_buildOverlay: inputSize=$inputSize");

    // Show empty state if user is searching but no results found
    if (filteredItems.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        // User is searching but no results - show empty state
        return _buildEmptyStateOverlay(inputContext);
      }
      // No search text and no items - hide overlay
      print("_buildOverlay: filteredItems is EMPTY - returning SizedBox.shrink");
      return const SizedBox.shrink();
    }
    
    print("_buildOverlay: building overlay with ${filteredItems.length} items");

    // Use custom builder if provided, otherwise use default with style parameters
    // We'll create a wrapper that passes separator info to the default builder
    final Widget Function(BuildContext, ItemDropperItem<T>, bool) itemBuilder;
    if (widget.popupItemBuilder != null) {
      itemBuilder = widget.popupItemBuilder!;
    } else {
      // Create a builder that tracks previous items for separator logic
      itemBuilder = (context, item, isSelected) {
        final int itemIndex = filteredItems.indexWhere((x) => x.value == item.value);
        final bool hasPrevious = itemIndex > 0;
        final bool previousIsGroupHeader = hasPrevious && filteredItems[itemIndex - 1].isGroupHeader;
        
        return ItemDropperRenderUtils.defaultDropdownPopupItemBuilder(
          context,
          item,
          isSelected,
          popupTextStyle: widget.popupTextStyle,
          popupGroupHeaderStyle: widget.popupGroupHeaderStyle,
          hasPreviousItem: hasPrevious,
          previousItemIsGroupHeader: previousIsGroupHeader,
        );
      };
    }

    // Use RepaintBoundary with stable key to prevent unnecessary rebuilds
    // The overlay content will update via the items list, but the widget tree structure stays stable
    return RepaintBoundary(
      key: const ValueKey<String>('overlay_stable'),
      child: Container(
        child: ItemDropperRenderUtils.buildDropdownOverlay(
          context: inputContext,
          items: filteredItems,
          maxDropdownHeight: widget.maxDropdownHeight ?? 200.0,
          width: widget.width,
          controller: _overlayController,
          scrollController: _scrollController,
          layerLink: _layerLink,
          isSelected: (ItemDropperItem<T> item) =>
              _selected.any((x) => x.value == item.value),
          builder: (BuildContext builderContext, ItemDropperItem<T> item,
              bool isSelected) {
            return ItemDropperRenderUtils.buildDropdownItemWithHover<T>(
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

  /// Builds an empty state overlay when search returns no results
  Widget _buildEmptyStateOverlay(BuildContext inputContext) {
    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final double inputFieldHeight = inputBox.size.height;
    final double maxDropdownHeight = widget.maxDropdownHeight ?? 200.0;
    
    final position = ItemDropperRenderUtils.calculateDropdownPosition(
      context: inputContext,
      inputBox: inputBox,
      inputFieldHeight: inputFieldHeight,
      maxDropdownHeight: maxDropdownHeight,
    );

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      offset: position.offset,
      child: SizedBox(
        width: widget.width,
        child: Material(
          elevation: ItemDropperConstants.kDropdownElevation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Text(
              'No results found',
              style: (widget.fieldTextStyle ?? const TextStyle(fontSize: 10.0)).copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
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
