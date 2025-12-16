part of '../../item_dropper_multi_select.dart';

// State management and helper methods
extension _MultiItemDropperStateHelpers<T> on _MultiItemDropperState<T> {
  void _clearHighlights() {
    _keyboardNavManager.clearHighlights();
  }

  /// Invalidate filtered items cache - call when search text or selected items change
  void _invalidateFilteredCache() {
    _cachedFilteredItems = null;
    _lastFilteredSearchText = '';
    _lastFilteredSelectedCount = -1;
    // Also ensure filter utils is initialized with current items
    _filterUtils.initializeItems(widget.items);
  }

  // Rebuild check helper
  void _requestRebuildIfNotScheduled() {
    if (!_rebuildScheduled) {
      _requestRebuild();
    }
  }

  // TextField padding calculation
  ({double top, double bottom}) _calculateTextFieldPadding({
    required double chipHeight,
    required double fontSize,
  }) {
    final double textLineHeight = fontSize * MultiSelectConstants.kTextLineHeightMultiplier;

    if (_measurements.chipTextTop != null) {
      // Use measured chip text center position to align TextField text
      // chipTextTop is already the text center (rowTop + rowHeight/2)
      final double chipTextCenter = _measurements.chipTextTop!;
      // Adjust for TextField's text rendering - needs offset upward
      final double top = chipTextCenter - (textLineHeight / 2.0) -
          MultiSelectConstants.kTextFieldPaddingOffset;
      final double bottom = chipHeight - textLineHeight - top;
      return (top: top, bottom: bottom);
    } else {
      // Fallback: calculate same as chip structure
      // Chip text center = chipVerticalPadding + rowHeight/2
      final double rowContentHeight = textLineHeight >
          MultiSelectConstants.kIconHeight
          ? textLineHeight
          : MultiSelectConstants.kIconHeight;
      final double chipTextCenter = MultiSelectConstants.kChipVerticalPadding +
          (rowContentHeight / 2.0);

      // Same adjustment as measured case
      final double top = chipTextCenter - (textLineHeight / 2.0) -
          MultiSelectConstants.kTextFieldPaddingOffset;
      final double bottom = chipHeight - textLineHeight - top;
      return (top: top, bottom: bottom);
    }
  }

