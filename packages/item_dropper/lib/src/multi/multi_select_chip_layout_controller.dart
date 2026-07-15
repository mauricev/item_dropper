import 'package:flutter/material.dart';
import 'package:item_dropper/src/multi/multi_select_constants.dart';
import 'package:item_dropper/src/multi/multi_select_layout_calculator.dart';

/// Coordinates measured chip layout values for the multi-select input.
class MultiSelectChipLayoutController {
  double? _chipHeight;
  double? _chipTextCenter;
  double? _lastContainerHeight;
  bool _chipMeasurementScheduled = false;
  _PendingChipMeasurement? _pendingChipMeasurement;

  bool get hasMeasuredChip => _chipHeight != null;

  double chipHeight({required double? fontSize}) {
    return _chipHeight ??
        MultiSelectLayoutCalculator.calculateTextFieldHeight(
          fontSize: fontSize,
          chipVerticalPadding: MultiSelectConstants.kChipVerticalPadding,
        );
  }

  ({double top, double bottom}) textFieldPadding({
    required double chipHeight,
    required double fontSize,
  }) {
    final double textLineHeight =
        fontSize * MultiSelectConstants.kTextLineHeightMultiplier;
    final double chipTextCenter =
        _chipTextCenter ?? _fallbackChipTextCenter(textLineHeight);

    final double top =
        chipTextCenter -
        (textLineHeight / 2.0) -
        MultiSelectConstants.kTextFieldPaddingOffset;
    final double bottom = chipHeight - textLineHeight - top;

    return (top: top, bottom: bottom);
  }

  void scheduleChipMeasurement({
    required BuildContext context,
    required GlobalKey rowKey,
    required bool Function() isMounted,
  }) {
    if (hasMeasuredChip) return;

    _pendingChipMeasurement = _PendingChipMeasurement(
      context: context,
      rowKey: rowKey,
      isMounted: isMounted,
    );

    if (_chipMeasurementScheduled) return;

    _chipMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chipMeasurementScheduled = false;

      final measurement = _pendingChipMeasurement;
      _pendingChipMeasurement = null;
      if (measurement == null || !measurement.isMounted() || hasMeasuredChip) {
        return;
      }

      final RenderBox? chipBox =
          measurement.context.findRenderObject() as RenderBox?;
      final RenderBox? rowBox =
          measurement.rowKey.currentContext?.findRenderObject() as RenderBox?;
      if (chipBox == null || rowBox == null) return;

      _chipHeight = chipBox.size.height;
      _chipTextCenter =
          MultiSelectConstants.kChipVerticalPadding + (rowBox.size.height / 2);
    });
  }

  void scheduleContainerHeightMeasurement({
    required BuildContext? fieldContext,
    required bool Function() isMounted,
    required bool Function() isOverlayShowing,
    required VoidCallback onHeightChanged,
  }) {
    if (fieldContext == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;

      final RenderBox? containerBox =
          fieldContext.findRenderObject() as RenderBox?;
      if (containerBox == null) return;

      final double newContainerHeight = containerBox.size.height;
      final bool heightChanged =
          _lastContainerHeight != null &&
          _lastContainerHeight != newContainerHeight;

      _lastContainerHeight = newContainerHeight;

      if (heightChanged && isOverlayShowing()) {
        onHeightChanged();
      }
    });
  }

  double _fallbackChipTextCenter(double textLineHeight) {
    final double rowContentHeight =
        textLineHeight > MultiSelectConstants.kIconHeight
        ? textLineHeight
        : MultiSelectConstants.kIconHeight;

    return MultiSelectConstants.kChipVerticalPadding + (rowContentHeight / 2.0);
  }
}

class _PendingChipMeasurement {
  final BuildContext context;
  final GlobalKey rowKey;
  final bool Function() isMounted;

  const _PendingChipMeasurement({
    required this.context,
    required this.rowKey,
    required this.isMounted,
  });
}
