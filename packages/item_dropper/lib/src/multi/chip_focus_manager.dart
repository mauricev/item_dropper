import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/item_dropper_item.dart';

/// Manages focus state for chips in multi-select dropdown
class ChipFocusManager<T> {
  /// Currently focused chip index (-1 if none, -2 if TextField is focused)
  int _focusedChipIndex = -2; // Start with TextField focused
  
  /// List of selected items (for determining chip count)
  List<ItemDropperItem<T>> _selectedItems = [];
  
  /// Callback when focus changes
  final VoidCallback onFocusChanged;
  
  /// Callback to remove a chip
  final void Function(ItemDropperItem<T> item) onRemoveChip;
  
  /// Callback to focus TextField
  final VoidCallback onFocusTextField;
  
  ChipFocusManager({
    required this.onFocusChanged,
    required this.onRemoveChip,
    required this.onFocusTextField,
  });
  
  /// Update selected items list
  void updateSelectedItems(List<ItemDropperItem<T>> items) {
    _selectedItems = items;
    // If focused chip index is out of bounds, reset to TextField
    if (_focusedChipIndex >= items.length) {
      _focusedChipIndex = -2;
      onFocusChanged();
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
      onFocusChanged();
      // Request focus for the chip's Focus widget
      // Note: The actual Focus widget will request focus in its onFocusChange callback
    }
  }
  
  /// Focus TextField
  void focusTextField() {
    _focusedChipIndex = -2;
    onFocusChanged();
    // Request focus for the TextField
    onFocusTextField();
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
        onFocusChanged();
        return KeyEventResult.handled;
      } else if (_focusedChipIndex == 0) {
        // Move from first chip to TextField
        _focusedChipIndex = -2;
        onFocusChanged();
        return KeyEventResult.handled;
      }
      // Already at TextField or no chips
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // Move focus right (to next chip or stay at TextField)
      if (_focusedChipIndex == -2 && itemCount > 0) {
        // Move from TextField to first chip
        _focusedChipIndex = 0;
        onFocusChanged();
        return KeyEventResult.handled;
      } else if (_focusedChipIndex >= 0 && _focusedChipIndex < itemCount - 1) {
        // Move to next chip
        _focusedChipIndex++;
        onFocusChanged();
        return KeyEventResult.handled;
      }
      // Already at last chip or no chips
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
               event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // Up/Down arrows: move to TextField if chip focused, or ignore if TextField focused
      if (_focusedChipIndex >= 0) {
        _focusedChipIndex = -2;
        onFocusChanged();
        onFocusTextField();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    } else if ((event.logicalKey == LogicalKeyboardKey.delete ||
                 event.logicalKey == LogicalKeyboardKey.backspace) &&
               _focusedChipIndex >= 0 &&
               _focusedChipIndex < itemCount) {
      // Delete/Backspace: remove focused chip
      final itemToRemove = _selectedItems[_focusedChipIndex];
      onRemoveChip(itemToRemove);
      
      // Adjust focus after removal
      if (itemCount == 1) {
        // Last chip removed, focus TextField
        _focusedChipIndex = -2;
      } else if (_focusedChipIndex >= itemCount - 1) {
        // Removed last chip, focus previous chip
        _focusedChipIndex = itemCount - 2;
      }
      // Otherwise stay at same index (which now points to next chip)
      
      onFocusChanged();
      return KeyEventResult.handled;
    }
    
    return KeyEventResult.ignored;
  }
  
  /// Clear focus
  void clearFocus() {
    _focusedChipIndex = -2;
    onFocusChanged();
  }
}

