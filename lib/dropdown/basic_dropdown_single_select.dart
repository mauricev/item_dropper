import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'basic_dropdown_common.dart';

class SearchDropdown<T> extends StatefulWidget {
  final GlobalKey? inputKey;
  final List<DropDownItem<T>> items;
  final DropDownItem<T>? selectedItem;
  final DropDownItemCallback<T> onChanged;
  final Widget Function(BuildContext, DropDownItem<T>, bool)? popupItemBuilder;
  final InputDecoration decoration;
  final double width;
  final double maxDropdownHeight;
  final double elevation;
  final bool showKeyboard;
  final double textSize;
  final double? itemHeight;
  final bool enabled;

  const SearchDropdown({
    super.key,
    this.inputKey,
    required this.items,
    this.selectedItem,
    required this.onChanged,
    this.popupItemBuilder,
    required this.decoration,
    required this.width,
    this.maxDropdownHeight = 200.0,
    this.elevation = 4.0,
    this.showKeyboard = false,
    this.textSize = 12.0,
    this.itemHeight,
    this.enabled = true,
  });

  @override
  State<SearchDropdown<T>> createState() => _SearchDropdownState<T>();
}

/// Dropdown interaction state
enum DropdownInteractionState {
  /// User is not actively editing the text field
  idle,

  /// User is actively typing/editing to search
  editing,
}

class _SearchDropdownState<T> extends State<SearchDropdown<T>> {
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

  int _hoverIndex = DropdownConstants.kNoHighlight;
  int _keyboardHighlightIndex = DropdownConstants.kNoHighlight;

  // Use shared filter utils
  final DropdownFilterUtils<T> _filterUtils = DropdownFilterUtils<T>();

  // State management
  DropdownInteractionState _interactionState = DropdownInteractionState.idle;
  DropDownItem<T>? _selected;
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

