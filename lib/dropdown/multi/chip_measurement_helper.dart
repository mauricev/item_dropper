import 'package:flutter/material.dart';

/// Helper class for managing chip and layout measurements in multi-select dropdown
class ChipMeasurementHelper {
  double? chipHeight;
  double? chipTextTop;
  double? chipTextHeight;
  double? chipWidth;
  double? totalChipWidth; // Sum of all chip widths (measured)
  double? remainingWidth;
  double? wrapHeight; // Measured, no hardcoded initial value
  double? calculatedTextFieldWidthForRow; // Width calculated based on chips on text field's row
  
  final GlobalKey chipRowKey = GlobalKey();
  final GlobalKey lastChipKey = GlobalKey();
  final GlobalKey textFieldKey = GlobalKey();
  final GlobalKey wrapKey = GlobalKey();
  
  bool _isMeasuring = false;
  
  // Reset measurement state - call when selection is cleared
  void resetMeasurementState() {
    totalChipWidth = null;
    remainingWidth = null;
    calculatedTextFieldWidthForRow = null; // Clear row-specific width
    _isMeasuring = false;
  }
  
  void measureChip({
    required BuildContext context,
    required GlobalKey rowKey,
    required double textSize,
    required double chipVerticalPadding,
    required void Function() requestRebuild,
  }) {
    if (_isMeasuring) return;
    _isMeasuring = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasuring = false;
      
      final RenderBox? chipBox = context.findRenderObject() as RenderBox?;
      final RenderBox? rowBox = rowKey.currentContext?.findRenderObject() as RenderBox?;
      
      if (chipBox != null && rowBox != null) {
        final double newChipHeight = chipBox.size.height;
        final double newChipWidth = chipBox.size.width;
        final double rowHeight = rowBox.size.height;
        final double rowTop = chipVerticalPadding;
        final double textCenter = rowTop + (rowHeight / 2.0);
        
        // Chip measurements only need to be done once - they don't change
        if (chipHeight == null) {
          chipHeight = newChipHeight;
          chipTextTop = textCenter;
          chipTextHeight = rowHeight;
          chipWidth = newChipWidth;
        }
      }
    });
  }
  
  void measureWrapAndTextField({
    required BuildContext? wrapContext,
    required BuildContext? textFieldContext,
    required BuildContext? lastChipContext,
    required int selectedCount,
    required double chipSpacing,
    required double minTextFieldWidth,
    required double? calculatedTextFieldWidth, // The actual width passed to the widget
    required void Function() requestRebuild,
  }) {
    // Only measure wrap height for overlay positioning - let Wrap handle width naturally
    if (wrapContext == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? wrapBox = wrapContext.findRenderObject() as RenderBox?;
      if (wrapBox == null) return;

      final double newWrapHeight = wrapBox.size.height;
      final bool wrapHeightChanged = newWrapHeight != wrapHeight;

      if (wrapHeightChanged) {
        wrapHeight = newWrapHeight;
        // Request rebuild to update overlay positioning
        Future.microtask(() {
          requestRebuild();
        });
      }
    });
  }
}
