import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  group('ItemDropperBase', () {
    final items = [
      ItemDropperItem<String>(value: 'apple', label: 'Apple'),
      ItemDropperItem<String>(value: 'banana', label: 'Banana'),
    ];

    test('SingleItemDropper exposes shared configuration contract', () {
      final inputKey = GlobalKey();
      final localizations = ItemDropperLocalizations.english;
      final dropper = SingleItemDropper<String>(
        items: items,
        selectedItem: items.first,
        onChanged: (_) {},
        hintText: 'Pick one',
        popupItemBuilder: (_, item, isSelected) => Text(item.label),
        width: 320,
        enabled: false,
        showKeyboard: true,
        onAddItem: (_) => null,
        onDeleteItem: (_) {},
        inputKey: inputKey,
        maxDropdownHeight: 240,
        elevation: 6,
        showScrollbar: false,
        scrollbarThickness: 3,
        fieldTextStyle: const TextStyle(fontSize: 16),
        popupTextStyle: const TextStyle(fontSize: 14),
        popupGroupHeaderStyle: const TextStyle(fontSize: 12),
        itemHeight: 44,
        fieldDecoration: const BoxDecoration(color: Colors.white),
        showDropdownPositionIcon: false,
        showDeleteAllIcon: false,
        localizations: localizations,
      );

      expect(dropper, isA<ItemDropperBase<String>>());

      final ItemDropperBase<String> base = dropper;
      expect(base.items, same(items));
      expect(base.hintText, 'Pick one');
      expect(base.width, 320);
      expect(base.enabled, isFalse);
      expect(base.inputKey, same(inputKey));
      expect(base.maxDropdownHeight, 240);
      expect(base.elevation, 6);
      expect(base.showScrollbar, isFalse);
      expect(base.scrollbarThickness, 3);
      expect(base.itemHeight, 44);
      expect(base.showDropdownPositionIcon, isFalse);
      expect(base.showDeleteAllIcon, isFalse);
      expect(base.localizations, same(localizations));
    });

    test('MultiItemDropper exposes shared configuration contract', () {
      final inputKey = GlobalKey<State<StatefulWidget>>();
      final localizations = ItemDropperLocalizations.english;
      final dropper = MultiItemDropper<String>(
        items: items,
        selectedItems: [items.first],
        onChanged: (_) {},
        popupItemBuilder: (_, item, isSelected) => Text(item.label),
        width: 360,
        enabled: false,
        hintText: 'Pick many',
        maxSelected: 2,
        onAddItem: (_) => null,
        onDeleteItem: (_) {},
        inputKey: inputKey,
        maxDropdownHeight: 260,
        showScrollbar: false,
        scrollbarThickness: 4,
        itemHeight: 48,
        popupTextStyle: const TextStyle(fontSize: 14),
        popupGroupHeaderStyle: const TextStyle(fontSize: 12),
        fieldTextStyle: const TextStyle(fontSize: 16),
        selectedChipDecoration: const BoxDecoration(color: Colors.blue),
        fieldDecoration: const BoxDecoration(color: Colors.white),
        elevation: 7,
        showDropdownPositionIcon: false,
        showDeleteAllIcon: false,
        localizations: localizations,
      );

      expect(dropper, isA<ItemDropperBase<String>>());

      final ItemDropperBase<String> base = dropper;
      expect(base.items, same(items));
      expect(base.hintText, 'Pick many');
      expect(base.width, 360);
      expect(base.enabled, isFalse);
      expect(base.inputKey, same(inputKey));
      expect(base.maxDropdownHeight, 260);
      expect(base.elevation, 7);
      expect(base.showScrollbar, isFalse);
      expect(base.scrollbarThickness, 4);
      expect(base.itemHeight, 48);
      expect(base.showDropdownPositionIcon, isFalse);
      expect(base.showDeleteAllIcon, isFalse);
      expect(base.localizations, same(localizations));
    });
  });
}
