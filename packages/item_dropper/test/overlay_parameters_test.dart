import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  const items = [
    ItemDropperItem<String>(value: 'a', label: 'Apple'),
    ItemDropperItem<String>(value: 'b', label: 'Banana'),
  ];
  final popupMaterial = find
      .descendant(
        of: find.byType(CompositedTransformFollower),
        matching: find.byType(Material),
      )
      .first;
  final popupScrollbar = find
      .descendant(
        of: find.byType(CompositedTransformFollower),
        matching: find.byType(Scrollbar),
      )
      .first;

  for (final multi in [false, true]) {
    testWidgets('overlay retains default settings: multi=$multi', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: multi
                ? MultiItemDropper<String>(
                    items: items,
                    width: 300,
                    onChanged: (_) {},
                  )
                : SingleItemDropper<String>(
                    items: items,
                    width: 300,
                    onChanged: (_) {},
                  ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(popupMaterial).elevation, 4);
      expect(tester.widget<Scrollbar>(popupScrollbar).thumbVisibility, isTrue);
      expect(tester.widget<Scrollbar>(popupScrollbar).thickness, 6);
    });

    testWidgets('overlay honors parameters and live updates: multi=$multi', (
      tester,
    ) async {
      late StateSetter rebuild;
      var elevation = 13.0;
      var showScrollbar = false;
      var thickness = 11.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return multi
                    ? MultiItemDropper<String>(
                        items: items,
                        width: 300,
                        onChanged: (_) {},
                        elevation: elevation,
                        showScrollbar: showScrollbar,
                        scrollbarThickness: thickness,
                      )
                    : SingleItemDropper<String>(
                        items: items,
                        width: 300,
                        onChanged: (_) {},
                        elevation: elevation,
                        showScrollbar: showScrollbar,
                        scrollbarThickness: thickness,
                      );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(popupMaterial).elevation, 13);
      expect(tester.widget<Scrollbar>(popupScrollbar).thumbVisibility, isFalse);
      expect(tester.widget<Scrollbar>(popupScrollbar).thickness, 11);
      rebuild(() {
        elevation = 0;
        showScrollbar = true;
        thickness = 3;
      });
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(popupMaterial).elevation, 0);
      expect(tester.widget<Scrollbar>(popupScrollbar).thumbVisibility, isTrue);
      expect(tester.widget<Scrollbar>(popupScrollbar).thickness, 3);
    });
  }

  for (final atMax in [false, true]) {
    testWidgets('multi information overlay honors elevation: atMax=$atMax', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: items,
              selectedItems: atMax ? [items.first] : [],
              maxSelected: atMax ? 1 : null,
              width: 300,
              elevation: 17,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      if (!atMax) {
        await tester.enterText(find.byType(TextField), 'No match');
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(popupMaterial).elevation, 17);
    });
  }
}
