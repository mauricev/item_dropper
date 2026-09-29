import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  const original = ItemDropperItem<String>(value: 'a', label: 'Apple');
  const renamed = ItemDropperItem<String>(value: 'a', label: 'Apricot');
  for (final multi in [false, true]) {
    testWidgets(
      'parent updates selected label with unchanged value: multi=$multi',
      (tester) async {
        var selection = original;
        var changes = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return multi
                      ? MultiItemDropper<String>(
                          items: [selection],
                          selectedItems: [selection],
                          width: 300,
                          onChanged: (_) => changes++,
                        )
                      : SingleItemDropper<String>(
                          items: [selection],
                          selectedItem: selection,
                          width: 300,
                          onChanged: (_) => changes++,
                        );
                },
              ),
            ),
          ),
        );
        expect(find.text('Apple'), findsOneWidget);
        for (final replacement in [
          const ItemDropperItem<String>(value: 'a', label: 'APPLE'),
          renamed,
        ]) {
          rebuild(() => selection = replacement);
          await tester.pumpAndSettle();
          expect(find.text(replacement.label), findsOneWidget);
          expect(find.text('Apple'), findsNothing);
          expect(changes, 0);
        }
      },
    );
  }

  testWidgets(
    'single selecting a changed item with the same value publishes its content',
    (tester) async {
      var selection = original;
      final changes = <ItemDropperItem<String>?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleItemDropper<String>(
                items: const [original, renamed],
                selectedItem: selection,
                width: 300,
                onChanged: (item) {
                  changes.add(item);
                  setState(() => selection = item!);
                },
              ),
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.selection = const TextSelection.collapsed(offset: 0);
      field.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apricot'));
      await tester.pumpAndSettle();
      expect(changes, [renamed]);
      expect(field.controller!.text, 'Apricot');
      expect(selection, same(renamed));
    },
  );
}
