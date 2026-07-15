import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_dropper/src/common/item_dropper_common.dart';
import 'package:item_dropper/src/common/live_region_manager.dart';
import 'package:item_dropper/src/common/keyboard_navigation_manager.dart';
import 'package:item_dropper/src/multi/multi_select_chip_focus_node_controller.dart';
import 'package:item_dropper/src/multi/multi_select_chip_layout_controller.dart';
import 'package:item_dropper/src/multi/multi_select_constants.dart';
import 'package:item_dropper/src/multi/multi_select_filter_controller.dart';
import 'package:item_dropper/src/multi/multi_select_focus_manager.dart';
import 'package:item_dropper/src/multi/multi_select_highlight_policy.dart';
import 'package:item_dropper/src/multi/multi_select_selection_manager.dart';
import 'package:item_dropper/src/multi/smartwrap.dart'
    show SmartWrapWithFlexibleLast;
import 'package:item_dropper/src/utils/item_dropper_selection_handler.dart';
import 'package:item_dropper/src/utils/item_dropper_overlay_content.dart';
import 'package:item_dropper/src/utils/item_dropper_items_utils.dart';
import 'package:item_dropper/src/single/single_select_constants.dart';
import 'package:item_dropper/src/common/item_dropper_localizations.dart';

/// Multi-select dropdown widget
/// Allows selecting multiple items with chip-based display
class MultiItemDropper<T> extends ItemDropperBase<T> {
  /// The items to display in the dropdown (required).
  @override
  final List<ItemDropperItem<T>> items;

  /// The currently selected items (optional for controlled usage).
  final List<ItemDropperItem<T>>? selectedItems;

  /// Called when the selection changes (required).
  final void Function(List<ItemDropperItem<T>>) onChanged;

  /// Optional custom builder for popup items.
  @override
  final Widget Function(BuildContext, ItemDropperItem<T>, bool)?
  popupItemBuilder;

  /// The width of the dropdown field (required).
  @override
  final double width;

  /// Whether the dropdown is enabled (defaults to true).
  @override
  final bool enabled;

  /// Hint/placeholder text for input field (if null, no hint).
  @override
  final String? hintText;

  /// Maximum number of items selectable (null means unlimited).
  final int? maxSelected;

  /// Callback for adding new items based on search text (optional).
  @override
  final ItemDropperItem<T>? Function(String searchText)? onAddItem;

  /// Callback for deleting items, provides the deleted item (optional).
  @override
  final void Function(ItemDropperItem<T> item)? onDeleteItem;

  /// Optional GlobalKey for the input field container.
  @override
  final GlobalKey<State<StatefulWidget>>? inputKey;

  /// Maximum dropdown popup height.
  @override
  final double maxDropdownHeight;

  /// Whether to show a vertical scrollbar in popup.
  @override
  final bool showScrollbar;

  /// Popup vertical scrollbar thickness.
  @override
  final double scrollbarThickness;

  /// Height for popup dropdown items.
  @override
  final double? itemHeight;

  /// Text style for popup dropdown items.
  @override
  final TextStyle? popupTextStyle;

  /// Text style for group headers in popup.
  @override
  final TextStyle? popupGroupHeaderStyle;

  /// Text style for input/search field and chips.
  @override
  final TextStyle? fieldTextStyle;

  /// Custom BoxDecoration for selected chips.
  final BoxDecoration? selectedChipDecoration;

  /// Optional BoxDecoration for the main field/container.
  @override
  final BoxDecoration? fieldDecoration;

  /// Popup shadow elevation.
  @override
  final double? elevation;

  /// Whether to show the dropdown position arrow (defaults to true).
  @override
  final bool showDropdownPositionIcon;

  /// Whether to show the clear/X icon (defaults to true).
  @override
  final bool showDeleteAllIcon;

  /// Localization strings for user-facing text (optional).
  /// If not provided, uses default English strings.
  @override
  final ItemDropperLocalizations? localizations;

