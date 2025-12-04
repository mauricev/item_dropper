import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_dropper/src/common/item_dropper_common.dart';
import 'package:item_dropper/src/utils/item_dropper_add_item_utils.dart';

/// Single-select dropdown widget
/// Allows selecting a single item from a searchable list
class SingleItemDropper<T> extends StatefulWidget {
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
  final List<ItemDropperItem<T>> items;
  final ItemDropperItem<T>? selectedItem;
  final ItemDropperItemCallback<T> onChanged;
  final Widget Function(BuildContext, ItemDropperItem<T>, bool)? popupItemBuilder;
  final double width;
  final double maxDropdownHeight;
  final double elevation;
  final bool showKeyboard;
  /// TextStyle for input field text.
  /// If null, defaults to fontSize 12 with black color.
  final TextStyle? fieldTextStyle;
  /// TextStyle for popup dropdown items (used by default popupItemBuilder).
  /// If null, defaults to fontSize 10.
  /// Ignored if custom popupItemBuilder is provided.
  final TextStyle? popupTextStyle;
  /// TextStyle for group headers in popup (used by default popupItemBuilder).
  /// If null, defaults to fontSize 9, bold, with reduced opacity.
  /// Ignored if custom popupItemBuilder is provided.
  final TextStyle? popupGroupHeaderStyle;
  final double? itemHeight;
  final bool enabled;
  final bool allowDelete;
  final void Function(ItemDropperItem<T> item)? onDeleteItem;
  /// Callback invoked when user wants to add a new item.
  /// Receives the search text and should return a new ItemDropperItem to add to the list.
  /// If null, the add row will not appear.
  final ItemDropperItem<T>? Function(String searchText)? onAddItem;

  /// Optional custom decoration for the dropdown field container.
  ///
  /// - If provided, this BoxDecoration is used as-is for the field container.
  /// - If null, a default white-to-grey gradient with rounded corners is applied.
  final BoxDecoration? fieldDecoration;

