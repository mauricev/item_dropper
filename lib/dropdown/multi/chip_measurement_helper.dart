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
  
  final GlobalKey chipRowKey = GlobalKey();
  final GlobalKey lastChipKey = GlobalKey();
  final GlobalKey textFieldKey = GlobalKey();
  final GlobalKey wrapKey = GlobalKey();
  
  bool _isMeasuring = false;
  int _lastMeasuredSelectedCount = -1;
  
  // Reset measurement state - call when selection is cleared
  void resetMeasurementState() {
    _lastMeasuredSelectedCount = -1;
    totalChipWidth = null;
    remainingWidth = null;
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
    required void Function() requestRebuild,
  }) {
    // Only measure if selection count changed or we haven't measured yet
    if (wrapContext == null) return;
    
    // Reset measurement tracking when selection count goes to 0
    if (selectedCount == 0) {
      _lastMeasuredSelectedCount = -1;
      remainingWidth = null; // Reset remaining width when no items
      return;
    }
    
    // Only measure if count changed - prevents duplicate measurements during same build
    if (_lastMeasuredSelectedCount == selectedCount) return;
    if (_isMeasuring) return; // Already measuring, skip
    
    // Set immediately to prevent duplicate calls during the same build cycle
    _lastMeasuredSelectedCount = selectedCount;
    _isMeasuring = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasuring = false;
      
      final RenderBox? wrapBox = wrapContext.findRenderObject() as RenderBox?;
      if (wrapBox == null) return;
      
      final double newWrapHeight = wrapBox.size.height;
      final double wrapWidth = wrapBox.size.width;
      
      // Detect wrapping by comparing to previous height or chip height
      final double? previousWrapHeight = wrapHeight;
      final double? singleRowHeight = chipHeight; // Single row should be approximately chip height
      
      // If we have a previous measurement and height increased significantly, it wrapped
      // Or if height is much larger than chip height, it wrapped
      final bool likelyWrapped = (previousWrapHeight != null && newWrapHeight > previousWrapHeight * 1.5) ||
          (singleRowHeight != null && newWrapHeight > singleRowHeight * 1.5);
      
      if (likelyWrapped) {
        // Calculate total width needed and inspect children
        double totalWidthNeeded = 0.0;
        double measuredChipWidth = 0.0; // Sum of chip widths only (exclude TextField)
        wrapBox.visitChildren((child) {
          if (child is RenderBox) {
            totalWidthNeeded += child.size.width;
            // Only count chips (RenderLayoutBuilder), not TextField (RenderConstrainedBox)
            if (child.runtimeType.toString().contains('LayoutBuilder')) {
              measuredChipWidth += child.size.width;
            }
          }
        });
        
        // Store measured chip width for use in _calculateTextFieldWidth
        if (measuredChipWidth > 0) {
          totalChipWidth = measuredChipWidth;
        }
      }
      
      // ALWAYS measure chip widths when selection count changes for accurate TextField width calculation
      // This ensures totalChipWidth is updated whenever chips are added/removed
      double measuredChipWidth = 0.0;
      int chipCount = 0;
      wrapBox.visitChildren((child) {
        if (child is RenderBox && child.runtimeType.toString().contains('LayoutBuilder')) {
          measuredChipWidth += child.size.width;
          chipCount++;
        }
      });
      if (measuredChipWidth > 0) {
        // Always update with actual measurement - this ensures we have correct width for TextField calculation
        totalChipWidth = measuredChipWidth;
      }
      
      // Track if wrapHeight changed (affects overlay positioning)
      final bool wrapHeightChanged = newWrapHeight != wrapHeight;
      
      if (wrapHeightChanged) {
        wrapHeight = newWrapHeight;
      }
      
      final RenderBox? textFieldBox = textFieldContext?.findRenderObject() as RenderBox?;
      final RenderBox? lastChipBox = lastChipContext?.findRenderObject() as RenderBox?;
      
      if (textFieldBox != null && lastChipBox != null) {
        final Offset? textFieldPos = textFieldBox.localToGlobal(Offset.zero);
        final Offset? lastChipPos = lastChipBox.localToGlobal(Offset.zero);
        final Offset? wrapPos = wrapBox.localToGlobal(Offset.zero);
        
        if (textFieldPos != null && lastChipPos != null && wrapPos != null) {
          final double textFieldY = textFieldPos.dy - wrapPos.dy;
          final double lastChipY = lastChipPos.dy - wrapPos.dy;
          final bool isOnSameLine = (textFieldY - lastChipY).abs() < 5.0;
          
          if (isOnSameLine) {
            final double lastChipRight = lastChipPos.dx - wrapPos.dx + lastChipBox.size.width;
            final double actualRemaining = wrapWidth - lastChipRight - chipSpacing;
            
            if (actualRemaining > 0 && (remainingWidth == null ||
                (remainingWidth! - actualRemaining).abs() > 1.0)) {
              remainingWidth = actualRemaining.clamp(minTextFieldWidth, wrapWidth);
            }
          } else {
            // TextField wrapped to new line - calculate remaining width on first line
            final double lastChipRight = lastChipPos.dx - wrapPos.dx + lastChipBox.size.width;
            final double firstLineRemaining = wrapWidth - lastChipRight - chipSpacing;
            
            // Only update if we have enough space and it's different from current
            if (firstLineRemaining > minTextFieldWidth && 
                (remainingWidth == null || (remainingWidth! - firstLineRemaining).abs() > 1.0)) {
              remainingWidth = firstLineRemaining;
            } else if (firstLineRemaining <= minTextFieldWidth) {
              // Not enough space on first line - use minimum width
              // TextField will wrap to next line
              if (remainingWidth == null || remainingWidth != minTextFieldWidth) {
                remainingWidth = minTextFieldWidth;
              }
            }
          }
        }
      }
      
      // Request rebuild when wrapHeight changes (affects overlay positioning)
      // Only rebuild when wrapHeight changes, not when remainingWidth changes
      // This ensures overlay repositions immediately when chips wrap/unwrap
      if (wrapHeightChanged) {
        // Use a microtask to avoid rebuilding during the current frame
        // This ensures the measurement is complete before rebuild
        Future.microtask(() {
          requestRebuild();
        });
      }
    });
  }
}