  /// Dependency factory hooks for tests and advanced integrations.
  final MultiItemDropperDependencies<T>? dependencies;

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
    this.dependencies,
  }) : assert(
         maxSelected == null || maxSelected >= 2,
         'maxSelected must be null or >= 2',
       );

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

  // Keyboard navigation manager
  late final KeyboardNavigationManager<T> _keyboardNavManager;

  final GlobalKey _chipRowKey = GlobalKey();
  final GlobalKey _textFieldKey = GlobalKey();
  final GlobalKey _wrapKey = GlobalKey();

  /// Get localizations with defaults
  ItemDropperLocalizations get _localizations =>
      widget.localizations ?? ItemDropperLocalizations.english;

  final RebuildScheduler _rebuildScheduler = RebuildScheduler();

  // Unified focus manager handles both TextField and chip focus
  late final MultiSelectFocusManager<T> _focusManager;

  late final DecorationCacheManager _decorationManager;

  late final MultiSelectFilterController<T> _filterController;
  late final MultiSelectChipLayoutController _chipLayoutController;
  late final MultiSelectChipFocusNodeController _chipFocusNodeController;
  late final MultiSelectHighlightPolicy _highlightPolicy;
  late final MultiItemDropperDependencies<T> _dependencies;

  // Live region for screen reader announcements
  late final LiveRegionManager _liveRegionManager;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    _dependencies = widget.dependencies ?? MultiItemDropperDependencies<T>();
    _decorationManager = _dependencies.createDecorationCacheManager();
    _filterController = _dependencies.createFilterController();
    _chipLayoutController = _dependencies.createChipLayoutController();
    _chipFocusNodeController = _dependencies.createChipFocusNodeController();
    _highlightPolicy = _dependencies.createHighlightPolicy();

    // Initialize unified focus manager (handles both TextField and chip focus)
    _focusManager = _dependencies.createFocusManager(
      focusNode: _focusNode,
      onFocusVisualStateChanged: _updateFocusVisualState,
      onFocusChanged: _handleFocusChange,
      onRemoveChip: _removeChip,
    );

    // Initialize selection manager with callbacks
    _selectionManager = _dependencies.createSelectionManager(
      maxSelected: widget.maxSelected,
      onSelectionChanged: () {
        // Selection changed - will notify parent via _handleSelectionChange
      },
      onFilterCacheInvalidated: () {
        _invalidateFilteredCache(clearBaseFilterCache: true);
      },
    );
    _selectionManager.syncItems(widget.selectedItems ?? []);

    // Initialize keyboard navigation manager
    _keyboardNavManager = _dependencies.createKeyboardNavigationManager(
      onRequestRebuild: () => _safeSetState(() {}),
      onEscape: () => _focusManager.loseFocus(),
      onOpenDropdown: () {
        // Show dropdown - if max is reached, overlay will show max reached message
        _focusManager.gainFocus();
        _showOverlay();
      },
    );

    // Initialize live region manager
    _liveRegionManager = _dependencies.createLiveRegionManager(
      onUpdate: () => _safeSetState(() {}),
    );

    // Update focus manager with initial selected items
    _focusManager.updateSelectedItems(_selectionManager.selected);

    _filterController.initializeItems(widget.items);

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
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            cursorPosition == 0) {
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

      final shouldOpenOnSpaceEnter =
          ItemDropperKeyboardNavigation.shouldOpenDropdownOnKey(
            logicalKey: event.logicalKey,
            isDropdownOpen: _overlayController.isShowing,
            text: _searchController.text,
            selection: _searchController.selection,
          );

      // If Space/Enter and shouldn't open dropdown, let TextField handle it normally
      if (ItemDropperKeyboardNavigation.isOpenDropdownKey(event.logicalKey) &&
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
    return _filterController.filteredItems(
      items: widget.items,
      searchText: _searchController.text,
      selectedCount: _selectionManager.selectedCount,
      selectedValues: _selectionManager.selectedValues,
      hasOnAddItemCallback: widget.onAddItem != null,
      localizations: _localizations,
    );
  }

  // Helper method to safely call setState (must stay in main class, not extension, because setState is protected)
  void _safeSetState(void Function() fn) {
    if (mounted) {
      setState(() {
        fn();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MultiItemDropper<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update focus manager with new selection
    _focusManager.updateSelectedItems(_selectionManager.selected);

    // If widget became disabled, unfocus and hide overlay
    if (oldWidget.enabled && !widget.enabled) {
      _focusManager.loseFocus();
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
    }

    // Sync selected items if parent changed them (and we didn't cause the change)
    // Detect if we caused the change by comparing our selection with widget's selection
    // If they match, we caused the change (parent hasn't updated yet)
    // If they don't match, parent changed it
    final ourSelection = _selectionManager.selected;
    final widgetSelection = widget.selectedItems ?? [];
    final weCausedChange = _areItemsEqual(ourSelection, widgetSelection);

    if (!weCausedChange &&
        !_areItemsEqual(widget.selectedItems, ourSelection)) {
      _selectionManager.syncItems(widgetSelection);
      // Don't trigger rebuild here if we're already rebuilding
      // Parent change will be reflected in the current rebuild cycle
      // _requestRebuild() coalesces nested requests internally
      _requestRebuild();
    }

    // Invalidate filter cache if items list changed
    if (ItemDropperItemsUtils.hasItemsChanged(oldWidget.items, widget.items)) {
      _filterController.initializeItems(widget.items);
      // Cache removed - overlay rebuilds automatically
      // Use central rebuild mechanism instead of direct setState
      // _requestRebuild() coalesces nested requests internally
      _requestRebuild();
    }
  }

  @override
  void dispose() {
    _chipFocusNodeController.dispose();
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
            if (_overlayController.isShowing) {
              _overlayController.hide();
            }
          },
          overlay: _buildDropdownOverlay(context),
          inputField: _buildInputField(),
        ),
        // Live region for screen reader announcements
        _liveRegionManager.build(),
      ],
    );
  }
}

