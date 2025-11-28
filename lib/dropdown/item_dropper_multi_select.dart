import 'dart:async';
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
  
  
  // Measurement helper
  final _ChipMeasurementHelper _measurements = _ChipMeasurementHelper();
  
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
    // Manual focus management - only update our manual state when Flutter's focus changes
    // But we control the visual state (border color) based on our manual state
    final bool flutterHasFocus = _focusNode.hasFocus;
    
    // Only update manual focus state if Flutter gained focus (user clicked TextField)
    // Don't update if Flutter lost focus - we manage that manually
    if (flutterHasFocus && !_manualFocusState) {
      _manualFocusState = true;
      _updateFocusVisualState();
    }
    // If Flutter lost focus but we want to keep it (overlay tap), restore it
    else if (!flutterHasFocus && _manualFocusState) {
      // User didn't intentionally unfocus - restore it
      scheduleMicrotask(() {
        if (mounted && _manualFocusState && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
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
          _clearHighlights();
          _overlayController.show();
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
    // Store focus state before selection update
    final bool hadFocusBeforeUpdate = _focusNode.hasFocus;
    
    // Mark that we're the source of this selection change
    _isInternalSelectionChange = true;
    
    // Set debug flag to track rebuilds after selection change
    
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
    // Group headers cannot be selected
    if (item.isGroupHeader) {
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
        final int selectedCountBefore = _selected.length;
        _selected.add(item);
        final int selectedCountAfter = _selected.length;
        
        debugPrint('DEBUG OVERLAY POS: Item added - count: $selectedCountBefore -> $selectedCountAfter, label: ${item.label}');
        
        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;
        
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
        
        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;
        
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
    
    // Set debug flag to track rebuilds after selection change
    
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
    // Don't show overlay if maxSelected is reached
    if (widget.maxSelected != null && 
        _selected.length >= widget.maxSelected!) {
      // Hide overlay if it's showing
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
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
      if (!_overlayController.isShowing) {
        _overlayController.show();
      }
    } else if (_filtered.isEmpty && _overlayController.isShowing) {
      _overlayController.hide();
    }
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
    if (!mounted) return;
    
    // Mark that this rebuild is from active code (not commented out)
    
    // If rebuild already in progress, ignore this request
    if (_rebuildScheduled) {
      return;
    }
    
    // Mark that rebuild is scheduled and trigger it immediately
    _rebuildScheduled = true;
    
    // Trigger immediate rebuild - state updates happen inside setState callback
    _safeSetState(() {
      // Execute state update callback if provided
      stateUpdate?.call();
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
        borderRadius: BorderRadius.circular(_containerBorderRadius),
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
                final double textFieldWidth = _calculateTextFieldWidth(
                    availableWidth);

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
                    chipSpacing: _chipSpacing,
                    minTextFieldWidth: _minTextFieldWidth,
                    requestRebuild: _requestRebuild,
                  );
                } else if (_selected.isEmpty) {
                  // Reset measurement state when selection is cleared
                  _measurements.resetMeasurementState();
                }
                debugPrint('DEBUG FIELD HEIGHT: Building Wrap widget');
                debugPrint('DEBUG FIELD HEIGHT:   - availableWidth: $availableWidth');
                debugPrint('DEBUG FIELD HEIGHT:   - textFieldWidth: $textFieldWidth');
                debugPrint('DEBUG FIELD HEIGHT:   - selectedCount: ${_selected.length}');
                debugPrint('DEBUG FIELD HEIGHT:   - constraints.maxWidth: ${constraints.maxWidth}');
                debugPrint('DEBUG FIELD HEIGHT:   - constraints.maxHeight: ${constraints.maxHeight}');
                
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

  double _calculateTextFieldWidth(double availableWidth) {
    if (_selected.isEmpty) {
      return availableWidth;
    }

    // Use measured chip widths - no estimates, no fallbacks
    final double? measuredTotalChipWidth = _measurements.totalChipWidth;
    if (measuredTotalChipWidth == null) {
      debugPrint('DEBUG FIELD HEIGHT: _calculateTextFieldWidth - no measurement yet, returning 0.0');
      return 0.0; // No measurement yet - don't render
    }

    // Calculate spacing:
    // - Between chips: (chipCount - 1) * spacing
    // - Between last chip and TextField: 1 * spacing (ALWAYS needed if we have chips)
    final double spacingBetweenChips = (_selected.length - 1) * _chipSpacing;
    final double spacingBeforeTextField = _chipSpacing; // Always need spacing before TextField if chips exist
    final double totalSpacing = spacingBetweenChips + spacingBeforeTextField;
    
    final double usedWidth = measuredTotalChipWidth + totalSpacing;
    final double remainingWidth = availableWidth - usedWidth;
    final double textFieldWidth = remainingWidth.clamp(100.0, availableWidth);

    debugPrint('DEBUG FIELD HEIGHT: _calculateTextFieldWidth:');
    debugPrint('DEBUG FIELD HEIGHT:   - availableWidth: $availableWidth');
    debugPrint('DEBUG FIELD HEIGHT:   - measuredTotalChipWidth: $measuredTotalChipWidth');
    debugPrint('DEBUG FIELD HEIGHT:   - spacingBetweenChips: $spacingBetweenChips');
    debugPrint('DEBUG FIELD HEIGHT:   - spacingBeforeTextField: $spacingBeforeTextField');
    debugPrint('DEBUG FIELD HEIGHT:   - totalSpacing: $totalSpacing');
    debugPrint('DEBUG FIELD HEIGHT:   - usedWidth: $usedWidth');
    debugPrint('DEBUG FIELD HEIGHT:   - remainingWidth: $remainingWidth');
    debugPrint('DEBUG FIELD HEIGHT:   - textFieldWidth: $textFieldWidth');
    debugPrint('DEBUG FIELD HEIGHT:   - Total needed: ${usedWidth + textFieldWidth}');
    debugPrint('DEBUG FIELD HEIGHT:   - Will fit: ${usedWidth + textFieldWidth <= availableWidth}');

    return textFieldWidth;
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
            chipVerticalPadding: _chipVerticalPadding,
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
      if ((fieldBox.size.height - expectedHeight).abs() > 1.0) {
        debugPrint('DEBUG FIELD HEIGHT: ==========================================');
        debugPrint('DEBUG FIELD HEIGHT: Field height mismatch detected!');
        debugPrint('DEBUG FIELD HEIGHT: Actual field height: ${fieldBox.size.height}');
        debugPrint('DEBUG FIELD HEIGHT: Expected height: $expectedHeight');
        debugPrint('DEBUG FIELD HEIGHT:   - wrapHeight: ${_measurements.wrapHeight}');
        debugPrint('DEBUG FIELD HEIGHT:   - verticalPadding: $verticalPadding (5.0 top + 3.0 bottom)');
        debugPrint('DEBUG FIELD HEIGHT:   - borderWidth: $borderWidth (1.0 top + 1.0 bottom)');
        debugPrint('DEBUG FIELD HEIGHT: Difference: ${fieldBox.size.height - expectedHeight}');
        
        // Debug: Check actual Wrap height and inspect children
        final RenderBox? wrapBox = _measurements.wrapKey.currentContext?.findRenderObject() as RenderBox?;
        if (wrapBox != null) {
          final double actualWrapHeight = wrapBox.size.height;
          debugPrint('DEBUG FIELD HEIGHT: Actual Wrap height: $actualWrapHeight');
          debugPrint('DEBUG FIELD HEIGHT: Wrap constraints: ${wrapBox.constraints}');
          
          // If Wrap wrapped, inspect children to see why
          if (actualWrapHeight > 40.0) {
            debugPrint('DEBUG FIELD HEIGHT: ⚠️⚠️⚠️ Wrap wrapped to $actualWrapHeight (expected ~36.0) ⚠️⚠️⚠️');
            debugPrint('DEBUG FIELD HEIGHT: Inspecting ALL children in Wrap...');
            double totalChildrenWidth = 0.0;
            double chipWidthSum = 0.0;
            double textFieldWidth = 0.0;
            int childIndex = 0;
            wrapBox.visitChildren((child) {
              if (child is RenderBox) {
                final String typeName = child.runtimeType.toString();
                final double childWidth = child.size.width;
                final double childHeight = child.size.height;
                totalChildrenWidth += childWidth;
                
                if (typeName.contains('LayoutBuilder')) {
                  chipWidthSum += childWidth;
                  debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] CHIP ($typeName): width=$childWidth, height=$childHeight');
                } else if (typeName.contains('ConstrainedBox') || typeName.contains('TextField') || typeName.contains('SizedBox')) {
                  textFieldWidth = childWidth;
                  debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] TEXTFIELD ($typeName): width=$childWidth, height=$childHeight');
                } else {
                  debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] OTHER ($typeName): width=$childWidth, height=$childHeight');
                }
                childIndex++;
              }
            });
            debugPrint('DEBUG FIELD HEIGHT: SUMMARY:');
            debugPrint('DEBUG FIELD HEIGHT:   - Total children width: $totalChildrenWidth');
            debugPrint('DEBUG FIELD HEIGHT:   - Chip width sum: $chipWidthSum');
            debugPrint('DEBUG FIELD HEIGHT:   - TextField width: $textFieldWidth');
            debugPrint('DEBUG FIELD HEIGHT:   - Wrap width: ${wrapBox.size.width}');
            debugPrint('DEBUG FIELD HEIGHT:   - Will wrap: ${totalChildrenWidth > wrapBox.size.width}');
            debugPrint('DEBUG FIELD HEIGHT:   - Current totalChipWidth: ${_measurements.totalChipWidth}');
            debugPrint('DEBUG FIELD HEIGHT:   - Selected count: ${_selected.length}');
            debugPrint('DEBUG FIELD HEIGHT:   - Spacing needed: ${_selected.length > 0 ? (_selected.length - 1) * _chipSpacing : 0.0}');
            debugPrint('DEBUG FIELD HEIGHT:   - Expected total: ${chipWidthSum + textFieldWidth + (_selected.length > 0 ? (_selected.length - 1) * _chipSpacing : 0.0)}');
          }
        } else {
          debugPrint('DEBUG FIELD HEIGHT: Wrap context is null!');
        }
        
        // Debug: Check Padding widget (by checking runtime type)
        RenderBox? current = fieldBox;
        while (current != null) {
          final String typeName = current.runtimeType.toString();
          if (typeName.contains('Padding')) {
            debugPrint('DEBUG FIELD HEIGHT: Found Padding render object: $typeName');
            debugPrint('DEBUG FIELD HEIGHT:   - size: ${current.size}');
            debugPrint('DEBUG FIELD HEIGHT:   - constraints: ${current.constraints}');
            break;
          }
          current = current.parent as RenderBox?;
        }
        
        // Debug: Check Column widget (by checking runtime type)
        current = fieldBox;
        while (current != null) {
          final String typeName = current.runtimeType.toString();
          if (typeName.contains('Flex') || typeName.contains('Column')) {
            debugPrint('DEBUG FIELD HEIGHT: Found Column/Flex render object: $typeName');
            debugPrint('DEBUG FIELD HEIGHT:   - size: ${current.size}');
            debugPrint('DEBUG FIELD HEIGHT:   - constraints: ${current.constraints}');
            break;
          }
          current = current.parent as RenderBox?;
        }
        
        // Debug: Check Container/field constraints
        debugPrint('DEBUG FIELD HEIGHT: Field box constraints: ${fieldBox.constraints}');
        debugPrint('DEBUG FIELD HEIGHT: ==========================================');
      }
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

/// Helper class for managing chip and layout measurements
class _ChipMeasurementHelper {
  double? chipHeight;
  double? chipTextTop;
  double? chipTextHeight;
  double? chipWidth;
  double? totalChipWidth; // Sum of all chip widths (measured)
  double? remainingWidth;
  double? wrapHeight; // Measured, no hardcoded initial value
  
  final GlobalKey chipRowKey = GlobalKey();
  final GlobalKey lastChipKey = GlobalKey();
  final GlobalKey textFieldKey = GlobalKey();
  final GlobalKey wrapKey = GlobalKey();
  
  bool _isMeasuring = false;
  int _lastMeasuredSelectedCount = -1;
  
  // Reset measurement state - call when selection is cleared
  void resetMeasurementState() {
    _lastMeasuredSelectedCount = -1;
    totalChipWidth = null;
    remainingWidth = null;
    _isMeasuring = false;
  }
  
  void measureChip({
    required BuildContext context,
    required GlobalKey rowKey,
    required double textSize,
    required double chipVerticalPadding,
    required void Function() requestRebuild, // Changed from safeSetState
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
        
        // Chip measurements only need to be done once - they don't change
        if (chipHeight == null) {
          chipHeight = newChipHeight;
          chipTextTop = textCenter;
          chipTextHeight = rowHeight;
          chipWidth = newChipWidth;
          
          
          // Don't request rebuild from measurements - measurements just update state
          // The rebuild will happen naturally on the next frame if state changed
          // Requesting rebuild here causes cascading rebuilds
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
    required void Function() requestRebuild, // Changed from safeSetState
  }) {
    // Only measure if selection count changed or we haven't measured yet
    if (wrapContext == null) return;
    
    // Reset measurement tracking when selection count goes to 0
    if (selectedCount == 0) {
      _lastMeasuredSelectedCount = -1;
      remainingWidth = null; // Reset remaining width when no items
      return;
    }
    
    // Only measure if count changed - prevents duplicate measurements during same build
    if (_lastMeasuredSelectedCount == selectedCount) return;
    if (_isMeasuring) return; // Already measuring, skip
    
    // Set immediately to prevent duplicate calls during the same build cycle
    _lastMeasuredSelectedCount = selectedCount;
    _isMeasuring = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasuring = false;
      
      final RenderBox? wrapBox = wrapContext.findRenderObject() as RenderBox?;
      if (wrapBox == null) return;
      
      final double newWrapHeight = wrapBox.size.height;
      final double wrapWidth = wrapBox.size.width;
      
      debugPrint('DEBUG FIELD HEIGHT: measureWrapAndTextField - measuring Wrap');
      debugPrint('DEBUG FIELD HEIGHT:   - wrapBox.size.height: $newWrapHeight');
      debugPrint('DEBUG FIELD HEIGHT:   - wrapBox.size.width: $wrapWidth');
      debugPrint('DEBUG FIELD HEIGHT:   - wrapBox.constraints: ${wrapBox.constraints}');
      debugPrint('DEBUG FIELD HEIGHT:   - selectedCount: $selectedCount');
      
      // DEBUG: Check if Wrap wrapped to multiple rows (this is the bug)
      // Detect wrapping by comparing to previous height or chip height
      final double? previousWrapHeight = wrapHeight;
      final double? singleRowHeight = chipHeight; // Single row should be approximately chip height
      
      // If we have a previous measurement and height increased significantly, it wrapped
      // Or if height is much larger than chip height, it wrapped
      final bool likelyWrapped = (previousWrapHeight != null && newWrapHeight > previousWrapHeight * 1.5) ||
          (singleRowHeight != null && newWrapHeight > singleRowHeight * 1.5);
      
      if (likelyWrapped) {
        debugPrint('DEBUG OVERLAY POS: BUG DETECTED - Wrap wrapped to multiple rows! Height: $newWrapHeight (previous: $previousWrapHeight, chipHeight: $singleRowHeight)');
        debugPrint('DEBUG OVERLAY POS: Wrap width: $wrapWidth, selectedCount: $selectedCount, constraints maxWidth: ${wrapBox.constraints.maxWidth}');
        
          // Calculate total width needed and inspect children
        double totalWidthNeeded = 0.0;
        double measuredChipWidth = 0.0; // Sum of chip widths only (exclude TextField)
        int childIndex = 0;
        wrapBox.visitChildren((child) {
          if (child is RenderBox) {
            totalWidthNeeded += child.size.width;
            // Only count chips (RenderLayoutBuilder), not TextField (RenderConstrainedBox)
            if (child.runtimeType.toString().contains('LayoutBuilder')) {
              measuredChipWidth += child.size.width;
            }
            debugPrint('DEBUG OVERLAY POS:   Child[$childIndex] ${child.runtimeType}: width=${child.size.width.toStringAsFixed(1)}, total=${totalWidthNeeded.toStringAsFixed(1)}');
            childIndex++;
          }
        });
        debugPrint('DEBUG OVERLAY POS: Total width needed: ${totalWidthNeeded.toStringAsFixed(1)}, Wrap width: $wrapWidth, Will wrap: ${totalWidthNeeded > wrapWidth}');
        
        // Store measured chip width for use in _calculateTextFieldWidth
        if (measuredChipWidth > 0) {
          totalChipWidth = measuredChipWidth;
        }
      }
      
      // ALWAYS measure chip widths when selection count changes for accurate TextField width calculation
      // This ensures totalChipWidth is updated whenever chips are added/removed
      double measuredChipWidth = 0.0;
      int chipCount = 0;
      wrapBox.visitChildren((child) {
        if (child is RenderBox && child.runtimeType.toString().contains('LayoutBuilder')) {
          measuredChipWidth += child.size.width;
          chipCount++;
          debugPrint('DEBUG FIELD HEIGHT: Measuring chip $chipCount: width=${child.size.width}');
        }
      });
      if (measuredChipWidth > 0) {
        // Always update with actual measurement - this ensures we have correct width for TextField calculation
        totalChipWidth = measuredChipWidth;
        debugPrint('DEBUG FIELD HEIGHT: Total chip width measured: $measuredChipWidth (from $chipCount chips, selectedCount: $selectedCount)');
      }
      
      // Debug: ALWAYS check children widths when Wrap height > 40 (wrapped)
      if (newWrapHeight > 40.0) {
        debugPrint('DEBUG FIELD HEIGHT: ⚠️⚠️⚠️ Wrap wrapped to $newWrapHeight (expected ~36.0) ⚠️⚠️⚠️');
        debugPrint('DEBUG FIELD HEIGHT: Checking ALL children widths...');
        double totalChildrenWidth = 0.0;
        double chipWidthSum = 0.0;
        double textFieldWidth = 0.0;
        int childIndex = 0;
        wrapBox.visitChildren((child) {
          if (child is RenderBox) {
            final String typeName = child.runtimeType.toString();
            final double childWidth = child.size.width;
            final double childHeight = child.size.height;
            totalChildrenWidth += childWidth;
            
            if (typeName.contains('LayoutBuilder')) {
              chipWidthSum += childWidth;
              debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] CHIP ($typeName): width=$childWidth, height=$childHeight');
            } else if (typeName.contains('ConstrainedBox') || typeName.contains('TextField')) {
              textFieldWidth = childWidth;
              debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] TEXTFIELD ($typeName): width=$childWidth, height=$childHeight');
            } else {
              debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] OTHER ($typeName): width=$childWidth, height=$childHeight');
            }
            childIndex++;
          }
        });
        debugPrint('DEBUG FIELD HEIGHT: SUMMARY:');
        debugPrint('DEBUG FIELD HEIGHT:   - Total children width: $totalChildrenWidth');
        debugPrint('DEBUG FIELD HEIGHT:   - Chip width sum: $chipWidthSum');
        debugPrint('DEBUG FIELD HEIGHT:   - TextField width: $textFieldWidth');
        debugPrint('DEBUG FIELD HEIGHT:   - Wrap width: $wrapWidth');
        debugPrint('DEBUG FIELD HEIGHT:   - Will wrap: ${totalChildrenWidth > wrapWidth}');
        debugPrint('DEBUG FIELD HEIGHT:   - Current totalChipWidth: $totalChipWidth');
        debugPrint('DEBUG FIELD HEIGHT:   - Spacing needed: ${selectedCount > 0 ? (selectedCount - 1) * chipSpacing : 0.0}');
        debugPrint('DEBUG FIELD HEIGHT:   - Expected total: ${chipWidthSum + textFieldWidth + (selectedCount > 0 ? (selectedCount - 1) * chipSpacing : 0.0)}');
      }
      
      // Debug: ALWAYS check children widths when Wrap height suggests wrapping
      if (newWrapHeight > 40.0 || (previousWrapHeight != null && newWrapHeight > previousWrapHeight! + 5.0)) {
        debugPrint('DEBUG FIELD HEIGHT: ⚠️⚠️⚠️ Wrap height changed significantly! ⚠️⚠️⚠️');
        debugPrint('DEBUG FIELD HEIGHT:   - Previous height: $previousWrapHeight');
        debugPrint('DEBUG FIELD HEIGHT:   - New height: $newWrapHeight');
        debugPrint('DEBUG FIELD HEIGHT:   - Checking ALL children widths...');
        double totalChildrenWidth = 0.0;
        double chipWidthSum = 0.0;
        double textFieldWidth = 0.0;
        int childIndex = 0;
        wrapBox.visitChildren((child) {
          if (child is RenderBox) {
            final String typeName = child.runtimeType.toString();
            final double childWidth = child.size.width;
            final double childHeight = child.size.height;
            totalChildrenWidth += childWidth;
            
            if (typeName.contains('LayoutBuilder')) {
              chipWidthSum += childWidth;
              debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] CHIP ($typeName): width=$childWidth, height=$childHeight');
            } else if (typeName.contains('ConstrainedBox') || typeName.contains('TextField')) {
              textFieldWidth = childWidth;
              debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] TEXTFIELD ($typeName): width=$childWidth, height=$childHeight');
            } else {
              debugPrint('DEBUG FIELD HEIGHT:   Child[$childIndex] OTHER ($typeName): width=$childWidth, height=$childHeight');
            }
            childIndex++;
          }
        });
        debugPrint('DEBUG FIELD HEIGHT: SUMMARY:');
        debugPrint('DEBUG FIELD HEIGHT:   - Total children width: $totalChildrenWidth');
        debugPrint('DEBUG FIELD HEIGHT:   - Chip width sum: $chipWidthSum');
        debugPrint('DEBUG FIELD HEIGHT:   - TextField width: $textFieldWidth');
        debugPrint('DEBUG FIELD HEIGHT:   - Wrap width: $wrapWidth');
        debugPrint('DEBUG FIELD HEIGHT:   - Will wrap: ${totalChildrenWidth > wrapWidth}');
        debugPrint('DEBUG FIELD HEIGHT:   - Current totalChipWidth: $totalChipWidth');
        debugPrint('DEBUG FIELD HEIGHT:   - Spacing needed: ${selectedCount > 0 ? (selectedCount - 1) * chipSpacing : 0.0}');
        debugPrint('DEBUG FIELD HEIGHT:   - Expected total: ${chipWidthSum + textFieldWidth + (selectedCount > 0 ? (selectedCount - 1) * chipSpacing : 0.0)}');
      }
      
      bool needsUpdate = false;
      
      if (newWrapHeight != wrapHeight) {
        debugPrint('DEBUG OVERLAY POS: wrapHeight changed: $wrapHeight -> $newWrapHeight');
        wrapHeight = newWrapHeight;
        needsUpdate = true;
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
              remainingWidth = actualRemaining.clamp(minTextFieldWidth, wrapWidth);
              needsUpdate = true;
            }
          } else {
            // TextField wrapped to new line - calculate remaining width on first line
            final double lastChipRight = lastChipPos.dx - wrapPos.dx + lastChipBox.size.width;
            final double firstLineRemaining = wrapWidth - lastChipRight - chipSpacing;
            
            // Only update if we have enough space and it's different from current
            if (firstLineRemaining > minTextFieldWidth && 
                (remainingWidth == null || (remainingWidth! - firstLineRemaining).abs() > 1.0)) {
              remainingWidth = firstLineRemaining;
              needsUpdate = true;
            } else if (firstLineRemaining <= minTextFieldWidth) {
              // Not enough space on first line - use minimum width
              // TextField will wrap to next line
              if (remainingWidth == null || remainingWidth != minTextFieldWidth) {
                remainingWidth = minTextFieldWidth;
                needsUpdate = true;
              }
            }
          }
        }
      }
      
      // Don't request rebuild from measurements - measurements just update state
      // The rebuild will happen naturally on the next frame if state changed
      // Requesting rebuild here causes cascading rebuilds
    });
  }
}

// Removed _OverlayCacheKey - no longer using overlay caching
