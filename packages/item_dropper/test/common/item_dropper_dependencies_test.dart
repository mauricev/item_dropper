import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/multi/multi_select_filter_controller.dart';
import 'package:item_dropper/src/utils/item_dropper_filter_utils.dart';

class _FakeFilterUtils<T> extends ItemDropperFilterUtils<T> {
  _FakeFilterUtils(this.filteredItems);

  final List<ItemDropperItem<T>> filteredItems;

  @override
  List<ItemDropperItem<T>> getFiltered(
    List<ItemDropperItem<T>> items,
    String searchText, {
    bool isUserEditing = false,
    Set<T>? excludeValues,
  }) {
    return filteredItems;
  }
}

class _SingleDependencies<T> extends SingleItemDropperDependencies<T> {
  const _SingleDependencies(this.filterUtils);

  final ItemDropperFilterUtils<T> filterUtils;

  @override
  ItemDropperFilterUtils<T> createFilterUtils() {
    return filterUtils;
  }
}

class _MultiDependencies<T> extends MultiItemDropperDependencies<T> {
  const _MultiDependencies(this.filterUtils);

  final ItemDropperFilterUtils<T> filterUtils;

  @override
  MultiSelectFilterController<T> createFilterController() {
    return MultiSelectFilterController<T>(filterUtils: filterUtils);
  }
}

void main() {
  group('ItemDropper dependency injection', () {
    testWidgets('SingleItemDropper uses injected filter utils', (tester) async {
      final visibleItem = ItemDropperItem<String>(
        value: 'injected',
        label: 'Injected',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleItemDropper<String>(
              items: [
                ItemDropperItem(value: 'apple', label: 'Apple'),
                ItemDropperItem(value: 'banana', label: 'Banana'),
              ],
              onChanged: (_) {},
              width: 300,
              dependencies: _SingleDependencies(
                _FakeFilterUtils([visibleItem]),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SingleItemDropper<String>));
      await tester.pumpAndSettle();

      expect(find.text('Injected'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Banana'), findsNothing);
    });

    testWidgets('MultiItemDropper uses injected filter utils', (tester) async {
      final visibleItem = ItemDropperItem<String>(
        value: 'injected',
        label: 'Injected',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiItemDropper<String>(
              items: [
                ItemDropperItem(value: 'apple', label: 'Apple'),
                ItemDropperItem(value: 'banana', label: 'Banana'),
              ],
              onChanged: (_) {},
              width: 300,
              dependencies: _MultiDependencies(_FakeFilterUtils([visibleItem])),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MultiItemDropper<String>));
      await tester.pumpAndSettle();

      expect(find.text('Injected'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Banana'), findsNothing);
    });
  });
}
