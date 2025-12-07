import 'package:flutter/material.dart';

/// Manages focus state and visual updates for multi-select dropdown
class MultiSelectFocusManager {
  final FocusNode focusNode;
  final VoidCallback onFocusVisualStateChanged;
  final VoidCallback? onFocusChanged;

  bool _manualFocusState = false;
  bool _disposed = false;

  MultiSelectFocusManager({
    required this.focusNode,
    required this.onFocusVisualStateChanged,
    this.onFocusChanged,
  }) {
    focusNode.addListener(_handleFocusChange);
  }

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
    }
    // If Flutter lost focus, clear manual state - no restoration attempts
    else if (!flutterHasFocus && _manualFocusState) {
      _manualFocusState = false;
      onFocusVisualStateChanged();
      onFocusChanged?.call();
    }
  }

  /// Clean up resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    focusNode.removeListener(_handleFocusChange);
  }
}