// State management and helper methods
extension _MultiItemDropperStateHelpers<T> on _MultiItemDropperState<T> {
  void _clearHighlights() {
    _keyboardNavManager.clearHighlights();
  }

  /// Show overlay and trigger rebuild so OverlayPortal displays it
  /// OverlayPortalController.show() doesn't trigger a rebuild automatically
  void _showOverlay() {
    if (!_overlayController.isShowing) {
      _clearHighlights();
      _overlayController.show();
      // Trigger rebuild so OverlayPortal can show the overlay
      _safeSetState(() {});
    }
  }

  /// Invalidate filtered items cache - call when search text or selected items change
  void _invalidateFilteredCache({bool clearBaseFilterCache = false}) {
    if (clearBaseFilterCache) {
      _filterController.clearFilterCache();
    } else {
      _filterController.invalidate();
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
    // Only show overlay if not already showing (to avoid redundant work)
    // The GestureDetector and TextField onTap handlers already show overlay immediately
    if (_focusManager.isFocused && !_overlayController.isShowing) {
      // Show overlay when focused - if max is reached, overlay will show max reached message
      // _showOverlay() already triggers a rebuild, so we can show it synchronously
      // If max is reached, show overlay (will display max reached message)
      if (_selectionManager.isMaxReached()) {
        _showOverlay();
        return;
      }

      final filtered = _filtered;
      // Only show if we have items
      if (filtered.isNotEmpty) {
        _showOverlay();
      }
    }
  }

  // Update visual state (border color) based on manual focus state
  void _updateFocusVisualState() {
    if (_rebuildScheduler.isRebuilding) {
      return;
    }
    _decorationManager.invalidate();
    // Note: setState must be called from main class, so we'll call _safeSetState from there
    // This is a helper that just invalidates the cache - the caller should trigger rebuild
  }

  /// Get decoration for the input field container.
  BoxDecoration _getDecoration({
    required bool isFocused,
    BoxDecoration? customDecoration,
  }) {
    return _decorationManager.get(
      isFocused: isFocused,
      customDecoration: customDecoration,
      borderRadius: MultiSelectConstants.kContainerBorderRadius,
      borderWidth: MultiSelectConstants.kContainerBorderWidth,
      gradientEndColor: const Color(0xFFE5E5E5),
    );
  }

  void _updateSelection(void Function() selectionUpdate) {
    // Preserve keyboard highlight state - only reset if keyboard navigation was active
    final bool wasKeyboardActive = _highlightPolicy.isKeyboardActive(
      _keyboardNavManager.keyboardHighlightIndex,
    );
    final int previousHoverIndex = _keyboardNavManager.hoverIndex;

    // Use unified selection change handler
    _handleSelectionChange(
      stateUpdate: () {
        // Update selection inside the rebuild callback
        selectionUpdate();

        // Update focus manager with new selection
        _focusManager.updateSelectedItems(_selectionManager.selected);

        _chipFocusNodeController.retainIndices(
          _selectionManager.selected.asMap().keys,
        );

        // Update highlights based on filtered items
        final List<ItemDropperItem<T>> remainingFilteredItems = _filtered;

        final highlightResult = _highlightPolicy.afterSelectionChange(
          wasKeyboardActive: wasKeyboardActive,
          previousHoverIndex: previousHoverIndex,
          remainingFilteredItemCount: remainingFilteredItems.length,
        );

        if (highlightResult.clearHighlights) {
          _clearHighlights();
        } else if (highlightResult.hoverIndex != null) {
          _keyboardNavManager.hoverIndex = highlightResult.hoverIndex!;
        }

        if (highlightResult.hideOverlay) {
          if (_overlayController.isShowing) {
            _overlayController.hide();
          }
        }
      },
      postRebuildCallback: () {
        // Restore focus if needed after selection update
        _focusManager.restoreFocusIfNeeded();

        // Measure Container height after selection change
        // This detects when chips wrap to a new row and triggers overlay repositioning
        _measureContainerHeight();
      },
    );
  }

  // Central rebuild mechanism - coalesces nested rebuild requests.
  void _requestRebuild([void Function()? stateUpdate]) {
    _rebuildScheduler.request(
      mounted: mounted,
      rebuild: _safeSetState,
      update: stateUpdate,
    );
  }

  /// Unified method to handle selection changes: rebuild + notify parent + cleanup
  /// Consolidates the common pattern of rebuilding, notifying parent, and cleanup
  void _handleSelectionChange({
    required void Function() stateUpdate,
    void Function()? postRebuildCallback,
  }) {
    // Update selection and all related state inside rebuild
    _requestRebuild(stateUpdate);

    // Notify parent immediately after rebuild
    // setState is synchronous, so the rebuild has already completed
    // didUpdateWidget will detect if we caused the change by comparing values
    if (mounted) {
      widget.onChanged(_selectionManager.selected);

      // Execute optional post-rebuild callback (e.g., focus management, overlay updates)
      if (postRebuildCallback != null) {
        postRebuildCallback();
      }
    }
  }

  /// Measure Container height and trigger rebuild if it changed
  /// This ensures overlay repositions immediately when chips wrap to a new row
  void _measureContainerHeight() {
    _chipLayoutController.scheduleContainerHeightMeasurement(
      fieldContext: (widget.inputKey ?? _fieldKey).currentContext,
      isMounted: () => mounted,
      isOverlayShowing: () => _overlayController.isShowing,
      onHeightChanged: () {
        // Trigger rebuild so overlay recalculates position with new height
        _safeSetState(() {});
      },
    );
  }

  // Helper to check if two item lists are equal (by value)
  // Delegates to shared utility
  bool _areItemsEqual(List<ItemDropperItem<T>>? a, List<ItemDropperItem<T>> b) {
    return ItemDropperItemsUtils.areItemsEqual(a, b);
  }
}

// Event handler methods
extension _MultiItemDropperStateHandlers<T> on _MultiItemDropperState<T> {
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
          _searchController.clear();

