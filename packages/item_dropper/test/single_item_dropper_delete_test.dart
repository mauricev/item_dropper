import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  const apple = ItemDropperItem<String>(
    value: 'a',
    label: 'Apple',
    isDeletable: true,
  );
  const banana = ItemDropperItem<String>(value: 'b', label: 'Banana');

  testWidgets('ignores confirmation after the dropdown is disposed', (
    tester,
  ) async {
    var visible = true;
    late StateSetter rebuild;
    final deleted = <ItemDropperItem<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return visible
                  ? SingleItemDropper<String>(
                      items: [apple],
                      width: 300,
                      onChanged: (_) {},
                      onDeleteItem: deleted.add,
                    )
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Apple'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    rebuild(() => visible = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final selected in [false, true]) {
    for (final confirm in [false, true]) {
      for (final secondary in [false, true]) {
        testWidgets(
          'delete selected=$selected confirm=$confirm secondary=$secondary',
          (tester) async {
            var items = [apple, banana];
            ItemDropperItem<String>? selection = selected ? apple : banana;
            final deleted = <ItemDropperItem<String>>[];
            final changes = <ItemDropperItem<String>?>[];
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => SingleItemDropper<String>(
                      items: items,
                      selectedItem: selection,
                      width: 300,
                      onChanged: (item) {
                        changes.add(item);
                        setState(() => selection = item);
                      },
                      onDeleteItem: (item) {
                        deleted.add(item);
                        setState(
                          () => items = items
                              .where((it) => it.value != item.value)
                              .toList(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            final field = find.byType(TextField);
            await tester.tap(field);
            await tester.pumpAndSettle();
            final row = find.text('Apple').last;
            if (secondary) {
              await tester.tap(row, buttons: kSecondaryMouseButton);
            } else {
              await tester.longPress(row);
            }
            await tester.pumpAndSettle();
            expect(find.text('Delete "Apple"?'), findsOneWidget);
            expect(deleted, isEmpty);
            expect(changes, isEmpty);
            await tester.tap(find.text(confirm ? 'Delete' : 'Cancel'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(deleted, confirm ? [apple] : isEmpty);
            expect(changes, confirm && selected ? [null] : isEmpty);
            expect(
              tester.widget<TextField>(field).controller!.text,
              confirm && selected
                  ? ''
                  : selected
                  ? 'Apple'
                  : 'Banana',
            );
            await tester.tap(field);
            await tester.pumpAndSettle();
            expect(find.text('Apple'), confirm ? findsNothing : findsWidgets);
          },
        );
      }
    }
  }

  for (final mode in ['no callback', 'not deletable', 'disabled', 'group']) {
    testWidgets('does not offer deletion: $mode', (tester) async {
      final item = ItemDropperItem<String>(
        value: 'a',
        label: 'Apple',
        isDeletable: mode != 'not deletable',
        isEnabled: mode != 'disabled',
        isGroupHeader: mode == 'group',
      );
      final deleted = <ItemDropperItem<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: [item],
              width: 300,
              onChanged: (_) {},
              onDeleteItem: mode == 'no callback' ? null : deleted.add,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(deleted, isEmpty);
    });
  }
}
