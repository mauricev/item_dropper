import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_dropper/src/common/item_dropper_common.dart';
import 'package:item_dropper/src/utils/item_dropper_add_item_utils.dart';
import 'package:item_dropper/src/utils/item_dropper_selection_handler.dart';
import 'package:item_dropper/src/single/single_select_constants.dart';
import 'package:item_dropper/src/multi/multi_select_constants.dart';
import 'package:item_dropper/src/common/item_dropper_semantics.dart';
import 'package:item_dropper/src/common/live_region_manager.dart';
import 'package:item_dropper/src/common/keyboard_navigation_manager.dart';
import 'package:item_dropper/src/common/decoration_cache_manager.dart';

/// Single-select dropdown widget
/// Allows selecting a single item from a searchable list
class SingleItemDropper<T> extends StatefulWidget {
  /// The items to display in the dropdown (required).
  final List<ItemDropperItem<T>> items;

  /// The currently selected item (optional for controlled usage).
  final ItemDropperItem<T>? selectedItem;

  /// Called when the selection changes (required).
  final ItemDropperItemCallback<T> onChanged;

  /// Hint/placeholder text for input field (if null, no hint).
  final String? hintText;

  /// Optional custom builder for popup items.
  final Widget Function(BuildContext, ItemDropperItem<
      T>, bool)? popupItemBuilder;

  /// The width of the dropdown field (required).
  final double width;

  /// Whether the dropdown is enabled (defaults to true).
  final bool enabled;

  /// Whether to show the mobile keyboard (defaults to false).
  final bool showKeyboard;

  /// Callback for adding new items based on search text (optional).
  final ItemDropperItem<T>? Function(String searchText)? onAddItem;

  /// Callback for deleting items, provides the deleted item (optional).
  final void Function(ItemDropperItem<T> item)? onDeleteItem;
  /// Optional GlobalKey for the input field.
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
  /// SingleItemDropper(
  ///   inputKey: key,
  ///   // ... other parameters
  /// );
  /// // Later, access the input field:
  /// final context = key.currentContext;
  /// ```
  final GlobalKey? inputKey;

  /// Maximum dropdown popup height.
  final double maxDropdownHeight;

  /// Popup shadow elevation.
  final double elevation;

  /// Whether to show a vertical scrollbar in popup.
  final bool showScrollbar;

  /// Popup vertical scrollbar thickness.
  final double scrollbarThickness;

  /// Text style for input/search field.
  /// If null, defaults to fontSize 12 with black color.
  final TextStyle? fieldTextStyle;

  /// Text style for popup dropdown items (used by default popupItemBuilder).
  /// If null, defaults to fontSize 10.
  /// Ignored if custom popupItemBuilder is provided.
  final TextStyle? popupTextStyle;

  /// Text style for group headers in popup (used by default popupItemBuilder).
  /// If null, defaults to fontSize 9, bold, with reduced opacity.
  /// Ignored if custom popupItemBuilder is provided.
  final TextStyle? popupGroupHeaderStyle;

  /// Height for popup dropdown items.
  final double? itemHeight;
  /// Optional custom decoration for the dropdown field container.
  ///
  /// - If provided, this BoxDecoration is used as-is for the field container.
  /// - If null, a default white-to-grey gradient with rounded corners is applied.
  final BoxDecoration? fieldDecoration;
  /// Whether to show the dropdown position icon (arrow up/down).
  /// When true, displays an arrow icon that toggles the dropdown visibility.
  /// Defaults to true.
  final bool showDropdownPositionIcon;
  /// Whether to show the delete all icon (clear/X button).
  /// When true, displays a clear button that clears the current selection.
  /// Defaults to true.
  final bool showDeleteAllIcon;

