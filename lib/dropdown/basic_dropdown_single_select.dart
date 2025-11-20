import 'package:flutter/material.dart';
import 'basic_dropdown_common.dart';

class SearchDropdown<T> extends SearchDropdownBase<T> {
  const SearchDropdown({
    super.key,
    super.inputKey,
    required super.items,
    super.selectedItem,
    required super.onChanged,
    required super.popupItemBuilder,
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
  // NEW: dedicated scroll controller for the TextField to control horizontal viewport
  late final ScrollController _textScrollCtrl;

  @override
  void initState() {
    super.initState();
    _textScrollCtrl = ScrollController();

    // Minimal hook: when the field loses focus, reset horizontal scroll to start
    focusNode.addListener(_handleFocusSnapScroll);
  }

  void _handleFocusSnapScroll() {
    if (!focusNode.hasFocus) {
      // After blur, EditableText may leave the viewport scrolled to the end.
      // Snap it back to the start on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textScrollCtrl.hasClients) {
          try {
            _textScrollCtrl.jumpTo(0.0);
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
              _textScrollCtrl.jumpTo(0.0);
            } catch (_) {}
          }
        });
      }
    }
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
            borderRadius: BorderRadius.circular(8.0),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 12.0),
                suffixIconConstraints: const BoxConstraints.tightFor(
                  width: 60.0,                      // <-- MATCH this to suffixIcon width
                  height: kMinInteractiveDimension, // keep touch target
                ),
                suffixIcon: SizedBox(
                  width: 60.0, // was 80.0 -> give us 10px of play
                  height: kMinInteractiveDimension,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    clipBehavior: Clip.none, // allow slight right overflow
                    children: [
                      Positioned(
                        right: 20.0, // was 30.0 -> move clear 10px right
                        child: IconButton(
                          icon: Icon(Icons.clear, size: 16.0, color: widget.enabled ? Colors.black : Colors.grey),
                          iconSize: 16.0,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 24.0, height: 24.0),
                          onPressed: widget.enabled
                              ? () {
                            withSquelch(() => controller.clear());
                            attemptSelectByInput('');
                            if (mounted) setState(() => hoverIndex = -1);
                          }
                              : null,
                        ),
                      ),
                      Positioned(
                        right: -10.0, // was 0.0 -> nudge arrow 10px right
                        child: IconButton(
                          icon: Icon(
                            overlayPortalController.isShowing ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            size: 16.0,
                            color: widget.enabled ? Colors.black : Colors.grey,
                          ),
                          iconSize: 16.0,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 24.0, height: 24.0),
                          onPressed: widget.enabled
                              ? () {
                            if (overlayPortalController.isShowing) {
                              dismissDropdown();
                            } else {
                              focusNode.requestFocus();
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
          ),
        ),
      ),
    );
  }
}