          // If we just reached the max, close the overlay
          if (_selectionManager.isMaxReached()) {
            if (_overlayController.isShowing) {
              _overlayController.hide();
            }
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
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
      return;
    }
    // Allow removing items even when max is reached (toggle behavior)

    _updateSelection(() {
      if (!isCurrentlySelected) {
        _handleAddItem(item);
      } else {
        _handleRemoveItem(item);
      }
      // After selection change, clear highlights
      _clearHighlights();
    });
  }

  /// Handles adding an item to the selection
  void _handleAddItem(ItemDropperItem<T> item) {
    _selectionManager.addItem(item);

    // Announce selection to screen readers
    final loc = _localizations;
    _liveRegionManager.announce('${item.label}${loc.itemSelectedSuffix}');

    // If we just reached the max, close the overlay
    if (_selectionManager.isMaxReached()) {
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
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
      // _handleTextChanged (triggered by clear()) already checks focus and shows overlay
      // gainFocus() already calls requestFocus(), so no need for post-frame callback
      _searchController.clear();
    }
  }

  /// Handles removing an item from the selection
  void _handleRemoveItem(ItemDropperItem<T> item) {
    // Capture state before removal to check if we should reopen overlay
    final bool wasAtMax = _selectionManager.isMaxReached();
    _selectionManager.removeItem(item.value);

    // Show overlay again if we're below maxSelected after removal
    // This handles the case where user removes an item after reaching max
    if (wasAtMax && _selectionManager.isBelowMax() && _focusManager.isFocused) {
      final filtered = _filtered;
      if (!_overlayController.isShowing && filtered.isNotEmpty) {
        _showOverlay();
      }
    }
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

        _clearHighlights();
      },
      postRebuildCallback: () {
        // Restore focus if needed after chip removal
        _focusManager.restoreFocusIfNeeded();

        // Show overlay if we're below maxSelected and focused
        if (_focusManager.isFocused && _selectionManager.isBelowMax()) {
          final filtered = _filtered;
          if (!_overlayController.isShowing && filtered.isNotEmpty) {
            _showOverlay();
          }
        }
      },
    );
  }

  /// Handle delete requests coming from overlay items (right-click / long-press).
  /// Uses a simple built-in confirmation dialog before invoking onDeleteItem.
  void _handleRequestDeleteFromOverlay(
    BuildContext context,
    ItemDropperItem<T> item,
  ) {
    // Only allow delete for items explicitly marked as deletable.
    if (!item.isDeletable) {
      return;
    }

    // Run async flow without blocking the gesture handler.
    _confirmAndDeleteItem(context, item);
  }

  Future<void> _confirmAndDeleteItem(
    BuildContext context,
    ItemDropperItem<T> item,
  ) async {
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
    // _requestRebuild() coalesces nested requests internally
    _requestRebuild();
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
        });
      }
    }
  }

  /// Handle arrow button press - toggle dropdown
  void _handleArrowPressed() {
    if (_overlayController.isShowing) {
      _focusManager.loseFocus();
      _overlayController.hide();
    } else {
      // Show dropdown - if max is reached, overlay will show max reached message
      _focusManager.gainFocus();
      _showOverlay();
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

    // Show overlay if focused - if max is reached, overlay will show max reached message
    // This allows continued selection after clearing search text
    // When we clear text after selection, focus is already set, so overlay stays open
    if (_focusManager.isFocused) {
      _showOverlay();
    } else if (_filtered.isEmpty && !_selectionManager.isMaxReached()) {
      // Hide overlay if no filtered items and not focused and not at max
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
    }
  }
}

