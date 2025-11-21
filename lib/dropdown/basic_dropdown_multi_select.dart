import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'basic_dropdown_common.dart';

/// Multi-select dropdown widget
/// Allows selecting multiple items with chip-based display
class MultiSearchDropdown<T> extends StatefulWidget {
  final GlobalKey? inputKey;
  final List<DropDownItem<T>> items;
  final List<DropDownItem<T>> selectedItems;
  final void Function(List<DropDownItem<T>>) onChanged;
  final Widget Function(BuildContext, DropDownItem<
      T>, bool isSelected) popupItemBuilder;
  final InputDecoration decoration;
  final double width;
  final double maxDropdownHeight;
  final double elevation;
  final double textSize;
  final double? itemHeight;
  final bool enabled;

  const MultiSearchDropdown({
    super.key,
    this.inputKey,
    required this.items,
    this.selectedItems = const [],
    required this.onChanged,
    required this.popupItemBuilder,
    required this.decoration,
    required this.width,
    this.maxDropdownHeight = 200.0,
    this.elevation = 4.0,
    this.textSize = 12.0,
    this.itemHeight,
    this.enabled = true,
  });

  @override
  State<MultiSearchDropdown<T>> createState() => _MultiSearchDropdownState<T>();
}

class _MultiSearchDropdownState<T> extends State<MultiSearchDropdown<T>> {
  // UI Layout Constants
  static const double _containerBorderRadius = 8.0;
  static const double _chipHorizontalPadding = 8.0;
  static const double _chipVerticalPadding = 4.0;
  static const double _chipSpacing = 4.0;
  static const double _iconSize = 16.0;
  static const double _chipDeleteIconSize = 14.0;
  static const double _textFieldVerticalPadding = 2.0;
  static const double _textFieldHorizontalPadding = 12.0;
  static const double _suffixIconWidth = 60.0;
  static const double _iconButtonSize = 24.0;
  static const double _clearButtonRightPosition = 40.0;
  static const double _arrowButtonRightPosition = 10.0;

  final GlobalKey _fieldKey = GlobalKey();
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;

  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  List<DropDownItem<T>> _selected = [];
  int _keyboardHighlightIndex = -1;
  int _hoverIndex = -1;
  double? _measuredItemHeight;

  // Filtering
  late List<({String label, DropDownItem<T> item})> _normalizedItems;
  List<DropDownItem<T>>? _cachedFilteredItems;
  String _lastFilterInput = '';

  double get _itemExtent => widget.itemHeight ?? _measuredItemHeight ?? 40.0;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _focusNode = FocusNode()
      ..addListener(_handleFocusChange);

    _selected = List.from(widget.selectedItems);
    _initializeNormalizedItems();

