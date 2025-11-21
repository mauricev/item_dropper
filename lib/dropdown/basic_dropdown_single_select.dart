import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'basic_dropdown_common.dart';

class SearchDropdown<T> extends SearchDropdownBase<T> {
  const SearchDropdown({
    super.key,
    super.inputKey,
    required super.items,
    super.selectedItem,
    required super.onChanged,
    super.popupItemBuilder,
    required super.decoration,
    required super.width,
    super.maxDropdownHeight,
    super.elevation,
    super.showKeyboard,
    super.textSize,
    super.itemHeight,
    super.enabled,
  });

  @override
  State<SearchDropdown<T>> createState() => _SearchDropdownState<T>();
}

class _SearchDropdownState<T> extends SearchDropdownBaseState<T, SearchDropdown<T>> {
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

  // Dedicated scroll controller for the TextField to control horizontal viewport
  late final ScrollController _textScrollCtrl;

  @override
  void initState() {
    super.initState();
    _textScrollCtrl = ScrollController();

    // Minimal hook: when the field loses focus, reset horizontal scroll to start
    focusNode.addListener(_handleFocusSnapScroll);

    // Attach keyboard event handler for arrow key navigation
    focusNode.onKeyEvent = _handleKeyEvent;
  }

  void _handleFocusSnapScroll() {
    if (!focusNode.hasFocus) {
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

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusSnapScroll);
    _textScrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final T? newVal = widget.selectedItem?.value;
    final T? oldVal = internalSelected?.value;

    if (newVal != oldVal) {
      // Keep internal selection in sync (no behavior change)
      setInternalSelection(widget.selectedItem);

      final String newLabel = widget.selectedItem?.label ?? '';
      final String currentText = controller.text;

      if (newLabel.isNotEmpty &&
          currentText.trim().toLowerCase() != newLabel.toLowerCase()) {
        // Preserve your existing behavior here; we are not changing caret semantics.
        withSquelch(() {
          controller.text = newLabel;
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
        });

        // Optional (safe): also ensure viewport is at start in case update happens while unfocused
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

  void _handleSubmit(String value) {
    // When Enter is pressed, select keyboard-highlighted item or the single item
    if (keyboardHighlightIndex >= 0) {
      // Keyboard navigation is active, select highlighted item
      selectKeyboardHighlightedItem();
    } else {
      // No keyboard navigation, check for single item auto-select
      final filteredList = filtered;
      if (filteredList.length == 1) {
        final item = filteredList.first;
        withSquelch(() {
          controller.text = item.label;
          controller.selection = const TextSelection.collapsed(offset: 0);
        });
        attemptSelectByInput(item.label);
        dismissDropdown();
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Handle both KeyDownEvent (initial press) and KeyRepeatEvent (auto-repeat when held)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      handleArrowDown();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      handleArrowUp();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = internalSelected != null;

    return CompositedTransformTarget(
      link: layerLink,
      child: OverlayPortal(
        controller: overlayPortalController,
        overlayChildBuilder: (context) => Stack(
          children: [
            // Dismiss dropdown when clicking outside the text field
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  final renderBox = (widget.inputKey ?? internalFieldKey).currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final offset = renderBox.localToGlobal(Offset.zero);
                    final size = renderBox.size;
                    final fieldRect = offset & size;
                    if (!fieldRect.contains(event.position)) {
                      dismissDropdown();
                    }
                  }
                },
              ),
            ),
            buildDropdownOverlay(),
          ],
        ),
        child: Container(
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
              key: widget.inputKey ?? internalFieldKey,
              controller: controller,
              focusNode: focusNode,
              // NEW: attach our controller so we can reset horizontal scroll
              scrollController: _textScrollCtrl,
              // BUGFixed, 10.16.25 was not passing keyboard state
              readOnly: !widget.showKeyboard,
              showCursor: true,
              enableInteractiveSelection: false,
              style: TextStyle(
                fontSize: widget.textSize,
                color: widget.enabled ? Colors.black : Colors.grey,
              ),
              onTap: () {
                final textLength = controller.text.length;
                controller.selection = TextSelection.collapsed(offset: textLength);
                showOverlay();
              },
              onSubmitted: _handleSubmit,
              onChanged: (value) {
                if (squelching) return;

                final bool hadSelection = hasSelection;
                final String selectedLabel = selectedLabelText;

                if (hadSelection) {
                  // Allow ONLY backspace (prefix shrink) to clear; block all other edits
                  final bool isPrefixShrink =
                      selectedLabel.isNotEmpty &&
                          selectedLabel.startsWith(value) &&
                          value.length < selectedLabel.length;

                  if (isPrefixShrink) {
                    withSquelch(() {
                      controller.clear();
                    });
                    attemptSelectByInput(''); // clears selection
                    if (mounted) setState(() {});
                  } else {
                    // Revert any other typing while selected
                    withSquelch(() {
                      controller.text = selectedLabel;
                      controller.selection = TextSelection.collapsed(offset: selectedLabel.length);
                    });
                  }
                  return;
                }

                // No selection → normal typing; live search managed by controller listener
              },
              decoration: widget.decoration.copyWith(
                filled: false,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.enabled ? Colors.black45 : Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.enabled ? Colors.blue : Colors.grey.shade400),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: _textFieldVerticalPadding,
                  horizontal: _textFieldHorizontalPadding,
                ),
                suffixIconConstraints: const BoxConstraints.tightFor(
                  width: _suffixIconWidth,
                  height: kMinInteractiveDimension,
                ),
                suffixIcon: DropdownSuffixIcons(
                  isDropdownShowing: overlayPortalController.isShowing,
                  enabled: widget.enabled,
                  onClearPressed: () {
                    withSquelch(() => controller.clear());
                    attemptSelectByInput('');
                    if (mounted) {
                      setState(() =>
                      hoverIndex = SearchDropdownBaseState.kNoHighlight);
                    }
                  },
                  onArrowPressed: () {
                    if (overlayPortalController.isShowing) {
                      dismissDropdown();
                    } else {
                      focusNode.requestFocus();
                    }
                  },
                  iconSize: _iconSize,
                  suffixIconWidth: _suffixIconWidth,
                  iconButtonSize: _iconButtonSize,
                  clearButtonRightPosition: _clearButtonRightPosition,
                  arrowButtonRightPosition: _arrowButtonRightPosition,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
