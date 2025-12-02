import 'package:flutter/material.dart';
import 'multi_select_layout_calculator.dart';

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
  int _lastMeasuredSelectedCount = -1;
  
  // Reset measurement state - call when selection is cleared
  void resetMeasurementState() {
    _lastMeasuredSelectedCount = -1;
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
    // Only measure if selection count changed or we haven't measured yet
    if (wrapContext == null) return;
    
    // Reset measurement tracking when selection count goes to 0
    if (selectedCount == 0) {
      _lastMeasuredSelectedCount = -1;
      remainingWidth = null; // Reset remaining width when no items
      calculatedTextFieldWidthForRow = null; // Clear row-specific width
      return;
    }
    
    // Only measure if count changed - prevents duplicate measurements during same build
    // When selection count changes, clear the stored width so we recalculate
    if (_lastMeasuredSelectedCount != selectedCount) {
      calculatedTextFieldWidthForRow = null; // Clear when selection changes
    }
    
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
      
      // ====== DEBUG: Measure all children and calculate space per row ======
      debugPrint("═══════════════════════════════════════════════════════════");
      debugPrint("[ROW_MEASUREMENT] Starting measurement");
      debugPrint("[ROW_MEASUREMENT] Wrap width: $wrapWidth, Wrap height: $wrapHeight");
      debugPrint("[ROW_MEASUREMENT] Selected count: $selectedCount");
      
      final RenderBox? textFieldBox = textFieldContext?.findRenderObject() as RenderBox?;
      final RenderBox? lastChipBox = lastChipContext?.findRenderObject() as RenderBox?;
      
      if (textFieldBox == null) {
        debugPrint("[ROW_MEASUREMENT] ❌ TextField box is null");
        return;
      }
      
      final Offset? wrapPos = wrapBox.localToGlobal(Offset.zero);
      if (wrapPos == null) {
        debugPrint("[ROW_MEASUREMENT] ❌ Wrap position is null");
        return;
      }
      
      final Offset? textFieldPos = textFieldBox.localToGlobal(Offset.zero);
      if (textFieldPos == null) {
        debugPrint("[ROW_MEASUREMENT] ❌ TextField position is null");
        return;
      }
      
      final double textFieldY = textFieldPos.dy - wrapPos.dy;
      final double textFieldX = textFieldPos.dx - wrapPos.dx;
      double textFieldWidth = textFieldBox.size.width;
      final double textFieldHeight = textFieldBox.size.height;
      
      // If width is 0, try to get it from constraints or find the actual rendered width
      if (textFieldWidth < 0.1) {
        // Check constraints
        if (textFieldBox.hasSize && textFieldBox.constraints.hasBoundedWidth) {
          textFieldWidth = textFieldBox.constraints.maxWidth;
        }
        
        // If still 0, try to find the actual width by visiting children
        double? actualWidth;
        textFieldBox.visitChildren((child) {
          if (child is RenderBox && child.hasSize) {
            if (child.size.width > 0.1) {
              actualWidth = child.size.width;
            }
          }
        });
        if (actualWidth != null) {
          textFieldWidth = actualWidth!;
        }
        
        // Last resort: check if there's a width constraint
        if (textFieldWidth < 0.1 && textFieldBox.constraints.hasBoundedWidth) {
          textFieldWidth = textFieldBox.constraints.maxWidth;
        }
      }
      
      debugPrint("[ROW_MEASUREMENT] TextField: measured width=$textFieldWidth, height=$textFieldHeight");
      debugPrint("[ROW_MEASUREMENT] TextField position: x=$textFieldX, y=$textFieldY (relative to wrap)");
      debugPrint("[ROW_MEASUREMENT] TextField constraints: ${textFieldBox.constraints}");
      if (textFieldBox.size.width < 0.1) {
        debugPrint("[ROW_MEASUREMENT] ⚠️  TextField RenderBox width is 0.0 - using fallback: $textFieldWidth");
      }
      
      // Collect all children and group them by row
      final Map<double, List<_ChildInfo>> rows = {};
      
      debugPrint("[ROW_MEASUREMENT] TextField box type: ${textFieldBox.runtimeType}");
      debugPrint("[ROW_MEASUREMENT] TextField box size: ${textFieldBox.size}");
      
      wrapBox.visitChildren((child) {
        if (child is RenderBox) {
          final Offset? childPos = child.localToGlobal(Offset.zero);
          if (childPos != null) {
            final double childY = childPos.dy - wrapPos.dy;
            final double childX = childPos.dx - wrapPos.dx;
            final double childWidth = child.size.width;
            final double childHeight = child.size.height;
            
            // Round Y to nearest 5px to group items on same row (accounting for small variations)
            final double rowY = (childY / 5.0).round() * 5.0;
            
            // Skip the text field box itself - we'll add it separately with correct measurements
            if (child == textFieldBox) {
              return; // Skip - we'll add it manually with correct measurements
            }
            
            final String childType = child.runtimeType.toString();
            final bool isChip = childType.contains('LayoutBuilder');
            
            // Only add non-zero width children (skip empty spacers)
            if (childWidth > 0.1) {
              rows.putIfAbsent(rowY, () => []).add(_ChildInfo(
                x: childX,
                y: childY,
                width: childWidth,
                height: childHeight,
                isTextField: false,
                isChip: isChip,
              ));
            }
          }
        }
      });
      
      // Calculate the text field width based on chips on ITS ROW, not all chips
      // This is the key fix - we need to know which row the text field is on
      // and only account for chips on that row
      
      // First, find which row the text field is on and which chips are on that row
      final double textFieldRowY = (textFieldY / 5.0).round() * 5.0;
      
      // Collect chips on the text field's row
      double chipsOnTextFieldRowWidth = 0.0;
      int chipsOnTextFieldRowCount = 0;
      
      wrapBox.visitChildren((child) {
        if (child is RenderBox && child != textFieldBox) {
          final Offset? childPos = child.localToGlobal(Offset.zero);
          if (childPos != null) {
            final double childY = childPos.dy - wrapPos.dy;
            final double childRowY = (childY / 5.0).round() * 5.0;
            
            // Check if this chip is on the same row as the text field
            if ((childRowY - textFieldRowY).abs() < 2.0) {
              final String childType = child.runtimeType.toString();
              if (childType.contains('LayoutBuilder')) {
                // This is a chip on the text field's row
                chipsOnTextFieldRowWidth += child.size.width;
                chipsOnTextFieldRowCount++;
              }
            }
          }
        }
      });
      
      // Calculate width based on chips on the text field's row only
      double actualTextFieldWidth;
      if (chipsOnTextFieldRowCount > 0) {
        // Calculate spacing: between chips on this row + before text field
        final double spacingBetweenChips = (chipsOnTextFieldRowCount - 1) * chipSpacing;
        final double spacingBeforeTextField = chipSpacing;
        final double totalSpacing = spacingBetweenChips + spacingBeforeTextField;
        
        final double usedWidth = chipsOnTextFieldRowWidth + totalSpacing;
        final double remainingWidth = wrapWidth - usedWidth;
        actualTextFieldWidth = remainingWidth.clamp(minTextFieldWidth, wrapWidth);
        
        debugPrint("[ROW_MEASUREMENT] Calculated width for row with ${chipsOnTextFieldRowCount} chip(s):");
        debugPrint("  Chips on row width: $chipsOnTextFieldRowWidth");
        debugPrint("  Spacing: $totalSpacing");
        debugPrint("  Used width: $usedWidth");
        debugPrint("  Remaining width: $remainingWidth");
        debugPrint("  TextField width: $actualTextFieldWidth");
      } else {
        // No chips on this row - text field should take full width
        actualTextFieldWidth = wrapWidth;
        debugPrint("[ROW_MEASUREMENT] No chips on text field's row - using full width: $actualTextFieldWidth");
      }
      
      debugPrint("[ROW_MEASUREMENT] Final TextField width used in calculation: $actualTextFieldWidth");
      
      // Store the calculated width so it can be used in the next build
      // This is the width the text field SHOULD be based on chips on its row
      if ((calculatedTextFieldWidthForRow == null || 
           (calculatedTextFieldWidthForRow! - actualTextFieldWidth).abs() > 1.0)) {
        calculatedTextFieldWidthForRow = actualTextFieldWidth;
        debugPrint("[ROW_MEASUREMENT] Storing calculatedTextFieldWidthForRow: $calculatedTextFieldWidthForRow");
        // Request rebuild to use this new width
        Future.microtask(() {
          requestRebuild();
        });
      }
      
      // Add the text field to the appropriate row using its known measurements
      // textFieldRowY is already defined above
      rows.putIfAbsent(textFieldRowY, () => []).add(_ChildInfo(
        x: textFieldX,
        y: textFieldY,
        width: actualTextFieldWidth,
        height: textFieldHeight,
        isTextField: true,
        isChip: false,
      ));
      
      // Sort rows by Y position
      final sortedRowYs = rows.keys.toList()..sort();
      
      debugPrint("[ROW_MEASUREMENT] Found ${rows.length} row(s)");
      debugPrint("[ROW_MEASUREMENT] TextField added to row at Y=$textFieldRowY");
      
      // Calculate space used and remaining for each row
      for (int i = 0; i < sortedRowYs.length; i++) {
        final double rowY = sortedRowYs[i];
        final List<_ChildInfo> children = rows[rowY]!;
        
        // Sort children by X position
        children.sort((a, b) => a.x.compareTo(b.x));
        
        debugPrint("─────────────────────────────────────────────────────────");
        debugPrint("[ROW_MEASUREMENT] Row $i (Y=$rowY):");
        
        double totalUsedWidth = 0.0;
        int chipCount = 0;
        bool hasTextField = false;
        double? textFieldWidthOnRow;
        
        for (final child in children) {
          final String type = child.isTextField ? "TextField" : (child.isChip ? "Chip" : "Other");
          debugPrint("  [$type] x=${child.x.toStringAsFixed(1)}, width=${child.width.toStringAsFixed(1)}");
          
          if (child.isTextField) {
            hasTextField = true;
            textFieldWidthOnRow = child.width;
          } else if (child.isChip) {
            chipCount++;
          }
          
          totalUsedWidth += child.width;
        }
        
        // Calculate spacing: between chips and before text field
        final int spacingCount = chipCount > 0 ? (hasTextField ? chipCount : chipCount - 1) : 0;
        final double totalSpacing = spacingCount * chipSpacing;
        final double totalUsedWithSpacing = totalUsedWidth + totalSpacing;
        final double remainingSpace = wrapWidth - totalUsedWithSpacing;
        
        debugPrint("  [Row $i Summary]");
        debugPrint("    Chips: $chipCount");
        debugPrint("    Has TextField: $hasTextField");
        if (textFieldWidthOnRow != null) {
          debugPrint("    TextField width: ${textFieldWidthOnRow.toStringAsFixed(1)}");
        }
        debugPrint("    Total chip+textfield width: ${totalUsedWidth.toStringAsFixed(1)}");
        debugPrint("    Spacing count: $spacingCount");
        debugPrint("    Total spacing: ${totalSpacing.toStringAsFixed(1)}");
        debugPrint("    Total used (width + spacing): ${totalUsedWithSpacing.toStringAsFixed(1)}");
        debugPrint("    Wrap width: $wrapWidth");
        debugPrint("    ⭐ REMAINING SPACE: ${remainingSpace.toStringAsFixed(1)} ⭐");
        
        if (remainingSpace.abs() > 1.0) {
          debugPrint("    ⚠️  WARNING: Remaining space should be close to 0!");
        }
      }
      
      debugPrint("═══════════════════════════════════════════════════════════");
      
      // Keep existing logic for now (but we'll see what the debug shows)
      if (lastChipBox != null) {
        final Offset? lastChipPos = lastChipBox.localToGlobal(Offset.zero);
        
        if (lastChipPos != null) {
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

/// Helper class for debug output - stores info about a child widget
class _ChildInfo {
  final double x;
  final double y;
  final double width;
  final double height;
  final bool isTextField;
  final bool isChip;
  
  _ChildInfo({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.isTextField,
    required this.isChip,
  });
}

