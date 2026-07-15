import 'package:flutter/material.dart';

/// Manages caching of BoxDecoration for dropdown field containers.
///
/// Only recreates decoration when focus state changes, avoiding expensive
/// rebuilds on every frame. Supports custom decorations or generates default
/// decoration with focus-based border colors.
///
/// Example usage:
/// ```dart
/// final decorationManager = DecorationCacheManager();
///
/// // In build:
/// Container(
///   decoration: decorationManager.get(
///     isFocused: _focusNode.hasFocus,
///     customDecoration: widget.fieldDecoration,
///   ),
///   child: TextField(...),
/// )
/// ```
class DecorationCacheManager {
  BoxDecoration? _cachedDecoration;
  bool? _cachedFocusState;
  double? _cachedBorderRadius;
  double? _cachedBorderWidth;
  Color? _cachedGradientEndColor;

  /// Gets decoration, using cached value if focus state hasn't changed.
  ///
  /// If [customDecoration] is provided, returns it as-is without caching.
  /// Otherwise, generates a default decoration with focus-based border color:
  /// - Blue border when focused
  /// - Grey border when not focused
  ///
  /// Parameters:
  ///   - [isFocused]: Current focus state
  ///   - [customDecoration]: Optional custom decoration (bypasses caching)
  ///   - [borderRadius]: Border radius for default decoration (default: 8.0)
  ///   - [borderWidth]: Border width for default decoration (default: 1.0)
  ///   - [gradientEndColor]: Optional bottom color for default gradient
  BoxDecoration get({
    required bool isFocused,
    BoxDecoration? customDecoration,
    double borderRadius = 8.0,
    double borderWidth = 1.0,
    Color? gradientEndColor,
  }) {
    // If custom decoration provided, use it as-is (no caching)
    if (customDecoration != null) {
      return customDecoration;
    }

    // Only recreate if cache is null or decoration inputs changed.
    if (_cachedDecoration == null ||
        _cachedFocusState != isFocused ||
        _cachedBorderRadius != borderRadius ||
        _cachedBorderWidth != borderWidth ||
        _cachedGradientEndColor != gradientEndColor) {
      _cachedFocusState = isFocused;
      _cachedBorderRadius = borderRadius;
      _cachedBorderWidth = borderWidth;
      _cachedGradientEndColor = gradientEndColor;
      _cachedDecoration = _buildDefaultDecoration(
        isFocused: isFocused,
        borderRadius: borderRadius,
        borderWidth: borderWidth,
        gradientEndColor: gradientEndColor,
      );
    }

    return _cachedDecoration!;
  }

  /// Builds the default decoration with focus-responsive border.
  BoxDecoration _buildDefaultDecoration({
    required bool isFocused,
    required double borderRadius,
    required double borderWidth,
    Color? gradientEndColor,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white, gradientEndColor ?? Colors.grey.shade200],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      border: Border.all(
        color: isFocused ? Colors.blue : Colors.grey.shade400,
        width: borderWidth,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  /// Invalidates the cache, forcing recreation on next [get] call.
  ///
  /// Useful when external factors change (e.g., theme changes).
  void invalidate() {
    _cachedDecoration = null;
    _cachedFocusState = null;
    _cachedBorderRadius = null;
    _cachedBorderWidth = null;
    _cachedGradientEndColor = null;
  }
}
