import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

class _Record {
  const _Record();
}

void main() {
  for (final multi in [false, true]) {
    for (final cancel in [false, true]) {
      testWidgets('create first item: multi=$multi, cancel=$cancel', (
        tester,
      ) async {
        final items = <ItemDropperItem<_Record>>[];
        final requests = <String>[];
        final changes = <List<ItemDropperItem<_Record>>>[];
        final created = ItemDropperItem<_Record>(
          value: const _Record(),
          label: 'Apple',
        );
        ItemDropperItem<_Record>? add(String text) {
          requests.add(text);
          if (cancel) return null;
          items.add(created);
          return created;
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: multi
                  ? MultiItemDropper<_Record>(
                      items: items,
                      width: 300,
                      onChanged: changes.add,
                      onAddItem: add,
                    )
                  : SingleItemDropper<_Record>(
                      items: items,
                      width: 300,
                      showKeyboard: true,
                      onChanged: (item) =>
                          changes.add([if (item != null) item]),
                      onAddItem: add,
                    ),
            ),
          ),
        );
        final field = find.byType(TextField);
        await tester.tap(field);
        await tester.pumpAndSettle();
        for (final text in ['A', 'Apple']) {
          await tester.enterText(field, text);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Add "$text"'), findsOneWidget);
          expect(requests, isEmpty);
          expect(changes, isEmpty);
        }
        await tester.tap(find.text('Add "Apple"'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(requests, ['Apple']);
        expect(
          changes,
          cancel
              ? isEmpty
              : [
                  [created],
                ],
        );
        if (!cancel) {
          expect(find.text('Apple'), findsWidgets);
          expect(changes.single.single.value, same(created.value));
        }
      });
    }
  }
}
