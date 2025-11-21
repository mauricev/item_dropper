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
      T>, bool isSelected)? popupItemBuilder;
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
    this.popupItemBuilder,
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
    // Filter out already selected items
    final Set removed = _selected.map((item) => item.value).toSet();
    if (input.isEmpty) {
      return widget.items
          .where((item) => !removed.contains(item.value))
          .toList();
    }
    if (_lastFilterInput == input && _cachedFilteredItems != null) {
      return _cachedFilteredItems!;
    }
    final result = _normalizedItems
        .where((entry) =>
    entry.label.contains(input) &&
        !removed.contains(entry.item.value))
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
        setState(() {
          _hoverIndex = -1;
          _keyboardHighlightIndex = -1;
        });
        _overlayController.show();
      }
    } else {
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
    }
    setState(() {});
  }

  void _updateSelection(void Function() selectionUpdate) {
    setState(() {
      selectionUpdate();
      final filtered = _filtered;
      if (filtered.isNotEmpty) {
        _keyboardHighlightIndex = 0;
        _hoverIndex = -1;
      } else {
        _keyboardHighlightIndex = -1;
        _hoverIndex = -1;
        _overlayController.hide();
      }
    });
    widget.onChanged(List.from(_selected));
    _focusNode.requestFocus();
  }

  void _toggleItem(DropDownItem<T> item) {
    _updateSelection(() {
      if (!_isSelected(item)) {
        _selected.add(item);
      }
      // After selection, clear highlights
      _keyboardHighlightIndex = -1;
      _hoverIndex = -1;
    });
  }

  void _removeChip(DropDownItem<T> item) {
    _updateSelection(() {
      _selected.removeWhere((selected) => selected.value == item.value);
      // After removal, clear highlights
      _keyboardHighlightIndex = -1;
      _hoverIndex = -1;
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
    // If no keyboard highlight but hover index exists, start from there
    if (_keyboardHighlightIndex == -1 && _hoverIndex != -1) {
      _keyboardHighlightIndex = _hoverIndex;
    }
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
    // If no keyboard highlight but hover index exists, start from there
    if (_keyboardHighlightIndex == -1 && _hoverIndex != -1) {
      _keyboardHighlightIndex = _hoverIndex;
    }
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
      // highlight will be set in _toggleItem
    }
  }

  void _scrollToKeyboardHighlight() {
    if (_keyboardHighlightIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        if (_scrollController.hasClients &&
            _scrollController.position.hasContentDimensions) {
          final double itemTop = _keyboardHighlightIndex * _itemExtent;
          final double itemBottom = itemTop + _itemExtent;
          final double viewportStart = _scrollController.offset;
          final double viewportEnd = viewportStart +
              _scrollController.position.viewportDimension;
          if (itemTop < viewportStart) {
            _scrollController.animateTo(
              itemTop,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          } else if (itemBottom > viewportEnd) {
            _scrollController.animateTo(
              itemBottom - _scrollController.position.viewportDimension,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          }
        }
      } catch (e) {
        debugPrint('[MULTI][KEYBOARD NAV] Scroll failed: $e');
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
  void didUpdateWidget(covariant MultiSearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync _selected if the parent (user) updates selectedItems externally
    if (widget.selectedItems != oldWidget.selectedItems) {
      setState(() {
        _selected = List.from(widget.selectedItems);
      });
    }
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
                    _hoverIndex = -1;
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
                              color: widget.enabled ? Colors.black : Colors
                                  .grey,
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
                              color: widget.enabled ? Colors.black : Colors
                                  .grey,
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
    final builderToUse = widget.popupItemBuilder ??
        SearchDropdownBaseState.defaultDropdownPopupItemBuilder;
    return SearchDropdownBaseState.sharedDropdownOverlay(
      context: context,
      items: list,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: _overlayController,
      scrollController: _scrollController,
      layerLink: _layerLink,
      hoverIndex: _hoverIndex,
      keyboardHighlightIndex: _keyboardHighlightIndex,
      onHover: (idx) => setState(() => _hoverIndex = idx),
      onItemTap: _toggleItem,
      isSelected: (item) => _selected.any((x) => x.value == item.value),
      builder: (context, item, isSelected) {
        final idx = list.indexWhere((x) => x.value == item.value);
        return MouseRegion(
          onEnter: (_) {
            if (_keyboardHighlightIndex != -1) {
              setState(() {
                _keyboardHighlightIndex = -1;
                _hoverIndex = idx;
              });
            } else {
              setState(() => _hoverIndex = idx);
            }
          },
          onExit: (_) => setState(() => _hoverIndex = -1),
          child: SearchDropdownBaseState.sharedDropdownItem(
            context: context,
            item: item,
            isHovered: idx == _hoverIndex && _keyboardHighlightIndex == -1,
            isKeyboardHighlighted: idx == _keyboardHighlightIndex,
            isSelected: isSelected,
            isSingleItem: list.length == 1,
            onTap: () => _toggleItem(item),
            builder: builderToUse,
          ),
        );
      },
    );
  }
}
