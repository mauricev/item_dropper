import 'package:flutter/material.dart';
import 'item_dropper_constants.dart';

/// Shared suffix icon widget for dropdown fields
/// Displays clear and dropdown arrow buttons
class ItemDropperSuffixIcons extends StatelessWidget {
  final bool isDropdownShowing;
  final bool enabled;
  final VoidCallback onClearPressed;
  final VoidCallback onArrowPressed;
  final double iconSize;
  final double suffixIconWidth;
  final double iconButtonSize;
  final double clearButtonRightPosition;
  final double arrowButtonRightPosition;
  final double textSize;
  /// Whether to show the dropdown position icon (arrow up/down).
  /// Defaults to true.
  final bool showDropdownPositionIcon;
  /// Whether to show the delete all icon (clear/X button).
  /// Defaults to true.
  final bool showDeleteAllIcon;

  const ItemDropperSuffixIcons({
    super.key,
    required this.isDropdownShowing,
    required this.enabled,
    required this.onClearPressed,
    required this.onArrowPressed,
    this.iconSize = 16.0,
    this.suffixIconWidth = 60.0,
    this.iconButtonSize = 24.0,
    this.clearButtonRightPosition = 40.0,
    this.arrowButtonRightPosition = 10.0,
    this.textSize = 14.0,
    this.showDropdownPositionIcon = true,
    this.showDeleteAllIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    
    // Add clear icon if enabled
    if (showDeleteAllIcon) {
      children.add(
        Positioned(
          right: clearButtonRightPosition,
          child: IconButton(
            icon: Icon(
              Icons.clear,
              size: iconSize,
              color: enabled ? Colors.black : Colors.grey,
            ),
            iconSize: iconSize,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: iconButtonSize,
              height: iconButtonSize,
            ),
            onPressed: enabled ? onClearPressed : null,
          ),
        ),
      );
    }
    
    // Add arrow icon if enabled
    if (showDropdownPositionIcon) {
      children.add(
        Positioned(
          right: arrowButtonRightPosition,
          child: IconButton(
            icon: Icon(
              isDropdownShowing
                  ? Icons.arrow_drop_up
                  : Icons.arrow_drop_down,
              size: iconSize,
              color: enabled ? Colors.black : Colors.grey,
            ),
            iconSize: iconSize,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: iconButtonSize,
              height: iconButtonSize,
            ),
            onPressed: enabled ? onArrowPressed : null,
          ),
        ),
      );
    }
    
    // If no icons are shown, return empty widget
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      width: suffixIconWidth,
      height: textSize * ItemDropperConstants.kSuffixIconHeightMultiplier,
      child: Stack(
        alignment: Alignment.centerRight,
        clipBehavior: Clip.none,
        children: children,
      ),
    );
  }
}