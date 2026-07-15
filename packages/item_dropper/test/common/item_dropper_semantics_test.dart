import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/item_dropper_localizations.dart';
import 'package:item_dropper/src/common/item_dropper_semantics.dart';

void main() {
  group('ItemDropperSemantics', () {
    const localizations = ItemDropperLocalizations(
      addItemPrefix: 'Create [',
      addItemSuffix: ']',
      selectedSuffix: ' chosen',
      itemSelectedSuffix: ' picked',
      itemRemovedSuffix: ' deleted',
      maxSelectionReachedPrefix: 'Limit ',
      maxSelectionReachedSuffix: ' reached',
      dropdownClosed: 'Menu closed',
    );

    test('uses English defaults when no localization is provided', () {
      expect(ItemDropperSemantics.formatAddItemLabel('Orange'), 'Add "Orange"');
      expect(
        ItemDropperSemantics.formatSelectedChipLabel('Apple'),
        'Apple, selected',
      );
      expect(
        ItemDropperSemantics.announceItemSelected('Apple'),
        'Apple selected',
      );
    });

    test('uses provided localizations for add item labels', () {
      final label = ItemDropperSemantics.formatAddItemLabel(
        'Orange',
        localizations: localizations,
      );

      expect(label, 'Create [Orange]');
      expect(
        ItemDropperSemantics.isAddItemLabel(
          label,
          localizations: localizations,
        ),
        isTrue,
      );
      expect(
        ItemDropperSemantics.extractSearchTextFromAddItemLabel(
          label,
          localizations: localizations,
        ),
        'Orange',
      );
    });

    test('uses provided localizations for announcements', () {
      expect(
        ItemDropperSemantics.formatSelectedChipLabel(
          'Apple',
          localizations: localizations,
        ),
        'Apple chosen',
      );
      expect(
        ItemDropperSemantics.announceItemSelected(
          'Apple',
          localizations: localizations,
        ),
        'Apple picked',
      );
      expect(
        ItemDropperSemantics.announceItemRemoved(
          'Apple',
          localizations: localizations,
        ),
        'Apple deleted',
      );
      expect(
        ItemDropperSemantics.announceMaxSelectionReached(
          3,
          localizations: localizations,
        ),
        'Limit 3 reached',
      );
      expect(
        ItemDropperSemantics.announceDropdownClosed(
          localizations: localizations,
        ),
        'Menu closed',
      );
    });
  });
}
