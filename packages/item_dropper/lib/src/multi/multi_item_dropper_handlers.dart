part of '../../item_dropper_multi_select.dart';

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
          _measurements.totalChipWidth = null;
          _searchController.clear();

          // If we just reached the max, close the overlay
          if (_selectionManager.isMaxReached()) {
            _overlayManager.hideIfNeeded();
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
      if (_overlayManager.isShowing) {
        _overlayManager.hideIfNeeded();
      }
      return;
    }
    // Allow removing items even when max is reached (toggle behavior)

    _updateSelection(() {
      if (!isCurrentlySelected) {
        _selectionManager.addItem(item);

        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;

        // Announce selection to screen readers
        final loc = _localizations;
        _liveRegionManager.announce(
          '${item.label}${loc.itemSelectedSuffix}',
        );

        // If we just reached the max, close the overlay
        if (_selectionManager.isMaxReached()) {
          _overlayManager.hideIfNeeded();
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
          // Focus is already set above, so overlay will stay open in _handleTextChanged
          _searchController.clear();
          
          // Ensure overlay stays open after text clear
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            
            // Ensure focus is maintained
            _focusNode.requestFocus();
            
            // Ensure overlay stays open (showIfNeeded checks isShowing internally)
            if (_focusManager.isFocused) {
              _overlayManager.showIfNeeded();
            }
          });
        }
      } else {
        // Item is already selected, remove it (toggle off)
        // Capture state before removal to check if we should reopen overlay
        final bool wasAtMax = _selectionManager.isMaxReached();
        _selectionManager.removeItem(item.value);

        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;

        // FIX: Show overlay again if we're below maxSelected after removal
        // This handles the case where user removes an item after reaching max
        if (wasAtMax && _selectionManager.isBelowMax() &&
            _focusManager.isFocused) {
          _overlayManager.showIfFocusedAndBelowMax<T>(
            isFocused: _focusManager.isFocused,
            isBelowMax: _selectionManager.isBelowMax(),
            filteredItems: _filtered,
          );
        }
      }
      // After selection change, clear highlights
      _clearHighlights();
    });
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

        // Reset totalChipWidth when selection count changes - will be remeasured correctly
        _measurements.totalChipWidth = null;

        _clearHighlights();
      },
      postRebuildCallback: () {
        // Restore focus if needed after chip removal
        _focusManager.restoreFocusIfNeeded();

        // Show overlay if we're below maxSelected and focused
        _overlayManager.showIfFocusedAndBelowMax<T>(
          isFocused: _focusManager.isFocused,
          isBelowMax: _selectionManager.isBelowMax(),
          filteredItems: _filtered,
        );
      },
    );
  }

  /// Handle delete requests coming from overlay items (right-click / long-press).
  /// Uses a simple built-in confirmation dialog before invoking onDeleteItem.
  void _handleRequestDeleteFromOverlay(BuildContext context,
      ItemDropperItem<T> item) {
    // Only allow delete for items explicitly marked as deletable.
    if (!item.isDeletable) {
      return;
    }

    // Run async flow without blocking the gesture handler.
    _confirmAndDeleteItem(context, item);
  }

  Future<void> _confirmAndDeleteItem(BuildContext context,
      ItemDropperItem<T> item) async {
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
    _requestRebuildIfNotScheduled();
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
          _measurements.totalChipWidth = null;
        });
      }
    }
  }

  /// Handle arrow button press - toggle dropdown
  void _handleArrowPressed() {
    if (_overlayController.isShowing) {
      _focusManager.loseFocus();
      _overlayManager.hideIfNeeded();
    } else {
      // Show dropdown - if max is reached, overlay will show max reached message
      _focusManager.gainFocus();
      _overlayManager.showIfNeeded();
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
      _overlayManager.showIfNeeded();
    } else if (_filtered.isEmpty && !_selectionManager.isMaxReached()) {
      // Hide overlay if no filtered items and not focused and not at max
      _overlayManager.hideIfNeeded();
    }
  }
}

