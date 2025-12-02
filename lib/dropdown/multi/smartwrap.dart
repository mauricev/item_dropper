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

  final double spacing;
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
      covariant _RenderSmartWrapWithFlexibleLast renderObject,
      ) {
    renderObject
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
    final maxWidth = constraints.maxWidth;

    double dx = 0.0;
    double dy = 0.0;
    double rowHeight = 0.0;

    RenderBox? child = firstChild;

    while (child != null) {
      final bool isLast = childAfter(child) == null;
      final parentData = child.parentData as _SmartWrapParentData;

      if (!isLast) {
        // Normal wrap behavior for all but the last child.
        child.layout(
          BoxConstraints(
            maxWidth: maxWidth,
          ),
          parentUsesSize: true,
        );
        final childSize = child.size;

        // Wrap to next line if needed.
        final double nextDx =
        dx == 0.0 ? childSize.width : dx + spacing + childSize.width;
        if (nextDx > maxWidth && dx != 0.0) {
          dx = 0.0;
          dy += rowHeight + runSpacing;
          rowHeight = 0.0;
        }

        // Place child.
        final double x = dx == 0.0 ? 0.0 : dx + spacing;
        parentData.offset = Offset(x, dy);
        dx = x + childSize.width;
        rowHeight = rowHeight > childSize.height ? rowHeight : childSize.height;
      } else {
        // Special logic for the last child.
        double x = dx;
        double availableWidth;

        if (dx == 0.0) {
          // Start of a new row already: give full width.
          x = 0.0;
          availableWidth = maxWidth;
        } else {
          // There are previous children on this row.
          final double xWithSpacing = dx + spacing;
          final double remaining = maxWidth - xWithSpacing;

          if (remaining >= minRemainingWidthForSameRow) {
            // Use remaining width on this row.
            x = xWithSpacing;
            availableWidth = remaining;
          } else {
            // Move to the next row and use full width.
            dx = 0.0;
            dy += rowHeight + runSpacing;
            rowHeight = 0.0;
            x = 0.0;
            availableWidth = maxWidth;
          }
        }

        child.layout(
          BoxConstraints(
            maxWidth: availableWidth,
          ),
          parentUsesSize: true,
        );
        final childSize = child.size;

        parentData.offset = Offset(x, dy);
        dx = x + childSize.width;
        rowHeight = rowHeight > childSize.height ? rowHeight : childSize.height;
      }

      child = childAfter(child);
    }

    final double width = maxWidth;
    final double height = dy + rowHeight;
    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth;

    double dx = 0.0;
    double dy = 0.0;
    double rowHeight = 0.0;

    RenderBox? child = firstChild;

    while (child != null) {
      final bool isLast = childAfter(child) == null;

      if (!isLast) {
        final childSize = child.getDryLayout(
          BoxConstraints(maxWidth: maxWidth),
        );

        final double nextDx =
        dx == 0.0 ? childSize.width : dx + spacing + childSize.width;
        if (nextDx > maxWidth && dx != 0.0) {
          dx = 0.0;
          dy += rowHeight + runSpacing;
          rowHeight = 0.0;
        }

        final double x = dx == 0.0 ? 0.0 : dx + spacing;
        dx = x + childSize.width;
        rowHeight = rowHeight > childSize.height ? rowHeight : childSize.height;
      } else {
        double x = dx;
        double availableWidth;

        if (dx == 0.0) {
          x = 0.0;
          availableWidth = maxWidth;
        } else {
          final double xWithSpacing = dx + spacing;
          final double remaining = maxWidth - xWithSpacing;

          if (remaining >= minRemainingWidthForSameRow) {
            x = xWithSpacing;
            availableWidth = remaining;
          } else {
            dx = 0.0;
            dy += rowHeight + runSpacing;
            rowHeight = 0.0;
            x = 0.0;
            availableWidth = maxWidth;
          }
        }

        final childSize = child.getDryLayout(
          BoxConstraints(maxWidth: availableWidth),
        );
        dx = x + childSize.width;
        rowHeight = rowHeight > childSize.height ? rowHeight : childSize.height;
      }

      child = childAfter(child);
    }

    final double width = maxWidth;
    final double height = dy + rowHeight;
    return constraints.constrain(Size(width, height));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
