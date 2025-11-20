import 'package:flutter/material.dart';

/// Widget that measures its child's size and reports it via [onChange].
class MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;
  const MeasureSize({super.key, required this.child, required this.onChange});

  @override
  MeasureSizeState createState() => MeasureSizeState();
}

class MeasureSizeState extends State<MeasureSize> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ro = context.findRenderObject();
      if (ro is RenderBox) {
        widget.onChange(ro.size);
      }
    });
    return widget.child;
  }
}

typedef DropDownItemCallback<T> = void Function(DropDownItem<T>? selected);

class DropDownItem<T> {
  final T value;
  final String label;
  const DropDownItem({required this.value, required this.label});
}

abstract class SearchDropdownBase<T> extends StatefulWidget {
  final GlobalKey? inputKey;
  final List<DropDownItem<T>> items;
  final DropDownItem<T>? selectedItem;
  final DropDownItemCallback<T> onChanged;
  final Widget Function(BuildContext, DropDownItem<T>, bool isSelected) popupItemBuilder;
  final InputDecoration decoration;
  final double width;
  final double maxDropdownHeight;
  final double elevation;
  final bool showKeyboard;
  final double textSize;
  final double? itemHeight;
  final bool enabled;

  const SearchDropdownBase({
    super.key,
    this.inputKey,
    required this.items,
    this.selectedItem,
    required this.onChanged,
    required this.popupItemBuilder,
    required this.decoration,
    required this.width,
    this.maxDropdownHeight = 200.0,
    this.elevation = 4.0,
    this.showKeyboard = false,
    this.textSize = 12.0,
    this.itemHeight,
    this.enabled = true,
  });
}

abstract class SearchDropdownBaseState<T, W extends SearchDropdownBase<T>> extends State<W> {
  final GlobalKey internalFieldKey = GlobalKey();
  late final TextEditingController controller;
  late final ScrollController scrollController;
  late final FocusNode focusNode;
  double? measuredItemHeight;
  int hoverIndex = -1;
  final LayerLink layerLink = LayerLink();
  final OverlayPortalController overlayPortalController = OverlayPortalController();

  double get fallbackItemExtent => widget.textSize * 1.2 + 16.0;
  double get itemExtent => widget.itemHeight ?? measuredItemHeight ?? fallbackItemExtent;

  bool isUserEditing = false;

  // ---- Internal selection state (source of truth) ----
  DropDownItem<T>? _selected;
  bool _squelchOnChanged = false; // gate TextField.onChanged for programmatic sets

  // Expose controlled access for subclasses in other files.
  DropDownItem<T>? get internalSelected => _selected;
  void setInternalSelection(DropDownItem<T>? item) => _selected = item;
  void withSquelch(void Function() action) {
    _squelchOnChanged = true;
    try {
      action();
    } finally {
      _squelchOnChanged = false;
    }
  }
  bool get squelching => _squelchOnChanged;
  String get selectedLabelText => _selected?.label ?? '';

  late List<({String label, DropDownItem<T> item})> _normalizedItems;
  List<DropDownItem<T>>? _lastItemsRef;

  List<DropDownItem<T>> get filtered {
    final String input = controller.text.trim().toLowerCase();

    if (!identical(_lastItemsRef, widget.items)) {
      _initializeNormalizedItems();
    }
    if (!isUserEditing || input.isEmpty) {
      return widget.items;
    }
    return _normalizedItems
        .where((entry) => entry.label.contains(input))
        .map((entry) => entry.item)
        .toList(growable: false);
  }

  void _initializeNormalizedItems() {
    _lastItemsRef = widget.items;
    _normalizedItems = widget.items
        .map((item) => (label: item.label.trim().toLowerCase(), item: item))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();

    controller = TextEditingController(text: widget.selectedItem?.label ?? '');
    scrollController = ScrollController();
    focusNode = FocusNode()..addListener(handleFocus);

    // Initialize internal selection SoT
    _selected = widget.selectedItem;

    _initializeNormalizedItems();

    controller.addListener(() {
      if (focusNode.hasFocus) {
        if (!isUserEditing) isUserEditing = true;
        handleSearch();
      }
    });
  }

  void _setSelected(DropDownItem<T>? newVal) {
    if (_selected?.value != newVal?.value) {
      _selected = newVal;
      widget.onChanged(newVal);
    }
  }

  void attemptSelectByInput(String input) {
    final String trimmedInput = input.trim().toLowerCase();

    // Find exact match (replaces firstWhereOrNull from collection package)
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
      if (isUserEditing) {
        isUserEditing = false;
        if (mounted) setState(() {});
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
      controller.clear();
      _setSelected(null);
      return;
    }

    // Case 4: Invalid input while a selection exists → clear selection
    if (_selected != null && trimmedInput.isNotEmpty) {
      _setSelected(null);
      return;
    }

    // Case 5: No match, no selection → optionally clear stray text only if not editing
    if (_selected == null && trimmedInput.isNotEmpty && !isUserEditing) {
      controller.clear();
    }
  }

  void clearInvalid() {
    attemptSelectByInput(controller.text.trim());
  }

