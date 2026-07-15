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
        expect(filtered.first.isAddItem, isTrue);
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

    test('cache key includes selected values when count is unchanged', () {
      final first = controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 1,
        selectedValues: {'apple'},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );
      final second = controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 1,
        selectedValues: {'apricot'},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );

      expect(first.map((item) => item.value), ['apricot']);
      expect(second.map((item) => item.value), ['apple']);
    });

    test('cache snapshots a mutable selected-values set', () {
      final selectedValues = {'apple'};
      controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 1,
        selectedValues: selectedValues,
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );

      selectedValues
        ..clear()
        ..add('apricot');
      final filtered = controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 1,
        selectedValues: selectedValues,
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );

      expect(filtered.map((item) => item.value), ['apple']);
    });

    test('cache key includes add-item callback availability', () {
      final withoutAddItem = controller.filteredItems(
        items: items,
        searchText: 'Orange',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );
      final withAddItem = controller.filteredItems(
        items: items,
        searchText: 'Orange',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: true,
        localizations: ItemDropperLocalizations.english,
      );

      expect(withoutAddItem, isEmpty);
      expect(withAddItem.single.isAddItem, isTrue);
    });

    test('cache key includes localized add-item delimiters', () {
      final english = controller.filteredItems(
        items: items,
        searchText: 'Orange',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: true,
        localizations: ItemDropperLocalizations.english,
      );
      const localized = ItemDropperLocalizations(
        addItemPrefix: 'Create [',
        addItemSuffix: ']',
      );
      final translated = controller.filteredItems(
        items: items,
        searchText: 'Orange',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: true,
        localizations: localized,
      );

      expect(english.single.label, 'Add "Orange"');
      expect(translated.single.label, 'Create [Orange]');
    });

    test('cache key includes item-list identity', () {
      final first = controller.filteredItems(
        items: items,
        searchText: 'ap',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );
      final replacementItems = [
        ItemDropperItem<String>(value: 'application', label: 'Application'),
      ];
      final second = controller.filteredItems(
        items: replacementItems,
        searchText: 'ap',
        selectedCount: 0,
        selectedValues: const {},
        hasOnAddItemCallback: false,
        localizations: ItemDropperLocalizations.english,
      );

      expect(first.length, 2);
      expect(second.single.value, 'application');
    });
  });
}
