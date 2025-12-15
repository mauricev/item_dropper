import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_dropper/src/common/item_dropper_common.dart';
import 'package:item_dropper/src/common/live_region_manager.dart';
import 'package:item_dropper/src/common/keyboard_navigation_manager.dart';
import 'package:item_dropper/src/multi/chip_measurement_helper.dart';
import 'package:item_dropper/src/multi/multi_select_constants.dart';
import 'package:item_dropper/src/multi/multi_select_focus_manager.dart';
import 'package:item_dropper/src/multi/multi_select_layout_calculator.dart';
import 'package:item_dropper/src/multi/multi_select_overlay_manager.dart';
import 'package:item_dropper/src/multi/multi_select_selection_manager.dart';
import 'package:item_dropper/src/multi/smartwrap.dart' show SmartWrapWithFlexibleLast;
import 'package:item_dropper/src/utils/item_dropper_add_item_utils.dart';
import 'package:item_dropper/src/utils/item_dropper_selection_handler.dart';
import 'package:item_dropper/src/utils/dropdown_position_calculator.dart';
import 'package:item_dropper/src/single/single_select_constants.dart';
import 'package:item_dropper/src/common/item_dropper_localizations.dart';

/// Multi-select dropdown widget
/// Allows selecting multiple items with chip-based display
class MultiItemDropper<T> extends StatefulWidget {
  /// The items to display in the dropdown (required).
  final List<ItemDropperItem<T>> items;

  /// The currently selected items (optional for controlled usage).
  final List<ItemDropperItem<T>>? selectedItems;

  /// Called when the selection changes (required).
  final void Function(List<ItemDropperItem<T>>) onChanged;

  /// Optional custom builder for popup items.
  final Widget Function(BuildContext, ItemDropperItem<T>, bool)? popupItemBuilder;

  /// The width of the dropdown field (required).
  final double width;

  /// Whether the dropdown is enabled (defaults to true).
  final bool enabled;

  /// Hint/placeholder text for input field (if null, no hint).
  final String? hintText;

  /// Maximum number of items selectable (null means unlimited).
  final int? maxSelected;

  /// Callback for adding new items based on search text (optional).
  final ItemDropperItem<T>? Function(String searchText)? onAddItem;

  /// Callback for deleting items, provides the deleted item (optional).
  final void Function(ItemDropperItem<T> item)? onDeleteItem;

  /// Optional GlobalKey for the input field container.
  final GlobalKey<State<StatefulWidget>>? inputKey;

  /// Maximum dropdown popup height.
  final double maxDropdownHeight;

  /// Whether to show a vertical scrollbar in popup.
  final bool showScrollbar;

  /// Popup vertical scrollbar thickness.
  final double scrollbarThickness;

  /// Height for popup dropdown items.
  final double? itemHeight;

  /// Text style for popup dropdown items.
  final TextStyle? popupTextStyle;

  /// Text style for group headers in popup.
  final TextStyle? popupGroupHeaderStyle;

  /// Text style for input/search field and chips.
  final TextStyle? fieldTextStyle;

  /// Custom BoxDecoration for selected chips.
  final BoxDecoration? selectedChipDecoration;

  /// Optional BoxDecoration for the main field/container.
  final BoxDecoration? fieldDecoration;

  /// Popup shadow elevation.
  final double? elevation;

  /// Whether to show the dropdown position arrow (defaults to true).
  final bool showDropdownPositionIcon;

  /// Whether to show the clear/X icon (defaults to true).
  final bool showDeleteAllIcon;

  /// Localization strings for user-facing text (optional).
  /// If not provided, uses default English strings.
  final ItemDropperLocalizations? localizations;