  const SingleItemDropper({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onChanged,
    this.hintText,
    this.popupItemBuilder,
    required this.width,
    this.enabled = true,
    this.showKeyboard = false,
    this.onAddItem,
    this.onDeleteItem,
    this.inputKey,
    this.maxDropdownHeight = SingleSelectConstants.kDefaultMaxDropdownHeight,
    this.elevation = ItemDropperConstants.kDropdownElevation,
    this.showScrollbar = true,
    this.scrollbarThickness = ItemDropperConstants.kDefaultScrollbarThickness,
    this.fieldTextStyle,
    this.popupTextStyle,
    this.popupGroupHeaderStyle,
    this.itemHeight,
    this.fieldDecoration,
    this.showDropdownPositionIcon = true,
    this.showDeleteAllIcon = true,
  });

  @override
  State<SingleItemDropper<T>> createState() => _SingleItemDropperState<T>();
}

/// Dropdown interaction state
enum DropdownInteractionState {
  /// User is not actively editing the text field
  idle,

  /// User is actively typing/editing to search
  editing,
}

class _SingleItemDropperState<T> extends State<SingleItemDropper<T>> {
  final GlobalKey _internalFieldKey = GlobalKey();
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late final ScrollController _textScrollCtrl;
  late final FocusNode _focusNode;

  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  // Use shared filter utils
  final ItemDropperFilterUtils<T> _filterUtils = ItemDropperFilterUtils<T>();

  // State management
  DropdownInteractionState _interactionState = DropdownInteractionState.idle;
  ItemDropperItem<T>? _selected;
  bool _squelchOnChanged = false;

  // Scroll debouncing
  Timer? _scrollDebounceTimer;

  // Keyboard navigation manager
  late final KeyboardNavigationManager<T> _keyboardNavManager;

  // Decoration cache manager
  final DecorationCacheManager _decorationManager = DecorationCacheManager();

  // Live region for screen reader announcements
  late final LiveRegionManager _liveRegionManager;

  bool get _isUserEditing =>
      _interactionState == DropdownInteractionState.editing;

  set _isUserEditing(bool value) {
    _interactionState = value
        ? DropdownInteractionState.editing
        : DropdownInteractionState.idle;
  }

  String get _selectedLabelText => _selected?.label ?? '';

