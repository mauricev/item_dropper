import 'dart:async';
import 'package:flutter/material.dart';
import 'package:item_dropper/src/common/item_dropper_common.dart';
import 'package:item_dropper/src/common/item_dropper_semantics.dart';
import 'package:item_dropper/src/common/live_region_manager.dart';
import 'package:item_dropper/src/common/keyboard_navigation_manager.dart';
import 'package:item_dropper/src/common/decoration_cache_manager.dart';
import 'package:item_dropper/src/multi/chip_measurement_helper.dart';
import 'package:item_dropper/src/multi/multi_select_constants.dart';
import 'package:item_dropper/src/multi/multi_select_focus_manager.dart';
import 'package:item_dropper/src/multi/multi_select_layout_calculator.dart';
import 'package:item_dropper/src/multi/multi_select_overlay_manager.dart';
import 'package:item_dropper/src/multi/multi_select_selection_manager.dart';
import 'package:item_dropper/src/multi/smartwrap.dart' show SmartWrapWithFlexibleLast;
import 'package:item_dropper/src/utils/item_dropper_add_item_utils.dart';
import 'package:item_dropper/src/utils/dropdown_position_calculator.dart';

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

  /// Callback invoked when user deletes an item from the dropdown.
  /// If null, delete buttons will not appear in the dropdown.
  final void Function(ItemDropperItem<T> item)? onDeleteItem;
  /// Optional custom decoration for selected chips.
  ///
  /// - If provided, this BoxDecoration is used as-is for each selected chip.
  /// - If null, a default blue vertical gradient and radius are applied.
  final BoxDecoration? selectedChipDecoration;

  /// Optional custom decoration for the dropdown field container.
  ///
  /// - If provided, this BoxDecoration is used as-is for the field container.
  /// - If null, a default white-to-grey gradient with focus-responsive border is applied.
  /// 
  /// Note: When providing a custom decoration, you are responsible for handling
  /// focus state styling if desired. The default decoration changes border color
  /// based on focus state (blue when focused, grey when not).
  final BoxDecoration? fieldDecoration;

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
    this.maxDropdownHeight = MultiSelectConstants.kDefaultMaxDropdownHeight,
    this.maxSelected,
    this.showScrollbar = true,
    this.scrollbarThickness = ItemDropperConstants.kDefaultScrollbarThickness,
    this.itemHeight, // Optional item height
    this.popupItemBuilder,
    this.elevation,
    this.onAddItem,
    this.onDeleteItem,
    this.selectedChipDecoration,
    this.fieldDecoration,
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
  
  // Decoration cache manager
  final DecorationCacheManager _decorationManager = DecorationCacheManager();

  bool _rebuildScheduled = false;
  // Track when we're the source of selection changes to prevent didUpdateWidget from rebuilding
  bool _isInternalSelectionChange = false;

  // Focus manager for manual focus state tracking
  late final MultiSelectFocusManager _focusManager;

  // Use shared filter utils
  final ItemDropperFilterUtils<T> _filterUtils = ItemDropperFilterUtils<T>();

  // Live region for screen reader announcements
  late final LiveRegionManager _liveRegionManager;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _focusNode = FocusNode();

    // Initialize focus manager with callback for visual state updates
    _focusManager = MultiSelectFocusManager(
      focusNode: _focusNode,
      onFocusVisualStateChanged: _updateFocusVisualState,
      onFocusChanged: _handleFocusChange,
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
    _selectionManager.syncItems(widget.selectedItems);

    // Initialize overlay manager
    _overlayManager = MultiSelectOverlayManager(
      controller: _overlayController,
      onClearHighlights: _clearHighlights,
    );

    // Initialize keyboard navigation manager
    _keyboardNavManager = KeyboardNavigationManager<T>(
      onRequestRebuild: () => _safeSetState(() {}),
      onEscape: () => _focusManager.loseFocus(),
    );

    // Initialize live region manager
    _liveRegionManager = LiveRegionManager(
      onUpdate: () => _safeSetState(() {}),
    );

    _filterUtils.initializeItems(widget.items);

    _focusNode.onKeyEvent = (node, event) =>
        _keyboardNavManager.handleKeyEvent(
          event: event,
          filteredItems: _filtered,
          scrollController: _scrollController,
          mounted: mounted,
        );
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
    // Focus change is now handled by the FocusManager
    // This method is kept for additional overlay logic

    // Use manual focus state for overlay logic
    if (_focusManager.isFocused) {
      // Don't show overlay if maxSelected is reached
      if (_selectionManager.isMaxReached()) {
        return;
      }

      // Show overlay when focused if there are any filtered items available
      // Use a post-frame callback to ensure input context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusManager.isFocused) {
          return;
        }

        // Check again if maxSelected is reached (might have changed)
        if (_selectionManager.isMaxReached()) {
          return;
        }

        final filtered = _filtered;
        if (!_overlayManager.isShowing && filtered.isNotEmpty) {
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
    _decorationManager.invalidate();
    _safeSetState(() {
      // Trigger rebuild to apply new decoration
    });
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

    // Handle add item selection
    if (ItemDropperAddItemUtils.isAddItem(item, widget.items)) {
      final String searchText = ItemDropperAddItemUtils
          .extractSearchTextFromAddItem(item);
      if (searchText.isNotEmpty && widget.onAddItem != null) {
        final ItemDropperItem<T>? newItem = widget.onAddItem!(searchText);
        if (newItem != null) {
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
        }
      }
      return;
    }

    // Manual focus management - maintain focus state when clicking overlay items
    // Don't let Flutter lose focus - we control it manually

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
      final bool wasAtMax = _selectionManager.isMaxReached();

      if (!isCurrentlySelected) {
        _selectionManager.addItem(item);

        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;

        // Clear search text after selection for continued searching
        _searchController.clear();

        // Announce selection to screen readers
        _liveRegionManager.announce(
          ItemDropperSemantics.announceItemSelected(item.label),
        );

        // If we just reached the max, close the overlay
        if (_selectionManager.isMaxReached()) {
          _overlayManager.hideIfNeeded();
          // Announce max reached
          if (widget.maxSelected != null) {
            _liveRegionManager.announce(
              ItemDropperSemantics.announceMaxSelectionReached(
                  widget.maxSelected!),
            );
          }
        }
      } else {
        // Item is already selected, remove it (toggle off)
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
      ItemDropperSemantics.announceItemRemoved(item.label),
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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete "${item.label}"?'),
          content: const Text('This will remove the item from the list.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
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
        _toggleItem(item);
      }
    } else {
      // Find first selectable item for auto-select
      final selectableItems = filteredItems
          .where((item) => !item.isGroupHeader)
          .toList();
      if (selectableItems.length == 1) {
        // No keyboard navigation, but exactly 1 selectable item - auto-select it
        _toggleItem(selectableItems[0]);
      } else {}
    }
  }

  void _handleTextChanged(String value) {
    // Don't show overlay if maxSelected is reached
    if (_selectionManager.isMaxReached()) {
      _overlayManager.hideIfNeeded();
      return;
    }

    // Invalidate filtered cache since search text changed
    _invalidateFilteredCache();

    // Filter utils already handles text-based cache invalidation automatically
    // Only need to clear highlights and trigger rebuild
    _safeSetState(() {
      _clearHighlights();
    });

    // Show overlay if there are filtered items OR if user is searching (to show empty state)
    // Use manual focus state
    if (_focusManager.isFocused) {
      _overlayManager.showIfNeeded();
    } else if (_filtered.isEmpty) {
      // Hide overlay if no filtered items and not focused
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

    // Single post-frame callback handles: parent notification, flag clearing, and optional callback
    // This consolidates what was previously multiple separate callbacks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Notify parent of change
        widget.onChanged(_selectionManager.selected);

        // Clear the internal change flag after parent's didUpdateWidget has run
        // (which happens synchronously when onChanged triggers parent rebuild)
        _isInternalSelectionChange = false;

        // Execute optional post-rebuild callback (e.g., focus management, overlay updates)
        if (postRebuildCallback != null) {
          postRebuildCallback();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant MultiItemDropper<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If widget became disabled, unfocus and hide overlay
    if (oldWidget.enabled && !widget.enabled) {
      _focusManager.loseFocus();
      _overlayManager.hideIfNeeded();
    }

    // Sync selected items if parent changed them (and we didn't cause the change)
    if (!_isInternalSelectionChange &&
        !_areItemsEqual(widget.selectedItems, _selectionManager
            .selected)) {
      _selectionManager.syncItems(widget.selectedItems);
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
  bool _areItemsEqual(List<ItemDropperItem<T>> a, List<ItemDropperItem<T>> b) {
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
  void dispose() {
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
    return Container(
      key: widget.inputKey ?? _fieldKey,
      width: widget.width, // Constrain to 500px
      // Let content determine height naturally to prevent overflow
      decoration: _decorationManager.get(
        isFocused: _focusManager.isFocused,
        customDecoration: widget.fieldDecoration,
        borderRadius: MultiSelectConstants.kContainerBorderRadius,
        borderWidth: MultiSelectConstants.kContainerBorderWidth,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Fill available space instead of min
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Integrated chips and text field area
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MultiSelectConstants.kContainerPaddingLeft,
              MultiSelectConstants.kContainerPaddingTop,
              MultiSelectConstants.kContainerPaddingRight,
              MultiSelectConstants.kContainerPaddingBottom,
            ),
            child: SmartWrapWithFlexibleLast(
              spacing: MultiSelectConstants.kChipSpacing,
              runSpacing: MultiSelectConstants.kChipSpacing,
              children: [
                // Selected chips
                ..._selectionManager.selected.map((item) =>
                    Container(
                      key: ValueKey('chip_${item.value}'),
                      // Unique key for each chip
                      child: _buildChip(item),
                    )),
                _buildTextFieldChip(double.infinity),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildChip(ItemDropperItem<T> item,
      [GlobalKey? chipKey, Key? valueKey]) {
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

        return Semantics(
          label: ItemDropperSemantics.formatSelectedChipLabel(item.label),
          button: true,
          excludeSemantics: true,
          child: Container(
            key: chipKey,
            // Use provided GlobalKey (for last chip) or null
            decoration: effectiveDecoration,
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
          label: ItemDropperSemantics.multiSelectFieldLabel,
          textField: true,
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
          style: widget.fieldTextStyle ??
              const TextStyle(fontSize: ItemDropperConstants
                  .kDropdownItemFontSize),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.only(
              right: fontSize * MultiSelectConstants.kTextLineHeightMultiplier,
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
      maxDropdownHeight: widget.maxDropdownHeight ?? MultiSelectConstants.kDefaultMaxDropdownHeight,
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

  /// Builds an empty state overlay when search returns no results
  Widget _buildEmptyStateOverlay(BuildContext inputContext) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final double inputFieldHeight = inputBox.size.height;
    // Use actual measured field width to ensure overlay matches field width exactly
    final double actualFieldWidth = inputBox.size.width;
    final double maxDropdownHeight = widget.maxDropdownHeight ??
        MultiSelectConstants.kDefaultMaxDropdownHeight;
    
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
              MultiSelectConstants.kEmptyStateMessage,
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

