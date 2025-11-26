import 'package:flutter/material.dart';

/// Shared suffix icon widget for dropdown fields
/// Displays clear and dropdown arrow buttons
class DropdownSuffixIcons extends StatelessWidget {
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

  const DropdownSuffixIcons({
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
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: suffixIconWidth,
      height: textSize * 3.2,
      child: Stack(
        alignment: Alignment.centerRight,
        clipBehavior: Clip.none,
        children: [
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
        ],
      ),
    );
  }
}