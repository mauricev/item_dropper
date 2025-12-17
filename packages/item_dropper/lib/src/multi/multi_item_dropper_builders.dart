part of '../../item_dropper_multi_select.dart';

// Build methods
extension _MultiItemDropperStateBuilders<T> on _MultiItemDropperState<T> {
  Widget _buildInputField() {
    // Calculate first row height for icon alignment
    final double chipHeight = _chipHeight ??
        MultiSelectLayoutCalculator.calculateTextFieldHeight(
          fontSize: widget.fieldTextStyle?.fontSize,
          chipVerticalPadding: MultiSelectConstants.kChipVerticalPadding,
        );
    final double firstRowHeight = chipHeight;
    final double fontSize = widget.fieldTextStyle?.fontSize ??
        ItemDropperConstants.kDropdownItemFontSize;
    final double iconContainerHeight = fontSize *
        ItemDropperConstants.kSuffixIconHeightMultiplier;
    
    return GestureDetector(
      onTap: () {
        // When container is tapped (but not on chips or icons), focus the TextField
        if (widget.enabled) {
          _focusManager.focusTextField();
          _focusManager.gainFocus();
          // Invalidate filter cache to ensure fresh calculation
          _invalidateFilteredCache();
          // Show overlay immediately
          _showOverlay();
        }
      },
      child: Container(
        key: widget.inputKey ?? _fieldKey,
        width: widget.width, // Constrain to 500px
        // Let content determine height naturally to prevent overflow
        decoration: _getDecoration(
          isFocused: _focusManager.isFocused,
          customDecoration: widget.fieldDecoration,
        ),
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            // Fill available space instead of min
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Integrated chips and text field area
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MultiSelectConstants.kContainerPaddingLeft,
                  MultiSelectConstants.kContainerPaddingTop,
                  // Add extra right padding to reserve space for suffix icons (if any are shown)
                  MultiSelectConstants.kContainerPaddingRight +
                      ((widget.showDropdownPositionIcon || widget.showDeleteAllIcon)
                          ? SingleSelectConstants.kSuffixIconWidth
                          : 0.0),
                  MultiSelectConstants.kContainerPaddingBottom,
                ),
                child: SmartWrapWithFlexibleLast(
                  key: _wrapKey,
                  spacing: MultiSelectConstants.kChipSpacing,
                  runSpacing: MultiSelectConstants.kChipSpacing,
                  children: [
                    // Selected chips
                    ..._selectionManager.selected.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Container(
                        key: ValueKey('chip_${item.value}'),
                        // Unique key for each chip
                        child: _buildChip(item, null, null, index),
                      );
                    }),
                    _buildTextFieldChip(double.infinity),
                  ],
                ),
              ),
            ],
          ),
          // Container-level suffix icons aligned with first row (only if at least one icon is enabled)
          if (widget.showDropdownPositionIcon || widget.showDeleteAllIcon)
            Positioned(
              top: MultiSelectConstants.kContainerPaddingTop +
                  (firstRowHeight - iconContainerHeight) / 2,
              right: MultiSelectConstants.kContainerPaddingRight,
              child: ItemDropperSuffixIcons(
                isDropdownShowing: _overlayController.isShowing,
                enabled: widget.enabled,
                onClearPressed: _handleClearPressed,
                onArrowPressed: _handleArrowPressed,
                iconSize: SingleSelectConstants.kIconSize,
                suffixIconWidth: SingleSelectConstants.kSuffixIconWidth,
                iconButtonSize: SingleSelectConstants.kIconButtonSize,
                clearButtonRightPosition: SingleSelectConstants.kClearButtonRightPosition,
                arrowButtonRightPosition: SingleSelectConstants.kArrowButtonRightPosition,
                textSize: fontSize,
                showDropdownPositionIcon: widget.showDropdownPositionIcon,
                showDeleteAllIcon: widget.showDeleteAllIcon,
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildChip(ItemDropperItem<T> item,
      [GlobalKey? chipKey, Key? valueKey, int? chipIndex]) {
    final index = chipIndex ?? _selectionManager.selected.indexOf(item);
    final isFocused = _focusManager.isChipFocused(index);
    
    // Only measure the first chip (index 0) to avoid GlobalKey conflicts
    final bool isFirstChip = _selectionManager.selected.isNotEmpty &&
        _selectionManager.selected.first.value == item.value;
    final GlobalKey? rowKey = isFirstChip ? _chipRowKey : null;

    return LayoutBuilder(
      key: valueKey, // Use stable ValueKey for widget preservation
      builder: (context, constraints) {
        // Schedule chip measurement after build completes - don't measure during build
        // Measure chip dimensions after first render (only for first chip, only once)
        // Chip measurements don't change, so we only need to measure once
        if (isFirstChip && rowKey != null && _chipHeight == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            // Re-check conditions in case they changed
            if (_chipHeight == null && rowKey.currentContext != null) {
              _measureChip(
                context: context,
                rowKey: rowKey,
                textSize: widget.fieldTextStyle?.fontSize ??
                    ItemDropperConstants.kDropdownItemFontSize,
                chipVerticalPadding: MultiSelectConstants.kChipVerticalPadding,
              );
            }
          });
        }

        // Determine chip decoration.
        // - If a custom BoxDecoration is provided, use it as-is.
        // - Otherwise, fall back to the default blue vertical gradient.
        final BoxDecoration effectiveDecoration = widget
            .selectedChipDecoration ??
            BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade100,
                  Colors.blue.shade200,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius:
              BorderRadius.circular(MultiSelectConstants.kChipBorderRadius),
            );

        // Add focus border if focused
        final BoxDecoration focusedDecoration = isFocused
            ? effectiveDecoration.copyWith(
                border: Border.all(
                  color: Colors.blue.shade600,
                  width: 2.0,
                ),
              )
            : effectiveDecoration;
        
        // Get or create FocusNode for this chip
        final chipFocusNode = _chipFocusNodes.putIfAbsent(
          index,
          () => FocusNode(skipTraversal: false, canRequestFocus: widget.enabled),
        );
        
        // Request focus when this chip becomes focused
        if (isFocused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_focusManager.isChipFocused(index)) {
              chipFocusNode.requestFocus();
            }
          });
        }
        
        return Semantics(
          label: '${item.label}${_localizations.selectedSuffix}',
          button: true,
          excludeSemantics: true,
          child: Focus(
            focusNode: chipFocusNode,
            onKeyEvent: (node, event) {
              // Delegate to chip focus manager
              return _focusManager.handleKeyEvent(event);
            },
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                _focusManager.focusChip(index);
              } else if (_focusManager.isChipFocused(index)) {
                // Lost focus but we still think it's focused - move to TextField
                _focusManager.focusTextField();
              }
            },
            child: GestureDetector(
              onTap: () {
                _focusManager.focusChip(index);
                chipFocusNode.requestFocus();
              },
              child: Container(
                key: chipKey,
                // Use provided GlobalKey (for last chip) or null
                decoration: focusedDecoration,
                padding: const EdgeInsets.symmetric(
                  horizontal: MultiSelectConstants.kChipHorizontalPadding,
                  vertical: MultiSelectConstants.kChipVerticalPadding,
                ),
                margin: const EdgeInsets.only(
                  right: MultiSelectConstants.kChipMarginRight,),
                child: Row(
                  key: rowKey, // Only first chip gets the key
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: (widget.fieldTextStyle ?? const TextStyle(
                          fontSize: ItemDropperConstants.kDropdownItemFontSize))
                          .copyWith(
                        color: widget.enabled
                            ? (widget.fieldTextStyle?.color ?? Colors.black)
                            : Colors.grey.shade500,
                      ),
                    ),
                    if (widget.enabled)
                      Container(
                        width: MultiSelectConstants.kChipDeleteButtonSize,
                        height: MultiSelectConstants.kChipDeleteButtonSize,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () {
                            _removeChip(item);
                          },
                          child: Icon(Icons.close,
                              size: MultiSelectConstants.kChipDeleteIconSize,
                              color: Colors.grey.shade700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextFieldChip(double width) {
    // Use measured chip dimensions if available, otherwise fall back to calculation
    final double chipHeight = _chipHeight ??
        MultiSelectLayoutCalculator.calculateTextFieldHeight(
          fontSize: widget.fieldTextStyle?.fontSize,
          chipVerticalPadding: MultiSelectConstants.kChipVerticalPadding,
        );
    final double fontSize = widget.fieldTextStyle?.fontSize ??
        ItemDropperConstants.kDropdownItemFontSize;
    final padding = _calculateTextFieldPadding(
      chipHeight: chipHeight,
      fontSize: fontSize,
    );
    final double textFieldPaddingTop = padding.top;
    final double textFieldPaddingBottom = padding.bottom;

    // Use Container with exact width - Wrap will use this for layout
    return SizedBox(
      key: _textFieldKey, // Key to measure TextField position
      width: width, // Exact width - Wrap will use this
      height: chipHeight, // Use measured chip height
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Semantics(
          label: _localizations.multiSelectFieldLabel,
          textField: true,
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
          style: widget.fieldTextStyle ??
              const TextStyle(fontSize: ItemDropperConstants
                  .kDropdownItemFontSize),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.only(
              right: ((widget.showDropdownPositionIcon || widget.showDeleteAllIcon)
                      ? SingleSelectConstants.kSuffixIconWidth
                      : 0.0) +
                  MultiSelectConstants.kContainerPaddingRight,
              top: textFieldPaddingTop,
              bottom: textFieldPaddingBottom,
            ),
            border: InputBorder.none,
            hintText: widget.hintText,
          ),
          onChanged: (value) => _handleTextChanged(value),
          onSubmitted: (value) => _handleEnter(),
          enabled: widget.enabled,
          // Ensure TextField can receive focus
          autofocus: false,
          onTap: () {
            // When TextField is tapped, focus it and clear chip focus
            _focusManager.focusTextField();
            _focusManager.gainFocus();
            // Show overlay immediately
            _showOverlay();
          },
        ), // Close TextField
        ), // Close Semantics
      ), // Close IgnorePointer
    );
  }

  Widget _buildDropdownOverlay(BuildContext context) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    final List<ItemDropperItem<T>> filteredItems = _filtered;

    // Use the context from build() method for proper positioning
    // Fall back to key-based context if needed, but prefer the passed context
    final BuildContext inputContext = (widget.inputKey ?? _fieldKey)
        .currentContext ?? context;

    final double effectiveItemHeight = _calculateEffectiveItemHeight();

    // Show max reached overlay if max selection is reached
    if (_selectionManager.isMaxReached()) {
      return _buildMaxReachedOverlay(inputContext);
    }
    
    // Show empty state if user is searching but no results found
    if (filteredItems.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        // User is searching but no results - show empty state
        return _buildEmptyStateOverlay(inputContext);
      }
      // No search text and no filtered items - check if we have items to show
      // If widget.items has items (excluding selected), show them
      final availableItems = widget.items
          .where((item) => item.isGroupHeader || !_selectionManager.selectedValues.contains(item.value))
          .toList();
      if (availableItems.isEmpty) {
        // No items available - hide overlay
        return const SizedBox.shrink();
      }
      // We have items but filteredItems is empty - use availableItems instead
      // This can happen during initialization before _filtered is properly calculated
      return _buildOverlayContent(
        items: availableItems,
        inputContext: inputContext,
        effectiveItemHeight: effectiveItemHeight,
      );
    }

    // Build overlay with filtered items
    return _buildOverlayContent(
      items: filteredItems,
      inputContext: inputContext,
      effectiveItemHeight: effectiveItemHeight,
    );
  }

  /// Calculates the effective item height from widget.itemHeight or popupTextStyle
  double _calculateEffectiveItemHeight() {
    // If widget.itemHeight is provided, use it
    if (widget.itemHeight != null) {
      return widget.itemHeight!;
    }
    
    // Otherwise, calculate from popupTextStyle
    final TextStyle resolvedStyle = widget.popupTextStyle ??
        const TextStyle(fontSize: ItemDropperConstants.kDropdownItemFontSize);
    final double fontSize = resolvedStyle.fontSize ??
        ItemDropperConstants.kDropdownItemFontSize;
    final double lineHeight = fontSize * (resolvedStyle.height ??
        MultiSelectConstants.kTextLineHeightMultiplier);
    return lineHeight +
        (ItemDropperConstants.kDropdownItemVerticalPadding * 2);
  }

  /// Gets the item builder function for a given item in a list
  Widget Function(BuildContext, ItemDropperItem<T>, bool) _getItemBuilder(
    List<ItemDropperItem<T>> items,
    int itemIndex,
  ) {
    // Use custom builder if provided
    if (widget.popupItemBuilder != null) {
      return widget.popupItemBuilder!;
    }
    
    // Otherwise, use default builder with style parameters
    final bool hasPrevious = itemIndex > 0;
    final bool previousIsGroupHeader = hasPrevious &&
        items[itemIndex - 1].isGroupHeader;
    
    return (context, item, isSelected) {
      return ItemDropperRenderUtils.defaultDropdownPopupItemBuilder(
        context,
        item,
        isSelected,
        popupTextStyle: widget.popupTextStyle,
        popupGroupHeaderStyle: widget.popupGroupHeaderStyle,
        hasPreviousItem: hasPrevious,
        previousItemIsGroupHeader: previousIsGroupHeader,
      );
    };
  }

  /// Builds the overlay content with the given items
  Widget _buildOverlayContent({
    required List<ItemDropperItem<T>> items,
    required BuildContext inputContext,
    required double effectiveItemHeight,
  }) {
    // Use Container's full height for overlay positioning (not Wrap height)
    // The Container includes border and padding, which must be accounted for
    // Don't pass preferredFieldHeight - use inputBox.size.height directly
    // This ensures overlay is positioned correctly relative to the Container
    return ItemDropperRenderUtils.buildDropdownOverlay<T>(
      context: inputContext,
      items: items,
      maxDropdownHeight: widget.maxDropdownHeight,
      width: widget.width,
      controller: _overlayController,
      scrollController: _scrollController,
      layerLink: _layerLink,
      isSelected: (ItemDropperItem<T> item) => _selectionManager.isSelected(item),
      builder: (BuildContext builderContext, ItemDropperItem<T> item, bool isSelected) {
        final int itemIndex = items.indexWhere((x) => x.value == item.value);
        final itemBuilder = _getItemBuilder(items, itemIndex);
        
        return ItemDropperRenderUtils.buildDropdownItemWithHover<T>(
          context: builderContext,
          item: item,
          isSelected: isSelected,
          filteredItems: items,
          hoverIndex: _keyboardNavManager.hoverIndex,
          keyboardHighlightIndex: _keyboardNavManager.keyboardHighlightIndex,
          safeSetState: _safeSetState,
          setHoverIndex: (index) => _keyboardNavManager.hoverIndex = index,
          onTap: () {
            _toggleItem(item);
          },
          customBuilder: itemBuilder,
          itemHeight: effectiveItemHeight,
          onRequestDelete: _handleRequestDeleteFromOverlay,
        );
      },
      itemHeight: effectiveItemHeight,
      // Don't pass preferredFieldHeight - use Container's full height from inputBox
    );
  }

  /// Builds a max reached overlay when maximum selection is reached
  Widget _buildMaxReachedOverlay(BuildContext inputContext) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final double inputFieldHeight = inputBox.size.height;
    // Use actual measured field width to ensure overlay matches field width exactly
    final double actualFieldWidth = inputBox.size.width;
    final double maxDropdownHeight = widget.maxDropdownHeight;
    
    final position = DropdownPositionCalculator.calculate(
      context: inputContext,
      inputBox: inputBox,
      inputFieldHeight: inputFieldHeight,
      maxDropdownHeight: maxDropdownHeight,
    );

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      offset: position.offset,
      child: SizedBox(
        width: actualFieldWidth,
        child: Material(
          elevation: ItemDropperConstants.kDropdownElevation,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MultiSelectConstants.kEmptyStatePaddingHorizontal,
              vertical: MultiSelectConstants.kEmptyStatePaddingVertical,
            ),
            child: Text(
              _localizations.maxItemsReachedOverlay,
              style: (widget.popupTextStyle ?? widget.fieldTextStyle ?? const TextStyle(fontSize: ItemDropperConstants
                  .kDropdownItemFontSize)).copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an empty state overlay when search returns no results
  Widget _buildEmptyStateOverlay(BuildContext inputContext) {
    // Don't build overlay if disabled
    if (!widget.enabled) return const SizedBox.shrink();

    final RenderBox? inputBox = inputContext.findRenderObject() as RenderBox?;
    if (inputBox == null) return const SizedBox.shrink();

    final double inputFieldHeight = inputBox.size.height;
    // Use actual measured field width to ensure overlay matches field width exactly
    final double actualFieldWidth = inputBox.size.width;
    final double maxDropdownHeight = widget.maxDropdownHeight;
    
    final position = DropdownPositionCalculator.calculate(
      context: inputContext,
      inputBox: inputBox,
      inputFieldHeight: inputFieldHeight,
      maxDropdownHeight: maxDropdownHeight,
    );

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      offset: position.offset,
      child: SizedBox(
        width: actualFieldWidth,
        child: Material(
          elevation: ItemDropperConstants.kDropdownElevation,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MultiSelectConstants.kEmptyStatePaddingHorizontal,
              vertical: MultiSelectConstants.kEmptyStatePaddingVertical,
            ),
            child: Text(
              _localizations.noResultsFound,
              style: (widget.popupTextStyle ?? widget.fieldTextStyle ?? const TextStyle(fontSize: ItemDropperConstants
                  .kDropdownItemFontSize)).copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
