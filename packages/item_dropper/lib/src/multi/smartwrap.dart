import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
class SmartWrapWithFlexibleLast extends MultiChildRenderObjectWidget {
  const SmartWrapWithFlexibleLast({
    super.key,
    required super.children,
    this.spacing = 0.0,
    this.runSpacing = 0.0,
    this.minRemainingWidthForSameRow = 100.0,
  });

  /// Horizontal space between children.
  final double spacing;

  /// Vertical space between rows.
  final double runSpacing;

  /// If the remaining width on the current row is at least this,
  /// the last child will be placed on that row and take the remaining width.
  /// Otherwise, it moves to the next row and takes the full width.
  final double minRemainingWidthForSameRow;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSmartWrapWithFlexibleLast(
      spacing: spacing,
      runSpacing: runSpacing,
      minRemainingWidthForSameRow: minRemainingWidthForSameRow,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context,
      covariant RenderObject renderObject,) {
    final _RenderSmartWrapWithFlexibleLast typedRenderObject = renderObject as _RenderSmartWrapWithFlexibleLast;
    typedRenderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..minRemainingWidthForSameRow = minRemainingWidthForSameRow;
  }
}

class _SmartWrapParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSmartWrapWithFlexibleLast extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SmartWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SmartWrapParentData> {
  _RenderSmartWrapWithFlexibleLast({
    required double spacing,
    required double runSpacing,
    required double minRemainingWidthForSameRow,
  })  : _spacing = spacing,
        _runSpacing = runSpacing,
        _minRemainingWidthForSameRow = minRemainingWidthForSameRow;

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  double _minRemainingWidthForSameRow;
  double get minRemainingWidthForSameRow => _minRemainingWidthForSameRow;
  set minRemainingWidthForSameRow(double value) {
    if (_minRemainingWidthForSameRow == value) return;
    _minRemainingWidthForSameRow = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SmartWrapParentData) {
      child.parentData = _SmartWrapParentData();
    }
  }

  @override
  void performLayout() {
    final double maxRowWidth = constraints.maxWidth;

    double currentRowX = 0.0;
    double currentRowY = 0.0;
    double currentRowHeight = 0.0;

    RenderBox? child = firstChild;

    while (child != null) {
      final bool isLastChildInList = childAfter(child) == null;
      final _SmartWrapParentData parentData =
      child.parentData as _SmartWrapParentData;

      if (!isLastChildInList) {
        // Normal wrap behavior for all but the last child.
        child.layout(
          BoxConstraints(
            maxWidth: maxRowWidth,
          ),
          parentUsesSize: true,
        );
        final Size childSize = child.size;

        // Where would the row end if we placed this child on the current row?
        final double proposedRowEndX = currentRowX == 0.0
            ? childSize.width
            : currentRowX + spacing + childSize.width;

        // If it doesn't fit and we already have something on this row,
        // move to a new row.
        if (proposedRowEndX > maxRowWidth && currentRowX != 0.0) {
          currentRowX = 0.0;
          currentRowY += currentRowHeight + runSpacing;
          currentRowHeight = 0.0;
        }

        // Final x position for this child on this row.
        final double childX = currentRowX == 0.0 ? 0.0 : currentRowX + spacing;
        parentData.offset = Offset(childX, currentRowY);

        currentRowX = childX + childSize.width;
        currentRowHeight =
        currentRowHeight > childSize.height ? currentRowHeight : childSize.height;
      } else {
        // Special logic for the last child in the *whole* widget.
        double childX = currentRowX;
        double availableWidthForLastChild;

        if (currentRowX == 0.0) {
          // We're already at the start of a new row: give it full width.
          childX = 0.0;
          availableWidthForLastChild = maxRowWidth;
        } else {
          // There are previous children on this row.
          final double childXWithSpacing = currentRowX + spacing;
          final double remainingWidthOnRow = maxRowWidth - childXWithSpacing;

          if (remainingWidthOnRow >= minRemainingWidthForSameRow) {
            // Use remaining width on this row.
            childX = childXWithSpacing;
            availableWidthForLastChild = remainingWidthOnRow;
          } else {
            // Move to the next row and use full width.
            currentRowX = 0.0;
            currentRowY += currentRowHeight + runSpacing;
            currentRowHeight = 0.0;

            childX = 0.0;
            availableWidthForLastChild = maxRowWidth;
          }
        }

        child.layout(
          BoxConstraints(
            maxWidth: availableWidthForLastChild,
          ),
          parentUsesSize: true,
        );
        final Size childSize = child.size;

        parentData.offset = Offset(childX, currentRowY);
        currentRowX = childX + childSize.width;
        currentRowHeight =
        currentRowHeight > childSize.height ? currentRowHeight : childSize.height;
      }

      child = childAfter(child);
    }

    final double layoutWidth = maxRowWidth;
    final double layoutHeight = currentRowY + currentRowHeight;
    size = constraints.constrain(Size(layoutWidth, layoutHeight));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double maxRowWidth = constraints.maxWidth;

    double currentRowX = 0.0;
    double currentRowY = 0.0;
    double currentRowHeight = 0.0;

    RenderBox? child = firstChild;

    while (child != null) {
      final bool isLastChildInList = childAfter(child) == null;

      if (!isLastChildInList) {
        final Size childSize =
        child.getDryLayout(BoxConstraints(maxWidth: maxRowWidth));

        final double proposedRowEndX = currentRowX == 0.0
            ? childSize.width
            : currentRowX + spacing + childSize.width;

        if (proposedRowEndX > maxRowWidth && currentRowX != 0.0) {
          currentRowX = 0.0;
          currentRowY += currentRowHeight + runSpacing;
          currentRowHeight = 0.0;
        }

        final double childX = currentRowX == 0.0 ? 0.0 : currentRowX + spacing;
        currentRowX = childX + childSize.width;
        currentRowHeight =
        currentRowHeight > childSize.height ? currentRowHeight : childSize.height;
      } else {
        double childX = currentRowX;
        double availableWidthForLastChild;

        if (currentRowX == 0.0) {
          childX = 0.0;
          availableWidthForLastChild = maxRowWidth;
        } else {
          final double childXWithSpacing = currentRowX + spacing;
          final double remainingWidthOnRow = maxRowWidth - childXWithSpacing;

          if (remainingWidthOnRow >= minRemainingWidthForSameRow) {
            childX = childXWithSpacing;
            availableWidthForLastChild = remainingWidthOnRow;
          } else {
            currentRowX = 0.0;
            currentRowY += currentRowHeight + runSpacing;
            currentRowHeight = 0.0;

            childX = 0.0;
            availableWidthForLastChild = maxRowWidth;
          }
        }

        final Size childSize = child.getDryLayout(
          BoxConstraints(maxWidth: availableWidthForLastChild),
        );
        currentRowX = childX + childSize.width;
        currentRowHeight =
        currentRowHeight > childSize.height ? currentRowHeight : childSize.height;
      }

      child = childAfter(child);
    }

    final double layoutWidth = maxRowWidth;
    final double layoutHeight = currentRowY + currentRowHeight;
    return constraints.constrain(Size(layoutWidth, layoutHeight));
  }

  @override
  bool hitTestChildren(
      BoxHitTestResult result, {
        required Offset position,
      }) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
