import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/item_dropper_item.dart';

/// Unified manager for focus state in multi-select dropdown.
/// Handles both TextField focus and chip focus navigation.
class MultiSelectFocusManager<T> {
  final FocusNode focusNode;
  final VoidCallback onFocusVisualStateChanged;
  final VoidCallback? onFocusChanged;
  
  // TextField focus state
  bool _manualFocusState = false;
  bool _disposed = false;
  
  // Chip focus state
  /// Currently focused chip index (-1 if none, -2 if TextField is focused)
  int _focusedChipIndex = -2; // Start with TextField focused
  
  /// List of selected items (for determining chip count)
  List<ItemDropperItem<T>> _selectedItems = [];
  
  /// Callback to remove a chip
  final void Function(ItemDropperItem<T> item)? onRemoveChip;

  MultiSelectFocusManager({
    required this.focusNode,
    required this.onFocusVisualStateChanged,
    this.onFocusChanged,
    this.onRemoveChip,
  }) {
    focusNode.addListener(_handleFocusChange);
  }

  // ============================================================================
  // TextField Focus Management
  // ============================================================================

  /// Whether the widget is manually focused (controlled by user interactions)
  bool get isFocused => _manualFocusState;

  /// Request focus and set manual focus state
  void gainFocus() {
    if (!_manualFocusState) {
      _manualFocusState = true;
      focusNode.requestFocus();
      onFocusVisualStateChanged();
    }
  }

  /// Clear manual focus state and unfocus
  void loseFocus() {
    _manualFocusState = false;
    onFocusVisualStateChanged();
    focusNode.unfocus();
  }

  /// Restore focus if manual state indicates we should be focused
  /// Called after operations that might cause focus loss (e.g., selection changes)
  void restoreFocusIfNeeded() {
    if (_manualFocusState && !focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  /// Handle focus change events from FocusNode
  void _handleFocusChange() {
    if (_disposed) return;
    
    final bool flutterHasFocus = focusNode.hasFocus;

    // Only update manual focus state if Flutter gained focus (user clicked TextField)
    if (flutterHasFocus && !_manualFocusState) {
      _manualFocusState = true;
      onFocusVisualStateChanged();
      onFocusChanged?.call();
      // When TextField gains focus, ensure chip focus reflects this
      _focusedChipIndex = -2;
    }
    // If Flutter lost focus, clear manual state - no restoration attempts
    else if (!flutterHasFocus && _manualFocusState) {
      _manualFocusState = false;
      onFocusVisualStateChanged();
      onFocusChanged?.call();
    }
  }

  // ============================================================================
  // Chip Focus Management
  // ============================================================================

  /// Update selected items list
  void updateSelectedItems(List<ItemDropperItem<T>> items) {
    _selectedItems = items;
    // If focused chip index is out of bounds, reset to TextField
    if (_focusedChipIndex >= items.length) {
      _focusedChipIndex = -2;
      onFocusChanged?.call();
    }
  }

  /// Get currently focused chip index (-1 = no focus, -2 = TextField focused, >= 0 = chip index)
  int get focusedChipIndex => _focusedChipIndex;

  /// Check if TextField is focused
  bool get isTextFieldFocused => _focusedChipIndex == -2;

  /// Check if a chip is focused
  bool isChipFocused(int index) => _focusedChipIndex == index;

  /// Focus a specific chip
  void focusChip(int index) {
    if (index >= 0 && index < _selectedItems.length) {
      _focusedChipIndex = index;
      onFocusChanged?.call();
      // Request focus for the chip's Focus widget
      // Note: The actual Focus widget will request focus in its onFocusChange callback
    }
  }

  /// Focus TextField
  void focusTextField() {
    _focusedChipIndex = -2;
    onFocusChanged?.call();
    // Request focus for the TextField
    focusNode.requestFocus();
  }

  /// Handle keyboard events for chip navigation
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    
    final itemCount = _selectedItems.length;
    
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // Move focus left (to previous chip or TextField)
      if (_focusedChipIndex > 0) {
        _focusedChipIndex--;
        onFocusChanged?.call();
        return KeyEventResult.handled;
      } else if (_focusedChipIndex == 0) {
        // Move from first chip to TextField
        _focusedChipIndex = -2;
        onFocusChanged?.call();
        return KeyEventResult.handled;
      }
      // Already at TextField or no chips
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // Move focus right (to next chip or stay at TextField)
      if (_focusedChipIndex == -2 && itemCount > 0) {
        // Move from TextField to first chip
        _focusedChipIndex = 0;
        onFocusChanged?.call();
        return KeyEventResult.handled;
      } else if (_focusedChipIndex >= 0 && _focusedChipIndex < itemCount - 1) {
        // Move to next chip
        _focusedChipIndex++;
        onFocusChanged?.call();
        return KeyEventResult.handled;
      }
      // Already at last chip or no chips
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
               event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // Up/Down arrows: move to TextField if chip focused, or ignore if TextField focused
      if (_focusedChipIndex >= 0) {
        _focusedChipIndex = -2;
        onFocusChanged?.call();
        focusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    } else if ((event.logicalKey == LogicalKeyboardKey.delete ||
                 event.logicalKey == LogicalKeyboardKey.backspace) &&
               _focusedChipIndex >= 0 &&
               _focusedChipIndex < itemCount &&
               onRemoveChip != null) {
      // Delete/Backspace: remove focused chip
      final itemToRemove = _selectedItems[_focusedChipIndex];
      onRemoveChip!(itemToRemove);
      
      // Adjust focus after removal
      if (itemCount == 1) {
        // Last chip removed, focus TextField
        _focusedChipIndex = -2;
      } else if (_focusedChipIndex >= itemCount - 1) {
        // Removed last chip, focus previous chip
        _focusedChipIndex = itemCount - 2;
      }
      // Otherwise stay at same index (which now points to next chip)
      
      onFocusChanged?.call();
      return KeyEventResult.handled;
    }
    
    return KeyEventResult.ignored;
  }

  /// Clear chip focus (return to TextField)
  void clearChipFocus() {
    _focusedChipIndex = -2;
    onFocusChanged?.call();
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Clean up resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    focusNode.removeListener(_handleFocusChange);
  }
}
