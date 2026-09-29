import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  testWidgets(
    'arrow opens a newly populated list while the field stays focused',
    (tester) async {
      var items = <ItemDropperItem<String>>[];
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SingleItemDropper<String>(
                  items: items,
                  width: 300,
                  onChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pumpAndSettle();
      final focusNode = tester.widget<TextField>(field).focusNode!;
      expect(focusNode.hasFocus, isTrue);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      rebuild(
        () =>
            items = [const ItemDropperItem<String>(value: 'a', label: 'Apple')],
      );
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);
      expect(find.text('Apple'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_drop_up));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
