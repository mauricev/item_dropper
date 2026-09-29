import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  for (final controlled in [false, true]) {
    for (final secondLabel in ['Same', ' SAME ']) {
      testWidgets(
        'preserves picked identity: controlled=$controlled label="$secondLabel"',
        (tester) async {
          final items = [
            const ItemDropperItem<int>(value: 1, label: 'Same'),
            ItemDropperItem<int>(value: 2, label: secondLabel),
          ];
          final changes = <int?>[];
          ItemDropperItem<int>? selected;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    void onChanged(ItemDropperItem<int>? item) {
                      changes.add(item?.value);
                      if (controlled) setState(() => selected = item);
                    }

                    return controlled
                        ? SingleItemDropper<int>(
                            items: items,
                            selectedItem: selected,
                            width: 300,
                            onChanged: onChanged,
                          )
                        : SingleItemDropper<int>(
                            items: items,
                            width: 300,
                            onChanged: onChanged,
                          );
                  },
                ),
              ),
            ),
          );
          final field = find.byType(TextField);
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.text(secondLabel).last);
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
          expect(changes, [2]);
          expect(tester.widget<TextField>(field).controller!.text, secondLabel);

          // A later focus/blur cycle must retain the same item's identity too.
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.arrow_drop_up));
          await tester.pumpAndSettle();
          expect(changes, [2]);
          expect(tester.widget<TextField>(field).controller!.text, secondLabel);

          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.clear));
          await tester.pumpAndSettle();
          expect(changes, [2, null]);
          expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        },
      );
    }
  }
}
