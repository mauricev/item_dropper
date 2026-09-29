import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  const apple = ItemDropperItem<String>(value: 'a', label: 'Apple');
  const banana = ItemDropperItem<String>(value: 'b', label: 'Banana');
  const cherry = ItemDropperItem<String>(value: 'c', label: 'Cherry');
  const reached = 'Reached maximum allowed items';
  for (final limits in [(1, 2), (1, null), (null, 1), (3, 1)]) {
    testWidgets('maxSelected updates from ${limits.$1} to ${limits.$2}', (
      tester,
    ) async {
      int? maximum = limits.$1;
      var selection = [apple];
      final changes = <List<ItemDropperItem<String>>>[];
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return MultiItemDropper<String>(
                  items: const [apple, banana, cherry],
                  width: 400,
                  selectedItems: selection,
                  maxSelected: maximum,
                  onChanged: (items) {
                    changes.add(items);
                    setState(() => selection = items);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      rebuild(() => maximum = limits.$2);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(find.text('Apple'), findsOneWidget);
      if (maximum == 1) {
        expect(find.text(reached), findsOneWidget);
        expect(find.text('Banana'), findsNothing);
      } else {
        expect(find.text(reached), findsNothing);
        await tester.tap(find.text('Banana'));
        await tester.pumpAndSettle();
        expect(changes, [
          [apple, banana],
        ]);
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        if (maximum == null) {
          await tester.tap(find.text('Cherry'));
          await tester.pumpAndSettle();
          expect(changes.last, [apple, banana, cherry]);
        } else {
          expect(find.text(reached), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'lowering the limit preserves existing chips and permits removal',
    (tester) async {
      var maximum = 3;
      var selection = [apple, banana];
      final changes = <List<ItemDropperItem<String>>>[];
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return MultiItemDropper<String>(
                  items: const [apple, banana, cherry],
                  width: 400,
                  selectedItems: selection,
                  maxSelected: maximum,
                  onChanged: (items) {
                    changes.add(items);
                    setState(() => selection = items);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      rebuild(() => maximum = 1);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(selection, [apple, banana]);
      expect(find.text(reached), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(changes.last, [banana]);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(changes.last, isEmpty);
      expect(find.text(reached), findsNothing);
      await tester.tap(find.text('Cherry'));
      await tester.pumpAndSettle();
      expect(changes.last, [cherry]);
    },
  );
}
