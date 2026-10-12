import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

const fruits = [
  ItemDropperItem(value: 'apple', label: 'Apple'),
  ItemDropperItem(value: 'banana', label: 'Banana'),
];

Widget demo({
  bool searchEnabled = true,
  bool showKeyboard = false,
  bool enabled = true,
  ValueChanged<ItemDropperItem<String>?>? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SingleItemDropper<String>(
          items: fruits,
          width: 300,
          showKeyboard: showKeyboard,
          searchEnabled: searchEnabled,
          enabled: enabled,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'optional search preserves standard field height and toggle dimensions',
    (tester) async {
      await tester.pumpWidget(demo(searchEnabled: false));
      final field = find.byType(TextField);
      final standardFieldSize = tester.getSize(field);
      await tester.pumpWidget(demo());
      expect(tester.getSize(field), standardFieldSize);
      Finder button() =>
          find.widgetWithIcon(IconButton, Icons.keyboard_outlined);
      final fieldSize = tester.getSize(field);
      final buttonSize = tester.getSize(button());
      expect(buttonSize, const Size.square(32));
      void expectBorderSpacing() {
        final fieldRect = tester.getRect(field);
        final buttonRect = tester.getRect(button());
        expect(buttonRect.left - fieldRect.left, 5);
        expect(buttonRect.top - fieldRect.top, greaterThanOrEqualTo(5));
        expect(fieldRect.bottom - buttonRect.bottom, greaterThanOrEqualTo(5));
      }

      expectBorderSpacing();
      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_hide), findsNothing);

      await tester.tap(button());
      await tester.pump();
      expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.block), findsNothing);
      expect(find.byIcon(Icons.keyboard_hide), findsNothing);
      expect(tester.getSize(field), fieldSize);
      expect(tester.getSize(button()), buttonSize);
      await tester.pumpAndSettle();
      expect(tester.getSize(field), fieldSize);
      expect(tester.getSize(button()), buttonSize);
      expectBorderSpacing();

      await tester.tap(button());
      await tester.pump();
      expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(tester.getSize(field), fieldSize);
      expect(tester.getSize(button()), buttonSize);
      await tester.pumpAndSettle();
      expect(tester.getSize(field), fieldSize);
      expect(tester.getSize(button()), buttonSize);
      expectBorderSpacing();
    },
  );

  testWidgets(
    'browse without input, explicitly search, then reset on selection',
    (tester) async {
      ItemDropperItem<String>? selected;
      await tester.pumpWidget(demo(onChanged: (item) => selected = item));
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).readOnly, isTrue);
      expect(tester.widget<TextField>(field).showCursor, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);

      await tester.tap(find.byTooltip('Enable search keyboard'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).readOnly, isFalse);
      expect(tester.widget<TextField>(field).showCursor, isTrue);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(field, 'ban');
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Banana'), findsOneWidget);
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();
      expect(selected?.value, 'banana');
      expect(tester.widget<TextField>(field).readOnly, isTrue);
      expect(tester.widget<TextField>(field).showCursor, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byTooltip('Enable search keyboard'), findsOneWidget);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Apple'), findsOneWidget);
    },
  );

  testWidgets('hide keyboard and outside dismissal reset optional search', (
    tester,
  ) async {
    await tester.pumpWidget(demo());
    final field = find.byType(TextField);
    await tester.tap(find.byTooltip('Enable search keyboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide search keyboard'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).readOnly, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byTooltip('Enable search keyboard'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).readOnly, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('defaults and immediate typing remain compatible', (
    tester,
  ) async {
    await tester.pumpWidget(demo(searchEnabled: false));
    expect(find.byIcon(Icons.keyboard_outlined), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.pumpWidget(demo(showKeyboard: true));
    expect(find.byIcon(Icons.keyboard_outlined), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
  });

  testWidgets('disabled field cannot activate search', (tester) async {
    await tester.pumpWidget(demo(enabled: false));
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.keyboard_outlined),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