  List<DropDownItem<T>> get _filtered {
    return _filterUtils.getFiltered(
      widget.items,
      _controller.text,
      isUserEditing: _isUserEditing,
    );
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

  void _setSelected(DropDownItem<T>? newVal) {
    if (_selected?.value != newVal?.value) {
      _selected = newVal;
      widget.onChanged(newVal);
    }
  }

  void _attemptSelectByInput(String input) {
    final String trimmedInput = input.trim().toLowerCase();

    // Find exact match
    DropDownItem<T>? match;
    for (final item in widget.items) {
      if (item.label.trim().toLowerCase() == trimmedInput) {
        match = item;
        break;
      }
    }

    final String currentSelected = _selected?.label.trim().toLowerCase() ?? '';

    // Case 1: Exact match → select
    if (match != null) {
      if (_selected?.value != match.value) {
        _setSelected(match);
      }
      if (_isUserEditing) {
        _isUserEditing = false;
        _safeSetState(() {});
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
    if (_selected != null && trimmedInput.isNotEmpty) {
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
    _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
    _safeSetState(() {});

    // Debounced scroll animation
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(DropdownConstants.kScrollDebounceDelay, () {
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
            itemIndex * DropdownConstants.kDropdownItemHeight,
            duration: DropdownConstants.kScrollAnimationDuration,
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
      _hoverIndex = DropdownConstants.kNoHighlight;
      _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
    });
    _overlayController.show();
  }

  void _dismissDropdown() {
    _focusNode.unfocus();
    _removeOverlay();
    _safeSetState(() {
      _hoverIndex = DropdownConstants.kNoHighlight;
      _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
    });
  }

  void _removeOverlay() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    _hoverIndex = DropdownConstants.kNoHighlight;
    _keyboardHighlightIndex = DropdownConstants.kNoHighlight;
  }

  void _handleArrowDown() {
    _keyboardHighlightIndex = DropdownKeyboardNavigation.handleArrowDown(
      _keyboardHighlightIndex,
      _hoverIndex,
      _filtered.length,
    );
    _safeSetState(() {
      _hoverIndex = DropdownConstants.kNoHighlight;
    });
    DropdownKeyboardNavigation.scrollToHighlight(
      highlightIndex: _keyboardHighlightIndex,
      scrollController: _scrollController,
      mounted: mounted,
    );
  }

  void _handleArrowUp() {
    _keyboardHighlightIndex = DropdownKeyboardNavigation.handleArrowUp(
      _keyboardHighlightIndex,
      _hoverIndex,
      _filtered.length,
    );
    _safeSetState(() {
      _hoverIndex = DropdownConstants.kNoHighlight;
    });
    DropdownKeyboardNavigation.scrollToHighlight(
      highlightIndex: _keyboardHighlightIndex,
      scrollController: _scrollController,
      mounted: mounted,
    );
  }

  void _selectKeyboardHighlightedItem() {
    final List<DropDownItem<T>> filteredItems = _filtered;
    if (_keyboardHighlightIndex >= 0 &&
        _keyboardHighlightIndex < filteredItems.length) {
      final DropDownItem<
          T> selectedItem = filteredItems[_keyboardHighlightIndex];
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
      if (!mounted || retryCount >= DropdownConstants.kMaxScrollRetries) {
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
          DropdownConstants.kDropdownItemHeight;
      final double viewportHeight = _scrollController.position
          .viewportDimension;
      final double centeredOffset = (itemTop -
          (viewportHeight / DropdownConstants.kCenteringDivisor) +
          (DropdownConstants.kDropdownItemHeight /
              DropdownConstants.kCenteringDivisor))
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
      if (filteredList.length == 1) {
        final item = filteredList.first;
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
    final List<DropDownItem<T>> filteredItems = _filtered;

    // Get the input field's context for proper positioning
    final BuildContext? inputContext = (widget.inputKey ?? _internalFieldKey)
        .currentContext;
    if (inputContext == null) return const SizedBox.shrink();

    return DropdownRenderUtils.buildDropdownOverlay(
      context: inputContext,
      items: filteredItems,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: _overlayController,
      scrollController: _scrollController,
      layerLink: _layerLink,
      isSelected: (DropDownItem<T> item) => item.value == _selected?.value,
      builder: (BuildContext builderContext, DropDownItem<T> item,
          bool isSelected) {
        return DropdownRenderUtils.buildDropdownItemWithHover<T>(
          context: builderContext,
          item: item,
          isSelected: isSelected,
          filteredItems: filteredItems,
          hoverIndex: _hoverIndex,
          keyboardHighlightIndex: _keyboardHighlightIndex,
          safeSetState: _safeSetState,
          setHoverIndex: (index) => _hoverIndex = index,
          onTap: () {
            debugPrint("single buildDropdownItem onTap called!");
            _withSquelch(() {
              _controller.text = item.label;
              _controller.selection =
              const TextSelection.collapsed(offset: 0);
            });
            _attemptSelectByInput(item.label);
            _dismissDropdown();
          },
          customBuilder: widget.popupItemBuilder ??
              DropdownRenderUtils.defaultDropdownPopupItemBuilder<T>,
        );
      },
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
  void didUpdateWidget(covariant SearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

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

    return DropdownWithOverlay(
      layerLink: _layerLink,
      overlayController: _overlayController,
      fieldKey: widget.inputKey ?? _internalFieldKey,
      onDismiss: _dismissDropdown,
      overlay: _buildDropdownOverlay(),
      inputField: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade200],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(_containerBorderRadius),
          ),
          child: SizedBox(
            width: widget.width,
            child: TextField(
              key: widget.inputKey ?? _internalFieldKey,
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _textScrollCtrl,
              readOnly: !widget.showKeyboard,
              showCursor: true,
              enableInteractiveSelection: false,
              style: TextStyle(
                fontSize: widget.textSize,
                color: widget.enabled ? Colors.black : Colors.grey,
              ),
              onTap: () {
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
                  // Allow ONLY backspace (prefix shrink) to clear; block all other edits
                  final bool isPrefixShrink = selectedLabel.isNotEmpty &&
                      selectedLabel.startsWith(value) &&
                      value.length < selectedLabel.length;

                  if (isPrefixShrink) {
                    _withSquelch(() {
                      _controller.clear();
                    });
                    _attemptSelectByInput(''); // clears selection
                    if (mounted) setState(() {});
                  } else {
                    // Revert any other typing while selected
                    _withSquelch(() {
                      _controller.text = selectedLabel;
                      _controller.selection =
                          TextSelection.collapsed(offset: selectedLabel.length);
                    });
                  }
                  return;
                }

                // No selection → normal typing; live search managed by controller listener
              },
              decoration: widget.decoration.copyWith(
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
                  height: widget.textSize *
                      3.2, // Match calculated suffix icon height
                ),
                suffixIcon: DropdownSuffixIcons(
                  isDropdownShowing: _overlayController.isShowing,
                  enabled: widget.enabled,
                  onClearPressed: () {
                    _withSquelch(() => _controller.clear());
                    _attemptSelectByInput('');
                    if (mounted) {
                      setState(() =>
                      _hoverIndex = DropdownConstants.kNoHighlight);
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
                  textSize: widget.textSize, // Pass font size
                ),
              ),
            ),
          ),
        ),
    );
  }
}
