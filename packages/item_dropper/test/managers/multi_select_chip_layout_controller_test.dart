import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/item_dropper_common.dart';
import 'package:item_dropper/src/multi/multi_select_chip_layout_controller.dart';
import 'package:item_dropper/src/multi/multi_select_constants.dart';
import 'package:item_dropper/src/multi/multi_select_layout_calculator.dart';

void main() {
  group('MultiSelectChipLayoutController', () {
    test('uses calculated chip height before measurement', () {
      final controller = MultiSelectChipLayoutController();

      expect(
        controller.chipHeight(fontSize: 16),
        MultiSelectLayoutCalculator.calculateTextFieldHeight(
          fontSize: 16,
          chipVerticalPadding: MultiSelectConstants.kChipVerticalPadding,
        ),
      );
    });

    test('calculates fallback text field padding from chip structure', () {
      final controller = MultiSelectChipLayoutController();
      const fontSize = ItemDropperConstants.kDropdownItemFontSize;
      final chipHeight = controller.chipHeight(fontSize: fontSize);

      final padding = controller.textFieldPadding(
        chipHeight: chipHeight,
        fontSize: fontSize,
      );

      expect(padding.top, 6.0);
      expect(padding.bottom, 18.0);
    });

    testWidgets('records chip height after first rendered measurement', (
      tester,
    ) async {
      final controller = MultiSelectChipLayoutController();
      final rowKey = GlobalKey();
      late BuildContext chipContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Builder(
              builder: (context) {
                chipContext = context;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: MultiSelectConstants.kChipVerticalPadding,
                  ),
                  child: Row(
                    key: rowKey,
                    mainAxisSize: MainAxisSize.min,
                    children: const [Text('Apple')],
                  ),
                );
              },
            ),
          ),
        ),
      );

      controller.scheduleChipMeasurement(
        context: chipContext,
        rowKey: rowKey,
        isMounted: () => true,
      );

      expect(controller.hasMeasuredChip, isFalse);

      await tester.pump();

      expect(controller.hasMeasuredChip, isTrue);
      expect(controller.chipHeight(fontSize: 10), greaterThan(0));
    });

    testWidgets('notifies when measured container height changes', (
      tester,
    ) async {
      final controller = MultiSelectChipLayoutController();
      final fieldKey = GlobalKey();
      var height = 40.0;
      var notifications = 0;

      Future<void> pumpField() {
        return tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(key: fieldKey, width: 100, height: height),
            ),
          ),
        );
      }

      await pumpField();
      controller.scheduleContainerHeightMeasurement(
        fieldContext: fieldKey.currentContext,
        isMounted: () => true,
        isOverlayShowing: () => true,
        onHeightChanged: () => notifications++,
      );
      await tester.pump();

      controller.scheduleContainerHeightMeasurement(
        fieldContext: fieldKey.currentContext,
        isMounted: () => true,
        isOverlayShowing: () => true,
        onHeightChanged: () => notifications++,
      );
      height = 80.0;
      await pumpField();
      await tester.pump();

      expect(notifications, 1);
    });
  });
}