    _focusNode.onKeyEvent = _handleKeyEvent;
  }

  void _initializeNormalizedItems() {
    _normalizedItems = widget.items
        .map((item) => (label: item.label.trim().toLowerCase(), item: item))
        .toList(growable: false);
  }

  List<DropDownItem<T>> get _filtered {
    final String input = _searchController.text.trim().toLowerCase();

    if (input.isEmpty) {
      return widget.items;
    }

    if (_lastFilterInput == input && _cachedFilteredItems != null) {
      return _cachedFilteredItems!;
    }

    final result = _normalizedItems
        .where((entry) => entry.label.contains(input))
        .map((entry) => entry.item)
        .toList(growable: false);

    _lastFilterInput = input;
    _cachedFilteredItems = result;
    return result;
  }

  bool _isSelected(DropDownItem<T> item) {
    return _selected.any((selected) => selected.value == item.value);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      if (!_overlayController.isShowing && _filtered.isNotEmpty) {
        _overlayController.show();
      }
    } else {
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
    }
    setState(() {});
  }

  void _toggleItem(DropDownItem<T> item) {
    setState(() {
      if (_isSelected(item)) {
        _selected.removeWhere((selected) => selected.value == item.value);
      } else {
        _selected.add(item);
      }
    });
    widget.onChanged(List.from(_selected));
  }

  void _removeChip(DropDownItem<T> item) {
    setState(() {
      _selected.removeWhere((selected) => selected.value == item.value);
    });
    widget.onChanged(List.from(_selected));
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
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _handleEnter();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handleArrowDown() {
    final list = _filtered;
    if (list.isEmpty) return;

    setState(() {
      if (_keyboardHighlightIndex < list.length - 1) {
        _keyboardHighlightIndex++;
      } else {
        _keyboardHighlightIndex = 0;
      }
    });
    _scrollToKeyboardHighlight();
  }

  void _handleArrowUp() {
    final list = _filtered;
    if (list.isEmpty) return;

    setState(() {
      if (_keyboardHighlightIndex > 0) {
        _keyboardHighlightIndex--;
      } else {
        _keyboardHighlightIndex = list.length - 1;
      }
    });
    _scrollToKeyboardHighlight();
  }

  void _handleEnter() {
    final list = _filtered;
    if (_keyboardHighlightIndex >= 0 && _keyboardHighlightIndex < list.length) {
      _toggleItem(list[_keyboardHighlightIndex]);
    }
  }

  void _scrollToKeyboardHighlight() {
    if (_keyboardHighlightIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        if (_scrollController.hasClients &&
            _scrollController.position.hasContentDimensions) {
          final double target = (_keyboardHighlightIndex * _itemExtent)
              .clamp(0.0, _scrollController.position.maxScrollExtent);
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      } catch (e) {
        debugPrint('[KEYBOARD NAV] Scroll failed: $e');
      }
    });
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) => _buildOverlay(),
        child: _buildInputField(),
      ),
    );
  }

  Widget _buildInputField() {
    return SizedBox(
        width: widget.width,
        child: Container(
          key: widget.inputKey ?? _fieldKey,
          decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(_containerBorderRadius),
      ),
      child: Stack(
        children: [
          TextField(
            controller: _searchController,
              focusNode: _focusNode,
              style: TextStyle(fontSize: widget.textSize),
              onChanged: (value) {
                setState(() {
                  _cachedFilteredItems = null;
                  _keyboardHighlightIndex = -1;
                });

                if (_filtered.isNotEmpty &&
                    !_overlayController.isShowing) {
                  _overlayController.show();
                } else if (_filtered.isEmpty &&
                    _overlayController.isShowing) {
                  _overlayController.hide();
                }
              },
              decoration: InputDecoration(
                hintText: widget.decoration.hintText ?? 'Search...',
                hintStyle: widget.decoration.hintStyle,
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
                // Show chips as a prefix instead
                prefix: _selected.isEmpty ? null : Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Wrap(
                    spacing: _chipSpacing,
                    runSpacing: _chipSpacing,
                    children: _selected
                        .map((item) => _buildChip(item))
                        .toList(),
                  ),
                ),
                suffixIconConstraints: const BoxConstraints.tightFor(
                  width: _suffixIconWidth,
                  height: kMinInteractiveDimension,
                ),
                suffixIcon: SizedBox(
                  width: _suffixIconWidth,
                  height: kMinInteractiveDimension,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: _clearButtonRightPosition,
                        child: IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: _iconSize,
                            color: widget.enabled ? Colors.black : Colors.grey,
                          ),
                          iconSize: _iconSize,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: _iconButtonSize,
                            height: _iconButtonSize,
                          ),
                          onPressed: widget.enabled
                              ? () {
                            setState(() {
                              _searchController.clear();
                              _selected.clear();
                              _cachedFilteredItems = null;
                              _lastFilterInput = '';
                              widget.onChanged([]);
                            });
                          }
                              : null,
                        ),
                      ),
                      Positioned(
                        right: _arrowButtonRightPosition,
                        child: IconButton(
                          icon: Icon(
                            _overlayController.isShowing
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            size: _iconSize,
                            color: widget.enabled ? Colors.black : Colors.grey,
                          ),
                          iconSize: _iconSize,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: _iconButtonSize,
                            height: _iconButtonSize,
                          ),
                          onPressed: widget.enabled
                              ? () {
                            if (_overlayController.isShowing) {
                              _focusNode.unfocus();
                            } else {
                              _focusNode.requestFocus();
                            }
                          }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildChip(DropDownItem<T> item) {
    return Chip(
      label: Text(
        item.label,
        style: TextStyle(fontSize: widget.textSize),
      ),
      deleteIcon: Icon(
        Icons.close,
        size: _chipDeleteIconSize,
      ),
      onDeleted: widget.enabled ? () => _removeChip(item) : null,
      padding: const EdgeInsets.symmetric(
        horizontal: _chipHorizontalPadding,
        vertical: _chipVerticalPadding,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.blue.shade100,
    );
  }



  Widget _buildOverlay() {
    final list = _filtered;
    if (list.isEmpty) return const SizedBox.shrink();

    final RenderBox? inputBox = (widget.inputKey ?? _fieldKey).currentContext
        ?.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomInset = mediaQuery.viewInsets.bottom;
    final offset = inputBox.localToGlobal(Offset.zero);
    final size = inputBox.size;

    const dropdownMargin = 4.0;
    final availableBelow = screenHeight - bottomInset -
        (offset.dy + size.height + dropdownMargin);
    final availableAbove = offset.dy - dropdownMargin;
    final showBelow = availableBelow > widget.maxDropdownHeight / 2;
    final maxHeight = (showBelow ? availableBelow : availableAbove).clamp(
        0.0, widget.maxDropdownHeight);

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      offset: showBelow
          ? Offset(0.0, size.height + dropdownMargin)
          : Offset(0.0, -maxHeight - dropdownMargin),
      child: Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: widget.elevation,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              minWidth: size.width,
              maxWidth: size.width,
            ),
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: list.length,
              itemBuilder: (context, index) => _buildDropdownItem(list, index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownItem(List<DropDownItem<T>> list, int index) {
    final item = list[index];
    final isSelected = _isSelected(item);
    final isHovered = index == _hoverIndex;
    final isKeyboardHighlighted = index == _keyboardHighlightIndex;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverIndex = index),
      onExit: (_) => setState(() => _hoverIndex = -1),
      child: InkWell(
        onTap: () => _toggleItem(item),
        child: Container(
          color: (isHovered || isKeyboardHighlighted)
              ? Theme
              .of(context)
              .hoverColor
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: widget.enabled ? (value) => _toggleItem(item) : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                      fontSize: widget.textSize, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