  const MultiItemDropper({
    super.key,
    required this.items,
    this.selectedItems,
    required this.onChanged,
    this.popupItemBuilder,
    required this.width,
    this.enabled = true,
    this.hintText,
    this.maxSelected,
    this.onAddItem,
    this.onDeleteItem,
    this.inputKey,
    this.maxDropdownHeight = MultiSelectConstants.kDefaultMaxDropdownHeight,
    this.showScrollbar = true,
    this.scrollbarThickness = ItemDropperConstants.kDefaultScrollbarThickness,
    this.itemHeight,
    this.popupTextStyle,
    this.popupGroupHeaderStyle,
    this.fieldTextStyle,
    this.selectedChipDecoration,
    this.fieldDecoration,
    this.elevation,
    this.showDropdownPositionIcon = true,
    this.showDeleteAllIcon = true,
    this.localizations,
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

  // Selection manager handles selected items state
  late final MultiSelectSelectionManager<T> _selectionManager;

  // Overlay manager handles overlay visibility
  late final MultiSelectOverlayManager _overlayManager;

  // Keyboard navigation manager
  late final KeyboardNavigationManager<T> _keyboardNavManager;
  
  // Memoized filtered items - invalidated when search text or selected items change
  List<ItemDropperItem<T>>? _cachedFilteredItems;
  String _lastFilteredSearchText = '';
  int _lastFilteredSelectedCount = -1;
  
  
  // Measurement helper
  final ChipMeasurementHelper _measurements = ChipMeasurementHelper();
  
  /// Get localizations with defaults
  ItemDropperLocalizations get _localizations =>
      widget.localizations ?? ItemDropperLocalizations.english;
  
  // State flags - consolidated to reduce complexity
  bool _rebuildScheduled = false;
  // Track when we're the source of selection changes to prevent didUpdateWidget from rebuilding
  bool _isInternalSelectionChange = false;
  // Track when we're programmatically clearing search text to prevent overlay from closing
  bool _isClearingSearchForSelection = false;

  // Unified focus manager handles both TextField and chip focus
  late final MultiSelectFocusManager<T> _focusManager;
  
  // Cached decoration state (simplified from DecorationCacheManager)
  BoxDecoration? _cachedDecoration;
  bool? _cachedFocusState;

  // Use shared filter utils
  final ItemDropperFilterUtils<T> _filterUtils = ItemDropperFilterUtils<T>();

  // Live region for screen reader announcements
  late final LiveRegionManager _liveRegionManager;
  
  // Map to store FocusNodes for each chip (keyed by chip index)
  final Map<int, FocusNode> _chipFocusNodes = {};

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _focusNode = FocusNode();

    // Initialize unified focus manager (handles both TextField and chip focus)
    _focusManager = MultiSelectFocusManager<T>(
      focusNode: _focusNode,
      onFocusVisualStateChanged: _updateFocusVisualState,
      onFocusChanged: _handleFocusChange,
      onRemoveChip: _removeChip,
    );

    // Initialize selection manager with callbacks
    _selectionManager = MultiSelectSelectionManager<T>(
      maxSelected: widget.maxSelected,
      onSelectionChanged: () {
        // Selection changed - will notify parent via _handleSelectionChange
      },
      onFilterCacheInvalidated: () {
        _filterUtils.clearCache();
        _invalidateFilteredCache();
      },
    );
    _selectionManager.syncItems(widget.selectedItems ?? []);

    // Initialize overlay manager
    _overlayManager = MultiSelectOverlayManager(
      controller: _overlayController,
      onClearHighlights: _clearHighlights,
    );

    // Initialize keyboard navigation manager
    _keyboardNavManager = KeyboardNavigationManager<T>(
      onRequestRebuild: () => _safeSetState(() {}),
      onEscape: () => _focusManager.loseFocus(),
      onOpenDropdown: () {
        // Show dropdown - if max is reached, overlay will show max reached message
        _focusManager.gainFocus();
        _overlayManager.showIfNeeded();
      },
    );

    // Initialize live region manager
    _liveRegionManager = LiveRegionManager(
      onUpdate: () => _safeSetState(() {}),
    );
    
    // Update focus manager with initial selected items
    _focusManager.updateSelectedItems(_selectionManager.selected);

    _filterUtils.initializeItems(widget.items);

    _focusNode.onKeyEvent = (node, event) {
      // Only process KeyDownEvent and KeyRepeatEvent (ignore KeyUpEvent)
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      
      // If a chip is focused, let focus manager handle arrow/delete keys
      if (!_focusManager.isTextFieldFocused) {
        final chipResult = _focusManager.handleKeyEvent(event);
        if (chipResult == KeyEventResult.handled) {
          return chipResult;
        }
      }
      
      // Handle left/right arrow keys: navigate between TextField and chips
      // This should work even when dropdown is open (when cursor is at boundary)
      if (_focusManager.isTextFieldFocused &&
          _selectionManager.selectedCount > 0) {
        final cursorPosition = _searchController.selection.baseOffset;
        
        // Left arrow at cursor position 0: move to last chip
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft && cursorPosition == 0) {
          _focusManager.focusChip(_selectionManager.selectedCount - 1);
          return KeyEventResult.handled;
        }
        
        // Right arrow at end of text: move to first chip
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            cursorPosition == _searchController.text.length) {
          _focusManager.focusChip(0);
          return KeyEventResult.handled;
        }
      }
      
      // Check if Space/Enter should open dropdown (only if text is empty or cursor at start)
      final shouldOpenOnSpaceEnter = !_overlayController.isShowing &&
          (event.logicalKey == LogicalKeyboardKey.space ||
           event.logicalKey == LogicalKeyboardKey.enter) &&
          (_searchController.text.isEmpty ||
           _searchController.selection.baseOffset == 0);
      
      // If Space/Enter and shouldn't open dropdown, let TextField handle it normally
      if ((event.logicalKey == LogicalKeyboardKey.space ||
           event.logicalKey == LogicalKeyboardKey.enter) &&
          !shouldOpenOnSpaceEnter) {
        return KeyEventResult.ignored;
      }
      
      return _keyboardNavManager.handleKeyEvent(
        event: event,
        filteredItems: _filtered,
        scrollController: _scrollController,
        mounted: mounted,
        isDropdownOpen: _overlayController.isShowing,
      );
    };
  }

  List<ItemDropperItem<T>> get _filtered {
    final String currentSearchText = _searchController.text;
    final int currentSelectedCount = _selectionManager.selectedCount;

    // Return cached result if search text and selected count haven't changed
    if (_cachedFilteredItems != null &&
        _lastFilteredSearchText == currentSearchText &&
        _lastFilteredSelectedCount == currentSelectedCount) {
      return _cachedFilteredItems!;
    }

    // Filter out already selected items - use existing Set for O(1) lookups
    // getFiltered will reinitialize if items reference changed
    final result = _filterUtils.getFiltered(
      widget.items,
      currentSearchText,
      isUserEditing: true, // always filter in multi-select
      excludeValues: _selectionManager.selectedValues,
    );

    // Add "add item" row if no matches, search text exists, and callback is provided
    final filteredWithAdd = ItemDropperAddItemUtils.addAddItemIfNeeded<T>(
      filteredItems: result,
      searchText: currentSearchText,
      originalItems: widget.items,
      hasOnAddItemCallback: () => widget.onAddItem != null,
      localizations: _localizations,
    );
    
    // Cache the result
    _cachedFilteredItems = filteredWithAdd;
    _lastFilteredSearchText = currentSearchText;
    _lastFilteredSelectedCount = currentSelectedCount;
    
    return filteredWithAdd;
  }
  
  /// Invalidate filtered items cache - call when search text or selected items change
  void _invalidateFilteredCache() {
    _cachedFilteredItems = null;
    _lastFilteredSearchText = '';
    _lastFilteredSelectedCount = -1;
    // Also ensure filter utils is initialized with current items
    _filterUtils.initializeItems(widget.items);
  }



  void _clearHighlights() {
    _keyboardNavManager.clearHighlights();
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
    final double textLineHeight = fontSize * MultiSelectConstants.kTextLineHeightMultiplier;

    if (_measurements.chipTextTop != null) {
      // Use measured chip text center position to align TextField text
      // chipTextTop is already the text center (rowTop + rowHeight/2)
      final double chipTextCenter = _measurements.chipTextTop!;
      // Adjust for TextField's text rendering - needs offset upward
      final double top = chipTextCenter - (textLineHeight / 2.0) -
          MultiSelectConstants.kTextFieldPaddingOffset;
      final double bottom = chipHeight - textLineHeight - top;
      return (top: top, bottom: bottom);
    } else {
      // Fallback: calculate same as chip structure
      // Chip text center = chipVerticalPadding + rowHeight/2
      final double rowContentHeight = textLineHeight >
          MultiSelectConstants.kIconHeight
          ? textLineHeight
          : MultiSelectConstants.kIconHeight;
      final double chipTextCenter = MultiSelectConstants.kChipVerticalPadding +
          (rowContentHeight / 2.0);

      // Same adjustment as measured case
      final double top = chipTextCenter - (textLineHeight / 2.0) -
          MultiSelectConstants.kTextFieldPaddingOffset;
      final double bottom = chipHeight - textLineHeight - top;
      return (top: top, bottom: bottom);
    }
  }

  void _handleFocusChange() {
    // When TextField gains focus, ensure chip focus index reflects this
    // (Don't call focusTextField() here as it would cause infinite recursion)
    if (_focusNode.hasFocus && !_focusManager.isTextFieldFocused) {
      // Just update the chip focus index without requesting focus
      _focusManager.clearChipFocus();
    }
    // Focus change is now handled by the FocusManager
    // This method is kept for additional overlay logic

    // Use manual focus state for overlay logic
    if (_focusManager.isFocused) {
      // Show overlay when focused - if max is reached, overlay will show max reached message
      // Use a post-frame callback to ensure input context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusManager.isFocused) {
          return;
        }

        // If max is reached, show overlay (will display max reached message)
        if (_selectionManager.isMaxReached()) {
          _overlayManager.showIfNeeded();
          return;
        }

        final filtered = _filtered;
        // showIfNeeded checks isShowing internally, only check if we have items
        if (filtered.isNotEmpty) {
          _overlayManager.showIfNeeded();
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
    // Invalidate decoration cache - will be recreated on next build with new focus state
    _cachedDecoration = null;
    _cachedFocusState = null;
    _safeSetState(() {
      // Trigger rebuild to apply new decoration
    });
  }

  /// Get decoration for the input field container (simplified from DecorationCacheManager)
  BoxDecoration _getDecoration({
    required bool isFocused,
    BoxDecoration? customDecoration,
  }) {
    // If custom decoration provided, use it as-is (no caching)
    if (customDecoration != null) {
      return customDecoration;
    }

    // Only recreate if cache is null or focus state changed
    if (_cachedDecoration == null || _cachedFocusState != isFocused) {
      _cachedFocusState = isFocused;
      _cachedDecoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFE5E5E5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: isFocused ? Colors.blue : Colors.grey.shade400,
          width: MultiSelectConstants.kContainerBorderWidth,
        ),
        borderRadius: BorderRadius.circular(MultiSelectConstants.kContainerBorderRadius),
      );
    }

    return _cachedDecoration!;
  }

  void _updateSelection(void Function() selectionUpdate) {
    // Preserve keyboard highlight state - only reset if keyboard navigation was active
    final bool wasKeyboardActive = _keyboardNavManager.keyboardHighlightIndex !=
        ItemDropperConstants.kNoHighlight;
    final int previousHoverIndex = _keyboardNavManager.hoverIndex;

    // Use unified selection change handler
    _handleSelectionChange(
      stateUpdate: () {
        // Update selection inside the rebuild callback
        selectionUpdate();
        
        // Update focus manager with new selection
        _focusManager.updateSelectedItems(_selectionManager.selected);
        
        // Clean up FocusNodes for chips that no longer exist
        final currentIndices = _selectionManager.selected.asMap().keys.toSet();
        final nodesToRemove = _chipFocusNodes.keys.where((i) => !currentIndices.contains(i)).toList();
        for (final index in nodesToRemove) {
          _chipFocusNodes[index]?.dispose();
          _chipFocusNodes.remove(index);
        }

        // Update highlights based on filtered items
        final List<ItemDropperItem<T>> remainingFilteredItems = _filtered;

        if (remainingFilteredItems.isNotEmpty) {
          // Only reset keyboard highlight if keyboard navigation was active
          if (wasKeyboardActive) {
            _keyboardNavManager.clearHighlights();
            // Set keyboard highlight to first item
            // Note: We can't directly set the index, so we'll clear it
            // The manager will handle resetting on next arrow key
          } else {
            // Preserve hover index if still valid
            if (previousHoverIndex >= 0 &&
                previousHoverIndex < remainingFilteredItems.length) {
              // Hover index is still valid, keep it
              _keyboardNavManager.hoverIndex = previousHoverIndex;
            } else {
              // Hover index is invalid, clear it
              _keyboardNavManager.clearHighlights();
            }
          }
        } else {
          _clearHighlights();
          _overlayManager.hideIfNeeded();
        }
      },
      postRebuildCallback: () {
        // Restore focus if needed after selection update
        _focusManager.restoreFocusIfNeeded();
      },
    );
  }

  void _toggleItem(ItemDropperItem<T> item) {
    // Group headers and disabled items cannot be selected
    if (item.isGroupHeader || !item.isEnabled) {
      return;
    }

    // Handle add item selection using shared handler
    final addItemResult = ItemDropperSelectionHandler.handleAddItemIfNeeded<T>(
      item: item,
      originalItems: widget.items,
      onAddItem: widget.onAddItem,
      localizations: _localizations,
      onItemCreated: (newItem) {
        // Add the new item to the list and select it
        // Note: The parent should update widget.items to include the new item
        // For now, we'll just select it and let the parent handle adding to the list
        _updateSelection(() {
          _selectionManager.addItem(newItem);
          _measurements.totalChipWidth = null;
          _searchController.clear();

          // If we just reached the max, close the overlay
          if (_selectionManager.isMaxReached()) {
            _overlayManager.hideIfNeeded();
          }
        });
      },
    );
    
    if (addItemResult.handled) {
      return;
    }

    // Manual focus management - maintain focus state when clicking overlay items
    // Explicitly ensure focus state is maintained for this interaction
    _focusManager.gainFocus();

    final bool isCurrentlySelected = _selectionManager.isSelected(item);

    // If maxSelected is set and already reached, only allow removal (toggle off)
    if (_selectionManager.isMaxReached() && !isCurrentlySelected) {
      // Block adding new items when max is reached
      // Close the overlay and keep it closed
      if (_overlayManager.isShowing) {
        _overlayManager.hideIfNeeded();
      }
      return;
    }
    // Allow removing items even when max is reached (toggle behavior)

    _updateSelection(() {
      if (!isCurrentlySelected) {
        _selectionManager.addItem(item);

        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;

        // Announce selection to screen readers
        final loc = _localizations;
        _liveRegionManager.announce(
          '${item.label}${loc.itemSelectedSuffix}',
        );

        // If we just reached the max, close the overlay
        if (_selectionManager.isMaxReached()) {
          _overlayManager.hideIfNeeded();
          // Clear search text after closing overlay
          _searchController.clear();
          // Announce max reached
          if (widget.maxSelected != null) {
            _liveRegionManager.announce(
              '${loc.maxSelectionReachedPrefix}${widget.maxSelected}${loc.maxSelectionReachedSuffix}',
            );
          }
        } else {
          // Keep focus and overlay open for continued selection
          // Ensure focus is maintained BEFORE clearing search text
          _focusManager.gainFocus();
          
          // Clear search text after selection for continued searching
          // Set flag to prevent overlay from closing
          _isClearingSearchForSelection = true;
          _searchController.clear();
          _isClearingSearchForSelection = false;
          
          // Ensure overlay stays open after text clear
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            
            // Ensure focus is maintained
            _focusNode.requestFocus();
            
            // Ensure overlay stays open (showIfNeeded checks isShowing internally)
            if (_focusManager.isFocused) {
              _overlayManager.showIfNeeded();
            }
          });
        }
      } else {
        // Item is already selected, remove it (toggle off)
        // Capture state before removal to check if we should reopen overlay
        final bool wasAtMax = _selectionManager.isMaxReached();
        _selectionManager.removeItem(item.value);

        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;

        // FIX: Show overlay again if we're below maxSelected after removal
        // This handles the case where user removes an item after reaching max
        if (wasAtMax && _selectionManager.isBelowMax() &&
            _focusManager.isFocused) {
          _overlayManager.showIfFocusedAndBelowMax<T>(
            isFocused: _focusManager.isFocused,
            isBelowMax: _selectionManager.isBelowMax(),
            filteredItems: _filtered,
          );
        }
      }
      // After selection change, clear highlights
      _clearHighlights();
    });
  }

  void _removeChip(ItemDropperItem<T> item) {
    // Focus the field and set manual focus state when removing a chip (even if unfocused)
    // This allows users to remove chips and immediately see the dropdown
    _focusManager.gainFocus();

    // Announce removal to screen readers
    _liveRegionManager.announce(
      '${item.label}${_localizations.itemRemovedSuffix}',
    );

    // Use unified selection change handler
    _handleSelectionChange(
      stateUpdate: () {
        // Update selection inside the rebuild callback
        _selectionManager.removeItem(item.value);

        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;

        _clearHighlights();
      },
      postRebuildCallback: () {
        // Restore focus if needed after chip removal
        _focusManager.restoreFocusIfNeeded();

        // Show overlay if we're below maxSelected and focused
        _overlayManager.showIfFocusedAndBelowMax<T>(
          isFocused: _focusManager.isFocused,
          isBelowMax: _selectionManager.isBelowMax(),
          filteredItems: _filtered,
        );
      },
    );
  }

  /// Handle delete requests coming from overlay items (right-click / long-press).
  /// Uses a simple built-in confirmation dialog before invoking onDeleteItem.
  void _handleRequestDeleteFromOverlay(BuildContext context,
      ItemDropperItem<T> item) {
    // Only allow delete for items explicitly marked as deletable.
    if (!item.isDeletable) {
      return;
    }

    // Run async flow without blocking the gesture handler.
    _confirmAndDeleteItem(context, item);
  }

  Future<void> _confirmAndDeleteItem(BuildContext context,
      ItemDropperItem<T> item) async {
    // Show a simple confirmation dialog above the existing overlay/dialogs.
    final loc = _localizations;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(loc.deleteDialogTitle.replaceAll('{label}', item.label)),
          content: Text(loc.deleteDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(loc.deleteDialogCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(loc.deleteDialogDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    // If the item is currently selected, remove it from the selection.
    if (_selectionManager.isSelected(item)) {
      _safeSetState(() {
        _selectionManager.removeItem(item.value);
      });
    }

    // Notify parent so it can remove the item from the source list.
    if (widget.onDeleteItem != null) {
      widget.onDeleteItem!(item);
    }

    // Invalidate filtered cache and request a rebuild so overlay updates.
    _invalidateFilteredCache();
    _requestRebuildIfNotScheduled();
  }

  void _handleEnter() {
    final List<ItemDropperItem<T>> filteredItems = _filtered;

    if (_keyboardNavManager.keyboardHighlightIndex >= 0 &&
        _keyboardNavManager.keyboardHighlightIndex < filteredItems.length) {
      // Keyboard navigation is active, select highlighted item
      final item = filteredItems[_keyboardNavManager.keyboardHighlightIndex];
      // Skip group headers
      if (!item.isGroupHeader) {
        // Ensure focus is maintained before toggling
        _focusManager.gainFocus();
        _toggleItem(item);
      }
    } else {
      // Find first selectable item for auto-select
      final selectableItems = filteredItems
          .where((item) => !item.isGroupHeader)
          .toList();
      if (selectableItems.length == 1) {
        // No keyboard navigation, but exactly 1 selectable item - auto-select it
        // Ensure focus is maintained before toggling
        _focusManager.gainFocus();
        _toggleItem(selectableItems[0]);
      } else {}
    }
  }

  /// Handle clear button press with two-stage behavior:
  /// 1. If search text exists, clear search text
  /// 2. If search text is empty, clear all selections
  void _handleClearPressed() {
    if (_searchController.text.isNotEmpty) {
      // Stage 1: Clear search text
      _searchController.clear();
      _invalidateFilteredCache();
      _safeSetState(() {
        _clearHighlights();
      });
    } else {
      // Stage 2: Clear all selections
      if (_selectionManager.selectedCount > 0) {
        _updateSelection(() {
          _selectionManager.clear();
          _measurements.totalChipWidth = null;
        });
      }
    }
  }

  /// Handle arrow button press - toggle dropdown
  void _handleArrowPressed() {
    if (_overlayController.isShowing) {
      _focusManager.loseFocus();
      _overlayManager.hideIfNeeded();
    } else {
      // Show dropdown - if max is reached, overlay will show max reached message
      _focusManager.gainFocus();
      _overlayManager.showIfNeeded();
    }
  }

  void _handleTextChanged(String value) {
    // Invalidate filtered cache since search text changed
    _invalidateFilteredCache();

    // Filter utils already handles text-based cache invalidation automatically
    // Only need to clear highlights and trigger rebuild
    _safeSetState(() {
      _clearHighlights();
    });

    // If we're clearing search text as part of selection, keep overlay open
    if (_isClearingSearchForSelection) {
      if (_focusManager.isFocused) {
        _overlayManager.showIfNeeded();
      }
      return;
    }

    // Show overlay if focused - if max is reached, overlay will show max reached message
    // This allows continued selection after clearing search text
    if (_focusManager.isFocused) {
      _overlayManager.showIfNeeded();
    } else if (_filtered.isEmpty && !_selectionManager.isMaxReached()) {
      // Hide overlay if no filtered items and not focused and not at max
      _overlayManager.hideIfNeeded();
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

  /// Unified method to handle selection changes: rebuild + notify parent + cleanup
  /// Consolidates the common pattern of rebuilding, notifying parent, and clearing flags
  void _handleSelectionChange({
    required void Function() stateUpdate,
    void Function()? postRebuildCallback,
  }) {
    // Mark that we're the source of this selection change
    _isInternalSelectionChange = true;

    // Update selection and all related state inside rebuild
    _requestRebuild(stateUpdate);

    // Use a post-frame callback to notify parent after current frame completes
    // This ensures our rebuild completes before parent is notified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Notify parent of change (this triggers parent rebuild synchronously)
      // Our didUpdateWidget will run as part of the parent rebuild, and will see
      // _isInternalSelectionChange = true, preventing unnecessary sync
      widget.onChanged(_selectionManager.selected);

      // Clear the flag AFTER notifying parent, but use a microtask to ensure
      // didUpdateWidget has completed its synchronous execution first
      // This prevents race conditions where didUpdateWidget might check the flag
      // after it's been cleared but during the same synchronous execution
      Future.microtask(() {
        if (mounted) {
          _isInternalSelectionChange = false;

          // Execute optional post-rebuild callback (e.g., focus management, overlay updates)
          if (postRebuildCallback != null) {
            postRebuildCallback();
          }
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant MultiItemDropper<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update focus manager with new selection
    _focusManager.updateSelectedItems(_selectionManager.selected);

    // If widget became disabled, unfocus and hide overlay
    if (oldWidget.enabled && !widget.enabled) {
      _focusManager.loseFocus();
      _overlayManager.hideIfNeeded();
    }

    // Sync selected items if parent changed them (and we didn't cause the change)
    if (!_isInternalSelectionChange &&
        !_areItemsEqual(widget.selectedItems, _selectionManager
            .selected)) {
      _selectionManager.syncItems(widget.selectedItems ?? []);
      // Don't trigger rebuild here if we're already rebuilding
      // Parent change will be reflected in the current rebuild cycle
      _requestRebuildIfNotScheduled();
    }

    // Invalidate filter cache if items list changed
    // Fast path: check reference equality first (O(1))
    if (!identical(widget.items, oldWidget.items)) {
      // Only do expensive comparison if lengths differ or we need to check content
      bool itemsChanged = widget.items.length != oldWidget.items.length;
      if (!itemsChanged) {
        // Only do expensive comparison if reference changed but length is same
        itemsChanged = !_areItemsEqual(widget.items, oldWidget.items);
      }

      if (itemsChanged) {
        _filterUtils.initializeItems(widget.items);
        _invalidateFilteredCache();
        // Cache removed - overlay rebuilds automatically
        // Use central rebuild mechanism instead of direct setState
        // But only if not already rebuilding
        _requestRebuildIfNotScheduled();
      }
    }
  }

  // Helper to check if two item lists are equal (by value)
  // Optimized for performance: early returns and efficient Set-based comparison
  // Time complexity: O(n) where n is the length of the lists
  bool _areItemsEqual(List<ItemDropperItem<T>>? a, List<ItemDropperItem<T>> b) {
    // Handle null
    if (a == null) return b.isEmpty;
    
    // Fast path: reference equality
    if (identical(a, b)) return true;

    // Fast path: length check (O(1))
    if (a.length != b.length) return false;

    // Fast path: empty lists
    if (a.isEmpty) return true;

    // For small lists, use simple iteration (more cache-friendly)
    if (a.length <= MultiSelectConstants.kListComparisonThreshold) {
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
  @override
  void dispose() {
    // Dispose chip focus nodes
    for (final focusNode in _chipFocusNodes.values) {
      focusNode.dispose();
    }
    _chipFocusNodes.clear();
    
    _liveRegionManager.dispose();
    _focusManager.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ItemDropperWithOverlay(
          layerLink: _layerLink,
          overlayController: _overlayController,
          fieldKey: widget.inputKey ?? _fieldKey,
          onDismiss: () {
            // Manual focus management - user clicked outside, unfocus
            _focusManager.loseFocus();
            _overlayManager.hideIfNeeded();
          },
          overlay: _buildDropdownOverlay(),
          inputField: _buildInputField(),
        ),
        // Live region for screen reader announcements
        _liveRegionManager.build(),
      ],
    );
  }

  Widget _buildInputField() {
    // Calculate first row height for icon alignment
    final double chipHeight = _measurements.chipHeight ??
        MultiSelectLayoutCalculator.calculateTextFieldHeight(
          fontSize: widget.fieldTextStyle?.fontSize,
          chipVerticalPadding: MultiSelectConstants.kChipVerticalPadding,
        );
    final double firstRowHeight = chipHeight;
    final double fontSize = widget.fieldTextStyle?.fontSize ??
        ItemDropperConstants.kDropdownItemFontSize;
    final double iconContainerHeight = fontSize *
        ItemDropperConstants.kSuffixIconHeightMultiplier;
    
    return GestureDetector(
      onTap: () {
        // When container is tapped (but not on chips or icons), focus the TextField
        if (widget.enabled) {
          _focusManager.focusTextField();
          _focusManager.gainFocus();
          // Invalidate filter cache to ensure fresh calculation
          _invalidateFilteredCache();
          // Show overlay immediately - _handleFocusChange will also handle it, but this ensures
          // it shows right away for tests and immediate user feedback
          if (_selectionManager.isMaxReached()) {
            _overlayManager.showIfNeeded();
          } else {
            // Check if we have items to show (either from _filtered or widget.items)
            final filtered = _filtered;
            if (filtered.isNotEmpty || widget.items.isNotEmpty) {
              _overlayManager.showIfNeeded();
            }
          }
        }
      },
      child: Container(
        key: widget.inputKey ?? _fieldKey,
        width: widget.width, // Constrain to 500px
        // Let content determine height naturally to prevent overflow
        decoration: _getDecoration(
          isFocused: _focusManager.isFocused,
          customDecoration: widget.fieldDecoration,
        ),
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            // Fill available space instead of min
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Integrated chips and text field area
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MultiSelectConstants.kContainerPaddingLeft,
                  MultiSelectConstants.kContainerPaddingTop,
                  // Add extra right padding to reserve space for suffix icons (if any are shown)
                  MultiSelectConstants.kContainerPaddingRight +
                      ((widget.showDropdownPositionIcon || widget.showDeleteAllIcon)
                          ? SingleSelectConstants.kSuffixIconWidth
                          : 0.0),
                  MultiSelectConstants.kContainerPaddingBottom,
                ),
                child: SmartWrapWithFlexibleLast(
                  spacing: MultiSelectConstants.kChipSpacing,
                  runSpacing: MultiSelectConstants.kChipSpacing,
                  children: [
                    // Selected chips
                    ..._selectionManager.selected.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Container(
                        key: ValueKey('chip_${item.value}'),
                        // Unique key for each chip
                        child: _buildChip(item, null, null, index),
                      );
                    }),
                    _buildTextFieldChip(double.infinity),
                  ],
                ),
              ),
            ],
          ),
          // Container-level suffix icons aligned with first row (only if at least one icon is enabled)
          if (widget.showDropdownPositionIcon || widget.showDeleteAllIcon)
            Positioned(
              top: MultiSelectConstants.kContainerPaddingTop +
                  (firstRowHeight - iconContainerHeight) / 2,
              right: MultiSelectConstants.kContainerPaddingRight,
              child: ItemDropperSuffixIcons(
                isDropdownShowing: _overlayController.isShowing,
                enabled: widget.enabled,
                onClearPressed: _handleClearPressed,
                onArrowPressed: _handleArrowPressed,
                iconSize: SingleSelectConstants.kIconSize,
                suffixIconWidth: SingleSelectConstants.kSuffixIconWidth,
                iconButtonSize: SingleSelectConstants.kIconButtonSize,
                clearButtonRightPosition: SingleSelectConstants.kClearButtonRightPosition,
                arrowButtonRightPosition: SingleSelectConstants.kArrowButtonRightPosition,
                textSize: fontSize,
                showDropdownPositionIcon: widget.showDropdownPositionIcon,
                showDeleteAllIcon: widget.showDeleteAllIcon,
              ),
            ),
        ],
      ),
      ),
    );
  }


  Widget _buildChip(ItemDropperItem<T> item,
      [GlobalKey? chipKey, Key? valueKey, int? chipIndex]) {
    final index = chipIndex ?? _selectionManager.selected.indexOf(item);
    final isFocused = _focusManager.isChipFocused(index);
    
    // Only measure the first chip (index 0) to avoid GlobalKey conflicts
    final bool isFirstChip = _selectionManager.selected.isNotEmpty &&
        _selectionManager.selected.first.value == item.value;
    final GlobalKey? rowKey = isFirstChip ? _measurements.chipRowKey : null;

    return LayoutBuilder(
      key: valueKey, // Use stable ValueKey for widget preservation
      builder: (context, constraints) {
        // Schedule chip measurement after build completes - don't measure during build
        // Measure chip dimensions after first render (only for first chip, only once)
        // Chip measurements don't change, so we only need to measure once
        if (isFirstChip && rowKey != null && _measurements.chipHeight == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            // Re-check conditions in case they changed
            if (_measurements.chipHeight == null &&
                rowKey.currentContext != null) {
              _measurements.measureChip(
                context: context,
                rowKey: rowKey,
                textSize: widget.fieldTextStyle?.fontSize ??
                    ItemDropperConstants.kDropdownItemFontSize,
                chipVerticalPadding: MultiSelectConstants.kChipVerticalPadding,
                requestRebuild: _requestRebuild,
              );
            }
          });
        }

        // Determine chip decoration.
        // - If a custom BoxDecoration is provided, use it as-is.
        // - Otherwise, fall back to the default blue vertical gradient.
        final BoxDecoration effectiveDecoration = widget
            .selectedChipDecoration ??
            BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade100,
                  Colors.blue.shade200,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius:
              BorderRadius.circular(MultiSelectConstants.kChipBorderRadius),
            );

        // Add focus border if focused
        final BoxDecoration focusedDecoration = isFocused
            ? effectiveDecoration.copyWith(
                border: Border.all(
                  color: Colors.blue.shade600,
                  width: 2.0,
                ),
              )
            : effectiveDecoration;
        
        // Get or create FocusNode for this chip
        final chipFocusNode = _chipFocusNodes.putIfAbsent(
          index,
          () => FocusNode(skipTraversal: false, canRequestFocus: widget.enabled),
        );
        
        // Request focus when this chip becomes focused
        if (isFocused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_focusManager.isChipFocused(index)) {
              chipFocusNode.requestFocus();
            }
          });
        }
        
        return Semantics(
          label: '${item.label}${_localizations.selectedSuffix}',
          button: true,
          excludeSemantics: true,
          child: Focus(
            focusNode: chipFocusNode,
            onKeyEvent: (node, event) {
              // Delegate to chip focus manager
              return _focusManager.handleKeyEvent(event);
            },
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                _focusManager.focusChip(index);
              } else if (_focusManager.isChipFocused(index)) {
                // Lost focus but we still think it's focused - move to TextField
                _focusManager.focusTextField();
              }
            },
            child: GestureDetector(
              onTap: () {
                _focusManager.focusChip(index);
                chipFocusNode.requestFocus();
              },
              child: Container(
                key: chipKey,
                // Use provided GlobalKey (for last chip) or null
                decoration: focusedDecoration,
                padding: const EdgeInsets.symmetric(
                  horizontal: MultiSelectConstants.kChipHorizontalPadding,
                  vertical: MultiSelectConstants.kChipVerticalPadding,
                ),
                margin: const EdgeInsets.only(
                  right: MultiSelectConstants.kChipMarginRight,),
                child: Row(
                  key: rowKey, // Only first chip gets the key
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: (widget.fieldTextStyle ?? const TextStyle(
                          fontSize: ItemDropperConstants.kDropdownItemFontSize))
                          .copyWith(
                        color: widget.enabled
                            ? (widget.fieldTextStyle?.color ?? Colors.black)
                            : Colors.grey.shade500,
                      ),
                    ),
                    if (widget.enabled)
                      Container(
                        width: MultiSelectConstants.kChipDeleteButtonSize,
                        height: MultiSelectConstants.kChipDeleteButtonSize,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () {
                            _removeChip(item);
                          },
                          child: Icon(Icons.close,
                              size: MultiSelectConstants.kChipDeleteIconSize,
                              color: Colors.grey.shade700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextFieldChip(double width) {
    // Use measured chip dimensions if available, otherwise fall back to calculation
    final double chipHeight = _measurements.chipHeight ??
        MultiSelectLayoutCalculator.calculateTextFieldHeight(
          fontSize: widget.fieldTextStyle?.fontSize,
          chipVerticalPadding: MultiSelectConstants.kChipVerticalPadding,
        );
    final double fontSize = widget.fieldTextStyle?.fontSize ??
        ItemDropperConstants.kDropdownItemFontSize;
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
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Semantics(
          label: _localizations.multiSelectFieldLabel,
          textField: true,
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
          style: widget.fieldTextStyle ??
              const TextStyle(fontSize: ItemDropperConstants
                  .kDropdownItemFontSize),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.only(
              right: ((widget.showDropdownPositionIcon || widget.showDeleteAllIcon)
                      ? SingleSelectConstants.kSuffixIconWidth
                      : 0.0) +
                  MultiSelectConstants.kContainerPaddingRight,
              top: textFieldPaddingTop,
              bottom: textFieldPaddingBottom,
            ),
            border: InputBorder.none,
            hintText: widget.hintText,
          ),
          onChanged: (value) => _handleTextChanged(value),
          onSubmitted: (value) => _handleEnter(),
          enabled: widget.enabled,
          // Ensure TextField can receive focus
          autofocus: false,
          onTap: () {
            // When TextField is tapped, focus it and clear chip focus
            _focusManager.focusTextField();
            _focusManager.gainFocus();
            // Show overlay immediately - similar to SingleItemDropper
            if (_selectionManager.isMaxReached()) {
              _overlayManager.showIfNeeded();
            } else {
              final filtered = _filtered;
              if (filtered.isNotEmpty || widget.items.isNotEmpty) {
                _overlayManager.showIfNeeded();
              }
            }
          },
        ), // Close TextField
        ), // Close Semantics
      ), // Close IgnorePointer
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

    // Calculate effective item height:
    // - If widget.itemHeight is provided, use it
    // - Otherwise, calculate from popupTextStyle
    double calculateItemHeightFromStyle() {
      final TextStyle resolvedStyle = widget.popupTextStyle ??
          const TextStyle(fontSize: ItemDropperConstants.kDropdownItemFontSize);
      final double fontSize = resolvedStyle.fontSize ??
          ItemDropperConstants.kDropdownItemFontSize;
      final double lineHeight = fontSize * (resolvedStyle.height ??
          MultiSelectConstants.kTextLineHeightMultiplier);
      return lineHeight +
          (ItemDropperConstants.kDropdownItemVerticalPadding * 2);
    }

    final double effectiveItemHeight = widget.itemHeight ??
        calculateItemHeightFromStyle();

    // Show max reached overlay if max selection is reached
    if (_selectionManager.isMaxReached()) {
      return _buildMaxReachedOverlay(inputContext);
    }
    
    // Show empty state if user is searching but no results found
    if (filteredItems.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        // User is searching but no results - show empty state
        return _buildEmptyStateOverlay(inputContext);
      }
      // No search text and no filtered items - check if we have items to show
      // If widget.items has items (excluding selected), show them
      final availableItems = widget.items
          .where((item) => item.isGroupHeader || !_selectionManager.selectedValues.contains(item.value))
          .toList();
      if (availableItems.isEmpty) {
        // No items available - hide overlay
        return const SizedBox.shrink();
      }
      // We have items but filteredItems is empty - use availableItems instead
      // This can happen during initialization before _filtered is properly calculated
      // Continue with availableItems as the items to display
      return ItemDropperRenderUtils.buildDropdownOverlay<T>(
        context: inputContext,
        items: availableItems,
        maxDropdownHeight: widget.maxDropdownHeight,
        width: widget.width,
        controller: _overlayController,
        scrollController: _scrollController,
        layerLink: _layerLink,
        isSelected: (ItemDropperItem<T> item) => _selectionManager.isSelected(item),
        builder: (BuildContext builderContext, ItemDropperItem<T> item, bool isSelected) {
          final int itemIndex = availableItems.indexWhere((x) => x.value == item.value);
          final bool hasPrevious = itemIndex > 0;
          final bool previousIsGroupHeader = hasPrevious && availableItems[itemIndex - 1].isGroupHeader;
          
          final Widget Function(BuildContext, ItemDropperItem<T>, bool) itemBuilder;
          if (widget.popupItemBuilder != null) {
            itemBuilder = widget.popupItemBuilder!;
          } else {
            itemBuilder = (context, item, isSelected) {
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
          
          return ItemDropperRenderUtils.buildDropdownItemWithHover<T>(
            context: builderContext,
            item: item,
            isSelected: isSelected,
            filteredItems: availableItems,
            hoverIndex: _keyboardNavManager.hoverIndex,
            keyboardHighlightIndex: _keyboardNavManager.keyboardHighlightIndex,
            safeSetState: _safeSetState,
            setHoverIndex: (index) => _keyboardNavManager.hoverIndex = index,
            onTap: () {
              _toggleItem(item);
            },
            customBuilder: itemBuilder,
            itemHeight: effectiveItemHeight,
            onRequestDelete: _handleRequestDeleteFromOverlay,
          );
        },
        itemHeight: effectiveItemHeight,
        preferredFieldHeight: _measurements.wrapHeight,
      );
    }

    // Use custom builder if provided, otherwise use default with style parameters
    final Widget Function(BuildContext, ItemDropperItem<T>, bool) itemBuilder;
    if (widget.popupItemBuilder != null) {
      itemBuilder = widget.popupItemBuilder!;
    } else {
      itemBuilder = (context, item, isSelected) {
        final int itemIndex = filteredItems.indexWhere((x) =>
        x.value == item.value);
        final bool hasPrevious = itemIndex > 0;
        final bool previousIsGroupHeader = hasPrevious &&
            filteredItems[itemIndex - 1].isGroupHeader;

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

    // Use measured wrapHeight directly for overlay positioning
    // This prevents overlay flash when field height changes during chip removal
    _measurements.measureWrapAndTextField(
      wrapContext: _measurements.wrapKey.currentContext,
      textFieldContext: null,
      // Not needed for simple height measurement
      lastChipContext: null,
      // Not needed for simple height measurement
      selectedCount: _selectionManager.selectedCount,
      chipSpacing: MultiSelectConstants.kChipSpacing,
      minTextFieldWidth: MultiSelectConstants.kMinTextFieldWidth,
      calculatedTextFieldWidth: null,
      // Not needed for simple height measurement
      requestRebuild: _requestRebuild,
    );

    final double? measuredWrapHeight = _measurements.wrapHeight;
    
    return ItemDropperRenderUtils.buildDropdownOverlay(
      context: inputContext,
      items: filteredItems,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: _overlayController,
      scrollController: _scrollController,
      layerLink: _layerLink,
      isSelected: (ItemDropperItem<T> item) =>
          _selectionManager.isSelected(item),
      builder: (BuildContext builderContext, ItemDropperItem<T> item,
          bool isSelected) {
        return ItemDropperRenderUtils.buildDropdownItemWithHover<T>(
          context: builderContext,
          item: item,
          isSelected: isSelected,
          filteredItems: filteredItems,
          hoverIndex: _keyboardNavManager.hoverIndex,
          keyboardHighlightIndex: _keyboardNavManager.keyboardHighlightIndex,
          safeSetState: _safeSetState,
          setHoverIndex: (index) => _keyboardNavManager.hoverIndex = index,
          onTap: () {
            _toggleItem(item);
          },
          customBuilder: itemBuilder,
          itemHeight: effectiveItemHeight,
          onRequestDelete: _handleRequestDeleteFromOverlay,
        );
      },
      itemHeight: effectiveItemHeight,
      preferredFieldHeight: measuredWrapHeight, // Pass measured height directly
    );
  }

  /// Builds a max reached overlay when maximum selection is reached
  Widget _buildMaxReachedOverlay(BuildContext inputContext) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final double inputFieldHeight = inputBox.size.height;
    // Use actual measured field width to ensure overlay matches field width exactly
    final double actualFieldWidth = inputBox.size.width;
    final double maxDropdownHeight = widget.maxDropdownHeight;
    
    final position = DropdownPositionCalculator.calculate(
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
        width: actualFieldWidth,
        child: Material(
          elevation: ItemDropperConstants.kDropdownElevation,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MultiSelectConstants.kEmptyStatePaddingHorizontal,
              vertical: MultiSelectConstants.kEmptyStatePaddingVertical,
            ),
            child: Text(
              _localizations.maxItemsReachedOverlay,
              style: (widget.popupTextStyle ?? widget.fieldTextStyle ?? const TextStyle(fontSize: ItemDropperConstants
                  .kDropdownItemFontSize)).copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an empty state overlay when search returns no results
  Widget _buildEmptyStateOverlay(BuildContext inputContext) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final double inputFieldHeight = inputBox.size.height;
    // Use actual measured field width to ensure overlay matches field width exactly
    final double actualFieldWidth = inputBox.size.width;
    final double maxDropdownHeight = widget.maxDropdownHeight;
    
    final position = DropdownPositionCalculator.calculate(
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
        width: actualFieldWidth,
        child: Material(
          elevation: ItemDropperConstants.kDropdownElevation,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MultiSelectConstants.kEmptyStatePaddingHorizontal,
              vertical: MultiSelectConstants.kEmptyStatePaddingVertical,
            ),
            child: Text(
              _localizations.noResultsFound,
              style: (widget.popupTextStyle ?? widget.fieldTextStyle ?? const TextStyle(fontSize: ItemDropperConstants
                  .kDropdownItemFontSize)).copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

