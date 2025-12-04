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

    // Since overlays render globally (not clipped by scrollable viewport),
    // we should use the actual window bounds, not the scrollable viewport bounds
    availableSpaceBelow =
        windowHeight - inputFieldBottomScreen - viewInsets.bottom -
            padding.bottom;
    availableSpaceAbove = inputFieldScreenPos.dy - padding.top;

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

    // DEBUG: Print position calculation details (only when overlay is shown)
    print('=== DROPDOWN POSITION CALCULATION ===');
    print('Input field screen Y: ${inputFieldScreenPos.dy.toStringAsFixed(1)}');
    print('Input field bottom: ${inputFieldBottomScreen.toStringAsFixed(1)}');
    print('Input field height: ${inputFieldHeight.toStringAsFixed(1)}');
    print('Requested max dropdown height: ${maxDropdownHeight.toStringAsFixed(
        1)}');
    print('Available space BELOW: ${availableSpaceBelow.toStringAsFixed(1)}');
    print('Available space ABOVE: ${availableSpaceAbove.toStringAsFixed(1)}');
    print('Window height: ${windowHeight.toStringAsFixed(1)}');
    print('View insets bottom: ${viewInsets.bottom.toStringAsFixed(1)}');
    if (scrollRenderBox != null) {
      final Offset scrollScreenPos = scrollRenderBox.localToGlobal(Offset.zero);
      final Size scrollBoxSize = scrollRenderBox.size;
      print('Scroll viewport top: ${scrollScreenPos.dy.toStringAsFixed(1)}');
      print(
          'Scroll viewport bottom: ${(scrollScreenPos.dy + scrollBoxSize.height)
              .toStringAsFixed(1)}');
      print(
          'Scroll viewport height: ${scrollBoxSize.height.toStringAsFixed(1)}');
    } else {
      print('No scrollable parent found');
    }
    print('DECISION: Open ${shouldShowBelow ? "BELOW" : "ABOVE"}');
    print('Constrained height: ${constrainedMaxHeight.toStringAsFixed(1)}');
    print('Offset: ${offset.dy.toStringAsFixed(1)}');
    print('=====================================\n');
    
    return DropdownPositionResult(
      shouldShowBelow: shouldShowBelow,
      constrainedMaxHeight: constrainedMaxHeight,
      offset: offset,
    );
  }
}
