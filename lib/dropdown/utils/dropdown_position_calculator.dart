import 'package:flutter/material.dart';
import '../common/item_dropper_constants.dart';

/// Result of dropdown position calculation
class DropdownPositionResult {
  final bool shouldShowBelow;
  final double constrainedMaxHeight;
  final Offset offset;

  const DropdownPositionResult({
    required this.shouldShowBelow,
    required this.constrainedMaxHeight,
    required this.offset,
  });
}

/// Helper class for calculating dropdown overlay position
class DropdownPositionCalculator {
  /// Calculates the position and constraints for a dropdown overlay
  /// 
  /// Uses screen coordinates to accurately determine available space,
  /// accounting for Scrollable viewports and other UI elements.
  static DropdownPositionResult calculate({
    required BuildContext context,
    required RenderBox inputBox,
    required double inputFieldHeight,
    required double maxDropdownHeight,
  }) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double windowHeight = mediaQuery.size.height;
    final EdgeInsets viewInsets = mediaQuery.viewInsets;
    final EdgeInsets padding = mediaQuery.padding;
    
    // Get input field position in screen coordinates
    final Offset inputFieldScreenPos = inputBox.localToGlobal(Offset.zero);
    final double inputFieldBottomScreen = inputFieldScreenPos.dy + inputFieldHeight;
    
    // Find Scrollable to get the actual viewport bounds
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    RenderBox? scrollRenderBox;
    
    if (scrollable != null) {
      final RenderObject? scrollRenderObject = scrollable.context.findRenderObject();
      if (scrollRenderObject is RenderBox) {
        scrollRenderBox = scrollRenderObject;
      }
    }
    
    // Calculate available space using screen coordinates
    double availableSpaceBelow;
    double availableSpaceAbove;
    double inputFieldViewportY;
    
    if (scrollRenderBox != null) {
      // Use Scrollable as the viewport reference
      final Offset scrollScreenPos = scrollRenderBox.localToGlobal(Offset.zero);
      final double scrollOffset = scrollable!.position.hasContentDimensions ? scrollable.position.pixels : 0.0;
      final Size scrollBoxSize = scrollRenderBox.size;
      
      // Scrollable bottom in screen coordinates
      final double scrollableBottomScreen = scrollScreenPos.dy + scrollBoxSize.height;
      
      // Available space = Scrollable bottom - Input field bottom
      availableSpaceBelow = scrollableBottomScreen - inputFieldBottomScreen - viewInsets.bottom;
      availableSpaceAbove = inputFieldScreenPos.dy - scrollScreenPos.dy;
      
      // Convert to viewport coordinates for CompositedTransformFollower offset
      inputFieldViewportY = inputFieldScreenPos.dy - scrollScreenPos.dy + scrollOffset;
      
    } else {
      // Fallback: no Scrollable found
      inputFieldViewportY = inputFieldScreenPos.dy - padding.top;
      availableSpaceBelow = windowHeight - inputFieldBottomScreen - viewInsets.bottom;
      availableSpaceAbove = inputFieldScreenPos.dy - padding.top;
    }
    
    // Create viewport position offset for CompositedTransformFollower
    final Offset inputFieldOffset = Offset(inputFieldScreenPos.dx - padding.left, inputFieldViewportY);
    
    // Only show below if there's enough space for the full dropdown
    final bool shouldShowBelow = availableSpaceBelow >= maxDropdownHeight;
    
    // Constrain max height to available space
    final double constrainedMaxHeight = (shouldShowBelow
        ? availableSpaceBelow
        : availableSpaceAbove)
        .clamp(0.0, maxDropdownHeight);
    
    // Offset for CompositedTransformFollower (relative to input field)
    final Offset offset = shouldShowBelow
        ? Offset(0.0, inputFieldHeight + ItemDropperConstants.kDropdownMargin)
        : Offset(0.0, -constrainedMaxHeight - ItemDropperConstants.kDropdownMargin);
    
    return DropdownPositionResult(
      shouldShowBelow: shouldShowBelow,
      constrainedMaxHeight: constrainedMaxHeight,
      offset: offset,
    );
  }
}
