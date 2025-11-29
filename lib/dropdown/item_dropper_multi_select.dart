import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'item_dropper_common.dart';
import 'chip_measurement_helper.dart';
import 'multi_select_constants.dart';
import 'multi_select_layout_calculator.dart';

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
  final String? debugId; // Temporary debug identifier to distinguish dropdowns

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
    this.debugId, // Temporary debug identifier
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
    final String id = widget.debugId ?? 'UNKNOWN';
    debugPrint('DEBUG FREEZE: ==========================================');
    debugPrint('DEBUG FREEZE: [$id] _handleFocusChange() called');
    debugPrint('DEBUG FREEZE: [$id]   - flutterHasFocus: ${_focusNode.hasFocus}');
    debugPrint('DEBUG FREEZE: [$id]   - _manualFocusState: $_manualFocusState');
    debugPrint('DEBUG FREEZE: [$id]   - mounted: $mounted');
    debugPrint('DEBUG FREEZE: [$id]   - maxSelected: ${widget.maxSelected}');
    debugPrint('DEBUG FREEZE: [$id]   - selected.length: ${_selected.length}');
    
    // Manual focus management - only update our manual state when Flutter's focus changes
    // But we control the visual state (border color) based on our manual state
    final bool flutterHasFocus = _focusNode.hasFocus;
    
    // Only update manual focus state if Flutter gained focus (user clicked TextField)
    if (flutterHasFocus && !_manualFocusState) {
      debugPrint('DEBUG FREEZE: [$id]   -> Flutter gained focus, updating manual state');
      _manualFocusState = true;
      _updateFocusVisualState();
      debugPrint('DEBUG FREEZE: [$id]   -> After _updateFocusVisualState()');
    }
    // If Flutter lost focus, clear manual state - no restoration attempts
    else if (!flutterHasFocus && _manualFocusState) {
      debugPrint('DEBUG FREEZE: [$id]   -> Flutter lost focus, clearing manual state');
      _manualFocusState = false;
      _updateFocusVisualState();
      debugPrint('DEBUG FREEZE: [$id]   -> Manual state cleared');
    }
    
    // Use manual focus state for overlay logic
    if (_manualFocusState) {
      debugPrint('DEBUG FREEZE: [$id]   -> Manual focus state is true, checking overlay');
      // Don't show overlay if maxSelected is reached
      if (widget.maxSelected != null && 
          _selected.length >= widget.maxSelected!) {
        debugPrint('DEBUG FREEZE: [$id]   -> maxSelected reached, not showing overlay');
        return;
      }
      
      debugPrint('DEBUG FREEZE: [$id]   -> Scheduling post-frame callback to show overlay');
      // Show overlay when focused if there are any filtered items available
      // Use a post-frame callback to ensure input context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('DEBUG FREEZE: [$id]   -> Post-frame callback executing');
        debugPrint('DEBUG FREEZE: [$id]     - mounted: $mounted');
        debugPrint('DEBUG FREEZE: [$id]     - _manualFocusState: $_manualFocusState');
        if (!mounted || !_manualFocusState) {
          debugPrint('DEBUG FREEZE: [$id]     -> Early return (not mounted or no manual focus)');
          return;
        }
        
        // Check again if maxSelected is reached (might have changed)
        if (widget.maxSelected != null && 
            _selected.length >= widget.maxSelected!) {
          debugPrint('DEBUG FREEZE: [$id]     -> maxSelected reached in callback, not showing overlay');
          return;
        }
        
        debugPrint('DEBUG FREEZE: [$id]     -> Getting filtered items');
        final filtered = _filtered;
        debugPrint('DEBUG FREEZE: [$id]     - filtered.length: ${filtered.length}');
        debugPrint('DEBUG FREEZE: [$id]     - _overlayController.isShowing: ${_overlayController.isShowing}');
        if (!_overlayController.isShowing && filtered.isNotEmpty) {
          debugPrint('DEBUG FREEZE: [$id]     -> Showing overlay');
          _clearHighlights();
          _overlayController.show();
          debugPrint('DEBUG FREEZE: [$id]     -> After overlayController.show()');
        } else {
          debugPrint('DEBUG FREEZE: [$id]     -> Not showing overlay (already showing or no items)');
        }
        debugPrint('DEBUG FREEZE: [$id]   -> Post-frame callback complete');
      });
      debugPrint('DEBUG FREEZE: [$id]   -> Post-frame callback scheduled');
    }
    debugPrint('DEBUG FREEZE: [$id] _handleFocusChange() complete');
    debugPrint('DEBUG FREEZE: [$id] ==========================================');
  }
  
  // Update visual state (border color) based on manual focus state
  void _updateFocusVisualState() {
    final String id = widget.debugId ?? 'UNKNOWN';
    debugPrint('DEBUG FREEZE: [$id] _updateFocusVisualState() called');
    debugPrint('DEBUG FREEZE: [$id]   - _rebuildScheduled: $_rebuildScheduled');
    debugPrint('DEBUG FREEZE: [$id]   - _isInternalSelectionChange: $_isInternalSelectionChange');
    if (_rebuildScheduled) {
      debugPrint('DEBUG FREEZE: [$id]   -> Early return (rebuild scheduled)');
      return;
    }
    if (_isInternalSelectionChange) {
      debugPrint('DEBUG FREEZE: [$id]   -> Early return (internal selection change)');
      return;
    }
    debugPrint('DEBUG FREEZE: [$id]   -> Calling _safeSetState()');
    _safeSetState(() {
      // Invalidate decoration cache so it rebuilds with new focus state
      _cachedDecoration = null;
      debugPrint('DEBUG FREEZE: [$id]   -> Inside _safeSetState callback, cache cleared');
    });
    debugPrint('DEBUG FREEZE: [$id] _updateFocusVisualState() complete');
  }

  void _updateSelection(void Function() selectionUpdate) {
    final String id = widget.debugId ?? 'UNKNOWN';
    debugPrint('DEBUG FREEZE: [$id] _updateSelection() called');
    // Store focus state before selection update
    final bool hadFocusBeforeUpdate = _focusNode.hasFocus;
    debugPrint('DEBUG FREEZE: [$id]   - hadFocusBeforeUpdate: $hadFocusBeforeUpdate');
    debugPrint('DEBUG FREEZE: [$id]   - _isInternalSelectionChange: $_isInternalSelectionChange');
    
    // Mark that we're the source of this selection change
    _isInternalSelectionChange = true;
    debugPrint('DEBUG FREEZE: [$id]   -> Set _isInternalSelectionChange = true');
    
    // Preserve keyboard highlight state - only reset if keyboard navigation was active
    final bool wasKeyboardActive = _keyboardHighlightIndex != ItemDropperConstants.kNoHighlight;
    final int previousHoverIndex = _hoverIndex;
    
    // Update selection and all related state inside setState to ensure single rebuild
    debugPrint('DEBUG FREEZE: [$id]   -> Calling _requestRebuild()');
    _requestRebuild(() {
      debugPrint('DEBUG FREEZE: [$id]   -> Inside _requestRebuild callback in _updateSelection');
      // Update selection inside the rebuild callback
      debugPrint('DEBUG FREEZE: [$id]     -> Calling selectionUpdate()');
      selectionUpdate();
      debugPrint('DEBUG FREEZE: [$id]     -> selectionUpdate() complete');
      
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
        _overlayController.hide();
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
    final String id = widget.debugId ?? 'UNKNOWN';
    debugPrint('DEBUG FREEZE: [$id] _toggleItem() called');
    debugPrint('DEBUG FREEZE: [$id]   - item.label: "${item.label}"');
    debugPrint('DEBUG FREEZE: [$id]   - item.isGroupHeader: ${item.isGroupHeader}');
    
    // Group headers cannot be selected
    if (item.isGroupHeader) {
      debugPrint('DEBUG FREEZE: [$id]   -> Early return (group header)');
      return;
    }
    
    // Manual focus management - maintain focus state when clicking overlay items
    // Don't let Flutter lose focus - we control it manually
    
    final bool isCurrentlySelected = _isSelected(item);
    debugPrint('DEBUG FREEZE: [$id]   - isCurrentlySelected: $isCurrentlySelected');
    
    // If maxSelected is set and already reached, only allow removal (toggle off)
    if (widget.maxSelected != null && 
        _selected.length >= widget.maxSelected! && 
        !isCurrentlySelected) {
      debugPrint('DEBUG FREEZE: [$id]   -> maxSelected reached, blocking add');
      // Block adding new items when max is reached
      // Close the overlay and keep it closed
      if (_overlayController.isShowing) {
        debugPrint('DEBUG FREEZE: [$id]     -> Hiding overlay');
        _overlayController.hide();
      }
      debugPrint('DEBUG FREEZE: [$id]   -> Early return');
      return;
    }
    // Allow removing items even when max is reached (toggle behavior)
    
    debugPrint('DEBUG FREEZE: [$id]   -> Calling _updateSelection()');
    _updateSelection(() {
      debugPrint('DEBUG FREEZE: [$id]   -> Inside _updateSelection callback in _toggleItem');
      final bool wasAtMax = widget.maxSelected != null && 
          _selected.length >= widget.maxSelected!;
      
      if (!isCurrentlySelected) {
        final String id = widget.debugId ?? 'UNKNOWN';
        final int selectedCountBefore = _selected.length;
        debugPrint('DEBUG FREEZE: [$id]     -> Adding item (count: $selectedCountBefore)');
        _selected.add(item);
        final int selectedCountAfter = _selected.length;
        debugPrint('DEBUG FREEZE: [$id]     -> Item added (count: $selectedCountBefore -> $selectedCountAfter)');
        
        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;
        debugPrint('DEBUG FREEZE: [$id]     -> totalChipWidth reset to null');
        
        // Clear search text after selection for continued searching
        debugPrint('DEBUG FREEZE: [$id]     -> Clearing search text');
        _searchController.clear();
        debugPrint('DEBUG FREEZE: [$id]     -> Search text cleared');
        
        // If we just reached the max, close the overlay
        if (widget.maxSelected != null && 
            _selected.length >= widget.maxSelected! &&
            _overlayController.isShowing) {
          final String id = widget.debugId ?? 'UNKNOWN';
          debugPrint('DEBUG FREEZE: [$id]     -> Max reached, hiding overlay');
          _overlayController.hide();
        }
      } else {
        final String id = widget.debugId ?? 'UNKNOWN';
        debugPrint('DEBUG FREEZE: [$id]     -> Removing item (toggle off)');
        // Item is already selected, remove it (toggle off)
        _selected.removeWhere((selected) => selected.value == item.value);
        debugPrint('DEBUG FREEZE: [$id]     -> Item removed, new count: ${_selected.length}');
        
        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;
        debugPrint('DEBUG FREEZE: [$id]     -> totalChipWidth reset to null');
        
        // FIX: Show overlay again if we're below maxSelected after removal
        // This handles the case where user removes an item after reaching max
        if (wasAtMax && 
            widget.maxSelected != null && 
            _selected.length < widget.maxSelected! &&
            _manualFocusState) {
          final filtered = _filtered;
          if (!_overlayController.isShowing && filtered.isNotEmpty) {
            _clearHighlights();
            _overlayController.show();
          }
        }
      }
      // After selection change, clear highlights
      _clearHighlights();
    });
  }

  void _removeChip(ItemDropperItem<T> item) {
    // Mark that we're the source of this selection change
    _isInternalSelectionChange = true;
    
    // Update selection immediately (synchronous)
    _selected.removeWhere((selected) => selected.value == item.value);
    
    // Reset totalChipWidth when selection count changes - will be remeasured correctly
    _measurements.totalChipWidth = null;
    
    _clearHighlights();
    
    // Mark that this is an internal selection change
    _isInternalSelectionChange = true;
    
    // Request rebuild through central mechanism
    _requestRebuild();
    
    // Notify parent of change after rebuild completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onChanged(List.from(_selected));
        // Clear the internal change flag after parent has been notified
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _isInternalSelectionChange = false;
            // Invalidate overlay cache if showing (will rebuild on next natural build)
            if (_overlayController.isShowing) {
            }
            // Ensure focus is maintained (manual focus management)
            if (_manualFocusState && !_focusNode.hasFocus) {
              _focusNode.requestFocus();
            }
            
            // FIX: Show overlay again if we're below maxSelected and still focused
            // This handles the case where user removes an item after reaching max
            if (_manualFocusState && 
                (widget.maxSelected == null || _selected.length < widget.maxSelected!)) {
              final filtered = _filtered;
              if (!_overlayController.isShowing && filtered.isNotEmpty) {
                _clearHighlights();
                _overlayController.show();
              }
            }
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
      final String stackTrace = StackTrace.current.toString().split('\n').take(10).join('\n');
      _manualFocusState = false;
      _updateFocusVisualState();
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
        _toggleItem(selectableItems[0]);
      } else {
      }
    }
  }

  void _handleTextChanged(String value) {
    final String id = widget.debugId ?? 'UNKNOWN';
    debugPrint('DEBUG FREEZE: [$id] _handleTextChanged() called');
    debugPrint('DEBUG FREEZE: [$id]   - value: "$value"');
    debugPrint('DEBUG FREEZE: [$id]   - maxSelected: ${widget.maxSelected}');
    debugPrint('DEBUG FREEZE: [$id]   - selected.length: ${_selected.length}');
    debugPrint('DEBUG FREEZE: [$id]   - _manualFocusState: $_manualFocusState');
    
    // Don't show overlay if maxSelected is reached
    if (widget.maxSelected != null && 
        _selected.length >= widget.maxSelected!) {
      debugPrint('DEBUG FREEZE: [$id]   -> maxSelected reached, hiding overlay');
      // Hide overlay if it's showing
      if (_overlayController.isShowing) {
        _overlayController.hide();
        debugPrint('DEBUG FREEZE: [$id]     -> Overlay hidden');
      }
      debugPrint('DEBUG FREEZE: [$id]   -> Early return');
      return;
    }
    
    debugPrint('DEBUG FREEZE: [$id]   -> Calling _safeSetState() to clear cache');
    // Cache removed - overlay rebuilds automatically
    _safeSetState(() {
      debugPrint('DEBUG FREEZE: [$id]   -> Inside _safeSetState callback in _handleTextChanged');
      _filterUtils.clearCache();
      _clearHighlights();
      debugPrint('DEBUG FREEZE: [$id]   -> Cache cleared, highlights cleared');
    });
    debugPrint('DEBUG FREEZE: [$id]   -> After _safeSetState() in _handleTextChanged');
    
    // Show overlay if there are filtered items OR if user is searching (to show empty state)
    // Use manual focus state
    if (_manualFocusState) {
      debugPrint('DEBUG FREEZE: [$id]   -> Manual focus state is true');
      debugPrint('DEBUG FREEZE: [$id]     - _overlayController.isShowing: ${_overlayController.isShowing}');
      if (!_overlayController.isShowing) {
        debugPrint('DEBUG FREEZE: [$id]     -> Showing overlay');
        _overlayController.show();
        debugPrint('DEBUG FREEZE: [$id]     -> After overlayController.show()');
      }
    } else if (_filtered.isEmpty && _overlayController.isShowing) {
      debugPrint('DEBUG FREEZE: [$id]   -> Manual focus false and filtered empty, hiding overlay');
      _overlayController.hide();
    }
    debugPrint('DEBUG FREEZE: [$id] _handleTextChanged() complete');
  }

  // Helper method to safely call setState
  void _safeSetState(void Function() fn) {
    if (mounted) {
      setState(() {
        fn();
        // Reset flag after setState callback completes (rebuild will happen after this)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
          }
        });
      });
    }
  }

  // Central rebuild mechanism - prevents cascading rebuilds
  // Only allows one rebuild at a time - ignores further requests until rebuild completes
  void _requestRebuild([void Function()? stateUpdate]) {
    final String id = widget.debugId ?? 'UNKNOWN';
    debugPrint('DEBUG FREEZE: [$id] _requestRebuild() called');
    debugPrint('DEBUG FREEZE: [$id]   - mounted: $mounted');
    debugPrint('DEBUG FREEZE: [$id]   - _rebuildScheduled: $_rebuildScheduled');
    debugPrint('DEBUG FREEZE: [$id]   - stateUpdate: ${stateUpdate != null ? "provided" : "null"}');
    if (!mounted) {
      debugPrint('DEBUG FREEZE: [$id]   -> Early return (not mounted)');
      return;
    }
    
    // Mark that this rebuild is from active code (not commented out)
    
    // If rebuild already in progress, ignore this request
    if (_rebuildScheduled) {
      debugPrint('DEBUG FREEZE: [$id]   -> Early return (rebuild already scheduled)');
      return;
    }
    
    // Mark that rebuild is scheduled and trigger it immediately
    _rebuildScheduled = true;
    debugPrint('DEBUG FREEZE: [$id]   -> Setting _rebuildScheduled = true');
    debugPrint('DEBUG FREEZE: [$id]   -> Calling _safeSetState()');
    
    // Trigger immediate rebuild - state updates happen inside setState callback
    _safeSetState(() {
      debugPrint('DEBUG FREEZE: [$id]   -> Inside _safeSetState callback in _requestRebuild');
      // Execute state update callback if provided
      if (stateUpdate != null) {
        debugPrint('DEBUG FREEZE: [$id]     -> Calling stateUpdate callback');
        stateUpdate.call();
        debugPrint('DEBUG FREEZE: [$id]     -> stateUpdate callback complete');
      }
    });
    debugPrint('DEBUG FREEZE: [$id]   -> After _safeSetState() in _requestRebuild');
    
    // After rebuild completes, reset flag to allow future rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('DEBUG FREEZE: [$id]   -> Post-frame callback from _requestRebuild executing');
      debugPrint('DEBUG FREEZE: [$id]     - mounted: $mounted');
      if (mounted) {
        debugPrint('DEBUG FREEZE: [$id]     -> Resetting _rebuildScheduled = false');
        _rebuildScheduled = false;
        debugPrint('DEBUG FREEZE: [$id]     -> _rebuildScheduled reset complete');
      }
      debugPrint('DEBUG FREEZE: [$id]   -> Post-frame callback from _requestRebuild complete');
    });
    debugPrint('DEBUG FREEZE: [$id] _requestRebuild() complete');
  }



  @override
  void didUpdateWidget(covariant MultiItemDropper<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sync selected items if parent changed them (and we didn't cause the change)
    if (!_isInternalSelectionChange && !_areItemsEqual(widget.selectedItems, _selected)) {
      _selected = List.from(widget.selectedItems);
      // Don't trigger rebuild here if we're already rebuilding
      // Parent change will be reflected in the current rebuild cycle
      if (!_rebuildScheduled) {
        _requestRebuild();
      }
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
      if (!_rebuildScheduled) {
        _requestRebuild();
      }
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
    if (a.length <= 10) {
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
        final String stackTrace = StackTrace.current.toString().split('\n').take(10).join('\n');
        _manualFocusState = false;
        _updateFocusVisualState();
        _focusNode.unfocus();
        if (_overlayController.isShowing) {
          _overlayController.hide();
        }
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
          width: 1.0,
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
            padding: const EdgeInsets.fromLTRB(12.0, 5.0, 12.0, 3.0),
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
            textSize: widget.fieldTextStyle?.fontSize ?? 10.0,
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
      // Fallback: calculate same as chip structure
      // Chip text center = chipVerticalPadding (6px) + rowHeight/2
      // For fontSize 10: rowHeight = max(12, 24) = 24, so text center = 6 + 12 = 18
      const double iconHeight = 24.0;
      final double rowContentHeight = textLineHeight > iconHeight ? textLineHeight : iconHeight;
      final double chipTextCenter = MultiSelectConstants.chipVerticalPadding + (rowContentHeight / 2.0);
      
      // Same adjustment as measured case
      textFieldPaddingTop = chipTextCenter - (textLineHeight / 2.0) - 6.0;
      textFieldPaddingBottom = chipHeight - textLineHeight - textFieldPaddingTop;
    }
    
    // Use Container with exact width - Wrap will use this for layout
    return SizedBox(
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
        // Ensure TextField can receive focus
        autofocus: false,
      ),
    );
  }


  Widget _buildDropdownOverlay() {
    final List<ItemDropperItem<T>> filteredItems = _filtered;

    // Get the input field's context for proper positioning
    final BuildContext? inputContext = (widget.inputKey ?? _fieldKey)
        .currentContext;
    if (inputContext == null) return const SizedBox.shrink();
    
    // Check for field height mismatch (indicates Wrap wrapped when it shouldn't)
    final RenderBox? fieldBox = inputContext.findRenderObject() as RenderBox?;
    if (fieldBox != null && _measurements.wrapHeight != null) {
      // Calculate expected height from measured wrapHeight + padding + border
      // Padding: EdgeInsets.fromLTRB(12.0, 5.0, 12.0, 3.0) = 5.0 + 3.0 = 8.0 vertical
      // Border: 1.0 top + 1.0 bottom = 2.0
      const double verticalPadding = 5.0 + 3.0; // top + bottom padding
      const double borderWidth = 2.0; // top + bottom border
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

    return ItemDropperRenderUtils.buildDropdownOverlay(
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
          itemHeight: widget.itemHeight,
        );
      },
      itemHeight: widget.itemHeight,
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

