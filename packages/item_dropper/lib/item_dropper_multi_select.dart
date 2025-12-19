import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_dropper/src/common/item_dropper_common.dart';
import 'package:item_dropper/src/common/live_region_manager.dart';
import 'package:item_dropper/src/common/keyboard_navigation_manager.dart';
import 'package:item_dropper/src/multi/multi_select_constants.dart';
import 'package:item_dropper/src/multi/multi_select_focus_manager.dart';
import 'package:item_dropper/src/multi/multi_select_layout_calculator.dart';
import 'package:item_dropper/src/multi/multi_select_selection_manager.dart';
import 'package:item_dropper/src/multi/smartwrap.dart'
    show SmartWrapWithFlexibleLast;
import 'package:item_dropper/src/utils/item_dropper_add_item_utils.dart';
import 'package:item_dropper/src/utils/item_dropper_selection_handler.dart';
import 'package:item_dropper/src/utils/dropdown_position_calculator.dart';
import 'package:item_dropper/src/utils/item_dropper_items_utils.dart';
import 'package:item_dropper/src/single/single_select_constants.dart';
import 'package:item_dropper/src/common/item_dropper_localizations.dart';

part 'src/multi/multi_item_dropper_state.dart';
part 'src/multi/multi_item_dropper_handlers.dart';
part 'src/multi/multi_item_dropper_builders.dart';

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
  final Widget Function(BuildContext, ItemDropperItem<T>, bool)?
  popupItemBuilder;

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

  // Memoized filtered items - invalidated when search text or selected items change
  List<ItemDropperItem<T>>? _cachedFilteredItems;
  String _lastFilteredSearchText = '';
  int _lastFilteredSelectedCount = -1;

  // Chip measurement state
  double? _chipHeight;
  double? _chipTextTop;
  double?
  _lastContainerHeight; // Track Container height for overlay repositioning

  final GlobalKey _chipRowKey = GlobalKey();
  final GlobalKey _textFieldKey = GlobalKey();
  final GlobalKey _wrapKey = GlobalKey();

  bool _isMeasuring = false;

  /// Get localizations with defaults
  ItemDropperLocalizations get _localizations =>
      widget.localizations ?? ItemDropperLocalizations.english;

  // State flag for rebuild scheduling
  bool _rebuildScheduled = false;

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

    // Initialize keyboard navigation manager
    _keyboardNavManager = KeyboardNavigationManager<T>(
      onRequestRebuild: () => _safeSetState(() {}),
      onEscape: () => _focusManager.loseFocus(),
      onOpenDropdown: () {
        // Show dropdown - if max is reached, overlay will show max reached message
        _focusManager.gainFocus();
        _showOverlay();
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

      // Check if Space/Enter should open dropdown (only if text is empty or cursor at start)
      final shouldOpenOnSpaceEnter =
          !_overlayController.isShowing &&
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
      // _requestRebuild() already checks _rebuildScheduled internally
      _requestRebuild();
    }

    // Invalidate filter cache if items list changed
    if (ItemDropperItemsUtils.hasItemsChanged(oldWidget.items, widget.items)) {
      _filterUtils.initializeItems(widget.items);
      _invalidateFilteredCache();
      // Cache removed - overlay rebuilds automatically
      // Use central rebuild mechanism instead of direct setState
      // _requestRebuild() already checks _rebuildScheduled internally
      _requestRebuild();
    }
  }

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
