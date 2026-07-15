import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/utils/item_dropper_overlay_builder.dart';
import 'package:item_dropper/src/utils/item_dropper_overlay_content.dart';

void main() {
  group('ItemDropperOverlayContent', () {
    test('list content reports empty state', () {
      final content = ItemDropperListOverlayContent<String>(
        items: const [],
        isSelected: (_) => false,
        builder: (_, item, isSelected) => Text(item.label),
        itemHeight: 40,
      );

      expect(content.isEmpty, isTrue);
    });

    test('list content caps height by visible item count', () {
      final content = ItemDropperListOverlayContent<String>(
        items: [
          ItemDropperItem(value: 'a', label: 'A'),
          ItemDropperItem(value: 'b', label: 'B'),
          ItemDropperItem(value: 'c', label: 'C'),
        ],
        isSelected: (_) => false,
        builder: (_, item, isSelected) => Text(item.label),
        itemHeight: 40,
      );

      expect(content.maxHeightFor(100), 80);
      expect(content.maxHeightFor(200), 120);
    });

    test('widget content uses provided max height or requested height', () {
      const capped = ItemDropperWidgetOverlayContent<String>(
        child: Text('Loading'),
        maxHeight: 48,
      );
      const uncapped = ItemDropperWidgetOverlayContent<String>(
        child: Text('Loading'),
      );

      expect(capped.maxHeightFor(200), 48);
      expect(uncapped.maxHeightFor(200), 200);
    });

    testWidgets('overlay builder renders custom widget content', (
      tester,
    ) async {
      final layerLink = LayerLink();
      final scrollController = ScrollController();
      final fieldKey = GlobalKey();

      Widget buildHost({required bool includeOverlay}) {
        return MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CompositedTransformTarget(
                  link: layerLink,
                  child: SizedBox(
                    key: fieldKey,
                    width: 240,
                    height: 40,
                    child: const Text('Input'),
                  ),
                ),
                if (includeOverlay)
                  Builder(
                    builder: (_) {
                      return ItemDropperOverlayBuilder.buildContent<String>(
                        context: fieldKey.currentContext!,
                        content: const ItemDropperWidgetOverlayContent<String>(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Loading results'),
                          ),
                          maxHeight: 60,
                        ),
                        maxDropdownHeight: 200,
                        scrollController: scrollController,
                        layerLink: layerLink,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHost(includeOverlay: false));
      await tester.pumpWidget(buildHost(includeOverlay: true));
      await tester.pump();

      expect(find.text('Loading results'), findsOneWidget);

      scrollController.dispose();
    });
  });
}