// Build methods
extension _MultiItemDropperStateBuilders<T> on _MultiItemDropperState<T> {
  Widget _buildInputField() {
    // Calculate first row height for icon alignment
    final double chipHeight = _chipLayoutController.chipHeight(
      fontSize: widget.fieldTextStyle?.fontSize,
    );
    final double firstRowHeight = chipHeight;
    final double fontSize =
        widget.fieldTextStyle?.fontSize ??
        ItemDropperConstants.kDropdownItemFontSize;
    final double iconContainerHeight =
        fontSize * ItemDropperConstants.kSuffixIconHeightMultiplier;

    return GestureDetector(
      onTap: () {
        // When container is tapped (but not on chips or icons), focus the TextField
        if (widget.enabled) {
          _focusManager.focusTextField();
          _focusManager.gainFocus();
          // Invalidate filter cache to ensure fresh calculation
          _invalidateFilteredCache();
          // Show overlay immediately
          _showOverlay();
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
                        ((widget.showDropdownPositionIcon ||
                                widget.showDeleteAllIcon)
                            ? SingleSelectConstants.kSuffixIconWidth
                            : 0.0),
                    MultiSelectConstants.kContainerPaddingBottom,
                  ),
                  child: SmartWrapWithFlexibleLast(
                    key: _wrapKey,
                    spacing: MultiSelectConstants.kChipSpacing,
                    runSpacing: MultiSelectConstants.kChipSpacing,
                    children: [
                      // Selected chips
                      ..._selectionManager.selected.asMap().entries.map((
                        entry,
                      ) {
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
                top:
                    MultiSelectConstants.kContainerPaddingTop +
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
                  clearButtonRightPosition:
                      SingleSelectConstants.kClearButtonRightPosition,
                  arrowButtonRightPosition:
                      SingleSelectConstants.kArrowButtonRightPosition,
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

  Widget _buildChip(
    ItemDropperItem<T> item, [
    GlobalKey? chipKey,
    Key? valueKey,
    int? chipIndex,
  ]) {
    final index = chipIndex ?? _selectionManager.selected.indexOf(item);
    final isFocused = _focusManager.isChipFocused(index);

    // Only measure the first chip (index 0) to avoid GlobalKey conflicts
    final bool isFirstChip =
        _selectionManager.selected.isNotEmpty &&
        _selectionManager.selected.first.value == item.value;
    final GlobalKey? rowKey = isFirstChip ? _chipRowKey : null;

    return LayoutBuilder(
      key: valueKey, // Use stable ValueKey for widget preservation
      builder: (context, constraints) {
        // Schedule chip measurement after build completes - don't measure during build
        // Measure chip dimensions after first render (only for first chip, only once)
        // Chip measurements don't change, so we only need to measure once
        if (isFirstChip && rowKey != null) {
          _chipLayoutController.scheduleChipMeasurement(
            context: context,
            rowKey: rowKey,
            isMounted: () => mounted,
          );
        }

        // Determine chip decoration.
        // - If a custom BoxDecoration is provided, use it as-is.
        // - Otherwise, fall back to the default blue vertical gradient.
        final BoxDecoration effectiveDecoration =
            widget.selectedChipDecoration ??
            BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade200],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(
                MultiSelectConstants.kChipBorderRadius,
              ),
            );

        // Add focus border if focused
        final BoxDecoration focusedDecoration = isFocused
            ? effectiveDecoration.copyWith(
                border: Border.all(color: Colors.blue.shade600, width: 2.0),
              )
            : effectiveDecoration;

        // Get or create FocusNode for this chip
        final chipFocusNode = _chipFocusNodeController.nodeForIndex(
          index,
          enabled: widget.enabled,
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
                  right: MultiSelectConstants.kChipMarginRight,
                ),
                child: Row(
                  key: rowKey, // Only first chip gets the key
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style:
                          (widget.fieldTextStyle ??
                                  const TextStyle(
                                    fontSize: ItemDropperConstants
                                        .kDropdownItemFontSize,
                                  ))
                              .copyWith(
                                color: widget.enabled
                                    ? (widget.fieldTextStyle?.color ??
                                          Colors.black)
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
                          child: Icon(
                            Icons.close,
                            size: MultiSelectConstants.kChipDeleteIconSize,
                            color: Colors.grey.shade700,
                          ),
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
    final double chipHeight = _chipLayoutController.chipHeight(
      fontSize: widget.fieldTextStyle?.fontSize,
    );
    final double fontSize =
        widget.fieldTextStyle?.fontSize ??
        ItemDropperConstants.kDropdownItemFontSize;
    final padding = _chipLayoutController.textFieldPadding(
      chipHeight: chipHeight,
      fontSize: fontSize,
    );
    final double textFieldPaddingTop = padding.top;
    final double textFieldPaddingBottom = padding.bottom;

    // Use Container with exact width - Wrap will use this for layout
    return SizedBox(
      key: _textFieldKey, // Key to measure TextField position
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
            style:
                widget.fieldTextStyle ??
                const TextStyle(
                  fontSize: ItemDropperConstants.kDropdownItemFontSize,
                ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.only(
                right:
                    ((widget.showDropdownPositionIcon ||
                            widget.showDeleteAllIcon)
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
              // Show overlay immediately
              _showOverlay();
            },
          ), // Close TextField
        ), // Close Semantics
      ), // Close IgnorePointer
    );
  }

  Widget _buildDropdownOverlay(BuildContext context) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    final List<ItemDropperItem<T>> filteredItems = _filtered;

    // Use the context from build() method for proper positioning
    // Fall back to key-based context if needed, but prefer the passed context
    final BuildContext inputContext =
        (widget.inputKey ?? _fieldKey).currentContext ?? context;

    final double effectiveItemHeight = _calculateEffectiveItemHeight();

    // Show max reached overlay if max selection is reached
    if (_selectionManager.isMaxReached()) {
      return _buildInfoOverlay(
        inputContext,
        _localizations.maxItemsReachedOverlay,
      );
    }

    // Show empty state if user is searching but no results found
    if (filteredItems.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        // User is searching but no results - show empty state
        return _buildInfoOverlay(inputContext, _localizations.noResultsFound);
      }
      // No search text and no filtered items - check if we have items to show
      // If widget.items has items (excluding selected), show them
      final availableItems = widget.items
          .where(
            (item) =>
                item.isGroupHeader ||
                !_selectionManager.selectedValues.contains(item.value),
          )
          .toList();
      if (availableItems.isEmpty) {
        // No items available - hide overlay
        return const SizedBox.shrink();
      }
      // We have items but filteredItems is empty - use availableItems instead
      // This can happen during initialization before _filtered is properly calculated
      return _buildOverlayContent(
        items: availableItems,
        inputContext: inputContext,
        effectiveItemHeight: effectiveItemHeight,
      );
    }

    // Build overlay with filtered items
    return _buildOverlayContent(
      items: filteredItems,
      inputContext: inputContext,
      effectiveItemHeight: effectiveItemHeight,
    );
  }

  /// Calculates the effective item height from widget.itemHeight or popupTextStyle
  double _calculateEffectiveItemHeight() {
    return ItemDropperLayoutUtils.calculateEffectiveItemHeight(
      itemHeight: widget.itemHeight,
      popupTextStyle: widget.popupTextStyle,
    );
  }

  /// Gets the item builder function for a given item in a list
  Widget Function(BuildContext, ItemDropperItem<T>, bool) _getItemBuilder(
    List<ItemDropperItem<T>> items,
    int itemIndex,
  ) {
    // Use custom builder if provided
    if (widget.popupItemBuilder != null) {
      return widget.popupItemBuilder!;
    }

    // Otherwise, use default builder with style parameters
    final bool hasPrevious = itemIndex > 0;
    final bool previousIsGroupHeader =
        hasPrevious && items[itemIndex - 1].isGroupHeader;

    return (context, item, isSelected) {
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

  /// Builds the overlay content with the given items
  Widget _buildOverlayContent({
    required List<ItemDropperItem<T>> items,
    required BuildContext inputContext,
    required double effectiveItemHeight,
  }) {
    // Use Container's full height for overlay positioning (not Wrap height)
    // The Container includes border and padding, which must be accounted for
    // Don't pass preferredFieldHeight - use inputBox.size.height directly
    // This ensures overlay is positioned correctly relative to the Container
    return ItemDropperRenderUtils.buildDropdownOverlay<T>(
      context: inputContext,
      items: items,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: _overlayController,
      scrollController: _scrollController,
      layerLink: _layerLink,
      isSelected: (ItemDropperItem<T> item) =>
          _selectionManager.isSelected(item),
      builder:
          (
            BuildContext builderContext,
            ItemDropperItem<T> item,
            bool isSelected,
          ) {
            final int itemIndex = items.indexWhere((x) => identical(x, item));
            final itemBuilder = _getItemBuilder(items, itemIndex);

            return ItemDropperRenderUtils.buildDropdownItemWithHover<T>(
              context: builderContext,
              item: item,
              isSelected: isSelected,
              filteredItems: items,
              hoverIndex: _keyboardNavManager.hoverIndex,
              keyboardHighlightIndex:
                  _keyboardNavManager.keyboardHighlightIndex,
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
      // Don't pass preferredFieldHeight - use Container's full height from inputBox
    );
  }

  /// Builds an informational overlay for non-list dropdown states.
  Widget _buildInfoOverlay(BuildContext inputContext, String message) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    return ItemDropperRenderUtils.buildDropdownOverlay<T>(
      context: inputContext,
      items: const [],
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: _overlayController,
      scrollController: _scrollController,
      layerLink: _layerLink,
      isSelected: (_) => false,
      builder: (_, item, isSelected) => const SizedBox.shrink(),
      itemHeight: _calculateEffectiveItemHeight(),
      content: ItemDropperWidgetOverlayContent<T>(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MultiSelectConstants.kEmptyStatePaddingHorizontal,
            vertical: MultiSelectConstants.kEmptyStatePaddingVertical,
          ),
          child: Text(
            message,
            style:
                (widget.popupTextStyle ??
                        widget.fieldTextStyle ??
                        const TextStyle(
                          fontSize: ItemDropperConstants.kDropdownItemFontSize,
                        ))
                    .copyWith(color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}
