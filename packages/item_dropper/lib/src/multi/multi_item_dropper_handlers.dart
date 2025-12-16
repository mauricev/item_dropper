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
          _searchController.clear();

          // If we just reached the max, close the overlay
          if (_selectionManager.isMaxReached()) {
            if (_overlayController.isShowing) {
              _overlayController.hide();
            }
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
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
      return;
    }
    // Allow removing items even when max is reached (toggle behavior)

    _updateSelection(() {
      if (!isCurrentlySelected) {
        _selectionManager.addItem(item);

        // Announce selection to screen readers
        final loc = _localizations;
        _liveRegionManager.announce(
          '${item.label}${loc.itemSelectedSuffix}',
        );

        // If we just reached the max, close the overlay
        if (_selectionManager.isMaxReached()) {
          if (_overlayController.isShowing) {
            _overlayController.hide();
          }
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
          // Use post-frame callback to ensure focus state is fully updated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            
            // Ensure focus is maintained
            _focusNode.requestFocus();
            
            // Ensure overlay stays open
            if (_focusManager.isFocused && !_overlayController.isShowing) {
              _clearHighlights();
              _overlayController.show();
            }
          });
        }
      } else {
        // Item is already selected, remove it (toggle off)
        // Capture state before removal to check if we should reopen overlay
        final bool wasAtMax = _selectionManager.isMaxReached();
        _selectionManager.removeItem(item.value);

        // FIX: Show overlay again if we're below maxSelected after removal
        // This handles the case where user removes an item after reaching max
        if (wasAtMax && _selectionManager.isBelowMax() &&
            _focusManager.isFocused) {
          final filtered = _filtered;
          if (!_overlayController.isShowing && filtered.isNotEmpty) {
            _clearHighlights();
            _overlayController.show();
          }
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

        _clearHighlights();
      },
      postRebuildCallback: () {
        // Restore focus if needed after chip removal
        _focusManager.restoreFocusIfNeeded();

        // Show overlay if we're below maxSelected and focused
        if (_focusManager.isFocused && _selectionManager.isBelowMax()) {
          final filtered = _filtered;
          if (!_overlayController.isShowing && filtered.isNotEmpty) {
            _clearHighlights();
            _overlayController.show();
          }
        }
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
    // _requestRebuild() already checks _rebuildScheduled internally
    _requestRebuild();
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
        });
      }
    }
  }

  /// Handle arrow button press - toggle dropdown
  void _handleArrowPressed() {
    if (_overlayController.isShowing) {
      _focusManager.loseFocus();
      _overlayController.hide();
    } else {
      // Show dropdown - if max is reached, overlay will show max reached message
      _focusManager.gainFocus();
      if (!_overlayController.isShowing) {
        _clearHighlights();
        _overlayController.show();
      }
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
      if (!_overlayController.isShowing) {
        _clearHighlights();
        _overlayController.show();
      }
    } else if (_filtered.isEmpty && !_selectionManager.isMaxReached()) {
      // Hide overlay if no filtered items and not focused and not at max
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
    }
  }
}

