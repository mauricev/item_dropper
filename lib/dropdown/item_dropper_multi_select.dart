import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common/item_dropper_common.dart';
import 'chip_measurement_helper.dart';
import 'multi/multi_select_constants.dart';
import 'multi/multi_select_layout_calculator.dart';
import 'utils/item_dropper_add_item_utils.dart';

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
  /// Callback invoked when user wants to add a new item.
  /// Receives the search text and should return a new ItemDropperItem to add to the list.
  /// If null, the add row will not appear.
  final ItemDropperItem<T>? Function(String searchText)? onAddItem;

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
    this.maxDropdownHeight = 300.0,
    this.maxSelected,
    this.showScrollbar = true,
    this.scrollbarThickness = 6.0,
    this.itemHeight, // Optional item height
    this.popupItemBuilder,
    this.elevation,
    this.onAddItem,
  }) : assert(maxSelected == null ||
      maxSelected >= 2, 'maxSelected must be null or >= 2');

  @override
  State<MultiItemDropper<T>> createState() => _MultiItemDropperState<T>();
}

class _MultiItemDropperState<T> extends State<MultiItemDropper<T>> {

  final GlobalKey _fieldKey = GlobalKey();
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;

  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  List<ItemDropperItem<T>> _selected = [];
  int _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
  int _hoverIndex = ItemDropperConstants.kNoHighlight;
  
  
  // Measurement helper
  final ChipMeasurementHelper _measurements = ChipMeasurementHelper();
  
  // Cache decoration to prevent recreation on every build
  BoxDecoration? _cachedDecoration;
  bool? _lastFocusState;
  

  // Single rebuild mechanism - prevents cascading rebuilds
  bool _needsRebuild = false;
  bool _rebuildScheduled = false;
  // Track when we're the source of selection changes to prevent didUpdateWidget from rebuilding
  bool _isInternalSelectionChange = false;
  // Manual focus management - track focus state ourselves instead of relying on Flutter
  bool _manualFocusState = false;

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