  void _handleFocusChange() {
    // When TextField gains focus, ensure chip focus index reflects this
    // (Don't call focusTextField() here as it would cause infinite recursion)
    if (_focusNode.hasFocus && !_focusManager.isTextFieldFocused) {
      // Just update the chip focus index without requesting focus
      _focusManager.clearChipFocus();
    }
    // Focus change is now handled by the FocusManager
    // This method is kept for additional overlay logic

    // Use manual focus state for overlay logic
    if (_focusManager.isFocused) {
      // Show overlay when focused - if max is reached, overlay will show max reached message
      // Use a post-frame callback to ensure input context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusManager.isFocused) {
          return;
        }

        // If max is reached, show overlay (will display max reached message)
        if (_selectionManager.isMaxReached()) {
          if (!_overlayController.isShowing) {
            _clearHighlights();
            _overlayController.show();
          }
          return;
        }

        final filtered = _filtered;
        // Only show if we have items and overlay is not already showing
        if (filtered.isNotEmpty && !_overlayController.isShowing) {
          _clearHighlights();
          _overlayController.show();
        }
      });
    }
  }

  // Update visual state (border color) based on manual focus state
  void _updateFocusVisualState() {
    if (_rebuildScheduled) {
      return;
    }
    // Invalidate decoration cache - will be recreated on next build with new focus state
    _cachedDecoration = null;
    _cachedFocusState = null;
    // Note: setState must be called from main class, so we'll call _safeSetState from there
    // This is a helper that just invalidates the cache - the caller should trigger rebuild
  }

  /// Get decoration for the input field container (simplified from DecorationCacheManager)
  BoxDecoration _getDecoration({
    required bool isFocused,
    BoxDecoration? customDecoration,
  }) {
    // If custom decoration provided, use it as-is (no caching)
    if (customDecoration != null) {
      return customDecoration;
    }

    // Only recreate if cache is null or focus state changed
    if (_cachedDecoration == null || _cachedFocusState != isFocused) {
      _cachedFocusState = isFocused;
      _cachedDecoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFE5E5E5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: isFocused ? Colors.blue : Colors.grey.shade400,
          width: MultiSelectConstants.kContainerBorderWidth,
        ),
        borderRadius: BorderRadius.circular(MultiSelectConstants.kContainerBorderRadius),
      );
    }

    return _cachedDecoration!;
  }

  void _updateSelection(void Function() selectionUpdate) {
    // Preserve keyboard highlight state - only reset if keyboard navigation was active
    final bool wasKeyboardActive = _keyboardNavManager.keyboardHighlightIndex !=
        ItemDropperConstants.kNoHighlight;
    final int previousHoverIndex = _keyboardNavManager.hoverIndex;

    // Use unified selection change handler
    _handleSelectionChange(
      stateUpdate: () {
        // Update selection inside the rebuild callback
        selectionUpdate();
        
        // Update focus manager with new selection
        _focusManager.updateSelectedItems(_selectionManager.selected);
        
        // Clean up FocusNodes for chips that no longer exist
        final currentIndices = _selectionManager.selected.asMap().keys.toSet();
        final nodesToRemove = _chipFocusNodes.keys.where((i) => !currentIndices.contains(i)).toList();
        for (final index in nodesToRemove) {
          _chipFocusNodes[index]?.dispose();
          _chipFocusNodes.remove(index);
        }

        // Update highlights based on filtered items
        final List<ItemDropperItem<T>> remainingFilteredItems = _filtered;

        if (remainingFilteredItems.isNotEmpty) {
          // Only reset keyboard highlight if keyboard navigation was active
          if (wasKeyboardActive) {
            _keyboardNavManager.clearHighlights();
            // Set keyboard highlight to first item
            // Note: We can't directly set the index, so we'll clear it
            // The manager will handle resetting on next arrow key
          } else {
            // Preserve hover index if still valid
            if (previousHoverIndex >= 0 &&
                previousHoverIndex < remainingFilteredItems.length) {
              // Hover index is still valid, keep it
              _keyboardNavManager.hoverIndex = previousHoverIndex;
            } else {
              // Hover index is invalid, clear it
              _keyboardNavManager.clearHighlights();
            }
          }
        } else {
          _clearHighlights();
          if (_overlayController.isShowing) {
            _overlayController.hide();
          }
        }
      },
      postRebuildCallback: () {
        // Restore focus if needed after selection update
        _focusManager.restoreFocusIfNeeded();
      },
    );
  }


  // Central rebuild mechanism - prevents cascading rebuilds
  // Only allows one rebuild at a time - ignores further requests until rebuild completes
  void _requestRebuild([void Function()? stateUpdate]) {
    if (!mounted) {
      return;
    }

    // If rebuild already in progress, ignore this request
    if (_rebuildScheduled) {
      return;
    }

    // Mark that rebuild is scheduled and trigger it immediately
    _rebuildScheduled = true;

    // Trigger immediate rebuild - state updates happen inside setState callback
    _safeSetState(() {
      // Execute state update callback if provided
      if (stateUpdate != null) {
        stateUpdate.call();
      }
    });

    // After rebuild completes, reset flag to allow future rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rebuildScheduled = false;
      }
    });
  }

  /// Unified method to handle selection changes: rebuild + notify parent + cleanup
  /// Consolidates the common pattern of rebuilding, notifying parent, and cleanup
  void _handleSelectionChange({
    required void Function() stateUpdate,
    void Function()? postRebuildCallback,
  }) {
    // Update selection and all related state inside rebuild
    _requestRebuild(stateUpdate);

    // Use a post-frame callback to notify parent after current frame completes
    // This ensures our rebuild completes before parent is notified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Notify parent of change (this triggers parent rebuild synchronously)
      // Our didUpdateWidget will detect if we caused the change by comparing values
      widget.onChanged(_selectionManager.selected);

      // Execute optional post-rebuild callback (e.g., focus management, overlay updates)
      if (postRebuildCallback != null) {
        postRebuildCallback();
      }
    });
  }

  // Helper to check if two item lists are equal (by value)
  // Optimized for performance: early returns and efficient Set-based comparison
  // Time complexity: O(n) where n is the length of the lists
  bool _areItemsEqual(List<ItemDropperItem<T>>? a, List<ItemDropperItem<T>> b) {
    // Handle null
    if (a == null) return b.isEmpty;
    
    // Fast path: reference equality
    if (identical(a, b)) return true;

    // Fast path: length check (O(1))
    if (a.length != b.length) return false;

    // Fast path: empty lists
    if (a.isEmpty) return true;

    // For small lists, use simple iteration (more cache-friendly)
    if (a.length <= MultiSelectConstants.kListComparisonThreshold) {
      final Set<T> bValues = b.map((item) => item.value).toSet();
      return a.every((item) => bValues.contains(item.value));
    }

    // For larger lists, use Set-based comparison
    final Set<T> aValues = a.map((item) => item.value).toSet();
    final Set<T> bValues = b.map((item) => item.value).toSet();

    // If lengths are equal and all a values are in b, then all b values must be in a
    // (since Set length equals list length when there are no duplicates)
    return aValues.length == bValues.length &&
        aValues.every((value) => bValues.contains(value));
  }
}

