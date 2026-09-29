import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/multi/multi_select_chip_focus_node_controller.dart';

class _Dependencies extends MultiItemDropperDependencies<String> {
  final nodes = MultiSelectChipFocusNodeController();

  @override
  MultiSelectChipFocusNodeController createChipFocusNodeController() => nodes;
}

void main() {
  const apple = ItemDropperItem<String>(value: 'a', label: 'Apple');
  const banana = ItemDropperItem<String>(value: 'b', label: 'Banana');
  const cherry = ItemDropperItem<String>(value: 'c', label: 'Cherry');
  for (final key in [LogicalKeyboardKey.backspace, LogicalKeyboardKey.delete]) {
    for (final scenario in ['replace', 'shrink', 'grow', 'clear']) {
      testWidgets('parent $scenario then ${key.keyLabel} uses current chips', (
        tester,
      ) async {
        final dependencies = _Dependencies();
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
                    selectedItems: selection,
                    width: 400,
                    dependencies: dependencies,
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
        await tester.tap(find.text('Banana'));
        await tester.pumpAndSettle();
        expect(dependencies.nodes.count, 2);
        final incoming = switch (scenario) {
          'replace' => [cherry, banana],
          'shrink' => [cherry],
          'grow' => [apple, banana, cherry],
          _ => <ItemDropperItem<String>>[],
        };
        rebuild(() => selection = incoming);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(changes, isEmpty);
        expect(dependencies.nodes.count, incoming.length);
        if (incoming.isEmpty) {
          await tester.tap(find.byType(TextField));
        } else {
          // Focus the displayed chip, whose index may refer to a different item now.
          await tester.tap(find.text('Cherry').first);
        }
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          changes,
          incoming.isEmpty
              ? isEmpty
              : [incoming.where((it) => it != cherry).toList()],
        );
      });
    }
  }
}
