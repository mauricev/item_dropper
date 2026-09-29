import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  for (final multi in [false, true]) {
    testWidgets('in-place changes refresh an active search: multi=$multi', (
      tester,
    ) async {
      final items = [
        const ItemDropperItem<String>(value: 'a', label: 'Apple'),
        const ItemDropperItem<String>(value: 'b', label: 'Banana'),
      ];
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return multi
                    ? MultiItemDropper<String>(
                        items: items,
                        width: 400,
                        onChanged: (_) {},
                      )
                    : SingleItemDropper<String>(
                        items: items,
                        width: 400,
                        showKeyboard: true,
                        onChanged: (_) {},
                      );
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Ap');
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      rebuild(
        () => items.add(
          const ItemDropperItem<String>(value: 'c', label: 'Apricot'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apricot'), findsOneWidget);

      // Same count and values, but different order, must refresh the cached result.
      rebuild(() => items.insert(0, items.removeLast()));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Apricot')).dy,
        lessThan(tester.getTopLeft(find.text('Apple')).dy),
      );

      // Replacing an item at the same index/value must refresh normalized labels.
      rebuild(
        () => items[0] = const ItemDropperItem<String>(
          value: 'c',
          label: 'Applesauce',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apricot'), findsNothing);
      expect(find.text('Applesauce'), findsOneWidget);

      rebuild(() => items.removeAt(1));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Applesauce'), findsOneWidget);
      rebuild(items.clear);
      await tester.pumpAndSettle();
      expect(find.text('Applesauce'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