    // Add "add item" row if no matches, search text exists, and callback is provided
    return ItemDropperAddItemUtils.addAddItemIfNeeded<T>(
      filteredItems: result,
      searchText: _searchController.text,
      originalItems: widget.items,
      hasOnAddItemCallback: () => widget.onAddItem != null,
    );
  }

  bool _isSelected(ItemDropperItem<T> item) {
    return _selected.any((selected) => selected.value == item.value);
  }

  void _clearHighlights() {
    _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
    _hoverIndex = ItemDropperConstants.kNoHighlight;
  }

  // Focus management helpers
  void _gainFocus() {
    if (!_manualFocusState) {
      _manualFocusState = true;
      _focusNode.requestFocus();
      _updateFocusVisualState();
    }
  }

  void _ensureFocusMaintained() {
    if (_manualFocusState && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void _loseFocus() {
    _manualFocusState = false;
    _updateFocusVisualState();
    _focusNode.unfocus();
  }

  // Overlay management helpers
  void _showOverlayIfNeeded() {
    if (!_overlayController.isShowing) {
      _clearHighlights();
      _overlayController.show();
    }
  }

  void _hideOverlayIfNeeded() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  void _showOverlayIfFocusedAndBelowMax() {
    if (_manualFocusState && 
        (widget.maxSelected == null || _selected.length < widget.maxSelected!)) {
      final filtered = _filtered;
      if (!_overlayController.isShowing && filtered.isNotEmpty) {
        _clearHighlights();
        _overlayController.show();
      }
    }
  }

  // Rebuild check helper
  void _requestRebuildIfNotScheduled() {
    if (!_rebuildScheduled) {
      _requestRebuild();
    }
  }

  // TextField padding calculation
  ({double top, double bottom}) _calculateTextFieldPadding({
    required double chipHeight,
    required double fontSize,
  }) {
    final double textLineHeight = fontSize * MultiSelectConstants.textLineHeightMultiplier;
    
    if (_measurements.chipTextTop != null) {
      // Use measured chip text center position to align TextField text
      // chipTextTop is already the text center (rowTop + rowHeight/2)
      final double chipTextCenter = _measurements.chipTextTop!;
      // Adjust for TextField's text rendering - needs offset upward
      final double top = chipTextCenter - (textLineHeight / 2.0) - MultiSelectConstants.textFieldPaddingOffset;
      final double bottom = chipHeight - textLineHeight - top;
      return (top: top, bottom: bottom);
    } else {
      // Fallback: calculate same as chip structure
      // Chip text center = chipVerticalPadding + rowHeight/2
      final double rowContentHeight = textLineHeight > MultiSelectConstants.iconHeight 
          ? textLineHeight 
          : MultiSelectConstants.iconHeight;
      final double chipTextCenter = MultiSelectConstants.chipVerticalPadding + (rowContentHeight / 2.0);
      
      // Same adjustment as measured case
      final double top = chipTextCenter - (textLineHeight / 2.0) - MultiSelectConstants.textFieldPaddingOffset;
      final double bottom = chipHeight - textLineHeight - top;
      return (top: top, bottom: bottom);
    }
  }

  void _handleFocusChange() {
    // Manual focus management - only update our manual state when Flutter's focus changes
    // But we control the visual state (border color) based on our manual state
    final bool flutterHasFocus = _focusNode.hasFocus;
    
    // Only update manual focus state if Flutter gained focus (user clicked TextField)
    if (flutterHasFocus && !_manualFocusState) {
      _manualFocusState = true;
      _updateFocusVisualState();
    }
    // If Flutter lost focus, clear manual state - no restoration attempts
    else if (!flutterHasFocus && _manualFocusState) {
      _manualFocusState = false;
      _updateFocusVisualState();
    }
    
    // Use manual focus state for overlay logic
    if (_manualFocusState) {
      // Don't show overlay if maxSelected is reached
      if (widget.maxSelected != null && 
          _selected.length >= widget.maxSelected!) {
        return;
      }
      
      // Show overlay when focused if there are any filtered items available
      // Use a post-frame callback to ensure input context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_manualFocusState) {
          return;
        }
        
        // Check again if maxSelected is reached (might have changed)
        if (widget.maxSelected != null && 
            _selected.length >= widget.maxSelected!) {
          return;
        }
        
        final filtered = _filtered;
        if (!_overlayController.isShowing && filtered.isNotEmpty) {
          _showOverlayIfNeeded();
        }
      });
    }
  }
  
  // Update visual state (border color) based on manual focus state
  void _updateFocusVisualState() {
    if (_rebuildScheduled) {
      return;
    }
    if (_isInternalSelectionChange) {
      return;
    }
    _safeSetState(() {
      // Invalidate decoration cache so it rebuilds with new focus state
      _cachedDecoration = null;
    });
  }

  void _updateSelection(void Function() selectionUpdate) {
    // Mark that we're the source of this selection change
    _isInternalSelectionChange = true;
    
    // Preserve keyboard highlight state - only reset if keyboard navigation was active
    final bool wasKeyboardActive = _keyboardHighlightIndex != ItemDropperConstants.kNoHighlight;
    final int previousHoverIndex = _hoverIndex;
    
    // Update selection and all related state inside setState to ensure single rebuild
    _requestRebuild(() {
      // Update selection inside the rebuild callback
      selectionUpdate();
      
      // Update highlights based on filtered items
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
        _hideOverlayIfNeeded();
      }
    });
    
    // Defer parent notification until after our rebuild completes
    // Single post-frame callback is sufficient - our rebuild completes in the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onChanged(List.from(_selected));
        // Clear the internal change flag after parent has been notified
        // This allows didUpdateWidget to detect external changes in the next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _isInternalSelectionChange = false;
            // Invalidate overlay cache if showing (will rebuild on next natural build)
            if (_overlayController.isShowing) {
            }
          }
        });
      }
    });
    
    // Manual focus management - ensure focus is maintained after selection update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _manualFocusState && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  void _toggleItem(ItemDropperItem<T> item) {
    // Group headers cannot be selected
    if (item.isGroupHeader) {
      return;
    }
    
    // Handle add item selection
    if (ItemDropperAddItemUtils.isAddItem(item, widget.items)) {
      final String searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(item);
      if (searchText.isNotEmpty && widget.onAddItem != null) {
        final ItemDropperItem<T>? newItem = widget.onAddItem!(searchText);
        if (newItem != null) {
          // Add the new item to the list and select it
          // Note: The parent should update widget.items to include the new item
          // For now, we'll just select it and let the parent handle adding to the list
          _updateSelection(() {
            _selected.add(newItem);
            _measurements.totalChipWidth = null;
            _searchController.clear();
            
            // If we just reached the max, close the overlay
            if (widget.maxSelected != null && 
                _selected.length >= widget.maxSelected! &&
                _overlayController.isShowing) {
              _hideOverlayIfNeeded();
            }
          });
        }
      }
      return;
    }
    
    // Manual focus management - maintain focus state when clicking overlay items
    // Don't let Flutter lose focus - we control it manually
    
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
        
        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;
        
        // Clear search text after selection for continued searching
        _searchController.clear();
        
        // If we just reached the max, close the overlay
        if (widget.maxSelected != null && 
            _selected.length >= widget.maxSelected! &&
            _overlayController.isShowing) {
          _hideOverlayIfNeeded();
        }
      } else {
        // Item is already selected, remove it (toggle off)
        _selected.removeWhere((selected) => selected.value == item.value);
        
        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;
        
        // FIX: Show overlay again if we're below maxSelected after removal
        // This handles the case where user removes an item after reaching max
        if (wasAtMax && 
            widget.maxSelected != null && 
            _selected.length < widget.maxSelected! &&
            _manualFocusState) {
          _showOverlayIfFocusedAndBelowMax();
        }
      }
      // After selection change, clear highlights
      _clearHighlights();
    });
  }

  void _removeChip(ItemDropperItem<T> item) {
    // Mark that we're the source of this selection change
    _isInternalSelectionChange = true;
    
    // Focus the field and set manual focus state when removing a chip (even if unfocused)
    // This allows users to remove chips and immediately see the dropdown
    _gainFocus();
    
    // Update selection immediately (synchronous)
    _selected.removeWhere((selected) => selected.value == item.value);
    
    // Reset totalChipWidth when selection count changes - will be remeasured correctly
    _measurements.totalChipWidth = null;
    
    _clearHighlights();
    
    // Request rebuild through central mechanism
    _requestRebuild();
    
    // Notify parent of change and handle post-removal state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onChanged(List.from(_selected));
        // Clear the internal change flag and handle focus/overlay after parent has been notified
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _isInternalSelectionChange = false;
            _ensureFocusMaintained();
            _showOverlayIfFocusedAndBelowMax();
          }
        });
      }
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
      // Manual focus management - user explicitly unfocused with Escape
      _loseFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handleArrowKeyNavigation(
    int Function({
      required int currentIndex,
      required int hoverIndex,
      required int itemCount,
      List<ItemDropperItem<T>>? items,
    }) navigationHandler,
  ) {
    final filtered = _filtered;
    _keyboardHighlightIndex = navigationHandler(
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

  void _handleArrowDown() {
    _handleArrowKeyNavigation(ItemDropperKeyboardNavigation.handleArrowDown<T>);
  }

  void _handleArrowUp() {
    _handleArrowKeyNavigation(ItemDropperKeyboardNavigation.handleArrowUp<T>);
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
        _toggleItem(selectableItems[0]);
      } else {
      }
    }
  }

  void _handleTextChanged(String value) {
    // Don't show overlay if maxSelected is reached
    if (widget.maxSelected != null && 
        _selected.length >= widget.maxSelected!) {
      _hideOverlayIfNeeded();
      return;
    }
    
    // Cache removed - overlay rebuilds automatically
    _safeSetState(() {
      _filterUtils.clearCache();
      _clearHighlights();
    });
    
    // Show overlay if there are filtered items OR if user is searching (to show empty state)
    // Use manual focus state
    if (_manualFocusState) {
      _showOverlayIfNeeded();
    } else if (_filtered.isEmpty && _overlayController.isShowing) {
      _hideOverlayIfNeeded();
    }
  }

  // Helper method to safely call setState
  void _safeSetState(void Function() fn) {
    if (mounted) {
      setState(() {
        fn();
      });
    }
  }

  // Central rebuild mechanism - prevents cascading rebuilds
  // Only allows one rebuild at a time - ignores further requests until rebuild completes
  void _requestRebuild([void Function()? stateUpdate]) {
    if (!mounted) {
      return;
    }
    
    // If rebuild already in progress, ignore this request
    if (_rebuildScheduled) {
      return;
    }
    
    // Mark that rebuild is scheduled and trigger it immediately
    _rebuildScheduled = true;
    
    // Trigger immediate rebuild - state updates happen inside setState callback
    _safeSetState(() {
      // Execute state update callback if provided
      if (stateUpdate != null) {
        stateUpdate.call();
      }
    });
    
    // After rebuild completes, reset flag to allow future rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rebuildScheduled = false;
      }
    });
  }

  @override
  void didUpdateWidget(covariant MultiItemDropper<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sync selected items if parent changed them (and we didn't cause the change)
    if (!_isInternalSelectionChange && !_areItemsEqual(widget.selectedItems, _selected)) {
      _selected = List.from(widget.selectedItems);
      // Don't trigger rebuild here if we're already rebuilding
      // Parent change will be reflected in the current rebuild cycle
      _requestRebuildIfNotScheduled();
    }
    
    // Invalidate filter cache if items list changed
    // Fast path: check reference equality first (O(1))
    if (!identical(widget.items, oldWidget.items) &&
        (widget.items.length != oldWidget.items.length ||
         !_areItemsEqual(widget.items, oldWidget.items))) {
      _filterUtils.initializeItems(widget.items);
      // Cache removed - overlay rebuilds automatically
      // Use central rebuild mechanism instead of direct setState
      // But only if not already rebuilding
      _requestRebuildIfNotScheduled();
    }
  }
  
  // Helper to check if two item lists are equal (by value)
  // Optimized for performance: early returns and efficient Set-based comparison
  // Time complexity: O(n) where n is the length of the lists
  bool _areItemsEqual(List<ItemDropperItem<T>> a, List<ItemDropperItem<T>> b) {
    // Fast path: reference equality
    if (identical(a, b)) return true;
    
    // Fast path: length check (O(1))
    if (a.length != b.length) return false;
    
    // Fast path: empty lists
    if (a.isEmpty) return true;
    
    // For small lists, use simple iteration (more cache-friendly)
    if (a.length <= MultiSelectConstants.listComparisonThreshold) {
      final Set<T> bValues = b.map((item) => item.value).toSet();
      return a.every((item) => bValues.contains(item.value));
    }
    
    // For larger lists, use Set-based comparison
    final Set<T> aValues = a.map((item) => item.value).toSet();
    final Set<T> bValues = b.map((item) => item.value).toSet();
    
    // If lengths are equal and all a values are in b, then all b values must be in a
    // (since Set length equals list length when there are no duplicates)
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
    return ItemDropperWithOverlay(
      layerLink: _layerLink,
      overlayController: _overlayController,
      fieldKey: widget.inputKey ?? _fieldKey,
      onDismiss: () {
        // Manual focus management - user clicked outside, unfocus
        _loseFocus();
        _hideOverlayIfNeeded();
      },
      overlay: _buildDropdownOverlay(),
      inputField: _buildInputField(),
    );
  }

  Widget _buildInputField({InputDecoration? previewDecoration}) {
    // Cache decoration and only recreate when manual focus state changes
    // Use manual focus state instead of Flutter's focus state for border color
    if (_cachedDecoration == null || _lastFocusState != _manualFocusState) {
      _lastFocusState = _manualFocusState;
      _cachedDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: _manualFocusState ? Colors.blue : Colors.grey.shade400,
          width: MultiSelectConstants.containerBorderWidth,
        ),
        borderRadius: BorderRadius.circular(MultiSelectConstants.containerBorderRadius),
      );
    }
    
    return Container(
      key: widget.inputKey ?? _fieldKey,
      width: widget.width, // Constrain to 500px
      // Let content determine height naturally to prevent overflow
      decoration: _cachedDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Fill available space instead of min
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Integrated chips and text field area
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MultiSelectConstants.containerPaddingLeft,
              MultiSelectConstants.containerPaddingTop,
              MultiSelectConstants.containerPaddingRight,
              MultiSelectConstants.containerPaddingBottom,
            ),
            child: LayoutBuilder(
              key: const ValueKey<String>('layout_builder_stable'),
              builder: (context, constraints) {
                final double availableWidth = constraints.maxWidth;
                final double textFieldWidth = MultiSelectLayoutCalculator.calculateTextFieldWidth(
                  availableWidth: availableWidth,
                  selectedCount: _selected.length,
                  chipSpacing: MultiSelectConstants.chipSpacing,
                  measurements: _measurements,
                );

                // Measure Wrap after render to detect wrapping and get actual remaining width
                // Only measure if contexts are available (after first frame)
                // Only measure if we have selected items (prevents measurement issues when empty)
                final wrapContext = _measurements.wrapKey.currentContext;
                if (wrapContext != null && _selected.isNotEmpty) {
                  _measurements.measureWrapAndTextField(
                    wrapContext: wrapContext,
                    textFieldContext: _measurements.textFieldKey.currentContext,
                    lastChipContext: _measurements.lastChipKey.currentContext,
                    selectedCount: _selected.length,
                    chipSpacing: MultiSelectConstants.chipSpacing,
                    minTextFieldWidth: MultiSelectConstants.minTextFieldWidth,
                    requestRebuild: _requestRebuild,
                  );
                } else if (_selected.isEmpty) {
                  // Reset measurement state when selection is cleared
                  _measurements.resetMeasurementState();
                }
                return Wrap(
                  key: _measurements.wrapKey,
                  spacing: MultiSelectConstants.chipSpacing,
                  runSpacing: MultiSelectConstants.chipSpacing,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Selected chips
                    ..._selected.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final ItemDropperItem<T> item = entry.value;
                      final bool isLastChip = index == _selected.length - 1;
                      return _buildChip(
                        item, 
                        isLastChip ? _measurements.lastChipKey : null,
                        ValueKey<T>(item.value), // Stable key based on item value
                      );
                    }),
                    // TextField with proper width based on available space
                    if (_selected.isNotEmpty && textFieldWidth > 0)
                      _buildTextFieldChip(textFieldWidth)
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


  Widget _buildChip(ItemDropperItem<T> item, [GlobalKey? chipKey, Key? valueKey]) {
    // Only measure the first chip (index 0) to avoid GlobalKey conflicts
    final bool isFirstChip = _selected.isNotEmpty && _selected.first.value == item.value;
    final GlobalKey? rowKey = isFirstChip ? _measurements.chipRowKey : null;
    
    return LayoutBuilder(
      key: valueKey, // Use stable ValueKey for widget preservation
      builder: (context, constraints) {
        // Measure chip dimensions after first render (only for first chip, only once)
        // Chip measurements don't change, so we only need to measure once
        if (isFirstChip && rowKey != null && _measurements.chipHeight == null) {
          _measurements.measureChip(
            context: context,
            rowKey: rowKey,
            textSize: widget.fieldTextStyle?.fontSize ?? MultiSelectConstants.defaultFontSize,
            chipVerticalPadding: MultiSelectConstants.chipVerticalPadding,
            requestRebuild: _requestRebuild,
          );
        }
        
        return Container(
          key: chipKey, // Use provided GlobalKey (for last chip) or null
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade100,
                Colors.blue.shade200,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(MultiSelectConstants.chipBorderRadius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MultiSelectConstants.chipHorizontalPadding,
            vertical: MultiSelectConstants.chipVerticalPadding,
          ),
          margin: const EdgeInsets.only(right: MultiSelectConstants.chipMarginRight,),
          child: Row(
            key: rowKey, // Only first chip gets the key
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                item.label,
                style: (widget.fieldTextStyle ?? const TextStyle(fontSize: MultiSelectConstants.defaultFontSize)).copyWith(
                  color: widget.enabled 
                      ? (widget.fieldTextStyle?.color ?? Colors.black)
                      : Colors.grey.shade500,
                ),
              ),
              if (widget.enabled)
                Container(
                  width: MultiSelectConstants.chipDeleteButtonSize,
                  height: MultiSelectConstants.chipDeleteButtonSize,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () => _removeChip(item),
                    child: Icon(Icons.close, size: MultiSelectConstants.chipDeleteIconSize,
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
    final double chipHeight = _measurements.chipHeight ?? MultiSelectLayoutCalculator.calculateTextFieldHeight(
      fontSize: widget.fieldTextStyle?.fontSize,
      chipVerticalPadding: MultiSelectConstants.chipVerticalPadding,
    );
    final double fontSize = widget.fieldTextStyle?.fontSize ?? MultiSelectConstants.defaultFontSize;
    final padding = _calculateTextFieldPadding(
      chipHeight: chipHeight,
      fontSize: fontSize,
    );
    final double textFieldPaddingTop = padding.top;
    final double textFieldPaddingBottom = padding.bottom;
    
    // Use Container with exact width - Wrap will use this for layout
    return SizedBox(
      key: _measurements.textFieldKey, // Key to measure TextField position
      width: width, // Exact width - Wrap will use this
      height: chipHeight, // Use measured chip height
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: widget.fieldTextStyle ?? const TextStyle(fontSize: MultiSelectConstants.defaultFontSize),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(
            right: fontSize * MultiSelectConstants.textLineHeightMultiplier,
            top: textFieldPaddingTop,
            bottom: textFieldPaddingBottom,
          ),
          border: InputBorder.none,
          hintText: 'Search',
        ),
        onChanged: (value) => _handleTextChanged(value),
        onSubmitted: (value) => _handleEnter(),
        enabled: widget.enabled,
        // Ensure TextField can receive focus
        autofocus: false,
      ),
    );
  }


  Widget _buildDropdownOverlay() {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();
    
    final List<ItemDropperItem<T>> filteredItems = _filtered;

    // Get the input field's context for proper positioning
    final BuildContext? inputContext = (widget.inputKey ?? _fieldKey)
        .currentContext;
    if (inputContext == null) return const SizedBox.shrink();
    
    // Check for field height mismatch (indicates Wrap wrapped when it shouldn't)
    final RenderBox? fieldBox = inputContext.findRenderObject() as RenderBox?;
    if (fieldBox != null && _measurements.wrapHeight != null) {
      // Calculate expected height from measured wrapHeight + padding + border
      final double verticalPadding = MultiSelectConstants.containerPaddingTop + 
          MultiSelectConstants.containerPaddingBottom;
      final double borderWidth = MultiSelectConstants.containerBorderWidth * 2.0; // top + bottom border
      final double expectedHeight = _measurements.wrapHeight! + verticalPadding + borderWidth;
    }

    // Show empty state if user is searching but no results found
    if (filteredItems.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        // User is searching but no results - show empty state
        return _buildEmptyStateOverlay(inputContext);
      }
      // No search text and no items - hide overlay
      return const SizedBox.shrink();
    }

    // Use custom builder if provided, otherwise use default with style parameters
    final Widget Function(BuildContext, ItemDropperItem<T>, bool) itemBuilder;
    if (widget.popupItemBuilder != null) {
      itemBuilder = widget.popupItemBuilder!;
    } else {
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

    // Use measured wrapHeight to calculate expected field height for accurate positioning
    // This prevents overlay flash when field height changes during chip removal
    final double? measuredWrapHeight = _measurements.wrapHeight;
    final double? expectedFieldHeight = measuredWrapHeight != null
        ? measuredWrapHeight + 
          MultiSelectConstants.containerPaddingTop + 
          MultiSelectConstants.containerPaddingBottom +
          (MultiSelectConstants.containerBorderWidth * 2.0)
        : null;
    
    return ItemDropperRenderUtils.buildDropdownOverlay(
      context: inputContext,
      items: filteredItems,
      maxDropdownHeight: widget.maxDropdownHeight ?? MultiSelectConstants.defaultMaxDropdownHeight,
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
          itemHeight: widget.itemHeight,
        );
      },
      itemHeight: widget.itemHeight,
      preferredFieldHeight: expectedFieldHeight, // Pass measured height if available
    );
  }

  /// Builds an empty state overlay when search returns no results
  Widget _buildEmptyStateOverlay(BuildContext inputContext) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();
    
    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final double inputFieldHeight = inputBox.size.height;
    final double maxDropdownHeight = widget.maxDropdownHeight ?? MultiSelectConstants.defaultMaxDropdownHeight;
    
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
            padding: const EdgeInsets.symmetric(
              horizontal: MultiSelectConstants.emptyStatePaddingHorizontal,
              vertical: MultiSelectConstants.emptyStatePaddingVertical,
            ),
            child: Text(
              MultiSelectConstants.emptyStateMessage,
              style: (widget.popupTextStyle ?? widget.fieldTextStyle ?? const TextStyle(fontSize: MultiSelectConstants.defaultFontSize)).copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