  List<ItemDropperItem<T>> get _filtered {
    final result = _filterUtils.getFiltered(
      widget.items,
      _controller.text,
      isUserEditing: _isUserEditing,
    );

    // Add "add item" row if no matches, search text exists, and callback is provided
    // Only show add item when user is actively editing
    if (_isUserEditing) {
      return ItemDropperAddItemUtils.addAddItemIfNeeded<T>(
        filteredItems: result,
        searchText: _controller.text,
        originalItems: widget.items,
        hasOnAddItemCallback: () => widget.onAddItem != null,
      );
    }
    return result;
  }

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.selectedItem?.label ?? '');
    _scrollController = ScrollController();
    _textScrollCtrl = ScrollController();
    _focusNode = FocusNode()
      ..addListener(_handleFocusChange);

    _selected = widget.selectedItem;
    _filterUtils.initializeItems(widget.items);

    // Initialize keyboard navigation manager
    _keyboardNavManager = KeyboardNavigationManager<T>(
      onRequestRebuild: () => _safeSetState(() {}),
      onEscape: _dismissDropdown,
      onOpenDropdown: _showOverlay,
    );

    // Initialize live region manager
    _liveRegionManager = LiveRegionManager(
      onUpdate: () => _safeSetState(() {}),
    );

    _controller.addListener(() {
      if (_focusNode.hasFocus) {
        if (!_isUserEditing) _isUserEditing = true;
        // Don't auto-select while user is actively typing - let them continue typing
        // Only handle search for overlay display
        _handleSearch();
      }
    });

    // Attach keyboard event handler for arrow key navigation
    _focusNode.onKeyEvent = (node, event) {
      // Check if Space/Enter should open dropdown (only if text is empty or cursor at start)
      final shouldOpenOnSpaceEnter = !_overlayController.isShowing &&
          (event.logicalKey == LogicalKeyboardKey.space ||
           event.logicalKey == LogicalKeyboardKey.enter) &&
          (_controller.text.isEmpty ||
           _controller.selection.baseOffset == 0);
      
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

    // Minimal hook: when the field loses focus, reset horizontal scroll to start
    _focusNode.addListener(_handleFocusSnapScroll);
  }

  void _handleFocusSnapScroll() {
    if (!_focusNode.hasFocus) {
      // After blur, EditableText may leave the viewport scrolled to the end.
      // Snap it back to the start on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textScrollCtrl.hasClients) {
          try {
            _textScrollCtrl.jumpTo(SingleSelectConstants.kScrollResetPosition);
          } catch (_) {
            // no-op: jumpTo can throw if the position isn't attached yet
          }
        }
      });
    }
  }

  void _setSelected(ItemDropperItem<T>? newVal) {
    if (_selected?.value != newVal?.value) {
      _selected = newVal;
      widget.onChanged(newVal);

      // Announce selection to screen readers
      if (newVal != null) {
        _liveRegionManager.announce(
          ItemDropperSemantics.announceItemSelected(newVal.label),
        );
      }
    }
  }

  void _attemptSelectByInput(String input) {
    final String trimmedInput = input.trim().toLowerCase();

    // Find exact match among enabled items
    ItemDropperItem<T>? match;
    for (final item in widget.items) {
      if (item.isEnabled &&
          item.label.trim().toLowerCase() == trimmedInput) {
        match = item;
        break;
      }
    }

    final String currentSelected = _selected?.label.trim().toLowerCase() ?? '';

    // Case 1: Exact match → select (but only if user is not actively editing)
    // If user is editing, don't auto-select - let them continue typing
    if (match != null && !_isUserEditing) {
      if (_selected?.value != match.value) {
        _setSelected(match);
      }
      return;
    }

    // Case 2: Empty input → clear selection
    if (trimmedInput.isEmpty) {
      _setSelected(null);
      return;
    }

    // Case 3: Partial backspace of selected value (prefix-aware)
    if (_selected != null &&
        currentSelected.isNotEmpty &&
        trimmedInput.length < currentSelected.length &&
        currentSelected.startsWith(trimmedInput)) {
      _controller.clear();
      _setSelected(null);
      return;
    }

    // Case 4: Invalid input while a selection exists → clear selection
    if (_selected != null && trimmedInput.isNotEmpty && !_isUserEditing) {
      _setSelected(null);
      return;
    }

    // Case 5: No match, no selection → clear stray text only if not editing
    if (_selected == null && trimmedInput.isNotEmpty && !_isUserEditing) {
      _controller.clear();
    }
  }

  void _clearInvalid() {
    _attemptSelectByInput(_controller.text.trim());
  }

  void _handleFocusChange() {
    // Invalidate decoration cache when focus changes to update border color
    _decorationManager.invalidate();

    if (_focusNode.hasFocus) {
      if (!_overlayController.isShowing) {
        _showOverlay();
      }
    } else {
      _isUserEditing = false;
      _clearInvalid();
    }
  }

  void _handleSearch() {
    if (!_focusNode.hasFocus) return;

    // Auto-hide if list becomes empty while typing
    if (_filtered.isEmpty) {
      if (_overlayController.isShowing) _removeOverlay();
      _safeSetState(() {});
      return;
    }

    if (!_overlayController.isShowing) {
      _showOverlay();
      return;
    }

    // Reset keyboard highlight when search results change
    _keyboardNavManager.clearHighlights();
    _safeSetState(() {});

    // Debounced scroll animation
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(ItemDropperConstants.kScrollDebounceDelay, () {
      _performScrollToMatch();
    });
  }

  void _performScrollToMatch() {
    if (!mounted) return;

    try {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        final String input = _controller.text.trim().toLowerCase();
        final int itemIndex = _filtered.indexWhere(
                (item) => item.label.toLowerCase().contains(input));
        if (itemIndex >= 0) {
          _scrollController.animateTo(
            itemIndex *
                (widget.itemHeight ?? ItemDropperConstants.kDropdownItemHeight),
            duration: ItemDropperConstants.kScrollAnimationDuration,
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      debugPrint('[SEARCH] Scroll failed: $e');
    }
  }

  void _showOverlay() {
    if (_overlayController.isShowing) return;
    if (_filtered.isEmpty) return;
    _waitThenScrollToSelected();
    _safeSetState(() {
      _keyboardNavManager.clearHighlights();
    });
    _overlayController.show();
  }

  void _dismissDropdown() {
    _focusNode.unfocus();
    _removeOverlay();
    _safeSetState(() {
      _keyboardNavManager.clearHighlights();
    });
  }

  void _removeOverlay() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    _keyboardNavManager.clearHighlights();
  }

  void _selectKeyboardHighlightedItem() {
    final List<ItemDropperItem<T>> filteredItems = _filtered;
    if (_keyboardNavManager.keyboardHighlightIndex >= 0 &&
        _keyboardNavManager.keyboardHighlightIndex < filteredItems.length) {
      final ItemDropperItem<
          T> selectedItem = filteredItems[_keyboardNavManager.keyboardHighlightIndex];
      // Skip group headers
      if (selectedItem.isGroupHeader) {
        return;
      }

      // Handle add item selection using shared handler
      final addItemResult = ItemDropperSelectionHandler.handleAddItemIfNeeded<T>(
        item: selectedItem,
        originalItems: widget.items,
        onAddItem: widget.onAddItem,
        onItemCreated: (newItem) {
          _withSquelch(() {
            _controller.text = newItem.label;
            _controller.selection = const TextSelection.collapsed(offset: 0);
          });
          _setSelected(newItem);
          _isUserEditing = false;
          _dismissDropdown();
        },
      );
      
      if (addItemResult.handled) {
        return;
      }

      _withSquelch(() {
        _controller.text = selectedItem.label;
        _controller.selection = const TextSelection.collapsed(offset: 0);
      });
      _attemptSelectByInput(selectedItem.label);
      _dismissDropdown();
    }
  }

  void _waitThenScrollToSelected() {
    if (_selected == null) return;

    final int selectedIndex = _filtered.indexWhere((it) =>
    it.value == _selected?.value);
    if (selectedIndex < 0) return;

    int retryCount = 0;

    void tryScroll() {
      if (!mounted || retryCount >= ItemDropperConstants.kMaxScrollRetries) {
        return;
      }

      retryCount++;

      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
        return;
      }

      // Center the selected item in the viewport if possible
      final double itemTop = selectedIndex *
          (widget.itemHeight ?? ItemDropperConstants.kDropdownItemHeight);
      final double viewportHeight = _scrollController.position
          .viewportDimension;
      final double centeredOffset = (itemTop -
          (viewportHeight / ItemDropperConstants.kCenteringDivisor) +
          ((widget.itemHeight ?? ItemDropperConstants.kDropdownItemHeight) /
              ItemDropperConstants.kCenteringDivisor))
          .clamp(0.0, _scrollController.position.maxScrollExtent);

      _scrollController.jumpTo(centeredOffset);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tryScroll();
    });
  }

  void _withSquelch(void Function() action) {
    _squelchOnChanged = true;
    try {
      action();
    } finally {
      _squelchOnChanged = false;
    }
  }

  void _handleSubmit(String value) {
    // When Enter is pressed, select keyboard-highlighted item or the single item
    if (_keyboardNavManager.keyboardHighlightIndex >= 0) {
      // Keyboard navigation is active, select highlighted item
      _selectKeyboardHighlightedItem();
    } else {
      // No keyboard navigation, check for single item auto-select
      final filteredList = _filtered;
      // Find first selectable item
      final selectableItems = filteredList
          .where((item) => !item.isGroupHeader)
          .toList();
      if (selectableItems.length == 1) {
        final item = selectableItems.first;

        // Handle add item selection using shared handler
        final addItemResult = ItemDropperSelectionHandler.handleAddItemIfNeeded<T>(
          item: item,
          originalItems: widget.items,
          onAddItem: widget.onAddItem,
          onItemCreated: (newItem) {
            _withSquelch(() {
              _controller.text = newItem.label;
              _controller.selection =
              const TextSelection.collapsed(offset: 0);
            });
            _setSelected(newItem);
            _isUserEditing = false;
            _dismissDropdown();
          },
        );
        
        if (addItemResult.handled) {
          return;
        }

        _withSquelch(() {
          _controller.text = item.label;
          _controller.selection = const TextSelection.collapsed(offset: 0);
        });
        _attemptSelectByInput(item.label);
        _dismissDropdown();
      }
    }
  }

  Widget _buildDropdownOverlay() {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    final List<ItemDropperItem<T>> filteredItems = _filtered;

    // Get the input field's context for proper positioning
    final BuildContext? inputContext = (widget.inputKey ?? _internalFieldKey)
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

    return ItemDropperRenderUtils.buildDropdownOverlay(
      context: inputContext,
      items: filteredItems,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: _overlayController,
      scrollController: _scrollController,
      layerLink: _layerLink,
      showScrollbar: widget.showScrollbar,
      scrollbarThickness: widget.scrollbarThickness,
      isSelected: (ItemDropperItem<T> item) => item.value == _selected?.value,
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
            // Skip group headers
            if (item.isGroupHeader) {
              return;
            }

            // Handle add item selection using shared handler
            final addItemResult = ItemDropperSelectionHandler.handleAddItemIfNeeded<T>(
              item: item,
              originalItems: widget.items,
              onAddItem: widget.onAddItem,
              onItemCreated: (newItem) {
                _withSquelch(() {
                  _controller.text = newItem.label;
                  _controller.selection =
                  const TextSelection.collapsed(offset: 0);
                });
                _setSelected(newItem);
                _isUserEditing = false;
                _dismissDropdown();
              },
            );
            
            if (addItemResult.handled) {
              return;
            }

            _withSquelch(() {
              _controller.text = item.label;
              _controller.selection =
              const TextSelection.collapsed(offset: 0);
            });
            _attemptSelectByInput(item.label);
            _dismissDropdown();
          },
          customBuilder: widget.popupItemBuilder ??
                  (context, item, isSelected) {
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
              },
          itemHeight: effectiveItemHeight,
        );
      },
      itemHeight: effectiveItemHeight,
    );
  }

  // Helper method to safely call setState
  void _safeSetState(void Function() fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    // Cancel and clear timer to prevent memory leaks
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = null;
    
    _liveRegionManager.dispose();
    _removeOverlay();
    
    // Remove listeners before disposing focus node
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.removeListener(_handleFocusSnapScroll);
    _focusNode.dispose();
    
    _controller.dispose();
    _scrollController.dispose();
    _textScrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SingleItemDropper<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If widget became disabled, unfocus and hide overlay
    if (oldWidget.enabled && !widget.enabled) {
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
      if (_overlayController.isShowing) {
        _dismissDropdown();
      }
    }

    final T? newVal = widget.selectedItem?.value;
    final T? oldVal = _selected?.value;

    if (newVal != oldVal) {
      // Keep internal selection in sync
      _selected = widget.selectedItem;

      final String newLabel = widget.selectedItem?.label ?? '';
      final String currentText = _controller.text;

      if (newLabel.isNotEmpty &&
          currentText.trim().toLowerCase() != newLabel.toLowerCase()) {
        _withSquelch(() {
          _controller.text = newLabel;
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
        });

        // Ensure viewport is at start in case update happens while unfocused
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _textScrollCtrl.hasClients) {
            try {
              _textScrollCtrl.jumpTo(SingleSelectConstants.kScrollResetPosition);
            } catch (_) {}
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = _selected != null;

    return Stack(
      children: [
      ItemDropperWithOverlay(
      layerLink: _layerLink,
      overlayController: _overlayController,
      fieldKey: widget.inputKey ?? _internalFieldKey,
      onDismiss: _dismissDropdown,
      overlay: _buildDropdownOverlay(),
      inputField: Container(
          decoration: _decorationManager.get(
            isFocused: _focusNode.hasFocus,
            customDecoration: widget.fieldDecoration,
            borderRadius: SingleSelectConstants.kContainerBorderRadius,
          ),
          child: SizedBox(
            width: widget.width,
            child: IgnorePointer(
              ignoring: !widget.enabled,
              child: Semantics(
                label: ItemDropperSemantics.singleSelectFieldLabel,
                textField: true,
                child: TextField(
                  key: widget.inputKey ?? _internalFieldKey,
                  controller: _controller,
                focusNode: _focusNode,
                scrollController: _textScrollCtrl,
                readOnly: !widget.showKeyboard,
                showCursor: true,
                enableInteractiveSelection: false,
                style: (widget.fieldTextStyle ?? const TextStyle(fontSize: ItemDropperConstants
                    .kDropdownItemFontSize)).copyWith(
                  color: widget.enabled 
                      ? (widget.fieldTextStyle?.color ?? Colors.black)
                      : Colors.grey,
                ),
                onTap: () {
                  if (!widget.enabled) return;
                  final textLength = _controller.text.length;
                  _controller.selection =
                      TextSelection.collapsed(offset: textLength);
                  _showOverlay();
                },
                onSubmitted: _handleSubmit,
                onChanged: (value) {
                if (_squelchOnChanged) return;

                final bool hadSelection = hasSelection;
                final String selectedLabel = _selectedLabelText;

                if (hadSelection) {
                  // User is typing - clear selection and allow them to continue typing
                  // Don't revert the text - let them type freely
                  if (value != selectedLabel) {
                    // User typed something different - clear selection and let them type
                    _setSelected(null);
                    _isUserEditing = true;
                  }
                  return;
                }

                // No selection → normal typing; live search managed by controller listener
              },
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: SingleSelectConstants
                      .kTextFieldVerticalPaddingNoBorder,
                  horizontal: SingleSelectConstants.kTextFieldHorizontalPadding,
                ),
                suffixIconConstraints: (widget.showDropdownPositionIcon || widget.showDeleteAllIcon)
                    ? BoxConstraints.tightFor(
                        width: SingleSelectConstants.kSuffixIconWidth,
                        height: (widget.fieldTextStyle?.fontSize ??
                            ItemDropperConstants.kDropdownItemFontSize) *
                            ItemDropperConstants.kSuffixIconHeightMultiplier,
                      )
                    : null,
                suffixIcon: (widget.showDropdownPositionIcon || widget.showDeleteAllIcon)
                    ? ItemDropperSuffixIcons(
                        isDropdownShowing: _overlayController.isShowing,
                        enabled: widget.enabled,
                        onClearPressed: () {
                          _withSquelch(() => _controller.clear());
                          _attemptSelectByInput('');
                          if (mounted) {
                            setState(() =>
                            _keyboardNavManager.hoverIndex = ItemDropperConstants.kNoHighlight);
                          }
                        },
                        onArrowPressed: () {
                          if (_overlayController.isShowing) {
                            _dismissDropdown();
                          } else {
                            _focusNode.requestFocus();
                          }
                        },
                        iconSize: SingleSelectConstants.kIconSize,
                        suffixIconWidth: SingleSelectConstants.kSuffixIconWidth,
                        iconButtonSize: SingleSelectConstants.kIconButtonSize,
                        clearButtonRightPosition: SingleSelectConstants
                            .kClearButtonRightPosition,
                        arrowButtonRightPosition: SingleSelectConstants
                            .kArrowButtonRightPosition,
                        textSize: widget.fieldTextStyle?.fontSize ??
                            ItemDropperConstants.kDropdownItemFontSize,
                        showDropdownPositionIcon: widget.showDropdownPositionIcon,
                        showDeleteAllIcon: widget.showDeleteAllIcon,
                      )
                    : null,
                hintText: widget.hintText,
              ), // Close InputDecoration
                ), // Close TextField
              ), // Close Semantics
            ), // Close IgnorePointer
          ), // Close SizedBox
      ), // Close Container
      ), // Close ItemDropperWithOverlay
        // Live region for screen reader announcements
        _liveRegionManager.build(),
      ],
    );
  }
}
