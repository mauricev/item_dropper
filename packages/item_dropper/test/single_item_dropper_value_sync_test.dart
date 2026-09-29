import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  const apple = ItemDropperItem<String>(value: 'apple', label: 'Apple');
  const banana = ItemDropperItem<String>(value: 'banana', label: 'Banana');
  const items = [apple, banana];

  for (final focused in [false, true]) {
    testWidgets('parent clears selection and text (focused: $focused)', (
      tester,
    ) async {
      ItemDropperItem<String>? selection = apple;
      late StateSetter rebuild;
      final changes = <ItemDropperItem<String>?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SingleItemDropper<String>(
                  items: items,
                  selectedItem: selection,
                  width: 300,
                  onChanged: changes.add,
                );
              },
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller!.text, 'Apple');
      if (focused) {
        await tester.tap(field);
        await tester.pumpAndSettle();
      }
      rebuild(() => selection = null);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(changes, isEmpty);

      // A later rebuild must not restore the old text or selection.
      rebuild(() {});
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(changes, isEmpty);
    });
  }

  for (final scenario in ['omitted', 'null', 'initial value']) {
    testWidgets('unchanged parent selection preserves user choice ($scenario)', (
      tester,
    ) async {
      late StateSetter rebuild;
      final changes = <ItemDropperItem<String>?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return scenario != 'omitted'
                    ? SingleItemDropper<String>(
                        items: items,
                        selectedItem: scenario == 'initial value'
                            ? banana
                            : null,
                        width: 300,
                        onChanged: changes.add,
                      )
                    : SingleItemDropper<String>(
                        items: items,
                        width: 300,
                        onChanged: changes.add,
                      );
              },
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(changes, [apple]);

      rebuild(() {});
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'Apple');
      expect(changes, [apple]);

      // Clearing proves that the internal selection also survived rebuilding.
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(changes, [apple, null]);
    });
  }
}