  void handleFocus() {
    if (focusNode.hasFocus) {
      // Isolation toggle: do NOT push caret to the end on focus.
      // This avoids forcing EditableText's horizontal scroll to the end.
      // Future.microtask(() {
      //   controller.selection = TextSelection.fromPosition(
      //     TextPosition(offset: controller.text.length),
      //   );
      // });

      if (!overlayPortalController.isShowing) {
        showOverlay();
      }
    } else {
      isUserEditing = false;
      clearInvalid();
    }
  }

  void handleSearch() {
    if (!focusNode.hasFocus) return;

    // Auto-hide if list becomes empty while typing
    if (filtered.isEmpty) {
      if (overlayPortalController.isShowing) removeOverlay();
      if (mounted) setState(() {});
      return;
    }

    if (!overlayPortalController.isShowing) {
      showOverlay();
      return;
    }

    if (mounted) setState(() {});
    try {
      if (scrollController.hasClients && scrollController.position.hasContentDimensions) {
        final String input = controller.text.trim().toLowerCase();
        final int idx = filtered.indexWhere((item) => item.label.toLowerCase().contains(input));
        if (idx >= 0) {
          scrollController.animateTo(
            idx * itemExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      debugPrint('[SEARCH] Scroll failed: $e');
    }
  }

  void showOverlay() {
    if (overlayPortalController.isShowing) return;
    if (filtered.isEmpty) return;
    waitThenScrollToSelected();
    overlayPortalController.show();
  }

  void dismissDropdown() {
    focusNode.unfocus();
    removeOverlay();
  }

  void removeOverlay() {
    if (overlayPortalController.isShowing) {
      overlayPortalController.hide();
    }
    hoverIndex = -1;
  }

  void waitThenScrollToSelected() {
    final int si = filtered.indexWhere((it) => it.value == _selected?.value);
    if (si < 0) return;

    void tryScroll() {
      if (!mounted) return;

      if (widget.itemHeight == null && measuredItemHeight == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
        return;
      }
      if (!scrollController.hasClients || !scrollController.position.hasContentDimensions) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
        return;
      }
      final double target = (si * itemExtent)
          .clamp(0.0, scrollController.position.maxScrollExtent);
      scrollController.jumpTo(target);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tryScroll();
    });
  }

  Widget buildDropdownOverlay() {
    final List<DropDownItem<T>> list = filtered;
    if (list.isEmpty) return const SizedBox.shrink();

    final RenderBox? inputBox = (widget.inputKey ?? internalFieldKey).currentContext?.findRenderObject() as RenderBox?;
    final MediaQueryData mq = MediaQuery.of(context);
    final double sh = mq.size.height;
    final double bi = mq.viewInsets.bottom;
    const double m = 4.0;
    final Offset offset = inputBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final Size size = inputBox?.size ?? Size(widget.width, 40.0);
    final double availBelow = sh - bi - (offset.dy + size.height + m);
    final double availAbove = offset.dy - m;
    final bool below = availBelow > widget.maxDropdownHeight / 2;
    final double mh = (below ? availBelow : availAbove).clamp(0.0, widget.maxDropdownHeight);

    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      offset: below ? Offset(0.0, size.height + m) : Offset(0.0, -mh - m),
      child: FocusScope(
        canRequestFocus: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {},
          child: Material(
            elevation: widget.elevation,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: mh,
                minWidth: size.width,
                maxWidth: size.width,
              ),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: widget.textSize),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: measuredItemHeight == null
                      ? ListView.builder(
                    controller: scrollController,
                    prototypeItem: widget.popupItemBuilder(
                      context,
                      list.first,
                      list.first.value == _selected?.value,
                    ),
                    padding: EdgeInsets.zero,
                    itemCount: list.length,
                    itemBuilder: (BuildContext c, int i) => buildItem(list, i),
                  )
                      : ListView.builder(
                    controller: scrollController,
                    itemExtent: itemExtent,
                    padding: EdgeInsets.zero,
                    itemCount: list.length,
                    itemBuilder: (BuildContext c, int i) => buildItem(list, i),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildItem(List<DropDownItem<T>> list, int idx) {
    final DropDownItem<T> item = list[idx];
    final bool hover = idx == hoverIndex;
    final bool sel = item.value == _selected?.value;

    Widget w = widget.popupItemBuilder(context, item, sel);
    if (idx == 0 && measuredItemHeight == null) {
      w = MeasureSize(
        child: w,
        onChange: (Size s) {
          if (mounted) {
            setState(() => measuredItemHeight = s.height);
          }
        },
      );
    }

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => hoverIndex = idx);
      },
      onExit: (_) {
        if (mounted) setState(() => hoverIndex = -1);
      },
      child: InkWell(
        hoverColor: Theme.of(context).hoverColor,
        onTap: () {
          withSquelch(() {
            controller.text = item.label;
            controller.selection = const TextSelection.collapsed(offset: 0);
          });
          attemptSelectByInput(item.label);
          dismissDropdown();
        },
        child: Container(
          color: (hover || sel) ? Theme.of(context).hoverColor : null,
          child: w,
        ),
      ),
    );
  }

  @override
  void dispose() {
    removeOverlay();
    focusNode.removeListener(handleFocus);
    focusNode.dispose();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
