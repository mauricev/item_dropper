import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/multi/multi_select_filter_controller.dart';

void main() {
  group('MultiSelectFilterController', () {
    late List<ItemDropperItem<String>> items;
    late MultiSelectFilterController<String> controller;

    setUp(() {
      items = [
        ItemDropperItem<String>(value: 'apple', label: 'Apple'),
        ItemDropperItem<String>(value: 'banana', label: 'Banana'),
        ItemDropperItem<String>(value: 'apricot', label: 'Apricot'),
      ];
      controller = MultiSelectFilterController<String>()
        ..initializeItems(items);
    });

    test('filters by search text and excludes selected values', () {
      final filtered = controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 1,
        selectedValues: {'apple'},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );

      expect(filtered.map((item) => item.label), ['Apricot']);
    });

    test(
      'adds add-item row when callback exists and no exact match exists',
      () {
        final filtered = controller.filteredItems(
          items: items,
          searchText: 'Orange',
          selectedCount: 0,
          selectedValues: const {},
          hasOnAddItemCallback: true,
          localizations: ItemDropperLocalizations.english,
        );

        expect(filtered.first.label, 'Add "Orange"');
        expect(filtered.first.value, 'apple');
      },
    );

    test('does not add add-item row for exact match', () {
      final filtered = controller.filteredItems(
        items: items,
        searchText: 'Apple',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: true,
        localizations: ItemDropperLocalizations.english,
      );

      expect(filtered.map((item) => item.label), ['Apple']);
    });

    test('returns cached result until invalidated', () {
      final first = controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );
      final second = controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );

      expect(second, same(first));

      controller.clearFilterCache();
      final third = controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );

      expect(third, isNot(same(first)));
    });
  });
}
