import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/utils/item_dropper_popup_item_builder.dart';

void main() {
  group('ItemDropperPopupItemBuilder', () {
    testWidgets('renders deletable item with delete icon', (tester) async {
      final item = ItemDropperItem<String>(
        value: 'apple',
        label: 'Apple',
        isDeletable: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ItemDropperPopupItemBuilder.build(context, item, false);
              },
            ),
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('renders disabled item with disabled text color', (
      tester,
    ) async {
      final item = ItemDropperItem<String>(
        value: 'apple',
        label: 'Apple',
        isEnabled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ItemDropperPopupItemBuilder.build(
                  context,
                  item,
                  false,
                  popupTextStyle: const TextStyle(fontSize: 18),
                );
              },
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Apple'));
      expect(text.style?.fontSize, 18);
      expect(text.style?.color, Colors.grey.shade400);
    });

    testWidgets('renders separator before group header when needed', (
      tester,
    ) async {
      final item = ItemDropperItem<String>(
        value: 'header',
        label: 'Fruit',
        isGroupHeader: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 40,
              width: 200,
              child: Builder(
                builder: (context) {
                  return ItemDropperPopupItemBuilder.build(
                    context,
                    item,
                    false,
                    hasPreviousItem: true,
                    previousItemIsGroupHeader: false,
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Fruit'), findsOneWidget);
      expect(find.byType(Positioned), findsOneWidget);
    });
  });
}
