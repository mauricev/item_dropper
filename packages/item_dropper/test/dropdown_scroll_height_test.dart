import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/utils/item_dropper_filter_utils.dart';

class _Unfiltered extends ItemDropperFilterUtils<int> {
  @override
  List<ItemDropperItem<int>> getFiltered(
    List<ItemDropperItem<int>> items,
    String searchText, {
    bool isUserEditing = false,
    Set<int>? excludeValues,
  }) => items;
}

class _Dependencies extends SingleItemDropperDependencies<int> {
  @override
  ItemDropperFilterUtils<int> createFilterUtils() => _Unfiltered();
}

void main() {
  final items = List.generate(
    20,
    (i) => ItemDropperItem<int>(value: i, label: 'Row $i'),
  );
  final popupList = find.descendant(
    of: find.byType(CompositedTransformFollower),
    matching: find.byType(ListView),
  );
  for (final explicit in [false, true]) {
    final height = explicit ? 64.0 : 76.0;
    final itemHeight = explicit ? height : null;
    const style = TextStyle(fontSize: 40, height: 1.5);
    for (final multi in [false, true]) {
      testWidgets(
        'keyboard scroll uses rendered height: explicit=$explicit multi=$multi',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: multi
                    ? MultiItemDropper<int>(
                        items: items,
                        width: 400,
                        maxDropdownHeight: height * 3,
                        itemHeight: itemHeight,
                        popupTextStyle: style,
                        onChanged: (_) {},
                      )
                    : SingleItemDropper<int>(
                        items: items,
                        width: 400,
                        maxDropdownHeight: height * 3,
                        itemHeight: itemHeight,
                        popupTextStyle: style,
                        onChanged: (_) {},
                      ),
              ),
            ),
          );
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();
          final controller = tester.widget<ListView>(popupList).controller!;
          for (var i = 0; i < 6; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
            await tester.pumpAndSettle();
          }
          expect(
            controller.offset,
            closeTo(7 * height - controller.position.viewportDimension, 0.01),
          );
          for (var i = 0; i < 4; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
            await tester.pumpAndSettle();
          }
          expect(controller.offset, closeTo(2 * height, 0.01));
        },
      );
    }

    testWidgets(
      'single centers selected row using rendered height: explicit=$explicit',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleItemDropper<int>(
                items: items,
                selectedItem: items[8],
                width: 400,
                maxDropdownHeight: height * 3,
                itemHeight: itemHeight,
                popupTextStyle: style,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        field.controller!.selection = const TextSelection.collapsed(offset: 0);
        field.focusNode!.requestFocus();
        await tester.pumpAndSettle();
        final controller = tester.widget<ListView>(popupList).controller!;
        expect(
          controller.offset,
          closeTo(
            8 * height - controller.position.viewportDimension / 2 + height / 2,
            0.01,
          ),
        );
      },
    );

    testWidgets(
      'single scrolls to search match using rendered height: explicit=$explicit',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleItemDropper<int>(
                items: items,
                width: 400,
                maxDropdownHeight: height * 3,
                showKeyboard: true,
                itemHeight: itemHeight,
                popupTextStyle: style,
                onChanged: (_) {},
                dependencies: _Dependencies(),
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Row 8');
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        final controller = tester.widget<ListView>(popupList).controller!;
        expect(controller.offset, closeTo(8 * height, 0.01));
      },
    );
  }
}