  const SingleItemDropper({
    super.key,
    this.inputKey, // Optional: provide a GlobalKey for external access to the input field
    required this.items,
    this.selectedItem,
    required this.onChanged,
    this.popupItemBuilder,
    required this.width,
    this.maxDropdownHeight = 200.0,
    this.elevation = 4.0,
    this.showKeyboard = false,
    this.fieldTextStyle,
    this.popupTextStyle,
    this.popupGroupHeaderStyle,
    this.itemHeight,
    this.enabled = true,
    this.allowDelete = false,
    this.onDeleteItem,
    this.onAddItem,
    this.fieldDecoration,
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
  // UI Layout Constants
  static const double _containerBorderRadius = 8.0;
  static const double _textFieldVerticalPadding = 2.0;
  static const double _textFieldHorizontalPadding = 12.0;
  static const double _suffixIconWidth = 60.0;
  static const double _iconSize = 16.0;
  static const double _iconButtonSize = 24.0;
  static const double _clearButtonRightPosition = 40.0;
  static const double _arrowButtonRightPosition = 10.0;
  static const double _scrollResetPosition = 0.0;

  final GlobalKey _internalFieldKey = GlobalKey();
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late final ScrollController _textScrollCtrl;
  late final FocusNode _focusNode;

  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  int _hoverIndex = ItemDropperConstants.kNoHighlight;
  int _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;

  // Use shared filter utils
  final ItemDropperFilterUtils<T> _filterUtils = ItemDropperFilterUtils<T>();

  // State management
  DropdownInteractionState _interactionState = DropdownInteractionState.idle;
  ItemDropperItem<T>? _selected;
  bool _squelchOnChanged = false;

  // Scroll debouncing
  Timer? _scrollDebounceTimer;

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

    _controller.addListener(() {
      if (_focusNode.hasFocus) {
        if (!_isUserEditing) _isUserEditing = true;
        // Don't auto-select while user is actively typing - let them continue typing
        // Only handle search for overlay display
        _handleSearch();
      }
    });

    // Attach keyboard event handler for arrow key navigation
    _focusNode.onKeyEvent = _handleKeyEvent;

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
            _textScrollCtrl.jumpTo(_scrollResetPosition);
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
    _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
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
      _hoverIndex = ItemDropperConstants.kNoHighlight;
      _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
    });
    _overlayController.show();
  }

  void _dismissDropdown() {
    _focusNode.unfocus();
    _removeOverlay();
    _safeSetState(() {
      _hoverIndex = ItemDropperConstants.kNoHighlight;
      _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
    });
  }

  void _removeOverlay() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    _hoverIndex = ItemDropperConstants.kNoHighlight;
    _keyboardHighlightIndex = ItemDropperConstants.kNoHighlight;
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

  void _selectKeyboardHighlightedItem() {
    final List<ItemDropperItem<T>> filteredItems = _filtered;
    if (_keyboardHighlightIndex >= 0 &&
        _keyboardHighlightIndex < filteredItems.length) {
      final ItemDropperItem<T> selectedItem = filteredItems[_keyboardHighlightIndex];
      // Skip group headers
      if (selectedItem.isGroupHeader) {
        return;
      }
      
      // Handle add item selection
      if (ItemDropperAddItemUtils.isAddItem(selectedItem, widget.items)) {
        final String searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(selectedItem);
        if (searchText.isNotEmpty && widget.onAddItem != null) {
          final ItemDropperItem<T>? newItem = widget.onAddItem!(searchText);
          if (newItem != null) {
            _withSquelch(() {
              _controller.text = newItem.label;
              _controller.selection = const TextSelection.collapsed(offset: 0);
            });
            _setSelected(newItem);
            _isUserEditing = false;
            _dismissDropdown();
          }
        }
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
    if (_keyboardHighlightIndex >= 0) {
      // Keyboard navigation is active, select highlighted item
      _selectKeyboardHighlightedItem();
    } else {
      // No keyboard navigation, check for single item auto-select
      final filteredList = _filtered;
      // Find first selectable item
      final selectableItems = filteredList.where((item) => !item.isGroupHeader).toList();
      if (selectableItems.length == 1) {
        final item = selectableItems.first;
        
        // Handle add item selection
        if (ItemDropperAddItemUtils.isAddItem(item, widget.items)) {
          final String searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(item);
          if (searchText.isNotEmpty && widget.onAddItem != null) {
            final ItemDropperItem<T>? newItem = widget.onAddItem!(searchText);
            if (newItem != null) {
              _withSquelch(() {
                _controller.text = newItem.label;
                _controller.selection = const TextSelection.collapsed(offset: 0);
              });
              _setSelected(newItem);
              _isUserEditing = false;
              _dismissDropdown();
            }
          }
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Handle both KeyDownEvent (initial press) and KeyRepeatEvent (auto-repeat when held)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _handleArrowDown();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _handleArrowUp();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildDropdownOverlay() {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();
    
    final List<ItemDropperItem<T>> filteredItems = _filtered;

    // Get the input field's context for proper positioning
    final BuildContext? inputContext = (widget.inputKey ?? _internalFieldKey)
        .currentContext;
    if (inputContext == null) return const SizedBox.shrink();

    return ItemDropperRenderUtils.buildDropdownOverlay(
      context: inputContext,
      items: filteredItems,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: _overlayController,
      scrollController: _scrollController,
      layerLink: _layerLink,
      isSelected: (ItemDropperItem<T> item) => item.value == _selected?.value,
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
            // Skip group headers
            if (item.isGroupHeader) {
              return;
            }
            
            // Handle add item selection
            if (ItemDropperAddItemUtils.isAddItem(item, widget.items)) {
              final String searchText = ItemDropperAddItemUtils.extractSearchTextFromAddItem(item);
              if (searchText.isNotEmpty && widget.onAddItem != null) {
                final ItemDropperItem<T>? newItem = widget.onAddItem!(searchText);
                if (newItem != null) {
                  // Select the new item
                  _withSquelch(() {
                    _controller.text = newItem.label;
                    _controller.selection = const TextSelection.collapsed(offset: 0);
                  });
                  _setSelected(newItem);
                  _isUserEditing = false;
                  _dismissDropdown();
                }
              }
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
              },
          itemHeight: widget.itemHeight,
        );
      },
      itemHeight: widget.itemHeight,
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
    _scrollDebounceTimer?.cancel();
    _removeOverlay();
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
              _textScrollCtrl.jumpTo(_scrollResetPosition);
            } catch (_) {}
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = _selected != null;

    return ItemDropperWithOverlay(
      layerLink: _layerLink,
      overlayController: _overlayController,
      fieldKey: widget.inputKey ?? _internalFieldKey,
      onDismiss: _dismissDropdown,
      overlay: _buildDropdownOverlay(),
      inputField: Container(
          decoration: widget.fieldDecoration ?? BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade200],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(_containerBorderRadius),
          ),
          child: SizedBox(
            width: widget.width,
            child: IgnorePointer(
              ignoring: !widget.enabled,
              child: TextField(
                key: widget.inputKey ?? _internalFieldKey,
                controller: _controller,
                focusNode: _focusNode,
                scrollController: _textScrollCtrl,
                readOnly: !widget.showKeyboard,
                showCursor: true,
                enableInteractiveSelection: false,
                style: (widget.fieldTextStyle ?? const TextStyle(fontSize: 12.0)).copyWith(
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
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: widget.enabled ? Colors.black45 : Colors.grey
                          .shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: widget.enabled ? Colors.blue : Colors.grey
                          .shade400),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: _textFieldVerticalPadding,
                  horizontal: _textFieldHorizontalPadding,
                ),
                suffixIconConstraints: BoxConstraints.tightFor(
                  width: _suffixIconWidth,
                  height: (widget.fieldTextStyle?.fontSize ?? 12.0) *
                      3.2, // Match calculated suffix icon height
                ),
                suffixIcon: ItemDropperSuffixIcons(
                  isDropdownShowing: _overlayController.isShowing,
                  enabled: widget.enabled,
                  onClearPressed: () {
                    _withSquelch(() => _controller.clear());
                    _attemptSelectByInput('');
                    if (mounted) {
                      setState(() =>
                      _hoverIndex = ItemDropperConstants.kNoHighlight);
                    }
                  },
                  onArrowPressed: () {
                    if (_overlayController.isShowing) {
                      _dismissDropdown();
                    } else {
                      _focusNode.requestFocus();
                    }
                  },
                  iconSize: _iconSize,
                  suffixIconWidth: _suffixIconWidth,
                  iconButtonSize: _iconButtonSize,
                  clearButtonRightPosition: _clearButtonRightPosition,
                  arrowButtonRightPosition: _arrowButtonRightPosition,
                  textSize: widget.fieldTextStyle?.fontSize ?? 12.0, // Pass font size
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
